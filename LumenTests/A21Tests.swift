import Foundation
import Testing
@testable import Lumen

/// A21.2: what counts as a question that stops mid-thought.
@Suite struct UnfinishedQuestionTests {
    @Test func halfQuestionsFromTobysT5() {
        for text in ["Vilka är de största?", "vilka är de största", "Vad är skillnaden mellan ett virus",
                     "Vem är den bästa", "what is the difference between a virus", "Vad är en", "Vilka städer och"] {
            #expect(UnfinishedQuestion.looksUnfinished(text), "\(text)")
        }
    }

    @Test func wholeQuestionsAreNeverHeld() {
        for text in ["Vad handlar boken om?", "Var kommer du från?", "Vad är det?", "Vad är fotosyntes?",
                     "Vad är skillnaden mellan mitos och meios?", "Hur många invånare har Sverige ungefär?",
                     "Varför?", "Vad tänker du på?", "Vad består det av?", "Vem skrev Röda rummet?",
                     "Vilka är de största bergen i världen?", "Vad betyder ordet empati?", "Where is the forest?",
                     "vad är skillnaden mellan ett virus och en bakterie"] {
            #expect(!UnfinishedQuestion.looksUnfinished(text), "\(text)")
        }
    }

    @Test func longUtterancesAreNeverHeld() {
        #expect(!UnfinishedQuestion.looksUnfinished("jag har funderat länge på vad som egentligen händer i en"))
    }
}

/// A21.2 in Frågor: the half question waits for its rest instead of being answered.
@MainActor
@Suite struct UnfinishedActivationTests {
    private let t0 = Date(timeIntervalSince1970: 2_100_000)

    private func recording(_ controller: ActivationController) -> () -> [String] {
        final class Box { var queries: [String] = [] }
        let box = Box()
        controller.onActivate = { box.queries.append($0.query) }
        return { box.queries }
    }

    private func say(_ text: String, at seconds: TimeInterval, to controller: ActivationController, in conversation: inout Conversation) {
        conversation.finalize(text, at: t0.addingTimeInterval(seconds))
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0.addingTimeInterval(seconds))
    }

    @Test func theRestJoinsTheHeldHalf() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        say("Vilka är de största?", at: 0, to: controller, in: &conversation)
        #expect(fired().isEmpty, "not answered at once")
        #expect(controller.pendingIsUnfinished)
        say("bergen i världen?", at: 1.5, to: controller, in: &conversation)
        #expect(!controller.pendingIsUnfinished)
        #expect(controller.fireDue(now: t0.addingTimeInterval(1.5)))
        #expect(fired() == ["Vilka är de största? bergen i världen?"])
    }

    @Test func aHalfWithNoRestIsAskedAfterTheHold() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        say("Vilka är de största?", at: 0, to: controller, in: &conversation)
        #expect(!controller.fireDue(now: t0.addingTimeInterval(UnfinishedQuestion.hold - 0.1)))
        #expect(controller.fireDue(now: t0.addingTimeInterval(UnfinishedQuestion.hold)))
        #expect(fired() == ["Vilka är de största?"])
    }

    @Test func wordsStillComingKeepTheHalfWaiting() {
        let controller = makeTestActivation()
        _ = recording(controller)
        var conversation = Conversation()
        say("Vad är skillnaden mellan ett virus", at: 0, to: controller, in: &conversation)
        controller.speechContinues(now: t0.addingTimeInterval(2.8))
        #expect(!controller.fireDue(now: t0.addingTimeInterval(3.2)), "the rest is being spoken")
        #expect(controller.fireDue(now: t0.addingTimeInterval(2.8 + ActivationController.continuesHold)))
    }

    @Test func aCompleteQuestionStillGoesAtOnce() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        say("Vem skrev Röda rummet?", at: 0, to: controller, in: &conversation)
        #expect(fired() == ["Vem skrev Röda rummet?"])
    }

    /// After the hold the half was asked; its rest still replaces it (Scribe's "?" no longer blocks the merge).
    @Test func aLateRestStillCompletesAQuestionMarkedHalf() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        say("Vilka är de största?", at: 0, to: controller, in: &conversation)
        #expect(controller.fireDue(now: t0.addingTimeInterval(UnfinishedQuestion.hold)))
        say("bergen i världen", at: 4, to: controller, in: &conversation)
        #expect(fired() == ["Vilka är de största?", "Vilka är de största? bergen i världen"])
    }
}

