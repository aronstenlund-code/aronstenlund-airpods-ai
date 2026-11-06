import Foundation
import Testing
@testable import Lumen

@Suite struct StudyMachineStallTests {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func tuned() -> StudyMachine {
        var tuning = StudyTuning()
        tuning.stallSilence = 4
        return StudyMachine(tuning: tuning)
    }

    /// Level readings every 40 ms from `start` for `seconds`; returns the events.
    private func feed(_ machine: inout StudyMachine, _ level: Double, from start: TimeInterval, seconds: TimeInterval) -> [StudyEvent] {
        var events: [StudyEvent] = []
        var time = start
        while time < start + seconds {
            if let event = machine.level(level, at: t0.addingTimeInterval(time)) { events.append(event) }
            time += 0.04
        }
        return events
    }

    @Test func silenceFiresOnceUntilSomeoneSpeaks() {
        var machine = tuned()
        machine.start(at: t0)
        #expect(feed(&machine, -70, from: 0, seconds: 3.9).isEmpty)
        #expect(feed(&machine, -70, from: 3.9, seconds: 5) == [.stalled], "one rescue per silence")

        #expect(feed(&machine, -20, from: 8.9, seconds: 0.5) == [.turnStarted])
        machine.transcriptPartial("hej")
        _ = feed(&machine, -70, from: 9.4, seconds: 2)
        machine.resumeListening(at: t0.addingTimeInterval(11.4))
        #expect(feed(&machine, -70, from: 11.4, seconds: 4.2) == [.stalled])
    }

    @Test func offUnlessAskedFor() {
        var machine = StudyMachine()
        machine.start(at: t0)
        #expect(feed(&machine, -70, from: 0, seconds: 30).isEmpty)
    }

    @Test func someoneTalkingIsSeenInEveryPhaseAndTheTurnLevelIsKept() {
        var machine = tuned()
        machine.start(at: t0)
        _ = feed(&machine, -70, from: 0, seconds: 1)
        #expect(!machine.someoneIsTalking(at: t0.addingTimeInterval(1)))

        _ = feed(&machine, -22, from: 1, seconds: 0.6)
        _ = machine.transcriptFinal("vad sa du", at: t0.addingTimeInterval(1.6))
        #expect(machine.someoneIsTalking(at: t0.addingTimeInterval(1.65)))
        #expect(!machine.someoneIsTalking(at: t0.addingTimeInterval(2.2)))

        #expect(feed(&machine, -70, from: 1.6, seconds: 1) == [.endOfTurn("vad sa du")])
        #expect(machine.phase == .thinking)
        #expect(abs((machine.lastTurnLevelDBFS ?? 0) + 22) < 0.01)
        machine.answerStarted()
        _ = feed(&machine, -20, from: 3, seconds: 0.2)
        #expect(machine.someoneIsTalking(at: t0.addingTimeInterval(3.25)), "also while the answer is being made")
    }
}

@Suite struct RizzSessionTests {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    @Test func theWindowIsTwoMinutes() {
        var session = RizzSession(style: .rolig)
        session.add(.other, text: "gammalt", at: t0)
        session.add(.user, text: "nyare", at: t0.addingTimeInterval(100))
        session.add(.other, text: "nytt", at: t0.addingTimeInterval(130))
        #expect(session.transcript == [SocialRequest.Line(speaker: "user", text: "nyare"), SocialRequest.Line(speaker: "other", text: "nytt")])
    }

    @Test func stayWithinTheBackendLimits() {
        var session = RizzSession(style: .rolig)
        for index in 0..<60 {
            session.add(.other, text: String(repeating: "x", count: 400), at: t0.addingTimeInterval(TimeInterval(index)))
        }
        #expect(session.transcript.count == RizzSession.maxLines)
        #expect(session.transcript[0].text.count == RizzSession.lineLimit)
    }

    @Test func nextWrapsAround() {
        var session = RizzSession(style: .rolig)
        #expect(session.next() == nil)
        session.offer(["Ett", "Två"])
        #expect(session.current == "Ett")
        #expect(session.next() == "Två")
        #expect(session.next() == "Ett")
        session.offer(["Tre"])
        #expect(session.current == "Tre")
        #expect(session.offered == ["Ett", "Två", "Tre"])
    }

    @Test func recognisesAUsedSuggestionLoosely() {
        var session = RizzSession(style: .rolig)
        session.offer(["Hur stark är du egentligen"])
        #expect(session.usesSuggestion("hur stark är du"))
        #expect(!session.usesSuggestion("ska vi gå hem nu"))
    }

