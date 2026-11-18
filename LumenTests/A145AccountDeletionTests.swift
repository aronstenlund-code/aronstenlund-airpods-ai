import Foundation
import Testing
@testable import Lumen

/// A145 (Ke78, K101): Radera konto. The server first; nothing on the phone is touched before it has said yes; then the
/// phone forgets everything, and the old sign-in never runs again.
@MainActor
@Suite struct A145AccountDeletionTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func signedIn(_ http: FakeHTTP) -> SupabaseAuth {
        let valid = SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600))
        return SupabaseAuth(config: config, store: InMemorySessionStore(valid), http: http, now: { t0 })
    }

    @Test func theServerIsAskedToDeleteWithConfirm() async throws {
        let http = FakeHTTP([.init(status: 200, body: #"{"deleted":true,"removed":{"audio_files":1,"shared_audio_kept":0},"subscription":{"active":true,"until":"2026-11-25"},"notice":"Veckokortet avslutas inte när kontot raderas."}"#)])
        let client = AccountClient(config: config, auth: signedIn(http), http: http)

        let result = await client.deleteAccount()

        #expect(result == .success(AccountDeletionReply(deleted: true, notice: "Veckokortet avslutas inte när kontot raderas.")))
        let request = try #require(http.requests.first)
        #expect(request.url?.path == "/functions/v1/account/delete")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        #expect(http.json(0)["confirm"] as? Bool == true, "K101 refuses without confirm")
    }

    @Test func a401RenewsTheTokenAndAsksOnceMore() async {
        let http = FakeHTTP([.init(status: 401, body: #"{"error":{"code":"unauthorized"}}"#),
                             .init(status: 200, body: Fixtures.tokenJSON(access: "jwt2", refresh: "r2")),
                             .init(status: 200, body: #"{"deleted":true}"#)])
        let client = AccountClient(config: config, auth: signedIn(http), http: http)

        #expect(await client.deleteAccount() == .success(AccountDeletionReply(deleted: true, notice: nil)))
        #expect(http.requests.map { $0.url?.path } == ["/functions/v1/account/delete", "/auth/v1/token", "/functions/v1/account/delete"])
        #expect(http.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer jwt2")
    }

    @Test func tooManyTriesAndNoNetworkAreSaidApart() async {
        let busy = FakeHTTP([.init(status: 429, body: #"{"error":{"code":"rate_limited"}}"#)])
        #expect(await AccountClient(config: config, auth: signedIn(busy), http: busy).deleteAccount() == .failure(.busy))
        let offline = FakeHTTP([.init(status: 0, body: "", error: URLError(.notConnectedToInternet))])
        #expect(await AccountClient(config: config, auth: signedIn(offline), http: offline).deleteAccount() == .failure(.offline))
        let broken = FakeHTTP([.init(status: 500, body: #"{"error":{"code":"internal"}}"#)])
        guard case .failure(.failed) = await AccountClient(config: config, auth: signedIn(broken), http: broken).deleteAccount() else {
            Issue.record("a server error is a failure")
            return
        }
    }

    @Test func nothingOnThePhoneIsTouchedWhenTheServerSaysNo() async {
        let deleter = FakeDeleter(.failure(.offline))
        var wiped = false
        var stopped = false
        var restartedWith: String?? = .none
        let model = AccountDeletionModel(client: deleter, wipe: { wiped = true }, stopEverything: { stopped = true })
        model.onDeleted = { restartedWith = .some($0) }

        await model.delete()

        #expect(!wiped && !stopped)
        #expect(restartedWith == .none)
        #expect(model.failureLine?.contains("Inget är raderat") == true)
        model.dismissFailure()
        #expect(model.state == .idle)
    }

    @Test func afterTheServerSaysYesEverythingStopsThePhoneForgetsAndTheAppStartsAsNew() async {
        let deleter = FakeDeleter(.success(AccountDeletionReply(deleted: true, notice: "Säg upp veckokortet.")))
        var order: [String] = []
        let model = AccountDeletionModel(client: deleter, wipe: { order.append("wipe") },
                                         stopEverything: { order.append("stop") })
        model.onDeleted = { order.append("restart: \($0 ?? "-")") }

        await model.delete()

        #expect(order == ["stop", "wipe", "restart: Säg upp veckokortet."])
        #expect(model.state == .idle)
    }

    @Test func thePhoneForgetsFilesSettingsAndTheSignIn() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("a145-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Lumen"), withIntermediateDirectories: true)
        try Data("prov".utf8).write(to: folder.appendingPathComponent("Lumen/drills.json"))
        try Data("ljud".utf8).write(to: folder.appendingPathComponent("piece.m4a"))
        let name = "a145-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.set(true, forKey: "firstStart.done")
        let session = InMemorySessionStore(SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0))
        var systemCalled = false

        let removed = LocalWipe(folders: [folder], defaults: [(defaults, name)], session: session) { systemCalled = true }.run()

        #expect(removed == 2)
        #expect(FileManager.default.fileExists(atPath: folder.path), "the folder itself stays")
        #expect((try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty == true)
        #expect(defaults.object(forKey: "firstStart.done") == nil, "the app starts as new")
        #expect(session.load() == nil, "the next start signs up a new anonymous account")
        #expect(systemCalled, "reminders and the widget")
    }

    @Test func theOldSignInNeverRunsAgain() async {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt-new"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { t0 })

        auth.retire()
        auth.prepare()
        for _ in 0..<50 { await Task.yield() }
        do {
            _ = try await auth.accessToken()
            Issue.record("a retired sign-in gives no token")
        } catch {}

        #expect(http.requests.isEmpty, "no stray anonymous account from the old app")
    }

    @Test func theWordsAreDeangelos() {
        #expect(AccountDeletionModel.questionDetail.hasSuffix("Det går inte att ångra."))
        #expect(AccountDeletionModel.passLine.contains("Prenumerationer"))
    }
}

@MainActor
private final class FakeDeleter: AccountDeleting {
    let result: Result<AccountDeletionReply, AccountDeletionFailure>
    init(_ result: Result<AccountDeletionReply, AccountDeletionFailure>) { self.result = result }
    func deleteAccount() async -> Result<AccountDeletionReply, AccountDeletionFailure> { result }
}