/// A21.2 in Provläge: the turn's endpoint is longer when its words stop mid-thought.
@Suite struct UnfinishedTurnTests {
    private let t0 = Date(timeIntervalSince1970: 3_200_000)

    private func firstEvent(_ machine: inout StudyMachine, level: Double, from start: TimeInterval, seconds: TimeInterval) -> (StudyEvent?, TimeInterval) {
        var t = start
        while t <= start + seconds + 1e-9 {
            if let event = machine.level(level, at: t0.addingTimeInterval(t)) { return (event, t) }
            t += 0.04
        }
        return (nil, start + seconds)
    }

    private func machine(hold: TimeInterval) -> StudyMachine {
        var tuning = StudyTuning()
        tuning.unfinishedHold = hold
        var machine = StudyMachine(tuning: tuning)
        machine.start(at: t0)
        _ = firstEvent(&machine, level: -62, from: 0, seconds: 1.0)
        var t = 1.04 // speech until 1.64 s, every reading (the onset event must not stop the feed)
        while t <= 1.64 + 1e-9 {
            _ = machine.level(-28, at: t0.addingTimeInterval(t))
            t += 0.04
        }
        return machine
    }

    @Test func aHalfTurnWaitsForTheHold() {
        var m = machine(hold: 3)
        _ = m.transcriptFinal("Vilka är de största?", at: t0.addingTimeInterval(1.7))
        let (event, at) = firstEvent(&m, level: -62, from: 1.68, seconds: 6)
        #expect(event == .endOfTurn("Vilka är de största?"))
        #expect(at >= 1.64 + 0.8 + 3 - 0.05, "ended at \(at)")
    }

    @Test func theRestArrivesAndTheTurnIsWhole() {
        var m = machine(hold: 3)
        _ = m.transcriptFinal("Vilka är de största?", at: t0.addingTimeInterval(1.7))
        #expect(firstEvent(&m, level: -62, from: 1.68, seconds: 2.0).0 == nil)
        _ = firstEvent(&m, level: -28, from: 3.72, seconds: 0.6)
        _ = m.transcriptFinal("bergen i världen?", at: t0.addingTimeInterval(4.4))
        let (event, _) = firstEvent(&m, level: -62, from: 4.36, seconds: 2)
        #expect(event == .endOfTurn("Vilka är de största? bergen i världen?"))
    }

    @Test func withoutTheHoldNothingChanges() {
        var m = machine(hold: 0)
        _ = m.transcriptFinal("Vilka är de största?", at: t0.addingTimeInterval(1.7))
        let (event, at) = firstEvent(&m, level: -62, from: 1.68, seconds: 3)
        #expect(event == .endOfTurn("Vilka är de största?"))
        #expect(at < 1.64 + 0.8 + 0.2)
    }
}

/// A21.3: the recogniser's safety timer.
@Suite struct OwnSpeechDeadlineTests {
    private let t0 = Date(timeIntervalSince1970: 4_000_000)

    @Test func sentencesAddUpAndAGapStartsFromNow() {
        var deadline = OwnSpeechDeadline()
        let first = String(repeating: "a", count: 26) // 2 s at rate 1
        deadline.spoke(first, rate: 1, at: t0)
        #expect(deadline.deadline == t0.addingTimeInterval(2 + OwnSpeechDeadline.margin))
        deadline.spoke(first, rate: 1, at: t0.addingTimeInterval(0.5)) // queued while the first plays
        #expect(deadline.deadline == t0.addingTimeInterval(4 + OwnSpeechDeadline.margin))
        deadline.spoke(first, rate: 1, at: t0.addingTimeInterval(10)) // after a gap
        #expect(deadline.deadline == t0.addingTimeInterval(12 + OwnSpeechDeadline.margin))
        #expect(!deadline.isOverdue(at: t0.addingTimeInterval(13.9)))
        #expect(deadline.isOverdue(at: t0.addingTimeInterval(14)))
        deadline.reset()
        #expect(!deadline.isOverdue(at: t0.addingTimeInterval(100)))
    }

