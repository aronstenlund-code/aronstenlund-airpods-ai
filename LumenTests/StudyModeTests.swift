import Foundation
import Testing
@testable import Lumen

@Suite struct StudyMachineTests {
    private let t0 = Date(timeIntervalSince1970: 3_000_000)
    private let quiet = -62.0
    private let loud = -28.0

    /// Feeds one reading per 40 ms from `from` for `seconds` (all frames); returns every event with its time.
    private func feedAll(_ machine: inout StudyMachine, level: Double, from start: TimeInterval, seconds: TimeInterval) -> [(event: StudyEvent, at: TimeInterval)] {
        var out: [(event: StudyEvent, at: TimeInterval)] = []
        var t = start
        let end = start + seconds
        while t <= end + 1e-9 {
            if let event = machine.level(level, at: t0.addingTimeInterval(t)) { out.append((event, t)) }
            t += 0.04
        }
        return out
    }

    /// First event (or nil) and the time it fired (or the end time).
    private func feed(_ machine: inout StudyMachine, level: Double, from start: TimeInterval, seconds: TimeInterval) -> (StudyEvent?, TimeInterval) {
        let events = feedAll(&machine, level: level, from: start, seconds: seconds)
        return (events.first?.event, events.first?.at ?? start + seconds)
    }

    private func started(autoEnd: TimeInterval? = 600) -> StudyMachine {
        var tuning = StudyTuning()
        tuning.autoEndSilence = autoEnd
        var machine = StudyMachine(tuning: tuning)
        machine.start(at: t0)
        // one second of room noise establishes the floor
        _ = feed(&machine, level: quiet, from: 0, seconds: 1.0)
        return machine
    }

    @Test func endpointFiresAfterSilenceOnceAFinalExists() {
        var machine = started()
        let speech = feedAll(&machine, level: loud, from: 1.0, seconds: 0.6)
        #expect(speech.map(\.event) == [.turnStarted])
        #expect(speech.first.map { $0.at >= 1.12 && $0.at < 1.2 } == true, "speech must hold 120 ms first: \(speech)")
        #expect(machine.isUserSpeaking)
        #expect(machine.transcriptFinal("förklara fotosyntes", at: t0.addingTimeInterval(1.7)) == nil, "the user may still be speaking")

        let (event, tEnd) = feed(&machine, level: quiet, from: 1.7, seconds: 2.0)
        #expect(event == .endOfTurn("förklara fotosyntes"))
        #expect(tEnd >= 2.4 && tEnd < 2.48, "0.8 s after the last loud frame (1.6): \(tEnd)")
        #expect(machine.phase == .thinking)
        #expect(!machine.isUserSpeaking)
    }

    @Test func endpointWaitsForTheFinalWhenOnlyAPartialExists() {
        var machine = started()
        _ = feedAll(&machine, level: loud, from: 1.0, seconds: 0.5) // last loud frame at 1.48
        machine.transcriptPartial("förklara foto")
        let (event, tEnd) = feed(&machine, level: quiet, from: 1.54, seconds: 3.0)
        #expect(event == .endOfTurn("förklara foto"), "after endpoint + grace the partial is used")
        #expect(tEnd >= 2.98 && tEnd < 3.06, "1.48 + 0.8 + 0.7 s: \(tEnd)")
    }

    @Test func aLateFinalClosesTheTurnAtOnce() {
        var machine = started()
        _ = feedAll(&machine, level: loud, from: 1.0, seconds: 0.5)
        machine.transcriptPartial("vad är")
        let (none, _) = feed(&machine, level: quiet, from: 1.54, seconds: 1.0) // 1.0 s silence, still inside the grace
        #expect(none == nil)
        let event = machine.transcriptFinal("Vad är fotosyntes?", at: t0.addingTimeInterval(2.6))
        #expect(event == .endOfTurn("Vad är fotosyntes?"))
    }

    @Test func noiseWithoutWordsIsForgotten() {
        var machine = started()
        _ = feedAll(&machine, level: loud, from: 1.0, seconds: 0.5)
        let (event, _) = feed(&machine, level: quiet, from: 1.54, seconds: 3.0)
        #expect(event == nil)
        #expect(machine.phase == .listening)
        #expect(!machine.isUserSpeaking)
        #expect(machine.turnText.isEmpty)
    }