    @Test func tagsByLevel() {
        #expect(RizzSpeaker.tag(levelDBFS: -20, thresholdDBFS: -30) == .user)
        #expect(RizzSpeaker.tag(levelDBFS: -40, thresholdDBFS: -30) == .other)
        #expect(RizzSpeaker.tag(levelDBFS: nil, thresholdDBFS: -30) == .other)
    }

    @Test func nextIsAWordOnItsOwn() {
        #expect(RizzCommand.isNext("Nästa."))
        #expect(!RizzCommand.isNext("nästa vecka"))
    }
}

@MainActor
@Suite struct ModeFlowTests {
    private struct Rig {
        let h: ControllerHarness
        let provider: FakeAnswerProvider
        let model: ListeningModel
        let apple: FakeTTSProvider
        let history: HistoryStore
        let activity: FakeActivityPresenter
        let settings: ModeSettings
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.modes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeRig(events: [AnswerEvent], microphone: MicrophoneSource? = nil) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: events)
        let apple = FakeTTSProvider(name: "apple")
        let history = makeTestHistory()
        let activity = FakeActivityPresenter()
        let settings = ModeSettings(defaults: freshDefaults())
        settings.interviewSetup = "Säljare på Volvo"
        let microphones = MicrophoneSettings(defaults: freshDefaults())
        if let microphone {
            for mode in ConversationMode.allCases { microphones.setSource(microphone, for: mode) }
        }
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), activity: activity,
                                   history: history, memory: makeTestMemory(), microphone: microphones, modeSettings: settings)
        return Rig(h: h, provider: provider, model: model, apple: apple, history: history, activity: activity, settings: settings)
    }

    /// One spoken turn at `level`, through the same level and transcript paths as the microphone. It ended a
    /// moment ago, so the room counts as quiet now.
    private func speak(_ text: String, level: Double, rig: Rig) {
        var time = Date().addingTimeInterval(-3)
        for _ in 0..<15 {
            rig.model.study.level(level, at: time)
            time = time.addingTimeInterval(0.04)
        }
        rig.model.receiveFinalTranscript(text, at: time)
        for _ in 0..<30 {
            rig.model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }
    }

    @Test func interviewAlternatesQuestionAndAnswerWithThePersona() async {
        let rig = makeRig(events: [.delta("Svara så här."), .done(AnswerDone(answered: true))], microphone: .airPods)
        await rig.model.startHandsFree(.interview)
        #expect(rig.model.study.isActive)
        rig.model.study.level(-70, at: Date())

        speak("Berätta om dig själv", level: -25, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests[0].persona?.persona == "interview")
        #expect(rig.provider.requests[0].persona?.setup == "Säljare på Volvo")
        #expect(rig.provider.requests[0].persona?.turn == "question")
        #expect(rig.provider.requests[0].mode == "tutor")
        #expect(await waitUntil { rig.history.entries.count == 1 })
        #expect(rig.history.entries[0].question == nil, "the interviewer's words are not saved")
    }

    @Test func prepareSendsTheJobAdAndIsNotSpoken() async {
        let rig = makeRig(events: [.delta("Fråga ett. "), .delta("Svar ett. "), .done(AnswerDone(answered: true))])
        rig.model.prepareInterview()

        #expect(await waitUntil { rig.model.conversation.answers.count == 1 })
        #expect(rig.provider.requests[0].mode == "interview_prep")
        #expect(rig.provider.requests[0].persona?.setup == "Säljare på Volvo")
        #expect(rig.apple.calls.isEmpty)
    }

    @Test func theRequestBodyCarriesPersonaAndSocial() throws {
        let persona = PersonaRequest(persona: "social", social: SocialRequest(style: "rolig", trigger: "stall", transcript: [SocialRequest.Line(speaker: "other", text: "hej")], interests: ["löpning"], profile: ""))
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "", mode: "tutor", language: "sv", persona: persona))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["persona"] as? String == "social")
        let social = try #require(json["social"] as? [String: Any])
        #expect(social["trigger"] as? String == "stall")
        #expect((social["transcript"] as? [[String: String]])?.first == ["speaker": "other", "text": "hej"])
    }

    @Test func suggestionsDecodeFromTheStream() throws {
        let event = SSEEvent(name: "suggestions", data: "[\"Ett\",\"Två\"]")
        #expect(try AnswerSSEDecoder.decode(event) == AnswerEvent.suggestions(["Ett", "Två"]))
    }

    @Test func rizzRespondsToTheOtherPersonSpeaksInAPauseAndShowsAll() async {
        let rig = makeRig(events: [.suggestions(["Bästa", "Andra"]), .done(AnswerDone(answered: true))], microphone: .iPhone)
        await rig.model.startHandsFree(.rizz)
        #expect(rig.h.playback.speechVolume == ListeningModel.rizzVolume)
        rig.model.study.level(-70, at: Date())

        speak("Jag älskar chili", level: -40, rig: rig)

        #expect(await waitUntil { rig.apple.calls.count == 1 })
        #expect(rig.apple.calls[0].text == "Bästa")
        #expect(rig.provider.requests[0].persona?.social?.trigger == "other_spoke")
        #expect(rig.provider.requests[0].persona?.social?.transcript == [SocialRequest.Line(speaker: "other", text: "Jag älskar chili")])
        #expect(rig.activity.lastState?.suggestions == ["Bästa", "Andra"])
    }

    @Test func rizzNeverTalksOverSomeone() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())

        for _ in 0..<5 { rig.model.study.level(-20, at: Date()) }
        rig.model.answerSuggestions(["Bästa", "Andra"])
        try? await Task.sleep(for: .milliseconds(30))

        #expect(rig.apple.calls.isEmpty, "the other person is talking")
        #expect(rig.activity.lastState?.suggestions == ["Bästa", "Andra"], "still on the Lock Screen")
    }

    @Test func nextSpeaksTheNextOption() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        await rig.model.startHandsFree(.rizz)
        rig.model.answerSuggestions(["Bästa", "Andra"])
        #expect(await waitUntil { rig.apple.calls.count == 1 && !rig.model.speaker.isSpeaking })

        rig.model.receiveFinalTranscript("Nästa", at: Date())

        #expect(await waitUntil { rig.apple.calls.count == 2 })
        #expect(rig.apple.calls[1].text == "Andra")
        #expect(rig.activity.lastState?.currentSuggestion == 1)
        #expect(rig.provider.requests.isEmpty, "a command, not a turn")
    }

    @Test func historyKeepsSuggestionsAndNeverTheOtherPersonsWords() async {
        let rig = makeRig(events: [.suggestions(["Bästa"]), .done(AnswerDone(answered: true))], microphone: .iPhone)
        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())
        speak("Jag heter Sara och bor på Södermalm", level: -40, rig: rig)
        #expect(await waitUntil { rig.apple.calls.count == 1 })

        await rig.model.stopListening()

        #expect(rig.model.rizz == nil)
        #expect(rig.model.conversation.finalSegments.isEmpty, "the transcript goes with the session")
        #expect(rig.history.entries.count == 1)
        let entry = rig.history.entries[0]
        #expect(entry.question == nil)
        #expect(entry.suggestions == ["Bästa"])
        #expect(!(entry.summary ?? "").contains("Sara"))
        #expect(rig.h.playback.speechVolume == 1)
    }

    @Test func aUsedSuggestionIsCountedNotStored() async {
        let rig = makeRig(events: [], microphone: .airPods)
        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())
        rig.model.answerSuggestions(["Hur stark är du egentligen"])
        try? await Task.sleep(for: .milliseconds(30))
        rig.model.speaker.interrupt()
        rig.model.study.resumeListening()

        speak("hur stark är du", level: -20, rig: rig)

        #expect(await waitUntil { rig.settings.styleCounts["rolig"] == 1 })
    }

    @Test func theTranscriptEndsWithAnOrdinarySessionToo() async {
        let rig = makeRig(events: [])
        await rig.model.startListening()
        rig.model.receiveFinalTranscript("något någon sa", at: Date())
        await rig.model.stopListening()
        #expect(rig.model.conversation.finalSegments.isEmpty)
    }

    @Test func theModeButtonOpensTheStartScreensAndDoesNotStartTheMicrophone() async {
        let rig = makeRig(events: [])
        rig.model.selectedMode = .rizz
        await rig.model.toggleSelectedMode()
        #expect(rig.model.isShowingRizzStart)
        #expect(!rig.model.isListening, "the consent screen comes first")
        rig.model.selectedMode = .interview
        await rig.model.toggleSelectedMode()
        #expect(rig.model.isShowingInterviewSetup)
    }
}
