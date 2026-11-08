import AVFAudio
import Foundation
import Testing
@testable import Lumen

/// D82.1: Lumen never answers its own voice. D82 (owner): shared history is uploaded once, with mode and persona.
@Suite struct EchoFilterTests {
    private let t0 = Date(timeIntervalSince1970: 5_000)

    @Test func lumensOwnAnswerComingBackIsRecognised() {
        var echo = EchoFilter()
        echo.record("Tjugo plus tjugo är fyrtio. Det är ett enkelt additionsexempel.", at: t0)
        // Aron's history on 8 Nov: the previous answer came back as the next question.
        #expect(echo.isEcho("tjugo plus tjugo är fyrtio det är ett enkelt", now: t0.addingTimeInterval(4)))
        #expect(echo.isEcho("När x är ett blir y", now: t0.addingTimeInterval(4)) == false, "a different sentence")
    }

    @Test func aRealQuestionWithAFewSharedWordsIsNotEcho() {
        var echo = EchoFilter()
        echo.record("När x är ett blir y lika med fem gånger ett plus tio, alltså femton.", at: t0)
        #expect(!echo.isEcho("vad händer om x är tre i stället", now: t0.addingTimeInterval(5)))
        #expect(echo.isEcho("när x är ett blir y lika med fem gånger ett plus tio", now: t0.addingTimeInterval(5)))
    }

    @Test func onlyTheLastThirtySecondsCount() {
        var echo = EchoFilter()
        echo.record("Du sätter in ett i formeln och gångrar med fem.", at: t0)
        #expect(echo.isEcho("du sätter in ett i formeln", now: t0.addingTimeInterval(29)))
        #expect(!echo.isEcho("du sätter in ett i formeln", now: t0.addingTimeInterval(31)))
    }

    @Test func shortUtterancesAreNotJudged() {
        var echo = EchoFilter()
        echo.record("Ja, precis.", at: t0)
        #expect(!echo.isEcho("ja precis", now: t0.addingTimeInterval(1)), "fewer than three words")
    }
}

@MainActor
@Suite struct EchoFlowTests {
    @Test func theRecogniserHearingLumenIsNeverAnswered() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tjugo plus tjugo är fyrtio. "), .done(AnswerDone(answered: true))])
        let apple = FakeTTSProvider(name: "apple")
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
        await model.startListening()
        model.receiveFinalTranscript("vad är tjugo plus tjugo?", at: Date())
        #expect(await waitUntil { apple.calls.count == 1 })
        try? await Task.sleep(for: .milliseconds(50))

        // The microphone picks up the answer and the recogniser turns it into a "question".
        model.receiveFinalTranscript("tjugo plus tjugo är fyrtio?", at: Date().addingTimeInterval(9))

        try? await Task.sleep(for: .milliseconds(80))
        #expect(provider.requests.count == 1, "its own voice is not a question")
        #expect(h.controller.eventLog.contains { $0.text.hasPrefix("Echo filtered") })
    }
}

@MainActor
@Suite struct SharedHistoryOnceTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")

    private func freshShare() -> ShareSettings {
        let suite = "lumen.tests.share82.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ShareSettings(defaults: defaults)
    }

    private func client(_ http: FakeHTTP, _ share: ShareSettings) -> FeedbackClient {
        let session = SupabaseSession(accessToken: "jwt", refreshToken: "r", expiresAt: Date().addingTimeInterval(3_600))
        return FeedbackClient(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http),
                              http: http, settings: share)
    }

    @Test func turningSharingOnAgainDoesNotUploadEverythingAgain() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}"), .init(status: 200, body: "{\"ok\":true}")])
        let share = freshShare()
        share.setSharing(true)
        let entries = [HistoryEntry(question: "Norge huvudstad", answer: "Oslo.", summary: nil, mode: "standard")]
        let uploader = client(http, share)
        await uploader.sync(entries)

        share.setSharing(true) // asked again in Settings
        await uploader.sync(entries)

        #expect(http.requests.count == 1, "7 Nov 16:18: the same question was uploaded twice")
    }

    @Test func theSameQuestionAndAnswerTwiceGoesOnce() {
        let t0 = Date(timeIntervalSince1970: 9_000)
        let entries = [HistoryEntry(createdAt: t0, question: "Kabel", answer: "En kabel är …", summary: nil),
                       HistoryEntry(createdAt: t0.addingTimeInterval(2), question: "kabel", answer: "En kabel är …", summary: nil),
                       HistoryEntry(createdAt: t0.addingTimeInterval(3), question: "Vad är en fiber", answer: "…", summary: nil)]
        let pending = FeedbackClient.pendingUploads(entries, uploaded: [])
        #expect(pending.map(\.question) == ["Kabel", "Vad är en fiber"])
    }

    @Test func modeAndPersonaGoAlong() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}")])
        let share = freshShare()
        share.setSharing(true)
        let entry = HistoryEntry(question: "Berätta om dig själv", answer: "Jag heter …", summary: nil, mode: "interview", persona: "interview")
        await client(http, share).sync([entry])

        let items = http.json(0)["items"] as? [[String: Any]]
        #expect(items?.first?["mode"] as? String == "interview")
        #expect(items?.first?["persona"] as? String == "interview")
        #expect(items?.first?["client_id"] as? String == entry.id.uuidString)
    }

    @Test func aConfirmedOptOutStartsAfresh() async {
        let http = FakeHTTP([.init(status: 200, body: "{\"ok\":true}"), .init(status: 200, body: "{\"ok\":true}"),
                             .init(status: 200, body: "{\"ok\":true}")])
        let share = freshShare()
        share.setSharing(true)
        let entries = [HistoryEntry(question: "Fråga", answer: "Svar", summary: nil)]
        let uploader = client(http, share)
        await uploader.sync(entries)
        share.setSharing(false)
        await uploader.sync(entries) // the server deletes everything
        share.setSharing(true)
        await uploader.sync(entries)

        #expect(http.requests.map(\.httpMethod) == ["POST", "DELETE", "POST"], "after a real deletion it may be shared again")
    }
}

