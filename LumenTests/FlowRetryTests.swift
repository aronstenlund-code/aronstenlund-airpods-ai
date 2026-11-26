import Foundation
import Testing
@testable import Lumen

/// The common flow (listen → ask → answer → history), Deangelo 2026-11-26 22:38: "Försök igen" on the card after a
/// failed answer asks the question that failed, not the one answered before it.
@MainActor
@Suite struct FlowRetryTests {
    private func makeModel(_ provider: FakeAnswerProvider) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let suite = "lumen.tests.flow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: ModeSettings(defaults: defaults))
        return (h, model)
    }

    /// Not a `provider_*` code: those have their own memory for the answer asked ahead (T57).
    private let down = AnswerError.backend(status: 504, failure: AnswerFailure(code: "timeout", message: nil, fallback: nil))
    private let good: [AnswerEvent] = [.delta("Oslo."), .done(AnswerDone(answered: true))]

    private func spoken(_ text: String) -> ActivationRequest {
        ActivationRequest(query: text, trigger: .auto, language: "sv")
    }

    @Test func tryAgainAsksTheQuestionThatFailed() async {
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Ungefär 3,14."), .done(AnswerDone(answered: true))])
        let (_, model) = makeModel(provider)
        await model.startListening()
        model.submitText("vad är pi")
        #expect(await waitUntil { model.conversation.answers.count == 1 })

        provider.events = []
        provider.error = down
        model.submitText("vad är fotosyntes")
        #expect(await waitUntil { model.problem == .overloaded }, "the second question fails: the card with Försök igen")
        let asked = provider.requests.count

        provider.events = [.delta("Växter gör socker av ljus."), .done(AnswerDone(answered: true))]
        provider.error = nil
        model.act(on: .overloaded)
        #expect(await waitUntil { provider.requests.count == asked + 1 })
        #expect(provider.requests.last?.fragment == "vad är fotosyntes", "the question that failed, not the one before it")
        #expect(await waitUntil { model.conversation.answers.count == 2 })
        #expect(model.conversation.answers.last?.answer == "Växter gör socker av ljus.")
        #expect(model.problem == nil)
        await model.stopListening()
    }

    @Test func tryAgainAfterTheFirstQuestionFailedAsksIt() async {
        let provider = FakeAnswerProvider(name: "cloud", error: down)
        let (_, model) = makeModel(provider)
        await model.startListening()
        model.submitText("vad är pi")
        #expect(await waitUntil { model.problem == .overloaded })
        provider.events = [.delta("Ungefär 3,14."), .done(AnswerDone(answered: true))]
        provider.error = nil
        model.act(on: .overloaded)
        #expect(await waitUntil { model.conversation.answers.count == 1 })
        #expect(provider.requests.last?.fragment == "vad är pi")
        await model.stopListening()
    }

    // A spoken question (the question gate, `.auto`) is remembered for 60 s so that it is not answered twice (A74).
    // One that failed has not been answered.

    @Test func tryAgainWorksForASpokenQuestion() async {
        let provider = FakeAnswerProvider(name: "cloud", error: down)
        let (_, model) = makeModel(provider)
        await model.startListening()
        model.activated(spoken("vad är huvudstaden i Norge?"))
        #expect(await waitUntil { model.problem == .overloaded })
        let asked = provider.requests.count
        provider.events = good
        provider.error = nil
        model.act(on: .overloaded)
        #expect(await waitUntil { provider.requests.count == asked + 1 }, "the press asks it again, also within the minute")
        #expect(await waitUntil { model.conversation.answers.last?.answer == "Oslo." })
        await model.stopListening()
    }

    @Test func aSpokenQuestionThatFailedCanBeAskedAgainAloud() async {
        let provider = FakeAnswerProvider(name: "cloud", error: down)
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.activated(spoken("vad är huvudstaden i Norge?"))
        #expect(await waitUntil { model.problem == .overloaded })
        let asked = provider.requests.count
        provider.events = good
        provider.error = nil
        model.activated(spoken("vad är huvudstaden i Norge?"))
        #expect(await waitUntil { provider.requests.count == asked + 1 }, "it was never answered: asking again is not a repeat")
        #expect(await waitUntil { model.conversation.answers.last?.answer == "Oslo." })
        #expect(!h.controller.eventLog.contains { $0.text.contains("not asked again (A74)") })
        await model.stopListening()
    }

    @Test func anAnsweredQuestionIsStillNotAnsweredTwice() async {
        // A74 stays: the same question within the minute, after an answer, is dropped.
        let provider = FakeAnswerProvider(name: "cloud", events: good)
        let (_, model) = makeModel(provider)
        await model.startListening()
        model.activated(spoken("vad är huvudstaden i Norge?"))
        #expect(await waitUntil { model.conversation.answers.count == 1 })
        let asked = provider.requests.count
        model.activated(spoken("vad är huvudstaden i Norge?"))
        try? await Task.sleep(for: .milliseconds(200))
        #expect(provider.requests.count == asked)
        await model.stopListening()
    }
}