    @Test func aFasterVoiceIsShorter() {
        #expect(OwnSpeechDeadline.seconds(for: String(repeating: "a", count: 26), rate: 2) == 1)
    }
}

/// A21.4: Scribe's result for words already used from a partial.
@Suite struct UsedWordsTests {
    private let used = AheadAnswer.key("Vem skrev Röda rummet")

    @Test func theSameWordsAreDropped() {
        #expect(UsedWords.remainder(of: "Vem skrev Röda rummet?", after: used) == "")
        #expect(UsedWords.remainder(of: "Vem skrev", after: used) == "")
    }

    @Test func newWordsAfterThemAreKept() {
        #expect(UsedWords.remainder(of: "Vem skrev Röda rummet? Och när kom den ut?", after: used) == "Och när kom den ut?")
    }

    @Test func otherWordsAreNotTouched() {
        #expect(UsedWords.remainder(of: "Vem skrev Hamlet?", after: used) == nil)
        #expect(UsedWords.remainder(of: "Vad är 250×250?", after: AheadAnswer.key("vad är 250×250")) == "")
    }
}

/// A21.4 on the coordinator: words Scribe never commits are asked for, then used as the final.
@MainActor
@Suite struct StaleWordsTests {
    @MainActor final class Rig {
        let h = ControllerHarness()
        let sink = FakeTranscriptSink()
        var created: [FakeSTTProvider] = []
        var coordinator: TranscriptionCoordinator!
    }

    private func makeRig() -> Rig {
        let rig = Rig()
        let suite = "lumen.tests.a21.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = STTSettings(defaults: defaults)
        settings.useCloud = true
        rig.coordinator = TranscriptionCoordinator(controller: rig.h.controller,
                                                   language: LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE")),
                                                   settings: settings,
                                                   probe: { _ in SpeechEngineAvailability(speechTranscriberLocales: ["sv-se"]) },
                                                   makeProvider: { [rig] locale, engine in
            let provider = FakeSTTProvider(locale: locale, engine: engine)
            rig.created.append(provider)
            return provider
        })
        rig.coordinator.sink = rig.sink
        return rig
    }

    @Test func uncommittedWordsBecomeAFinalAndScribesLateFinalIsDropped() async {
        let rig = makeRig()
        await rig.h.controller.start()
        #expect(await waitUntil { rig.coordinator.status == .running(.scribe) })
        guard let scribe = rig.created.first else { Issue.record("no provider"); return }
        scribe.emit.yield(STTResult(text: "Vem skrev Röda rummet", isFinal: false))

        #expect(await waitUntil(timeout: .seconds(4)) { scribe.commits == 1 }, "the final is asked for")
        #expect(await waitUntil(timeout: .seconds(4)) { rig.sink.finals == ["Vem skrev Röda rummet"] }, "then the partial is used")
        #expect(rig.coordinator.partialsUsedAsFinal == 1)

        scribe.emit.yield(STTResult(text: "Vem skrev Röda rummet?", isFinal: true))
        try? await Task.sleep(for: .milliseconds(300))
        #expect(rig.sink.finals == ["Vem skrev Röda rummet"], "no second turn for the same words")
    }

    @Test func aFinalInTimeNeedsNothing() async {
        let rig = makeRig()
        await rig.h.controller.start()
        #expect(await waitUntil { rig.coordinator.status == .running(.scribe) })
        guard let scribe = rig.created.first else { Issue.record("no provider"); return }
        scribe.emit.yield(STTResult(text: "Vem skrev", isFinal: false))
        try? await Task.sleep(for: .milliseconds(200))
        scribe.emit.yield(STTResult(text: "Vem skrev Röda rummet?", isFinal: true))
        #expect(await waitUntil { rig.sink.finals == ["Vem skrev Röda rummet?"] })
        try? await Task.sleep(for: .seconds(2.2))
        #expect(scribe.commits == 0)
        #expect(rig.sink.finals == ["Vem skrev Röda rummet?"])
    }
}

/// A21.1 and A21.3 end to end in Provläge, against fakes.
@MainActor
@Suite struct ProvTurnQueueTests {
    private let t0 = Date(timeIntervalSince1970: 3_300_000)

