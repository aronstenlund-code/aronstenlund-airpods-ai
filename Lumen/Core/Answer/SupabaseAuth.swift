import Foundation
import Security
import UIKit

/// An anonymous Supabase session (`POST /auth/v1/signup` with `{}`); refreshed with the refresh token.
struct SupabaseSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    func isValid(at date: Date, margin: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(date) > margin
    }
}

protocol SessionStore: AnyObject, Sendable {
    func load() -> SupabaseSession?
    func save(_ session: SupabaseSession)
    func clear()
}

/// Keychain-backed store (the session token is a credential for our backend; never UserDefaults).
final class KeychainSessionStore: SessionStore {
    private let service: String
    private let account = "anonymous-session"

    init(service: String = "com.rsolutions.lumen.supabase") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> SupabaseSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            // T55: "no account here" is the ordinary answer on a new install. Anything else means the keychain cannot
            // be read (an unsigned build in the Simulator, a locked phone), and the app then signs up a new account.
            if status != errSecItemNotFound {
                Log.answer.error("Auth: the keychain could not be read (status \(status, privacy: .public)); the app will sign in as a new account")
            }
            return nil
        }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    func save(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
        if status != errSecSuccess {
            // T55: an account that is not kept is a new account (and new credits) at the next start.
            Log.answer.error("Auth: the keychain did not keep the session (status \(status, privacy: .public)); the next start will be a new account")
        }
    }

    func clear() {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }
}

final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    // @unchecked: only touched from the main actor in the app and in tests.
    private var session: SupabaseSession?
    init(_ session: SupabaseSession? = nil) { self.session = session }
    func load() -> SupabaseSession? { session }
    func save(_ session: SupabaseSession) { self.session = session }
    func clear() { session = nil }
}

/// Signs in anonymously and keeps the token fresh (`backend/README.md` "Connect the app").
///
/// A143 (D225 point 4, D228): nothing the user does may wait for the sign-in.
/// - The sign-in starts when the app opens (`prepare`), and the token is renewed ahead of time when the app opens or
///   comes back with less than `renewAhead` left, so Spela finds a token that is already there.
/// - A call to the auth server that gets no answer is given up after `requestTimeout` (the system's own limit is 60 s)
///   and tried once more.
/// - The account is only ever replaced by a new anonymous one when the server refuses the refresh token. A 401 from
///   our own functions and a server error or rate limit during the refresh keep the account (before A143 both made a
///   new anonymous user, and the old one's exams and credits stayed with the old one).
/// - Every sign-in, renewal and wait is logged with its time ("Auth: …").
@MainActor
final class SupabaseAuth {
    /// How long a sign-up or a refresh may go without an answer. Shorter than the 10 s Supabase accepts a refresh token
    /// a second time, so the one retry also saves a refresh whose answer was lost on the way.
    nonisolated static let requestTimeout: TimeInterval = 8
    /// The token is renewed in the background when less than this is left of it.
    nonisolated static let renewAhead: TimeInterval = 300

    let config: BackendConfig
    private let store: any SessionStore
    private let http: any HTTPStreaming
    private let now: @Sendable () -> Date
    private var session: SupabaseSession?
    /// The running sign-in or refresh, shared by everyone who needs a token meanwhile.
    private var renewal: Task<String, any Error>?
    private var foregroundObserver: (any NSObjectProtocol)?

    init(config: BackendConfig, store: any SessionStore, http: any HTTPStreaming, now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.store = store
        self.http = http
        self.now = now
        self.session = store.load()
        #if LUMEN_TESTMODE
        // Toby T55: which account the app starts as, so a test can see whether a restart kept it. Debug and Beta only.
        Log.answer.notice("Auth: at start the account on this phone is \(Self.accountMark(self.session), privacy: .public)")
        #endif
    }

    /// Toby T55 (2026-11-19): the first characters of the account's id, enough to see in a log whether the app is the
    /// same account before and after a restart. Never the whole id, never the token. "none" without an account.
    nonisolated static func accountMark(_ session: SupabaseSession?) -> String {
        guard let session else { return "none" }
        return userID(fromJWT: session.accessToken).map { String($0.prefix(8)) } ?? "unreadable"
    }

