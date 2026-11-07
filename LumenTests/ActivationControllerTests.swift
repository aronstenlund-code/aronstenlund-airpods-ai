import Foundation
import Testing
@testable import Lumen

@MainActor
func makeTestActivation(sensitivity: GateSensitivity = .medium, debounce: TimeInterval = 0) -> ActivationController {
    let suite = "lumen.tests.activation.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let settings = ActivationSettings(defaults: defaults)
    settings.sensitivity = sensitivity
    settings.questionDebounce = debounce
    return ActivationController(settings: settings)
}

@MainActor
@Suite struct ActivationControllerTests {
    private let t0 = Date(timeIntervalSince1970: 2_000_000)

    private func recording(_ controller: ActivationController) -> () -> [ActivationRequest] {
        final class Box { var requests: [ActivationRequest] = [] }
        let box = Box()
        controller.onActivate = { box.requests.append($0) }
        return { box.requests }
    }

    @Test func autoModeFiresOnQuestionsAndRespectsCooldown() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()

        func say(_ text: String, at seconds: TimeInterval) {
            conversation.finalize(text, at: t0.addingTimeInterval(seconds))
            controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                        isPlaybackSpeaking: false, now: t0.addingTimeInterval(seconds))
        }

        say("idag ska vi prata om fotosyntes", at: 0)
        #expect(fired().isEmpty)
        #expect(controller.lastDecision?.fires == false)

        say("vad är fotosyntes?", at: 5)
        #expect(fired().map(\.query) == ["vad är fotosyntes?"])
        #expect(fired().first?.trigger == .auto)
        #expect(fired().first?.gate?.fires == true)

        say("hur många kromosomer har en människa", at: 8)
        #expect(fired().count == 1, "second question inside the 5 s minimum interval is skipped")

        say("hur många kromosomer har en människa", at: 14)
        #expect(fired().count == 2)
    }

    @Test func aQuestionWaitsForTheSpeakerToFinish() {
        let controller = makeTestActivation(debounce: 1.0)
        let fired = recording(controller)
        var conversation = Conversation()
        func say(_ text: String, at seconds: TimeInterval) {
            conversation.finalize(text, at: t0.addingTimeInterval(seconds))
            controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                        isPlaybackSpeaking: false, now: t0.addingTimeInterval(seconds))
        }

        say("vad är skillnaden mellan mitos", at: 0)
        #expect(fired().isEmpty, "Parrot design: a question waits one second")
        #expect(!controller.fireDue(now: t0.addingTimeInterval(0.5)))
        say("och meios?", at: 0.6)
        #expect(controller.fireDue(now: t0.addingTimeInterval(1.7)))
        #expect(fired().map(\.query) == ["vad är skillnaden mellan mitos och meios?"], "one question, not two halves")
    }

    @Test func halfASentenceNeverFires() {
        let gate = QuestionGate(sensitivity: .medium)
        #expect(!gate.evaluate("vad finns det i").fires)
        #expect(gate.evaluate("vad finns det i cellen").fires)
        #expect(gate.evaluate("vad tycker du om?").fires, "a question mark ends it")
    }

    @Test func aQuestionThatTurnsIntoAStatementIsDropped() {
        let controller = makeTestActivation(debounce: 1.0)
        let fired = recording(controller)
        var conversation = Conversation()
        conversation.finalize("vem vet", at: t0)
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0)
        conversation.finalize("idag ska vi prata om celler och om hur de delar sig och växer i kroppen hos alla djur", at: t0.addingTimeInterval(0.5))
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0.addingTimeInterval(0.5))
        #expect(!controller.fireDue(now: t0.addingTimeInterval(3)))
        #expect(fired().isEmpty)
    }

    @Test func autoModeIgnoresOurOwnPlayback() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()

        conversation.finalize("vad är fotosyntes?", at: t0, overlapsPlayback: true)
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0)
        #expect(fired().isEmpty, "words spoken over our answer are never a question")

        conversation.finalize("vad är fotosyntes?", at: t0.addingTimeInterval(1))
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: true, now: t0.addingTimeInterval(1))
        #expect(fired().isEmpty, "nothing fires while the answer is still playing")
    }

    @Test func sensitivityChangesWhatFires() {
        let medium = makeTestActivation(sensitivity: .medium)
        let high = makeTestActivation(sensitivity: .high)
        let firedMedium = recording(medium)
        let firedHigh = recording(high)
        var conversation = Conversation()
        conversation.finalize("fotosyntes", at: t0)
        for controller in [medium, high] {
            controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                        isPlaybackSpeaking: false, now: t0)
        }
        #expect(firedMedium().isEmpty)
        #expect(firedHigh().map(\.query) == ["fotosyntes"])
    }

    @Test func answerLastUsesTheLastSegmentNotSpokenOverPlayback() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        #expect(!controller.answerLast(conversation: conversation, language: .english))

        conversation.finalize("newtons andra lag", at: t0)
        conversation.finalize("echo of our own answer", at: t0.addingTimeInterval(1), overlapsPlayback: true)
        #expect(controller.answerLast(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(2)))
        #expect(controller.answerLast(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(2.5)), "manual triggers have no cooldown")
        #expect(fired().map(\.query) == ["newtons andra lag", "newtons andra lag"])
        #expect(fired().first?.trigger == .answerLast)
        #expect(fired().first?.trigger.backendMode == "push_to_talk", "a deliberate question for the backend")
    }

    @Test func textModeEntersTheSamePath() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        controller.submitText("  Vad är pi?  ", language: .swedish, now: t0)
        controller.submitText("   ", language: .swedish, now: t0)
        #expect(fired().map(\.query) == ["Vad är pi?"])
        #expect(fired().first?.trigger == .text)
        #expect(fired().first?.trigger.backendMode == "text")
    }

    @Test func historyIsNewestFirstAndCapped() {
        let controller = makeTestActivation()
        for i in 0..<(ActivationController.maxHistory + 5) {
            controller.submitText("q\(i)", language: .english, now: t0.addingTimeInterval(Double(i)))
        }
        #expect(controller.history.count == ActivationController.maxHistory)
        #expect(controller.history.first?.query == "q\(ActivationController.maxHistory + 4)")
    }

    @Test func settingsPersist() {
        let suite = "lumen.tests.activation.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let fresh = ActivationSettings(defaults: defaults)
        #expect(fresh.sensitivity == .medium)

        fresh.sensitivity = .high
        let reloaded = ActivationSettings(defaults: defaults)
        #expect(reloaded.sensitivity == .high)
    }
}

