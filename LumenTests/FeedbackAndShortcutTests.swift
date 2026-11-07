import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct FeedbackTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")

    private func freshShare() -> ShareSettings {
        let suite = "lumen.tests.share.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ShareSettings(defaults: defaults)
    }

    private func makeClient(_ http: FakeHTTP, share: ShareSettings) -> FeedbackClient {
        let session = SupabaseSession(accessToken: "jwt", refreshToken: "r", expiresAt: Date().addingTimeInterval(3_600))
        return FeedbackClient(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http), http: http, settings: share)
    }

    private func makeModel(_ provider: FakeAnswerProvider, http: FakeHTTP, share: ShareSettings? = nil,
                           history: HistoryStore? = nil, apple: FakeTTSProvider = FakeTTSProvider(name: "apple")) -> ListeningModel {
        let h = ControllerHarness()
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                              activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                              voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                              history: history ?? makeTestHistory(), memory: makeTestMemory(),
                              feedback: makeClient(http, share: share ?? freshShare()))
    }

    @Test func aReportSendsTheTurnWordForWord() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}")])
        let model = makeModel(FakeAnswerProvider(), http: http)
        let turn = AnswerTurn(question: "Vad är pi?", answer: "Tre.", latencyMs: 800, source: "cloud")

        #expect(await model.report(turn, comment: "fel svar"))

        #expect(http.requests[0].url == config.feedbackURL)
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        let body = http.json(0)
        #expect(body["type"] as? String == "report")
        #expect(body["fragment"] as? String == "Vad är pi?")
        #expect(body["answer"] as? String == "Tre.")
        #expect(body["comment"] as? String == "fel svar")
        #expect((body["install_id"] as? String)?.count == 36)
        #expect(model.reportNotice == "Skickat")
    }

    @Test func anotherPersonsWordsAreNeverReported() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}")])
        let model = makeModel(FakeAnswerProvider(), http: http)

        await model.report(AnswerTurn(question: "Läraren frågade något", answer: "Svar.", source: "cloud", isOwnQuestion: false))

        #expect(http.json(0)["fragment"] == nil)
        #expect(http.json(0)["answer"] as? String == "Svar.")
    }

    @Test func theSpokenCommandReportsThePreviousTurnAndConfirms() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tio."), .done(AnswerDone(answered: true))])
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}")])
        let apple = FakeTTSProvider(name: "apple")
        let model = makeModel(provider, http: http, apple: apple)
        model.submitText("roten ur hundra")
        #expect(await waitUntil { model.conversation.answers.count == 1 })

        provider.events = [.meta(AnswerMeta(isQuestion: false)), .done(AnswerDone(answered: false, report: true))]
        model.submitText("rapportera")

        #expect(await waitUntil { http.requests.count == 1 })
        #expect(http.json(0)["fragment"] as? String == "roten ur hundra")
        #expect(http.json(0)["answer"] as? String == "Tio.")
        #expect(await waitUntil { apple.calls.contains { $0.text == "Skickat" } })
        #expect(model.conversation.answers.count == 1, "the command is not a turn")
    }

    @Test func aFailedReportDoesNotClaimSuccess() async {
        let http = FakeHTTP([.init(status: 503, body: "{\"error\":{\"code\":\"down\"}}")])
        let apple = FakeTTSProvider(name: "apple")
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tio."), .done(AnswerDone(answered: true))])
        let model = makeModel(provider, http: http, apple: apple)
        model.submitText("roten ur hundra")
        #expect(await waitUntil { model.conversation.answers.count == 1 })
        provider.events = [.meta(AnswerMeta(isQuestion: false)), .done(AnswerDone(answered: false, report: true))]
        model.submitText("rapportera")

        #expect(await waitUntil { model.reportNotice?.contains("down") == true })
        try? await Task.sleep(for: .milliseconds(30))
        #expect(!apple.calls.contains { $0.text == "Skickat" })
    }

    @Test func sharingIsOffByDefaultAndNothingIsUploaded() async {
        let http = FakeHTTP()
        let share = freshShare()
        #expect(!share.isSharing)
        #expect(!share.hasAsked)

        await makeClient(http, share: share).sync([HistoryEntry(question: "Fråga", answer: "Svar", summary: nil)])

        #expect(http.requests.isEmpty)
    }

    @Test func sharingUploadsOwnQuestionsOnceAndNeverOtherPeoples() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}")])
        let share = freshShare()
        share.setSharing(true)
        let client = makeClient(http, share: share)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let entries = [HistoryEntry(createdAt: t0, question: "Min fråga", answer: "Svar", summary: "Kort"),
                       HistoryEntry(createdAt: t0.addingTimeInterval(1), question: nil, answer: "Svar på läraren", summary: nil)]

        await client.sync(entries)
        await client.sync(entries)

        #expect(http.requests.count == 1, "already shared")
        #expect(http.requests[0].url == config.sharedHistoryURL)
        let items = http.json(0)["items"] as? [[String: Any]]
        #expect(items?.count == 1)
        #expect(items?.first?["fragment"] as? String == "Min fråga")
    }

    @Test func turningItOffDeletesWhatWasSharedAndRetriesIfOffline() async {
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.notConnectedToInternet)),
                             .init(status: 200, body: "{\"ok\":true}")])
        let share = freshShare()
        share.setSharing(true)
        share.setSharing(false)
        let client = makeClient(http, share: share)

        await client.sync([])
        #expect(share.deleteIsPending, "offline: still owed")

        await client.sync([])
        #expect(http.requests[1].httpMethod == "DELETE")
        #expect(http.json(1)["install_id"] as? String == share.installID)
        #expect(!share.deleteIsPending)
    }

    @Test func aFreeTextGoesToFeedback() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}")])
        let model = makeModel(FakeAnswerProvider(), http: http)

        #expect(await model.sendFeedback(type: "suggestion", text: "Lägg till mörkt läge"))

        #expect(http.json(0)["type"] as? String == "suggestion")
        #expect(http.json(0)["comment"] as? String == "Lägg till mörkt läge")
    }
}

