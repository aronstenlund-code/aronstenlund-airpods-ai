import Foundation
import Testing
@testable import Lumen

/// A40 (D115): without the network, a short answer from the on-device model when there is one; otherwise as before.
@MainActor
@Suite struct OfflineAnswerTests {
    private func model(_ h: ControllerHarness, offline: FakeAnswerProvider?) -> ListeningModel {
        let engine = makeTestAnswerEngine(FakeAnswerProvider(name: "cloud", error: .offline))
        engine.offline = offline
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                              activation: makeTestActivation(), answers: engine, speaker: makeTestSpeaker(h.playback),
                              voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    @Test func theOnDeviceModelAnswersWhenTheNetworkIsGone() async {
        let h = ControllerHarness()
        let onDevice = FakeAnswerProvider(name: "on-device", events: [
            .meta(AnswerMeta(reconstructedQuestion: "vad är roten ur hundra", confidence: 0.8, isQuestion: true)),
            .delta(OnDeviceAnswerProvider.lead + " "), .delta("Tio."), .done(AnswerDone(answered: true)),
        ])
        let model = model(h, offline: onDevice)
        await model.startListening()
        model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { model.conversation.answers.last?.answer.hasSuffix("Tio.") == true })
        #expect(model.conversation.answers.last?.answer.hasPrefix("Jag svarar kort, nätet är borta.") == true)
        #expect(onDevice.requests.count == 1)
        #expect(model.problem != .offline)
    }

    @Test func withoutOneItIsNätetÄrBortaAsBefore() async {
        let h = ControllerHarness()
        let onDevice = FakeAnswerProvider(name: "on-device", error: .offline) // an iPhone without Apple Intelligence
        let model = model(h, offline: onDevice)
        await model.startListening()
        model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { model.problem == .offline })
        #expect(onDevice.requests.count == 1, "asked once, never in a loop")
    }
}