@MainActor
@Suite struct ListeningActivationTests {
    private func makeModel(defaults: UserDefaults? = nil) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let settings = defaults.map { ModeSettings(defaults: $0) } ?? ModeSettings(defaults: Self.freshDefaults())
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(), answers: makeTestAnswerEngine(),
                                   speaker: makeTestSpeaker(h.playback), voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: settings)
        return (h, model)
    }

    private static func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.listeningactivation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func questionsAreHandsFreeByDefault() async {
        let (h, model) = makeModel()
        #expect(model.selectedMode == .standard, "Frågor (Auto) on the first start")
        await model.startListening()
        model.receiveFinalTranscript("idag pratar vi om celler")
        #expect(model.pendingQuestion == nil)
        model.receiveFinalTranscript("hur många kromosomer har en människa?")
        #expect(model.pendingQuestion?.trigger == .auto)
        #expect(model.pendingQuestion?.query == "hur många kromosomer har en människa?")
        #expect(h.controller.eventLog.contains { $0.text.hasPrefix("Activation (auto)") })
        #expect(h.controller.eventLog.contains { $0.text.hasPrefix("Turn · standard · STT") }, "D74: recogniser and microphone per turn")
    }

    @Test func theLastChosenModeIsRemembered() {
        let defaults = Self.freshDefaults()
        let (_, first) = makeModel(defaults: defaults)
        first.selectedMode = .interview
        let (_, again) = makeModel(defaults: defaults)
        #expect(again.selectedMode == .interview)
    }

    @Test func rizzIsNotRememberedWithoutTheAgeConfirmation() {
        let defaults = Self.freshDefaults()
        let (_, first) = makeModel(defaults: defaults)
        first.selectedMode = .rizz
        let (_, again) = makeModel(defaults: defaults)
        #expect(again.selectedMode == .standard, "the 18+ gate is not skipped by a remembered choice")
    }

    @Test func askAboutLastAndClearHistory() async {
        let (_, model) = makeModel()
        await model.startListening()
        model.askAboutLast()
        #expect(model.pendingQuestion == nil)
        model.receiveFinalTranscript("newtons andra lag")
        model.askAboutLast()
        #expect(model.pendingQuestion?.trigger == .answerLast)
        model.clearHistory()
        #expect(model.pendingQuestion == nil)
    }
}