@Suite struct VoiceCommandTests {
    @Test func aCommandIsTheWholeUtterance() {
        #expect(VoiceCommand.isMusicHandOff("Pausa."))
        #expect(VoiceCommand.isMusicHandOff("spela musik"))
        #expect(!VoiceCommand.isMusicHandOff("vi tar en paus och spela musik sen"))
        #expect(VoiceCommand.isReport("Det där var fel!"))
        #expect(!VoiceCommand.isReport("det där var fel sa läraren igår"))
    }
}

@MainActor
@Suite struct HandsFreeStartTests {
    private func makeModel(_ h: ControllerHarness, provider: FakeAnswerProvider = FakeAnswerProvider()) -> ListeningModel {
        ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                       activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                       voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                       history: makeTestHistory(), memory: makeTestMemory())
    }

    @Test func sayingPausaLetsGoOfTheAudioAndSendsNothing() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud")
        let model = makeModel(h, provider: provider)
        await model.startListening()

        model.receiveFinalTranscript("Pausa", at: Date())

        #expect(await waitUntil { model.state == .paused(.user) })
        #expect(h.session.deactivateCalls == 1, "notifyOthersOnDeactivation, so Spotify carries on")
        #expect(provider.requests.isEmpty)
    }

    @Test func aShortcutWaitsForTheAppToBeActive() async {
        let h = ControllerHarness()
        let model = makeModel(h)
        await model.startFromShortcut()
        #expect(model.isListening)

        await model.pauseFromShortcut()
        #expect(model.state == .paused(.user))

        await model.pauseFromShortcut()
        #expect(model.state == .paused(.user), "pausing twice stays paused")
    }

    @Test func askingEndsAfterOneAnswerAndTheMicrophoneGoesOff() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.done(AnswerDone(answered: true))])
        let model = makeModel(h, provider: provider)

        await model.askFromShortcut()
        #expect(model.study.isActive)

        model.study.level(-70, at: Date())
        var time = Date().addingTimeInterval(-3)
        for _ in 0..<15 {
            model.study.level(-25, at: time)
            time = time.addingTimeInterval(0.04)
        }
        model.receiveFinalTranscript("Vad är pi", at: time)
        for _ in 0..<45 {
            model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }

        #expect(await waitUntil { provider.requests.count == 1 })
        #expect(await waitUntil { model.state == .idle })
        #expect(!model.study.isActive)
    }
}