    @Test func bargeInNeedsSustainedSpeechWhileSpeaking() {
        var machine = started()
        machine.answerStarted()
        #expect(machine.phase == .thinking)
        machine.speechStarted()
        #expect(machine.phase == .speaking)

        let (blip, _) = feed(&machine, level: loud, from: 5.0, seconds: 0.2)
        #expect(blip == nil, "a 200 ms blip is not a barge-in")
        let (none, _) = feed(&machine, level: quiet, from: 5.24, seconds: 0.4)
        #expect(none == nil)
        let (event, tBarge) = feed(&machine, level: loud, from: 5.7, seconds: 1.0)
        #expect(event == .bargeIn)
        #expect(tBarge >= 6.1 && tBarge < 6.2, "0.4 s of sustained speech: \(tBarge)")
        #expect(machine.phase == .listening)
        #expect(machine.isUserSpeaking, "the barge-in speech is the start of the next turn")
    }

    @Test func noTurnWhileThinkingAndLifecycle() {
        var machine = started()
        machine.answerStarted()
        let (event, _) = feed(&machine, level: loud, from: 2.0, seconds: 1.0)
        #expect(event == nil, "levels are ignored while thinking")
        #expect(machine.transcriptFinal("x", at: t0.addingTimeInterval(3)) == nil)
        machine.resumeListening(at: t0.addingTimeInterval(3))
        #expect(machine.phase == .listening)
        #expect(machine.turnText.isEmpty)
        machine.stop()
        #expect(machine.phase == .off)
        #expect(machine.level(loud, at: t0.addingTimeInterval(4)) == nil)
    }

    @Test func autoEndsAfterLongSilenceAndReleases() {
        var machine = started()
        var event: StudyEvent?
        var t = 1.0
        while event == nil, t < 700 {
            event = machine.level(quiet, at: t0.addingTimeInterval(t))
            t += 1
        }
        #expect(event == .autoEnded)
        #expect(t >= 600 && t <= 602, "10 minutes without speech: \(t)")
        #expect(machine.phase == .off)
    }

    @Test func neverAutoEndsByDefault() {
        #expect(StudyTuning().autoEndSilence == nil, "D71: Provläge runs until the user ends it")
        var machine = started(autoEnd: nil)
        for second in stride(from: 1.0, to: 3_700, by: 5) {
            #expect(machine.level(quiet, at: t0.addingTimeInterval(second)) != .autoEnded)
        }
        #expect(machine.phase == .listening)
    }

    @Test func speechPostponesTheAutoEnd() {
        var machine = started()
        _ = feedAll(&machine, level: loud, from: 500, seconds: 0.5) // the user said something at 8 min
        var event: StudyEvent?
        var t = 501.0
        while event == nil, t < 1_300 {
            event = machine.level(quiet, at: t0.addingTimeInterval(t))
            t += 1
        }
        #expect(event == .autoEnded)
        #expect(t >= 1_100 && t <= 1_102, "10 min after the last speech: \(t)")
    }

    @Test func noiseFloorDropsAtOnceAndRisesSlowly() {
        var machine = StudyMachine()
        machine.start(at: t0)
        _ = machine.level(-40, at: t0)
        #expect(machine.noiseFloorDBFS == -40)
        _ = machine.level(-65, at: t0.addingTimeInterval(0.04))
        #expect(machine.noiseFloorDBFS == -65, "quieter input is the new floor at once")
        _ = machine.level(-62, at: t0.addingTimeInterval(1.04))
        #expect(machine.noiseFloorDBFS.map { abs($0 - (-64)) < 0.01 } == true, "quiet frames pull the floor up 1 dB per second")
        _ = machine.level(-20, at: t0.addingTimeInterval(2.04))
        #expect(machine.noiseFloorDBFS.map { abs($0 - (-64)) < 0.01 } == true, "speech never becomes the floor")
        _ = machine.level(-62, at: t0.addingTimeInterval(500))
        #expect(machine.noiseFloorDBFS.map { abs($0 - (-63)) < 0.01 } == true, "a long gap counts as one second at most")
    }