    var hasSession: Bool { session != nil }

    /// Toby 2 T24: the signed-in (anonymous) user, the `sub` of the access token. Nil without a session.
    var userID: String? { session.flatMap { Self.userID(fromJWT: $0.accessToken) } }

    nonisolated static func userID(fromJWT token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = claims["sub"] as? String, !sub.isEmpty else { return nil }
        return sub
    }

    /// A145: the account was deleted and the app starts again with a new container. This one never signs in again,
    /// so nothing left of the old app makes a stray anonymous account or reaches the server.
    private var isRetired = false

    func retire() {
        isRetired = true
        renewal?.cancel()
        session = nil
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        foregroundObserver = nil
    }

    /// A valid access token: cached, refreshed, or from a fresh anonymous sign-up.
    func accessToken() async throws(AnswerError) -> String {
        if isRetired { throw .unauthorized(detail: "the account was deleted") }
        if let session, session.isValid(at: now()) {
            return session.accessToken
        }
        // The voices and the warm-up run together at launch: one sign-in, not one anonymous user per caller.
        let clock = ContinuousClock()
        let asked = clock.now
        let task = startRenewal()
        do {
            let token = try await task.value
            Log.answer.info("Auth: a call waited \(Self.seconds(asked.duration(to: clock.now)), privacy: .public) s for the token")
            return token
        } catch {
            let failure = AnswerError.from(error)
            Log.answer.error("Auth: a call got no token after \(Self.seconds(asked.duration(to: clock.now)), privacy: .public) s: \(failure.localizedDescription, privacy: .public)")
            throw failure
        }
    }

    /// A143: the app opened or came back. The sign-in (a new install) or the renewal (the token has run out, or has
    /// less than `renewAhead` left) starts now, in the background, so that the first thing the user does finds a token.
    func prepare() {
        guard !isRetired else { return }
        if let session, session.isValid(at: now(), margin: Self.renewAhead) { return }
        guard renewal == nil else { return }
        if let session {
            let left = Int(session.expiresAt.timeIntervalSince(now()))
            Log.answer.info("Auth: renewing the token when the app opens (\(max(0, left), privacy: .public) s left of it)")
        } else {
            Log.answer.info("Auth: signing in when the app opens (no account on this phone yet)")
        }
        _ = startRenewal()
    }

