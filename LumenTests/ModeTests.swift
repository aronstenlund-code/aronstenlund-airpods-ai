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
        var session = RizzSession(style: .flirt)
        session.add(.other, text: "gammalt", at: t0)
        session.add(.user, text: "nyare", at: t0.addingTimeInterval(100))
        session.add(.other, text: "nytt", at: t0.addingTimeInterval(130))
        #expect(session.transcript == [SocialRequest.Line(speaker: "user", text: "nyare"), SocialRequest.Line(speaker: "other", text: "nytt")])
    }

    @Test func stayWithinTheBackendLimits() {
        var session = RizzSession(style: .flirt)
        for index in 0..<60 {
            session.add(.other, text: String(repeating: "x", count: 400), at: t0.addingTimeInterval(TimeInterval(index)))
        }
        #expect(session.transcript.count == RizzSession.maxLines)
        #expect(session.transcript[0].text.count == RizzSession.lineLimit)
    }

    @Test func nextWrapsAround() {
        var session = RizzSession(style: .flirt)
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
        var session = RizzSession(style: .flirt)
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

    private func makeRig(events: [AnswerEvent], microphone: MicrophoneSource? = nil, adult: Bool = true) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: events)
        let apple = FakeTTSProvider(name: "apple")
        let history = makeTestHistory()
        let activity = FakeActivityPresenter()
        let settings = ModeSettings(defaults: freshDefaults())
        settings.interviewSetup = "Säljare på Volvo"
        if adult { settings.confirmAdult() }
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
        for _ in 0..<45 {
            rig.model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }
    }

    @Test func interviewAlternatesQuestionAndAnswerWithThePersona() async {
        let rig = makeRig(events: [.delta("Svara så här."), .done(AnswerDone(answered: true))], microphone: .airPods)
        await rig.model.startHandsFree(.interview)
        #expect(rig.model.study.isActive)
        rig.model.study.level(-70, at: Date())

        speak("Berätta om dig själv", level: -40, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests[0].persona?.persona == "interview")
        #expect(rig.provider.requests[0].persona?.setup == "Säljare på Volvo")
        #expect(rig.provider.requests[0].persona?.turn == "question")
        #expect(rig.provider.requests[0].mode == "tutor")
        #expect(await waitUntil { rig.history.entries.count == 1 })
        #expect(rig.history.entries[0].question == nil, "the interviewer's words are not saved")

        // D72: the wearer saying the answer aloud gets no feedback and no follow-up.
        _ = await waitUntil { !rig.model.speaker.isSpeaking && !rig.model.speaker.hasPendingSpeech }
        rig.model.study.resumeListening()
        speak("Jag heter Aron och har jobbat med försäljning i fem år", level: -20, rig: rig)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(rig.provider.requests.count == 1, "only the interviewer's questions are answered")
        #expect(rig.model.study.isActive)

        speak("Vad är din största svaghet", level: -40, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 2 })
        #expect(rig.provider.requests[1].persona?.turn == "question")
        #expect(!rig.provider.requests.contains { $0.persona?.turn == "user_answer" })

        // Asking for something out loud is sent: only then is there a summary.
        _ = await waitUntil { !rig.model.speaker.isSpeaking && !rig.model.speaker.hasPendingSpeech }
        rig.model.study.resumeListening()
        speak("Sammanfatta", level: -20, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 3 })
        #expect(rig.provider.requests[2].fragment == "Sammanfatta")
    }

    @Test func interviewRequestsAreRecognised() {
        #expect(VoiceCommand.isInterviewRequest("Klar."))
        #expect(VoiceCommand.isInterviewRequest("ge mig feedback på det"))
        #expect(VoiceCommand.isInterviewRequest("Hur var mitt svar?"))
        #expect(!VoiceCommand.isInterviewRequest("Jag har jobbat med försäljning i fem år"))
        #expect(!VoiceCommand.isInterviewRequest("klarade mig bra"))
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
        let persona = PersonaRequest(persona: "social", social: SocialRequest(style: "flirt", trigger: "stall", transcript: [SocialRequest.Line(speaker: "other", text: "hej")], interests: ["löpning"], profile: ""))
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
        #expect(rig.activity.lastState?.suggestions == ["Bästa"], "exactly one suggestion (D72)")
    }

    @Test func rizzNeverTalksOverSomeone() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())

        for _ in 0..<5 { rig.model.study.level(-20, at: Date()) }
        rig.model.answerSuggestions(["Bästa", "Andra"])
        try? await Task.sleep(for: .milliseconds(30))

        #expect(rig.apple.calls.isEmpty, "the other person is talking")
        #expect(rig.activity.lastState?.suggestions == ["Bästa"], "still on the Lock Screen")
    }

    @Test func nextAsksForAFreshSuggestion() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        await rig.model.startHandsFree(.social)
        rig.model.answerSuggestions(["Bästa", "Andra"])
        #expect(await waitUntil { rig.apple.calls.count == 1 && !rig.model.speaker.isSpeaking })
        #expect(rig.model.rizz?.suggestions == ["Bästa"], "one suggestion, shown and spoken (D72)")

        rig.model.receiveFinalTranscript("Nästa", at: Date())

        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests[0].persona?.social?.trigger == "opener")
        #expect(rig.model.rizz?.transcript.isEmpty == true, "a command, not a line of the conversation")
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

        #expect(await waitUntil { rig.settings.styleCounts["flirt"] == 1 })
    }

    @Test func theTranscriptEndsWithAnOrdinarySessionToo() async {
        let rig = makeRig(events: [])
        await rig.model.startListening()
        rig.model.receiveFinalTranscript("något någon sa", at: Date())
        await rig.model.stopListening()
        #expect(rig.model.conversation.finalSegments.isEmpty)
    }

    @Test func withoutAgeConfirmationNoRizzRequestIsSent() async {
        let rig = makeRig(events: [.suggestions(["Bästa"]), .done(AnswerDone(answered: true))], microphone: .iPhone, adult: false)

        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())
        speak("Jag älskar chili", level: -40, rig: rig)
        try? await Task.sleep(for: .milliseconds(30))

        #expect(!rig.model.study.isActive)
        #expect(!rig.model.isListening, "the microphone stays off")
        #expect(rig.model.isShowingAgeGate)
        #expect(rig.provider.requests.isEmpty)
    }

    @Test func theGateComesTheFirstTimeAndCancelGoesBack() {
        let rig = makeRig(events: [], adult: false)
        rig.model.selectedMode = .rizz
        rig.model.modeSelected()
        #expect(rig.model.isShowingAgeGate)

        rig.model.answerAgeGate(confirmed: false)

        #expect(rig.model.selectedMode == .standard)
        #expect(!rig.settings.isAdultConfirmed)
    }

    @Test func theAnswerIsRememberedOnThisPhone() {
        let defaults = freshDefaults()
        ModeSettings(defaults: defaults).confirmAdult()
        #expect(ModeSettings(defaults: defaults).isAdultConfirmed)

        let rig = makeRig(events: [], adult: false)
        rig.model.selectedMode = .rizz
        rig.model.modeSelected()
        rig.model.answerAgeGate(confirmed: true)
        rig.model.modeSelected()
        #expect(!rig.model.isShowingAgeGate)
        #expect(rig.model.selectedMode == .rizz)
    }

    @Test func rizzFlirtsAndSaysTheUserIsAnAdult() async throws {
        let rig = makeRig(events: [.suggestions(["Bästa"]), .done(AnswerDone(answered: true))], microphone: .iPhone)
        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())
        speak("Jag älskar chili", level: -40, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 1 })

        let persona = rig.provider.requests[0].persona
        #expect(persona?.social?.style == "flirt")
        #expect(persona?.adultConfirmed == true)
        let body = CloudAnswerProvider.encodeBody(rig.provider.requests[0])
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["adult_confirmed"] as? Bool == true)
    }

    @Test func socialLageNeedsNoAgeAndNeverSendsTheFlag() async throws {
        let rig = makeRig(events: [.suggestions(["Bästa"]), .done(AnswerDone(answered: true))], microphone: .iPhone, adult: false)
        rig.model.selectedMode = .social
        rig.model.modeSelected()
        #expect(!rig.model.isShowingAgeGate)

        await rig.model.startHandsFree(.social)
        #expect(rig.model.study.isActive)
        rig.model.study.level(-70, at: Date())
        speak("Jag älskar chili", level: -40, rig: rig)
        #expect(await waitUntil { rig.apple.calls.count == 1 })

        let persona = rig.provider.requests[0].persona
        #expect(persona?.persona == "social")
        #expect(persona?.social?.style == "social")
        #expect(persona?.adultConfirmed == nil)
        let body = CloudAnswerProvider.encodeBody(rig.provider.requests[0])
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["adult_confirmed"] == nil)
    }

    @Test func theModeButtonOpensTheStartScreensAndDoesNotStartTheMicrophone() async {
        let rig = makeRig(events: [])
        rig.model.selectedMode = .rizz
        await rig.model.toggleSelectedMode()
        #expect(rig.model.isShowingLiveStart)
        #expect(!rig.model.isListening, "the consent screen comes first")
        rig.model.isShowingLiveStart = false
        rig.model.selectedMode = .social
        await rig.model.toggleSelectedMode()
        #expect(rig.model.isShowingLiveStart)
        rig.model.selectedMode = .interview
        await rig.model.toggleSelectedMode()
        #expect(rig.model.isShowingInterviewSetup)
    }
}