    @Test func absoluteMinimumKeepsSilenceFromCountingAsSpeech() {
        var machine = StudyMachine()
        machine.start(at: t0)
        _ = feed(&machine, level: -90, from: 0, seconds: 1) // digital silence floor
        let (event, _) = feed(&machine, level: -70, from: 1.04, seconds: 1) // +20 dB but still far below -50 dBFS
        #expect(event == nil)
        #expect(!machine.isUserSpeaking)
    }
}

@MainActor
@Suite struct StudySettingsTests {
    @Test func defaultsPersistenceAndClamping() {
        let suite = "lumen.tests.study.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = StudySettings(defaults: defaults)
        #expect(settings.endpointSilence == 1.2, "D74")
        #expect(settings.autoEndMinutes == 0, "never, D71")
        #expect(!settings.useVoiceChatMode)
        #expect(settings.tuning.autoEndSilence == nil)

        settings.endpointSilence = 1.0
        settings.autoEndMinutes = 3
        settings.useVoiceChatMode = true
        let reloaded = StudySettings(defaults: defaults)
        #expect(reloaded.endpointSilence == 1.0)
        #expect(reloaded.autoEndMinutes == 3)
        #expect(reloaded.useVoiceChatMode)
        #expect(reloaded.tuning.endpointSilence == 1.0)
        #expect(reloaded.tuning.autoEndSilence == 180)
    }
}

/// Provläge end to end against fakes: microphone, recogniser, answers and voice.
@MainActor
@Suite struct StudyModeTests {
    private let t0 = Date(timeIntervalSince1970: 3_100_000)

    struct Rig {
        let coordinator: CoordinatorHarness
        let apple: FakeTTSProvider
        let provider: FakeAnswerProvider
        let study: StudySessionController
        let model: ListeningModel
        var h: ControllerHarness { coordinator.session }
    }

    private func makeRig(answerEvents: [AnswerEvent]? = nil, speechDelay: Duration = .zero) -> Rig {
        let coordinator = CoordinatorHarness()
        let apple = FakeTTSProvider(name: "apple")
        apple.delay = speechDelay
        let provider = FakeAnswerProvider(name: "cloud", events: answerEvents ?? [
            .meta(AnswerMeta(reconstructedQuestion: "Vad är fotosyntes?", isQuestion: true)),
            .delta("Fotosyntes är växternas sätt att göra energi. "), .delta("Vill du veta mer om klorofyll?"),
            .done(AnswerDone(answered: true)),
        ])
        let suite = "lumen.tests.studymode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let study = StudySessionController(settings: StudySettings(defaults: defaults), session: coordinator.session.controller)
        let model = ListeningModel(controller: coordinator.session.controller, consent: FakeConsentStore(granted: true),
                                   transcription: coordinator.coordinator, activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider),
                                   speaker: makeTestSpeaker(coordinator.session.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   study: study)
        return Rig(coordinator: coordinator, apple: apple, provider: provider, study: study, model: model)
    }

    /// Room noise, then speech, then silence past the endpoint — all through the controller's level input.
    private func speakTurn(_ rig: Rig, text: String, at start: TimeInterval) {
        for i in 0..<25 { rig.study.level(-62, at: t0.addingTimeInterval(start + Double(i) * 0.04)) }
        let speechStart = start + 1.0
        for i in 0..<15 { rig.study.level(-28, at: t0.addingTimeInterval(speechStart + Double(i) * 0.04)) }
        rig.model.receiveFinalTranscript(text, at: t0.addingTimeInterval(speechStart + 0.6))
        for i in 0..<45 { rig.study.level(-62, at: t0.addingTimeInterval(speechStart + 0.6 + Double(i) * 0.04)) }
    }

    @Test func startingStudyStartsTheMicrophoneAndListensForATurn() async {
        let rig = makeRig()
        #expect(!rig.model.isListening)
        await rig.model.toggleStudyMode()
        #expect(rig.model.isListening)
        #expect(rig.study.isActive)
        #expect(rig.study.phase == .listening)
        #expect(await waitUntil { rig.coordinator.coordinator.status.isRunning })
    }

