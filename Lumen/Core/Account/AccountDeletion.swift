import Foundation
import Observation
import UserNotifications
import WidgetKit

/// A145 (Ke78, Apple 5.1.1(v), Kevin's K101): "Radera konto" in Inställningar. The server deletes the account and
/// everything that belongs to it (`POST /functions/v1/account/delete` with `{"confirm": true}`); then the phone forgets
/// everything too, and the app starts as new, with a new anonymous account.
@MainActor
protocol AccountDeleting: AnyObject {
    func deleteAccount() async -> Result<AccountDeletionReply, AccountDeletionFailure>
}

/// K101's answer. `notice` comes when the weekly pass is active: Apple ends it, not we.
struct AccountDeletionReply: Decodable, Equatable, Sendable {
    var deleted: Bool
    var notice: String?
}

enum AccountDeletionFailure: Error, Equatable, Sendable {
    /// No network: the request never left the phone.
    case offline
    /// K101 takes at most 3 a minute.
    case busy
    /// Anything else (a timeout, a server error). The deletion may or may not have happened; trying again is safe,
    /// because K101 answers 200 for an account that is already gone.
    case failed(String)
}

@MainActor
final class AccountClient: AccountDeleting {
    let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func deleteAccount() async -> Result<AccountDeletionReply, AccountDeletionFailure> {
        for attempt in 1...2 {
            let token: String
            do {
                token = try await auth.accessToken()
            } catch {
                return .failure(Self.failure(error))
            }
            var request = URLRequest(url: config.accountDeleteURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = Data(#"{"confirm":true}"#.utf8)
            let response: HTTPURLResponse
            let data: Data
            do {
                (response, data) = try await http.data(for: request)
            } catch {
                Log.answer.error("Account: delete failed: \(error.localizedDescription, privacy: .public)")
                return .failure(Self.failure(error))
            }
            switch response.statusCode {
            case 200:
                guard let reply = try? JSONDecoder().decode(AccountDeletionReply.self, from: data), reply.deleted else {
                    return .failure(.failed("unexpected reply"))
                }
                return .success(reply)
            case 401 where attempt == 1:
                auth.invalidate() // A143: the token is renewed, the account is the same; once more
                continue
            case 429:
                return .failure(.busy)
            default:
                let failure = AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode)
                Log.answer.error("Account: delete answered HTTP \(response.statusCode, privacy: .public) (\(failure.code, privacy: .public))")
                return .failure(.failed("\(failure.code) (HTTP \(response.statusCode))"))
            }
        }
        return .failure(.failed("unauthorized"))
    }

    nonisolated static func failure(_ error: any Error) -> AccountDeletionFailure {
        switch AnswerError.from(error) {
        case .offline: .offline
        case let other: .failed(other.localizedDescription)
        }
    }
}

/// Everything the app keeps on the phone, so that after the deletion nothing of the old account is left and the app
/// starts as on a new install: the files in the app's own folders, the settings, the sign-in in the Keychain, the
/// widget's snapshot, and the reminders that are waiting.
@MainActor
struct LocalWipe {
    /// The contents are removed; the folders themselves stay (iOS owns them).
    var folders: [URL]
    /// Each `UserDefaults` with the domain name to remove.
    var defaults: [(UserDefaults, String)]
    var session: any SessionStore
    /// The reminders and the widget (system calls; nothing in the tests).
    var system: @MainActor () -> Void = {}

    static func live() -> LocalWipe {
        let files = FileManager.default
        let folders = [FileManager.SearchPathDirectory.applicationSupportDirectory, .documentDirectory, .cachesDirectory]
            .compactMap { files.urls(for: $0, in: .userDomainMask).first } + [files.temporaryDirectory]
        var defaults: [(UserDefaults, String)] = [(.standard, Bundle.main.bundleIdentifier ?? "com.rsolutions.lumen")]
        if let group = UserDefaults(suiteName: ExamWidgetSnapshot.appGroup) { defaults.append((group, ExamWidgetSnapshot.appGroup)) }
        return LocalWipe(folders: folders, defaults: defaults, session: KeychainSessionStore()) {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Returns how many files and folders were removed (for the log).
    @discardableResult
    func run() -> Int {
        var removed = 0
        let files = FileManager.default
        for folder in folders {
            let items = (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for item in items where (try? files.removeItem(at: item)) != nil { removed += 1 }
        }
        for (store, domain) in defaults {
            store.removePersistentDomain(forName: domain)
        }
        session.clear()
        system()
        Log.answer.info("Account: the phone forgot the account (\(removed, privacy: .public) files and folders removed)")
        return removed
    }
}

/// The deletion as Inställningar sees it: one press after the question, then the server, then the phone.
@MainActor
@Observable
final class AccountDeletionModel {
    enum State: Equatable {
        case idle
        case deleting
        case failed(String)
    }

    private(set) var state: State = .idle
    @ObservationIgnored private let client: any AccountDeleting
    @ObservationIgnored private let wipe: @MainActor () -> Void
    @ObservationIgnored private let stopEverything: @MainActor () async -> Void
    /// The app starts as new; the notice (the weekly pass) is said on the new start.
    @ObservationIgnored var onDeleted: (@MainActor (String?) -> Void)?

    init(client: any AccountDeleting, wipe: @escaping @MainActor () -> Void,
         stopEverything: @escaping @MainActor () async -> Void) {
        self.client = client
        self.wipe = wipe
        self.stopEverything = stopEverything
    }

    var isDeleting: Bool { state == .deleting }

    var failureLine: String? {
        switch state {
        case .failed(let line): line
        case .idle, .deleting: nil
        }
    }

    /// Nothing on the phone is touched until the server has said the account is deleted.
    func delete() async {
        guard state != .deleting else { return }
        state = .deleting
        switch await client.deleteAccount() {
        case .success(let reply):
            Log.answer.info("Account: deleted on the server; the phone forgets it and the app starts as new")
            await stopEverything()
            wipe()
            state = .idle
            onDeleted?(reply.notice)
        case .failure(let failure):
            state = .failed(Self.line(failure))
        }
    }

    func dismissFailure() {
        if case .failed = state { state = .idle }
    }

    nonisolated static func line(_ failure: AccountDeletionFailure) -> String {
        switch failure {
        case .offline: "Det gick inte att radera kontot, för telefonen har inget nät. Inget är raderat. Försök igen när du är uppkopplad."
        case .busy: "För många försök. Vänta en minut och försök igen."
        case .failed: "Det gick inte att radera kontot just nu. Försök igen om en stund."
        }
    }

    /// The words before the press (Deangelo, A145).
    nonisolated static let question = "Radera kontot?"
    nonisolated static let questionDetail = "Allt du har gjort raderas, både på telefonen och hos oss: prov, texter, ljud, krediter, historik och inställningar. Det går inte att ångra."
    nonisolated static let passLine = "Har du veckokortet? Det avslutas inte när kontot raderas. Säg upp det i Inställningar › ditt namn › Prenumerationer."
    nonisolated static let doneTitle = "Kontot är raderat"
    nonisolated static let doneLine = "EarMind börjar om som ny på den här telefonen."
}
