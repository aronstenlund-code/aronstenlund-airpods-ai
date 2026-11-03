import Foundation
import Testing
@testable import Lumen

@MainActor
func makeTestActivation(mode: ActivationMode = .pushToTalk, sensitivity: GateSensitivity = .medium) -> ActivationController {
    let suite = "lumen.tests.activation.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    let settings = ActivationSettings(defaults: defaults)
    settings.mode = mode
    settings.sensitivity = sensitivity
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

    @Test func pushToTalkCollectsWhatWasSaidWhileHolding() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        conversation.finalize("det här sa läraren innan", at: t0)

        controller.beginPushToTalk(conversation: conversation, now: t0.addingTimeInterval(10))
        #expect(controller.isHolding)
        conversation.finalize("vad är fotosyntes", at: t0.addingTimeInterval(11))
        conversation.finalize("och varför är den viktig", at: t0.addingTimeInterval(12))
        let immediate = controller.endPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(13))

        #expect(immediate)
        #expect(!controller.isHolding)
        #expect(fired().count == 1)
        #expect(fired().first?.query == "vad är fotosyntes och varför är den viktig")
        #expect(fired().first?.trigger == .pushToTalk)
        #expect(fired().first?.language == .swedish)
        #expect(fired().first?.backendModeIsPushToTalk == true)
    }

    @Test func releaseWithOpenPartialWaitsForTheFinal() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        controller.beginPushToTalk(conversation: conversation, now: t0)
        conversation.updatePartial("vad är foto", at: t0)

        let immediate = controller.endPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(1))
        #expect(!immediate)
        #expect(controller.isAwaitingFinal)
        #expect(fired().isEmpty)

        conversation.finalize("vad är fotosyntes?", at: t0.addingTimeInterval(1.5))
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0.addingTimeInterval(1.5))
        #expect(!controller.isAwaitingFinal)
        #expect(fired().map(\.query) == ["vad är fotosyntes?"])
        #expect(fired().first?.trigger == .pushToTalk)
    }

    @Test func flushAfterGraceUsesThePartialText() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        controller.beginPushToTalk(conversation: conversation, now: t0)
        conversation.finalize("roten ur", at: t0.addingTimeInterval(0.5))
        conversation.updatePartial("hundra", at: t0.addingTimeInterval(0.9))
        controller.endPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(1))

        controller.flushPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(3))
        #expect(fired().map(\.query) == ["roten ur hundra"])
        controller.flushPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(4))
        #expect(fired().count == 1, "flush is idempotent")
    }

    @Test func finalArrivingAfterTheGraceDoesNotFireInPushToTalkMode() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        var conversation = Conversation()
        controller.beginPushToTalk(conversation: conversation, now: t0)
        conversation.updatePartial("vad", at: t0)
        controller.endPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(1))

        conversation.finalize("vad är fotosyntes?", at: t0.addingTimeInterval(9))
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0.addingTimeInterval(9))
        #expect(fired().isEmpty)
        #expect(!controller.isAwaitingFinal)
    }

    @Test func releaseWithNothingSaidFiresNothing() {
        let controller = makeTestActivation()
        let fired = recording(controller)
        let conversation = Conversation()
        controller.beginPushToTalk(conversation: conversation, now: t0)
        controller.endPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(1))
        controller.flushPushToTalk(conversation: conversation, language: .swedish, now: t0.addingTimeInterval(4))
        #expect(fired().isEmpty)
    }

    @Test func autoModeFiresOnQuestionsAndRespectsCooldown() {
        let controller = makeTestActivation(mode: .auto)
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
        #expect(fired().count == 1, "second question inside the 8 s cooldown is skipped")

        say("hur många kromosomer har en människa", at: 14)
        #expect(fired().count == 2)
    }

    @Test func autoModeIgnoresOurOwnPlayback() {
        let controller = makeTestActivation(mode: .auto)
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

    @Test func pushToTalkModeNeverFiresAutomatically() {
        let controller = makeTestActivation(mode: .pushToTalk)
        let fired = recording(controller)
        var conversation = Conversation()
        conversation.finalize("vad är fotosyntes?", at: t0)
        controller.segmentFinalized(conversation.finalSegments.last!, conversation: conversation, language: .swedish,
                                    isPlaybackSpeaking: false, now: t0)
        #expect(fired().isEmpty)
        #expect(controller.lastDecision == nil, "the gate is not even evaluated")
    }

    @Test func sensitivityChangesWhatFires() {
        let medium = makeTestActivation(mode: .auto, sensitivity: .medium)
        let high = makeTestActivation(mode: .auto, sensitivity: .high)
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
        #expect(fresh.mode == .pushToTalk, "push-to-talk is the MVP default")
        #expect(fresh.sensitivity == .medium)

        fresh.mode = .auto
        fresh.sensitivity = .high
        let reloaded = ActivationSettings(defaults: defaults)
        #expect(reloaded.mode == .auto)
        #expect(reloaded.sensitivity == .high)
    }
}

private extension ActivationRequest {
    var backendModeIsPushToTalk: Bool { trigger.backendMode == "push_to_talk" }
}

@MainActor
@Suite struct ListeningActivationTests {
    private func makeModel() -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(), answers: makeTestAnswerEngine())
        return (h, model)
    }

    @Test func holdToAskProducesAPendingQuestion() async {
        let (_, model) = makeModel()
        await model.startListening()
        model.receiveFinalTranscript("det här sa läraren")

        model.pressPushToTalk()
        #expect(model.isHolding)
        model.receiveFinalTranscript("vad är fotosyntes")
        model.releasePushToTalk()

        #expect(!model.isHolding)
        #expect(model.pendingQuestion?.query == "vad är fotosyntes")
        #expect(model.pendingQuestion?.trigger == .pushToTalk)
        #expect(model.pendingQuestion?.language == .swedish)
    }

    @Test func holdIsIgnoredWhenNotListening() {
        let (_, model) = makeModel()
        model.pressPushToTalk()
        #expect(!model.isHolding)
    }

    @Test func releaseWaitsForTheFinalWordsThenFlushes() async {
        let (_, model) = makeModel()
        model.activation.settings.releaseGrace = 0.2
        await model.startListening()
        model.pressPushToTalk()
        model.receivePartialTranscript("roten ur hund")
        model.releasePushToTalk()
        #expect(model.pendingQuestion == nil)

        #expect(await waitUntil { model.pendingQuestion != nil })
        #expect(model.pendingQuestion?.query == "roten ur hund", "the open partial is used when no final arrives in time")
    }

    @Test func autoModeDetectsAQuestionFromTheTranscript() async {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(mode: .auto), answers: makeTestAnswerEngine())
        await model.startListening()
        model.receiveFinalTranscript("idag pratar vi om celler")
        #expect(model.pendingQuestion == nil)
        model.receiveFinalTranscript("hur många kromosomer har en människa?")
        #expect(model.pendingQuestion?.trigger == .auto)
        #expect(model.pendingQuestion?.query == "hur många kromosomer har en människa?")
        #expect(h.controller.eventLog.first?.text.hasPrefix("Activation (auto)") == true)
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