    @Test func aTurnBecomesATutorRequestWithSessionMemoryAndReturnsToListening() async {
        let rig = makeRig()
        for i in 0..<5 {
            rig.model.receiveAnswer(question: "q\(i)", answer: "a\(i)", source: "cloud")
        }
        await rig.model.toggleStudyMode()
        rig.study.start(at: t0) // test clock

        speakTurn(rig, text: "förklara fotosyntes", at: 0)

        #expect(await waitUntil { rig.provider.requests.count == 1 })
        let request = rig.provider.requests[0]
        #expect(request.mode == "tutor")
        #expect(request.fragment == "förklara fotosyntes")
        #expect(request.context.recentQA.count == 5, "the whole session, not only the last 3")
        #expect(rig.model.pendingQuestion?.trigger == .tutor)

        #expect(await waitUntil { rig.model.conversation.answers.count == 6 })
        #expect(await waitUntil { rig.apple.calls.count == 2 }, "both sentences spoken")
        #expect(await waitUntil { rig.study.phase == .listening }, "back to listening after speech")
        #expect(!rig.coordinator.coordinator.isInputGated)
        #expect(rig.model.isListening)
    }

    @Test func ownSpeechGatesTheRecogniserUntilFinished() async {
        let rig = makeRig(speechDelay: .milliseconds(300))
        await rig.model.toggleStudyMode()
        rig.study.start(at: t0)
        speakTurn(rig, text: "förklara fotosyntes", at: 0)
        #expect(await waitUntil { rig.apple.calls.count >= 1 })

        rig.h.playback.onAudioScheduled?() // first audio of the sentence reaches the player
        #expect(rig.study.phase == .speaking)
        #expect(rig.coordinator.coordinator.isInputGated)

        #expect(await waitUntil { rig.study.phase == .listening })
        #expect(!rig.coordinator.coordinator.isInputGated)
    }

    @Test func bargeInStopsSpeechAndOpensANewTurn() async {
        let rig = makeRig(speechDelay: .seconds(2))
        await rig.model.toggleStudyMode()
        rig.study.start(at: t0)
        speakTurn(rig, text: "förklara fotosyntes", at: 0)
        #expect(await waitUntil { rig.apple.calls.count >= 1 })
        rig.h.playback.onAudioScheduled?()
        #expect(rig.study.phase == .speaking)
        let stopsBefore = rig.h.playback.stopCalls

        for i in 0..<15 { rig.study.level(-28, at: t0.addingTimeInterval(10 + Double(i) * 0.04)) }

        #expect(rig.study.phase == .listening)
        #expect(rig.study.isUserSpeaking)
        #expect(rig.h.playback.stopCalls > stopsBefore, "TTS was interrupted")
        #expect(!rig.coordinator.coordinator.isInputGated)
        #expect(rig.model.conversation.streamingAnswer == nil)
        #expect(rig.model.answers.status == .idle)
    }

    @Test func aChosenAutoEndEndsAfterSilenceAndReleasesTheMicrophone() async {
        let rig = makeRig()
        rig.study.settings.autoEndMinutes = 10 // off by default (D71); the setting still works
        await rig.model.toggleStudyMode()
        #expect(rig.model.isListening)
        rig.study.start(at: t0)

        rig.study.level(-62, at: t0)
        rig.study.level(-62, at: t0.addingTimeInterval(601))

        #expect(!rig.study.isActive)
        #expect(rig.study.endedBySilence)
        #expect(rig.model.studyNotice?.contains("10 min") == true)
        #expect(await waitUntil { !rig.model.isListening }, "sparläge: the microphone is switched off")
    }

    @Test func byDefaultSilenceNeverEndsProvlage() async {
        let rig = makeRig()
        await rig.model.toggleStudyMode()
        rig.study.start(at: t0)

        rig.study.level(-62, at: t0)
        rig.study.level(-62, at: t0.addingTimeInterval(601))
        rig.study.level(-62, at: t0.addingTimeInterval(7_200))

        #expect(rig.study.isActive, "D71: Provläge runs until the user ends it")
        #expect(rig.model.isListening)
    }