    struct Rig {
        let coordinator: CoordinatorHarness
        let apple: FakeTTSProvider
        let provider: FakeAnswerProvider
        let study: StudySessionController
        let model: ListeningModel
        var h: ControllerHarness { coordinator.session }
    }

    private func makeRig(events: [AnswerEvent], speechDelay: Duration = .zero) -> Rig {
        let coordinator = CoordinatorHarness()
        let apple = FakeTTSProvider(name: "apple")
        apple.delay = speechDelay
        let provider = FakeAnswerProvider(name: "cloud", events: events)
        let suite = "lumen.tests.a21prov.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let study = StudySessionController(settings: StudySettings(defaults: defaults), session: coordinator.session.controller)
        let model = ListeningModel(controller: coordinator.session.controller, consent: FakeConsentStore(granted: true),
                                   transcription: coordinator.coordinator, activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider),
                                   speaker: makeTestSpeaker(coordinator.session.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   study: study, modeSettings: ModeSettings(defaults: defaults))
        return Rig(coordinator: coordinator, apple: apple, provider: provider, study: study, model: model)
    }

    private let shortAnswer: [AnswerEvent] = [
        .meta(AnswerMeta(isQuestion: true)), .delta("Ja."), .done(AnswerDone(answered: true)),
    ]

    /// Toby T5 del 2: four segments in one breath. The first ends the turn; the other three used to be dropped.
    @Test func segmentsHeardWhileATurnIsAnsweredBecomeTurns() async {
        let rig = makeRig(events: shortAnswer)
        await rig.model.toggleStudyMode()
        rig.study.start(at: t0)
        for i in 0..<25 { rig.study.level(-62, at: t0.addingTimeInterval(Double(i) * 0.04)) }
        for i in 0..<15 { rig.study.level(-28, at: t0.addingTimeInterval(1.0 + Double(i) * 0.04)) }
        for i in 0..<33 { rig.study.level(-62, at: t0.addingTimeInterval(1.6 + Double(i) * 0.04)) }
        let at = t0.addingTimeInterval(2.95)
        for text in ["Vad är fotosyntes?", "Vad gör klorofyll i bladen?", "Hur fungerar cellandningen?",
                     "I framtiden ska du svara kortare."] {
            rig.model.receiveFinalTranscript(text, at: at)
        }

        #expect(await waitUntil(timeout: .seconds(12)) { rig.provider.requests.count == 4 })
        #expect(rig.provider.requests.map(\.fragment) == ["Vad är fotosyntes?", "Vad gör klorofyll i bladen?",
                                                          "Hur fungerar cellandningen?", "I framtiden ska du svara kortare."])
    }

    /// Toby T5 finding 3: the voice never reports its end. The recogniser opens at the estimated end + 2 s anyway.
    @Test func theRecogniserOpensWhenTheVoiceNeverReportsItsEnd() async {
        let rig = makeRig(events: shortAnswer, speechDelay: .milliseconds(300))
        await rig.model.toggleStudyMode()
        rig.study.start(at: t0)
        for i in 0..<25 { rig.study.level(-62, at: t0.addingTimeInterval(Double(i) * 0.04)) }
        for i in 0..<15 { rig.study.level(-28, at: t0.addingTimeInterval(1.0 + Double(i) * 0.04)) }
        rig.model.receiveFinalTranscript("Vad är fotosyntes?", at: t0.addingTimeInterval(1.6))
        for i in 0..<45 { rig.study.level(-62, at: t0.addingTimeInterval(1.6 + Double(i) * 0.04)) }
        #expect(await waitUntil { rig.apple.calls.count >= 1 })
        // Stuck from now on: the end of the speech is never reported (set after the turn's interrupt, which stops
        // the fake player).
        rig.h.playback.isSpeaking = true
        rig.h.playback.onAudioScheduled?()
        #expect(rig.coordinator.coordinator.isInputGated)

        #expect(await waitUntil(timeout: .seconds(10)) { !rig.coordinator.coordinator.isInputGated })
        #expect(rig.model.gateWatchdogOpens == 1)
        #expect(rig.study.phase == .listening)
    }
}
