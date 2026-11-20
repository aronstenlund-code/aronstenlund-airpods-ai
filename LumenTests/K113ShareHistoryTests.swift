import Foundation
import Testing
@testable import Lumen

/// K113 (D247): the question log of the repetition mode is written only for the one who shares. The app says so with
/// `share_history: true` when "Dela historik" (D57) is on. Off, which is where everyone starts, nothing is said, and
/// the server logs nothing: the safe side is the default.
@MainActor
@Suite struct K113ShareHistoryTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// A client that is signed in, and the scripted server it talks to. The server's answer does not matter here
    /// (it answers 500): only what the app sent is looked at.
    private func client() -> (DrillCloudClient, FakeHTTP) {
        let http = FakeHTTP([.init(status: 500, body: "{}"), .init(status: 500, body: "{}"), .init(status: 500, body: "{}")])
        let valid = SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600))
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(valid), http: http, now: { t0 })
        return (DrillCloudClient(config: config, auth: auth, http: http), http)
    }

    private func settings() -> ShareSettings {
        let suite = "k113-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ShareSettings(defaults: defaults)
    }

    @Test func offTheSaveSaysNothingAboutSharing() async {
        let (client, http) = client()
        _ = try? await client.save(A79A81RepetitionTests.bio(3))
        #expect(http.json(0)["action"] as? String == "save")
        #expect(http.json(0)["share_history"] == nil, "no field at all: the server then logs nothing")

        let (starting, second) = self.client()
        _ = try? await starting.saveStarting(A79A81RepetitionTests.bio(3))
        #expect(second.json(0)["action"] as? String == "save" && second.json(0)["start"] as? Bool == true)
        #expect(second.json(0)["share_history"] == nil)
    }

    @Test func onEverySaveSaysSo() async {
        let (client, http) = client()
        client.sharesHistory = { true }
        _ = try? await client.save(A79A81RepetitionTests.bio(3))
        #expect(http.json(0)["action"] as? String == "save")
        #expect(http.json(0)["share_history"] as? Bool == true)

        let (starting, second) = self.client()
        starting.sharesHistory = { true }
        _ = try? await starting.saveStarting(A79A81RepetitionTests.bio(3))
        #expect(second.json(0)["start"] as? Bool == true && second.json(0)["share_history"] as? Bool == true)
    }

    /// The setting as the app wires it: read at every save, so turning "Dela historik" on or off counts from the next
    /// save, and a new install (never asked, never on) shares nothing.
    @Test func itFollowsDelaHistorikAtEverySave() async {
        let share = settings()
        #expect(!share.isSharing, "off until the user turns it on")

        let (first, a) = client()
        first.sharesHistory = { share.isSharing }
        _ = try? await first.save(A79A81RepetitionTests.bio(2))
        #expect(a.json(0)["share_history"] == nil)

        share.setSharing(true)
        let (second, b) = client()
        second.sharesHistory = { share.isSharing }
        _ = try? await second.save(A79A81RepetitionTests.bio(2))
        #expect(b.json(0)["share_history"] as? Bool == true)

        share.setSharing(false)
        _ = try? await second.save(A79A81RepetitionTests.bio(2))
        let last = b.json(b.requests.count - 1)
        #expect(last["action"] as? String == "save" && last["share_history"] == nil, "off again: the next save says nothing")
    }

    /// Kelly Ke85: the words under the switch and in the question after the consent say both things that are shared,
    /// each with its time, in Swedish and in English. Read from the app as it is built.
    @Test func theWordsSayBothWhatIsSharedAndForHowLong() throws {
        let app = Bundle(for: SearchToneController.self)
        let swedish = try #require(app.path(forResource: "sv", ofType: "lproj").flatMap { Bundle(path: $0) }, "the app has Swedish")
        for key in [ShareText.underTheSwitch, ShareText.question] {
            #expect(key.contains("12 months") && key.contains("14 days") && key.contains("quizzes"))
            let said = swedish.localizedString(forKey: key, value: "?", table: nil)
            #expect(said != "?" && said != key, "the Swedish is in the catalog under this key")
            #expect(said.contains("12 månader") && said.contains("14 dagar") && said.contains("prov"))
            #expect(said.contains("Andra personers tal skickas aldrig"))
        }
        #expect(ShareText.underTheSwitch.hasPrefix("Off by default"))
    }

    /// The other calls never carry it: only what makes the log (save).
    @Test func onlyTheSaveCarriesIt() {
        let body = DrillCloudClient.saveBody(A79A81RepetitionTests.bio(2))
        #expect(DrillCloudClient.sharing(body, on: false)["share_history"] == nil)
        #expect(DrillCloudClient.sharing(body, on: true)["share_history"] as? Bool == true)
        #expect(DrillCloudClient.sharing(body, on: true).count == body.count + 1, "nothing else is changed")
    }
}