    @Test func endingByTheUserKeepsListeningAndPausingEndsIt() async {
        let rig = makeRig()
        await rig.model.toggleStudyMode()
        await rig.model.toggleStudyMode()
        #expect(!rig.study.isActive)
        #expect(rig.model.isListening, "plain listening continues")
        #expect(rig.model.studyNotice == nil)

        await rig.model.toggleStudyMode()
        #expect(rig.study.isActive)
        await rig.model.togglePause()
        #expect(!rig.study.isActive, "no hands-free session without the microphone")
    }

    @Test func questionGateIsOffDuringStudy() async {
        let rig = makeRig()
        await rig.model.toggleStudyMode()
        rig.model.receiveFinalTranscript("vad är fotosyntes?")
        try? await Task.sleep(for: .milliseconds(100))
        #expect(rig.provider.requests.isEmpty, "turns end by silence, not by the gate")
        #expect(rig.study.machine.turnText == "vad är fotosyntes?")
    }
}

@MainActor
@Suite struct InputGatingTests {
    @Test func gatedChunksNeverReachTheProvider() async {
        let h = CoordinatorHarness()
        let (stream, continuation) = AsyncStream<AudioChunk>.makeStream()
        h.session.capture.chunks = stream
        await h.session.controller.start()
        #expect(await waitUntil { h.coordinator.status.isRunning })

        continuation.yield(AudioChunk(samples: [Int16](repeating: 1, count: 640), hostTime: 1, firstSampleIndex: 0))
        #expect(await waitUntil { h.provider?.receivedChunks.count == 1 })

        h.coordinator.setInputGated(true)
        continuation.yield(AudioChunk(samples: [Int16](repeating: 2, count: 640), hostTime: 2, firstSampleIndex: 640))
        continuation.yield(AudioChunk(samples: [Int16](repeating: 3, count: 640), hostTime: 3, firstSampleIndex: 1280))
        try? await Task.sleep(for: .milliseconds(150))
        #expect(h.provider?.receivedChunks.count == 1, "gated chunks are dropped")
        #expect(h.session.controller.chunkCount == 3, "the session still counts them (levels keep flowing)")

        h.coordinator.setInputGated(false)
        continuation.yield(AudioChunk(samples: [Int16](repeating: 4, count: 640), hostTime: 4, firstSampleIndex: 1920))
        #expect(await waitUntil { h.provider?.receivedChunks.count == 2 })
        #expect(h.provider?.receivedChunks.last?.firstSampleIndex == 1920)
    }
}

@MainActor
@Suite struct TutorModeFallbackTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func a400ForTutorIsRetriedAsPushToTalkOnce() async throws {
        let session = SupabaseSession(accessToken: "jwt", refreshToken: "r", expiresAt: t0.addingTimeInterval(3600))
        let http = FakeHTTP([.init(status: 400, body: "{\"error\":{\"code\":\"invalid_request\",\"message\":\"mode\"}}"),
                             .init(status: 200, body: Fixtures.answerSSE)])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http, now: { t0 })
        let provider = CloudAnswerProvider(config: config, auth: auth, http: http)

        var events: [AnswerEvent] = []
        for try await event in provider.answer(AnswerRequest(fragment: "förklara fotosyntes", mode: "tutor", language: "sv")) {
            events.append(event)
        }
        #expect(events.count == 4)
        #expect(http.json(0)["mode"] as? String == "tutor")
        #expect(http.json(1)["mode"] as? String == "push_to_talk")

        let twice = FakeHTTP([.init(status: 400, body: "{\"error\":{\"code\":\"invalid_request\"}}"),
                              .init(status: 400, body: "{\"error\":{\"code\":\"invalid_request\"}}")])
        let failing = CloudAnswerProvider(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(session), http: twice, now: { t0 }), http: twice)
        do {
            for try await _ in failing.answer(AnswerRequest(fragment: "x", mode: "tutor", language: "sv")) {}
            Issue.record("expected an error")
        } catch {
            #expect(twice.requests.count == 2, "only one fallback")
            guard case .backend(400, _) = AnswerError.from(error) else { Issue.record("wrong error \(error)"); return }
        }
    }
}