/// D82 (owner's correction): echo cancellation only when the sound goes out of the iPhone's own speaker.
@MainActor
@Suite struct EchoCancellationRouteTests {
    @Test func onlyWithTheBuiltInSpeaker() async {
        let speaker = ControllerHarness()
        speaker.session.outputPortType = AVAudioSession.Port.builtInSpeaker.rawValue
        speaker.controller.voiceProcessingPolicy = { $0.outputsToBuiltInSpeaker }
        await speaker.controller.start()
        #expect(speaker.capture.voiceProcessing, "the microphone would hear Lumen")

        let airPods = ControllerHarness()
        airPods.controller.voiceProcessingPolicy = { $0.outputsToBuiltInSpeaker }
        await airPods.controller.start()
        #expect(!airPods.capture.voiceProcessing, "AirPods keep their microphone quality")
    }

    @Test func followsTheOutputMidSession() async {
        let h = ControllerHarness()
        h.controller.voiceProcessingPolicy = { $0.outputsToBuiltInSpeaker }
        await h.controller.start()
        #expect(!h.capture.voiceProcessing)

        var onSpeaker = FakeSessionManager.makeSnapshot(config: .bHQ)
        onSpeaker.outputs = [PortInfo(portType: AVAudioSession.Port.builtInSpeaker.rawValue, portName: "Speaker", uid: "s",
                                      channelCount: 1, dataSource: nil)]
        h.session.eventHandler?(.routeChanged(reason: "override", outputLost: false, snapshot: onSpeaker))

        #expect(await waitUntil { h.capture.voiceProcessing })
        #expect(h.controller.state == .listening, "the session goes on")
        #expect(h.capture.isCapturing)
    }
}

/// D82.2: Silero says who is talking in the live modes; an uncertain speaker is the other person.
@MainActor
@Suite struct LiveTalkingTests {
    private let t0 = Date(timeIntervalSince1970: 7_000)

    @Test func anUncertainTurnIsTheOtherPersons() {
        #expect(RizzSpeaker.tag(levelDBFS: -28, thresholdDBFS: -30) == .other, "within 3 dB: not sure, so the other person")
        #expect(RizzSpeaker.tag(levelDBFS: -26, thresholdDBFS: -30) == .user)
        #expect(RizzSpeaker.reason(levelDBFS: -29, thresholdDBFS: -30).contains("uncertain"))
        #expect(RizzSpeaker.reason(levelDBFS: nil, thresholdDBFS: -30).contains("other"))
    }

    @Test func backgroundNoiseIsNotATurnWhenSileroSaysSilence() {
        var tuning = StudyTuning()
        tuning.endpointSilence = 0.8
        var machine = StudyMachine(tuning: tuning)
        machine.start(at: t0)
        var events: [StudyEvent] = []
        // Loud room noise for 5 s: by level it would be one endless turn.
        for i in 0..<125 {
            if let event = machine.level(-20, at: t0.addingTimeInterval(1 + Double(i) * 0.04), speech: false) { events.append(event) }
        }
        #expect(!events.contains(.turnStarted))
        #expect(!machine.someoneIsTalking(at: t0.addingTimeInterval(6)))
    }

    @Test func aTurnEndsAtThePauseEvenOverNoise() {
        var tuning = StudyTuning()
        tuning.endpointSilence = 0.8
        var machine = StudyMachine(tuning: tuning)
        machine.start(at: t0)
        var time = t0.addingTimeInterval(1)
        for _ in 0..<20 {
            _ = machine.level(-20, at: time, speech: true)
            time = time.addingTimeInterval(0.04)
        }
        _ = machine.transcriptFinal("hej hur mår du", at: time)
        var ended = false
        for _ in 0..<30 { // the noise goes on, the voice has stopped
            if machine.level(-20, at: time, speech: false) == .endOfTurn("hej hur mår du") { ended = true }
            time = time.addingTimeInterval(0.04)
        }
        #expect(ended, "not ten seconds of total silence: the pause after the voice")
    }

    @Test func stallIsTwoSeconds() {
        #expect(ListeningModel.stallSilence == 2)
    }
}
