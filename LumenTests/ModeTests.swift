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

    /// D199 step 1 (A111): Intervjuläge's decisions live in `InterviewModeController`, wired to the model, with the
    /// same persona and words as before the move.
    @Test func interviewIsItsOwnController() {
        let rig = makeRig(events: [])
        let interview = rig.model.interviewMode
        #expect(interview.mode == .interview)
        #expect(interview.host === rig.model)
        #expect(interview.spokenKeyterms.isEmpty)
        #expect(interview.persona(turn: "question").persona == "interview")
        #expect(interview.persona(turn: "question").setup == "Säljare på Volvo")
        #expect(interview.persona(turn: "question").turn == "question")
        #expect(interview.persona().turn == nil, "the preparation has no turn, as before")
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

    /// D199 step 2 (A113): the live session is `LiveModeController`, shared by Socialt läge and Rizzläge; the views
    /// still read it through `model.rizz`.
    @Test func theLiveSessionIsItsOwnController() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        #expect(rig.model.liveMode.host === rig.model)
        #expect(rig.model.socialMode.mode == .social)
        #expect(rig.model.socialMode.spokenKeyterms == ["rizz", "cringe", "flirtig", "flirtigare"])
        let ahead = rig.model.socialMode.aheadRequest(for: "Vad gör du i helgen?")
        #expect(ahead == nil, "a live mode answers ahead with a suggestion")
        #expect(!rig.model.liveMode.isActive && rig.model.rizz == nil)

        await rig.model.startHandsFree(.social)
        #expect(rig.model.liveMode.isActive)
        #expect(rig.model.rizz == rig.model.liveMode.session)
        rig.model.answerSuggestions(["Bästa", "Andra"])
        #expect(rig.model.liveMode.session?.suggestions == ["Bästa"], "D72: one suggestion, through the controller")
        #expect(!rig.model.liveMode.isInstructing)

        await rig.model.stopListening()
        #expect(!rig.model.liveMode.isActive && rig.model.rizz == nil)
    }

    /// D199 step 3 (A114): Rizzläge's own rules are `RizzModeController`, on the same live session as Socialt läge.
    /// D112 (owner): there is no 18+ gate any more, so the age check it carries never stops anything today.
    @Test func rizzIsItsOwnControllerOnTheSharedLiveSession() async {
        let rig = makeRig(events: [], microphone: .iPhone, adult: false)
        let rizz = rig.model.rizzMode
        #expect(rizz.mode == .rizz && rizz.style == .flirt)
        #expect(rizz.spokenKeyterms == rig.model.socialMode.spokenKeyterms)
        #expect(!rizz.needsAgeConfirmation, "D112: Rizzläge is for all ages")

        await rig.model.startHandsFree(.rizz)
        #expect(!rig.model.isShowingAgeGate, "D112: no gate, as before A114")
        #expect(rig.model.liveMode.isActive && rig.model.rizz?.style == .flirt)
        rig.model.answerSuggestions(["Bästa", "Andra"])
        #expect(rig.model.liveMode.session?.suggestions == ["Bästa"], "the same live session as Socialt läge")
        await rig.model.stopListening()
        #expect(!rig.model.liveMode.isActive)
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

    @Test func rizzNeedsNoAgeQuestion() async {
        // D112 (owner) / A35: Rizzläge is for all ages; there is no gate and nothing waits for one.
        let rig = makeRig(events: [.suggestions(["Bästa"]), .done(AnswerDone(answered: true))], microphone: .iPhone, adult: false)
        rig.model.selectedMode = .rizz
        rig.model.modeSelected()
        #expect(!rig.model.isShowingAgeGate)
        #expect(rig.settings.isAdultConfirmed)
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

    /// D199 step 5 (A120): Frågor's decisions are `StandardModeController`, and the "Mer?" window with its two levels
    /// is `MoreWindow`, which Provläge shares. The screen still reads the window through `model.isOfferingMore`.
    @Test func standardIsItsOwnController() {
        let rig = makeRig(events: [])
        let standard = rig.model.standardMode
        #expect(standard.mode == .standard)
        #expect(standard.host === rig.model && standard.more.host === rig.model)
        #expect(standard.spokenKeyterms == ["kortare", "upprepa", "viska", "högre"])
        #expect(standard.startBlock() == nil && standard.startScreen() == nil, "the button starts Frågor directly")
        #expect(rig.model.modeController(for: .standard) === standard)
        #expect(rig.model.modeController(for: .prov) === rig.model.provMode, "Provläge has its own since step 6c")

        // D80: only what the question gate would take is answered ahead, as an auto question.
        let ahead = standard.aheadRequest(for: "Vad är fotosyntes?")
        #expect(ahead?.request.trigger == .auto && ahead?.persona == nil)
        #expect(standard.aheadRequest(for: "Det regnar i dag.") == nil)

        // A75: after the name alone ("Ja?") the next sentence is said to Lumen, whatever the gate thinks of it.
        standard.nameAlone(at: Date())
        #expect(standard.aheadRequest(for: "Det regnar i dag.")?.request.trigger == .text)

        // A15, A56: the window and the two levels are for Frågor and Provläge only.
        #expect(MoreWindow.applies(to: .standard) && MoreWindow.applies(to: .prov))
        #expect(!MoreWindow.applies(to: .interview) && !MoreWindow.applies(to: .social) && !MoreWindow.applies(to: .rizz))
        #expect(!standard.more.isOpen && !rig.model.isOfferingMore)
        #expect(!standard.more.takes("ja", at: Date()), "no window, so \"ja\" is an ordinary turn")
    }

    /// D199 step 6a (A121): the exam session inside Provläge (D84) is `ExamSessionController`. The model's checks
    /// (`exam != nil`) read its session, and "Lumen, …" goes to it while a session runs.
    @Test func theExamSessionIsItsOwnController() {
        let rig = makeRig(events: [])
        let exam = rig.model.examSession
        #expect(exam.mode == .prov && exam.host === rig.model)
        #expect(!exam.isActive && rig.model.exam == nil && !rig.model.hasRunningExercise)
        #expect(exam.spokenKeyterms == rig.model.standardMode.spokenKeyterms)
        #expect(exam.startBlock() == nil && exam.startScreen() == nil)

        var paper = ExamPaper()
        paper.tasks = [ExamTask(no: "1", text: "Vad är 2 + 2?", points: .init(E: 1, C: 0, A: 0), answer: "4", assessment: ""),
                       ExamTask(no: "2", text: "Lös x + 1 = 3.", points: .init(E: 1, C: 1, A: 0), answer: "2", assessment: "")]
        exam.begin(paper: paper)
        #expect(exam.isActive && rig.model.exam?.paper == paper, "the model reads the controller's session")
        #expect(rig.model.hasRunningExercise, "no \"Mer?\" and no tips while the session runs")
        #expect(exam.aheadRequest(for: "Vad är fotosyntes?") == nil, "nothing is answered ahead in the session")

        rig.model.instruct("uppgift två") // "Lumen, uppgift två" through the model
        #expect(rig.model.exam?.currentTask?.no == "2")
        rig.model.instruct("vad är fotosyntes") // not an exam command: not answered
        #expect(rig.provider.requests.isEmpty)
        #expect(rig.model.exam?.currentTask?.no == "2")

        rig.model.instruct("avsluta provet")
        #expect(!exam.isActive && rig.model.exam == nil)
    }

    /// D199 step 6b (A125): the practice exam by voice inside Provläge (A16) is `PracticeExamController`. The screen
    /// still reads the run and its result through `model.practice` and `model.practiceResult`.
    @Test func thePracticeExamIsItsOwnController() throws {
        let rig = makeRig(events: [])
        let practice = rig.model.practiceExam
        #expect(practice.mode == .prov && practice.host === rig.model)
        #expect(!practice.isActive && rig.model.practice == nil && rig.model.practiceResult == nil)
        #expect(practice.spokenKeyterms == rig.model.standardMode.spokenKeyterms)
        #expect(practice.startBlock() == nil && practice.startScreen() == nil)

        var paper = ExamPaper()
        paper.tasks = [ExamTask(no: "1", text: "Vad är 2 + 2?", points: .init(E: 1, C: 0, A: 0), answer: "4", assessment: ""),
                       ExamTask(no: "2", text: "Lös x + 1 = 3.", points: .init(E: 1, C: 1, A: 0), answer: "2", assessment: "")]
        practice.begin(try #require(PracticeRun(paper: paper)))
        #expect(practice.isActive && rig.model.practice?.index == 0, "the model reads the controller's run")
        #expect(rig.model.hasRunningExercise)
        #expect(practice.aheadRequest(for: "Vad är fotosyntes?") == nil, "nothing is answered ahead in the run")

        practice.turn("nästa")
        #expect(rig.model.practice?.index == 1)
        practice.instruction("förra") // A16: "Lumen, förra" works as well as "förra"
        #expect(rig.model.practice?.index == 0)

        practice.turn("avsluta provet")
        #expect(!practice.isActive && rig.model.practice == nil)
        #expect(rig.model.practiceResult != nil, "the result stays on the listening screen")
        rig.model.dismissPracticeResult()
        #expect(rig.model.practiceResult == nil)
        #expect(rig.provider.requests.isEmpty, "the run never goes through the answer pipeline")
    }

    /// D199 step 6c (A126): Provläge is `ProvModeController`. It holds the exam session, the practice exam and the
    /// mini test (`MiniTestController`), and offers a turn to them in the order the model had: the practice exam
    /// before the filler filter, then the mini test, then the exam session, then the ordinary turn to the tutor.
    @Test func provlageIsItsOwnControllerAndKeepsTheTurnOrder() throws {
        let rig = makeRig(events: [])
        let prov = rig.model.provMode
        #expect(prov.mode == .prov && prov.host === rig.model)
        #expect(prov.exam === rig.model.examSession && prov.practice === rig.model.practiceExam)
        #expect(prov.exam.host === rig.model && prov.practice.host === rig.model && prov.miniTest.host === rig.model)
        #expect(prov.spokenKeyterms == rig.model.standardMode.spokenKeyterms)
        #expect(prov.startBlock() == nil && prov.startScreen() == nil)
        #expect(prov.aheadRequest(for: "Vad är fotosyntes?") == nil, "Provläge is not listening")
        #expect(!prov.takesUnfiltered("ja") && !prov.takesInstruction("nästa", inProv: true), "no exercise is running")

        var paper = ExamPaper()
        paper.tasks = [ExamTask(no: "1", text: "Vad är 2 + 2?", points: .init(E: 1, C: 0, A: 0), answer: "4", assessment: ""),
                       ExamTask(no: "2", text: "Lös x + 1 = 3.", points: .init(E: 1, C: 1, A: 0), answer: "2", assessment: "")]
        prov.exam.begin(paper: paper)
        prov.miniTest.begin(cards: [StudyCard(question: "Vad är en cell", answer: "Livets minsta del.", subject: nil, examDate: nil)])
        #expect(prov.miniTest.isActive && rig.model.miniTest != nil && rig.model.hasRunningExercise)

        // The mini test is asked before the exam session: "vet inte" skips its only card, and the test is over.
        prov.turn("vet inte")
        #expect(!prov.miniTest.isActive && rig.model.miniTest == nil)
        #expect(prov.exam.isActive, "the exam session was not asked")

        // Then the exam session: nothing is answered, only "Lumen, …" counts.
        prov.turn("Vad är fotosyntes?")
        #expect(rig.provider.requests.isEmpty)
        #expect(prov.takesInstruction("uppgift två", inProv: false), "the exam session takes \"Lumen, …\" in any mode, as before")
        #expect(rig.model.exam?.currentTask?.no == "2")

        // The practice exam comes first of all, and only in Provläge for "Lumen, …".
        prov.practice.begin(try #require(PracticeRun(paper: paper)))
        #expect(prov.takesUnfiltered("nästa") && rig.model.practice?.index == 1)
        #expect(prov.takesInstruction("förra", inProv: true) && rig.model.practice?.index == 0)
        #expect(rig.provider.requests.isEmpty, "no exercise goes through the answer pipeline here")
    }

    /// D199 step 6d (A127): the silent quiz inside Provläge (A20.2) is `SilentQuizController`, a part of `provMode`.
    /// The screen still reads the quiz through `model.silentQuiz` and starts it with `model.startSilentQuiz()`.
    @Test func theSilentQuizIsItsOwnController() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        let quiz = rig.model.provMode.silentQuiz
        #expect(quiz.host === rig.model && !quiz.isActive && rig.model.silentQuiz == nil)
        rig.model.startSilentQuiz()
        #expect(!quiz.isActive && rig.provider.requests.isEmpty, "only inside a running Provläge")

        await rig.model.startHandsFree(.prov)
        #expect(rig.model.study.isActive)
        rig.model.startSilentQuiz()
        #expect(quiz.isActive && rig.model.silentQuiz != nil && rig.model.hasRunningExercise)
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests.first?.fragment == SilentQuiz.questionRequest, "the first question is asked for")
        rig.model.startSilentQuiz()
        #expect(rig.provider.requests.count == 1, "a running quiz is not started again")
        quiz.answeredByVoice()
        #expect(rig.model.silentQuiz?.awaitingAnswer == false, "no question waits yet, so \"ja\" answers nothing")

        await rig.model.startHandsFree(.standard)
        #expect(!quiz.isActive && rig.model.silentQuiz == nil, "leaving Provläge ends the quiz, as before")
    }

    /// D199 step 6e (A128): the study plan (today's plan, the reminders, the summary at "avsluta", the links) is
    /// `StudyPlanController`, a part of `provMode`. Start still reads the plan through the model.
    @Test func theStudyPlanIsItsOwnController() async {
        let rig = makeRig(events: [])
        let plan = rig.model.provMode.studyPlan
        #expect(plan.host === rig.model && plan.plans.isEmpty)
        #expect(!plan.isSummarizing && !rig.model.canAskForReminders)

        // A19.2: the summary is only for a Provläge that runs and has had real questions.
        #expect(!plan.summarizeBeforeEnding(), "no Provläge runs: nothing to summarise")
        #expect(!plan.isSummary(ActivationRequest(query: "avsluta", trigger: .tutor, language: .swedish)))
        plan.endAfterSummary(reason: "test") // no summary is on its way: nothing ends
        plan.cancelSummary()
        #expect(!plan.isSummarizing && rig.provider.requests.isEmpty)

        // A19: without Kevin's /study-plan (the rig has no client) there is no plan and nothing is asked.
        await rig.model.refreshStudyPlan()
        #expect(plan.plans.isEmpty && !rig.model.canAskForReminders)

        // A43: Start reads the readiness and today's line from the plan, through the model.
        let exam = ExamPlan(grade: .y9, area: .no, subject: "Biologi", date: Date().addingTimeInterval(5 * 86_400), topics: "fotosyntes")
        #expect(rig.model.readiness(for: exam) == nil && rig.model.todayLine(for: exam) == nil)
        #if DEBUG // the staging is for the Simulator screenshots, in Debug builds only
        let today = StudyHistory.day(Date())
        let reply = StudyPlanAPI.ExamPlanReply(
            name: exam.name, date: StudyHistory.day(exam.date), daysLeft: 5, prompt: "I går missade du mitos. Ska vi ta det nu?",
            plan: [StudyPlanAPI.Day(date: today, minutes: 10, concepts: ["cellandning", "mitos"], note: nil)],
            readiness: StudyPlanAPI.Readiness(readyPct: 68, practiced: 7, total: 12, weakest: [], explain: ""))
        plan.stage(exam, reply: reply)
        #expect(rig.model.readiness(for: exam)?.readyPct == 68)
        #expect(rig.model.todayLine(for: exam) == StudyPlanAPI.todayLine(subject: "Biologi", day: reply.plan[0]))
        plan.sayPrompt(for: exam)
        #expect(rig.apple.calls.isEmpty, "the plan's question is only said in a Provläge that runs")
        #endif
    }

    /// D221 (A137, G7 step 7a): Provläge's ordinary turn (the question to the tutor, the tutor's persona, the last
    /// turns) is in `ProvModeController`, and the queue of split turns is `TurnQueue`, which Frågor shares.
    @Test func provlagesOrdinaryTurnIsInItsControllerAndTheQueueIsItsOwnPart() async {
        let rig = makeRig(events: [], microphone: .iPhone)
        let prov = rig.model.provMode
        let queue = rig.model.turnQueue
        #expect(queue.host === rig.model && queue.isEmpty && prov.turns.isEmpty)
        #expect(rig.model.tutorPersona() == prov.tutorPersona(), "the model asks the controller for the persona")

        // Outside a hands-free session nothing is asked from the queue.
        queue.putFirst(["Vad är mitos?"])
        #expect(!queue.askNext() && !queue.isEmpty)
        queue.clear()
        #expect(queue.isEmpty)

        await rig.model.startHandsFree(.prov)
        #expect(rig.model.study.isActive)
        prov.turn("Vad är mitos?")
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(prov.turns.map(\.text) == ["Vad är mitos?"] && prov.turns.first?.answered == false)
        #expect(prov.turnsBefore("Vad är mitos?").isEmpty, "the turn being answered is not a recent turn")
        #expect(prov.turnsBefore("Vad är en cell?").map(\.text) == ["Vad är mitos?"])
        prov.turnAnswered("Vad är mitos?")
        #expect(prov.turns.first?.answered == true)

        // A queued turn is asked instead of listening again, and it is a Provläge turn too (D87).
        queue.putFirst(["Vad är en cell?"])
        #expect(queue.askNext() && queue.isEmpty)
        #expect(prov.turns.map(\.text) == ["Vad är mitos?", "Vad är en cell?"])

        prov.forgetTurns() // another exam is studied
        #expect(prov.turns.isEmpty)
    }

    /// D231 (A149, G7 step 7b): the voice channel ("Lumen, …", the short commands and the tips) is
    /// `VoiceCommandsController`. The model and the screens reach it through the model, as before.
    @Test func theVoiceChannelIsItsOwnPart() {
        let rig = makeRig(events: [], microphone: .iPhone)
        let voice = rig.model.voiceCommands
        #expect(voice.host === rig.model)
        #expect(rig.model.tipNotice == nil && voice.tipNotice == nil)
        #expect(rig.model.commandsLine(for: .prov) == voice.commandsLine(for: .prov))

        // Words that are not for Lumen are conversation.
        #expect(!voice.heard(in: "vi ses i morgon", at: Date()))

        // A level 1 command is done on the phone: "kortare" sets the session's length, through the model or the part.
        rig.model.runCommand(.shorter)
        #expect(rig.model.answers.sessionLength == .short)
        voice.runCommand(.longer)
        #expect(rig.model.answers.sessionLength == .long)

        // "Lumen, kortare" is for Lumen. The same command again within 5 s is one command (the partial and the final
        // result both carry it), so the length chosen in between stays.
        #expect(voice.heard(in: "Lumen, kortare", at: Date()))
        #expect(rig.model.answers.sessionLength == .short)
        voice.runCommand(.longer)
        #expect(voice.heard(in: "Lumen, kortare", at: Date()))
        #expect(rig.model.answers.sessionLength == .long)
    }

    /// D231 (A149, G7 step 7c): how Provläge is started and which exam it is about is `ExamStartController`. The
    /// model and the screens reach it through the model, as before.
    @Test func theExamStartIsItsOwnPart() {
        let rig = makeRig(events: [], microphone: .iPhone)
        let start = rig.model.examStart
        #expect(start.host === rig.model)
        #expect(start.activeExamID == nil && rig.model.activeExamID == nil)
        #expect(!rig.model.provAnswersOnly && !rig.model.examQuestionDeclined && !rig.model.startsProvAfterExamStep)
        #expect(rig.model.currentExamID() == start.currentExamID())

        // Nothing was asked: ordinary words are not an exam said aloud, and not a subject.
        #expect(!rig.model.awaitingExamStatement)
        #expect(!start.takesExamStatement("Biologi på fredag", overlapsPlayback: false, at: Date()))
        #expect(!start.takesSubject("biologi", overlapsPlayback: false))

        // "Har du prov snart?" is answered in time; the rule is the part's, and the model's name for it still works.
        let asked = Date()
        #expect(ExamStartController.answersExamQuestion("Biologi på fredag", askedAt: asked, at: asked.addingTimeInterval(5)))
        #expect(!ListeningModel.answersExamQuestion("Biologi på fredag", askedAt: asked,
                                                    at: asked.addingTimeInterval(ExamStartController.examAnswerWindow + 15)))

        // The exam step is closed: the next sentence is an ordinary one.
        start.stopListeningForExamStatement()
        #expect(!rig.model.awaitingExamStatement)
    }

    /// D199 step 4 (A119): each mode says what the app must show before it starts; the model shows the sheet or
    /// says the line. The same checks as before the move.
    @Test func eachModeSaysWhatItNeedsBeforeItStarts() async {
        let rig = makeRig(events: [])
        #expect(rig.model.startBlock(for: .standard) == nil && rig.model.startBlock(for: .prov) == nil)
        #expect(rig.model.startBlock(for: .interview) == nil, "the rig has a role")
        rig.settings.interviewSetup = ""
        #expect(rig.model.startBlock(for: .interview) == .interviewSetup)
        #expect(rig.model.startBlock(for: .social) == .liveStartScreen)
        #expect(rig.model.startBlock(for: .rizz) == .liveStartScreen, "D112: no age question, only the start screen")
        rig.settings.confirmLiveStart(.social)
        #expect(rig.model.startBlock(for: .social) == nil)
        #expect(rig.model.socialMode.startScreen() == .liveStartScreen, "the mode button opens it every time")

        #expect(ModeStartBlock.liveStartScreen.spokenLine(for: .rizz) == "Rizzläge startas i appen första gången.")
        #expect(ModeStartBlock.interviewSetup.spokenLine(for: .interview) == "Intervjuläge behöver en roll i appen först.")

        await rig.model.switchMode(to: .rizz)
        #expect(rig.model.selectedMode == .rizz && rig.model.isShowingLiveStart, "Byt läge: selected, its sheet shown")
        rig.model.isShowingLiveStart = false
        await rig.model.switchMode(to: .interview)
        #expect(rig.model.selectedMode == .interview && rig.model.isShowingInterviewSetup)
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