    /// A143: from now on the token is also looked at every time the app comes back.
    func watchForeground() {
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                    object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.prepare() }
        }
    }

    private func startRenewal() -> Task<String, any Error> {
        if let renewal { return renewal }
        let task = Task { [self] in
            defer { renewal = nil }
            return try await renewToken()
        }
        renewal = task
        return task
    }

    private func renewToken() async throws(AnswerError) -> String {
        if let session, !session.refreshToken.isEmpty {
            do {
                return try await refresh(session).accessToken
            } catch {
                // Refresh token refused → start over with a new anonymous user. Offline, a timeout, a server error and
                // a rate limit keep the session (A143: `perform` says "unauthorized" only when the token is refused).
                guard case .unauthorized = AnswerError.from(error) else { throw AnswerError.from(error) }
                // Toby 2 T24: a new anonymous user cannot see the old one's exams; said in the log, never silent.
                Log.answer.error("Auth: the refresh token was refused, signing up a new anonymous user (the old one's server data stays with it)")
                discard()
            }
        }
        return try await signUp().accessToken
    }

    /// One of our functions answered 401: the access token is not accepted. It is not used again, and the next call
    /// renews it with the refresh token. A143: the account stays. Before, the session was thrown away here, and the
    /// next call made a new anonymous user without ever trying the refresh token.
    func invalidate() {
        guard var stale = session else { return }
        Log.answer.error("Auth: the server did not accept the access token (401); it is renewed before the next call")
        stale.expiresAt = .distantPast
        session = stale
        store.save(stale)
    }

    /// The server refused the refresh token: this phone's account cannot be reached any more.
    private func discard() {
        session = nil
        store.clear()
    }

    private func signUp() async throws(AnswerError) -> SupabaseSession {
        var request = URLRequest(url: config.signUpURL)
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return try await perform(request, .signUp)
    }

    private func refresh(_ old: SupabaseSession) async throws(AnswerError) -> SupabaseSession {
        var request = URLRequest(url: config.refreshURL)
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["refresh_token": old.refreshToken])
        return try await perform(request, .refresh)
    }

    private enum Call: String {
        case signUp = "sign-up"
        case refresh = "refresh"
    }

    /// The statuses with which Supabase Auth refuses a refresh token (not found, already used, the session or the user
    /// is gone). Everything else that is not a success (429, 5xx) is the server's trouble, and the account is kept.
    nonisolated static func refusesTheRefreshToken(_ status: Int) -> Bool {
        [400, 401, 403, 404].contains(status)
    }

    nonisolated static func seconds(_ duration: Duration) -> String {
        let value = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return String(format: "%.2f", value)
    }

    private func perform(_ original: URLRequest, _ call: Call) async throws(AnswerError) -> SupabaseSession {
        var request = original
        request.timeoutInterval = Self.requestTimeout
        let clock = ContinuousClock()
        var attempt = 0
        while true {
            attempt += 1
            let started = clock.now
            let response: HTTPURLResponse
            let data: Data
            do {
                (response, data) = try await http.data(for: request)
            } catch {
                let failure = AnswerError.from(error)
                let took = Self.seconds(started.duration(to: clock.now))
                // A143: no answer at all (a connection that never got through). Once more, at once: the first try
                // cost at most `requestTimeout`, not the system's 60 s.
                if (error as? URLError)?.code == .timedOut, attempt == 1 {
                    Log.answer.error("Auth: \(call.rawValue, privacy: .public) got no answer in \(took, privacy: .public) s, trying once more")
                    continue
                }
                Log.answer.error("Auth: \(call.rawValue, privacy: .public) failed after \(took, privacy: .public) s: \(failure.localizedDescription, privacy: .public)")
                throw failure
            }
            let took = Self.seconds(started.duration(to: clock.now))
            guard (200..<300).contains(response.statusCode) else {
                let failure = AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode)
                Log.answer.error("Auth: \(call.rawValue, privacy: .public) answered HTTP \(response.statusCode, privacy: .public) (\(failure.code, privacy: .public)) after \(took, privacy: .public) s")
                if call == .refresh, !Self.refusesTheRefreshToken(response.statusCode) {
                    throw AnswerError.backend(status: response.statusCode, failure: failure)
                }
                throw AnswerError.unauthorized(detail: "\(failure.code)\(failure.message.map { " — \($0)" } ?? "") (HTTP \(response.statusCode))")
            }
            struct TokenResponse: Decodable {
                var access_token: String
                var refresh_token: String?
                var expires_in: Double?
                var expires_at: Double?
            }
            let token: TokenResponse
            do {
                token = try JSONDecoder().decode(TokenResponse.self, from: data)
            } catch {
                throw AnswerError.decoding(detail: "auth: \(error.localizedDescription)")
            }
            let expiresAt: Date = if let at = token.expires_at {
                Date(timeIntervalSince1970: at)
            } else {
                now().addingTimeInterval(token.expires_in ?? 3600)
            }
            let newSession = SupabaseSession(accessToken: token.access_token, refreshToken: token.refresh_token ?? "", expiresAt: expiresAt)
            session = newSession
            store.save(newSession)
            Log.answer.info("Auth: \(call.rawValue, privacy: .public) took \(took, privacy: .public) s")
            #if LUMEN_TESTMODE
            Log.answer.notice("Auth: \(call.rawValue, privacy: .public) gave the account \(Self.accountMark(newSession), privacy: .public)")
            #endif
            return newSession
        }
    }
}
