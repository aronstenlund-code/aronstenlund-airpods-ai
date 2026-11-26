import Foundation
import Testing
@testable import Lumen

/// Toby's T57 finding (2026-11-24): while the server's model is down and the phone has no model of its own, one
/// question asked `/answer` twice: once ahead, on the words heard so far, and once more a moment later when the
/// pause was over, both refused with 503 `provider_quota`. The second call can only get the same no.
/// A pretend answer provider: no network, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct T57AheadServerDownTests {
    private struct Rig {
        let cloud: FakeAnswerProvider
        let model: ListeningModel
    }

    private func makeRig(error: AnswerError) -> Rig {
        let h = ControllerHarness()
        let cloud = FakeAnswerProvider(name: "cloud", error: error)
        let suite = "lumen.tests.t57.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let study = StudySessionController(settings: StudySettings(defaults: defaults), session: h.controller)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(cloud),
                                   speaker: makeTestSpeaker(h.playback, apple: FakeTTSProvider(name: "apple")),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), study: study, memory: makeTestMemory(),
                                   modeSettings: ModeSettings(defaults: defaults))
        return Rig(cloud: cloud, model: model)
    }

    @Test func aQuestionRefusedAheadIsNotAskedAgainAtThePause() async {
        let down = AnswerError.backend(status: 503, failure: AnswerFailure(code: "provider_quota", message: "LLM credits exhausted", fallback: true))
        let rig = makeRig(error: down)
        await rig.model.startListening()

        rig.model.receiveSentenceHeard("vad är roten ur hundra", at: Date())
        #expect(await waitUntil { rig.cloud.requests.count == 1 }, "the call starts before the pause")
        try? await Task.sleep(for: .milliseconds(120)) // the no has come back

        rig.model.receiveFinalTranscript("vad är roten ur hundra", at: Date()) // the pause is over
        #expect(await waitUntil { rig.model.problem == .overloaded }, "the app says it cannot answer, as before")
        try? await Task.sleep(for: .milliseconds(120))
        #expect(rig.cloud.requests.count == 1, "the server is not asked the same thing again a moment later")
    }

    /// Any other failure ahead is asked again at the pause, as before (a slow network may work the second time).
    @Test func anotherFailureAheadIsStillAskedAgain() async {
        let rig = makeRig(error: .transport(detail: "timed out"))
        await rig.model.startListening()
        rig.model.receiveSentenceHeard("vad är roten ur hundra", at: Date())
        #expect(await waitUntil { rig.cloud.requests.count == 1 })
        try? await Task.sleep(for: .milliseconds(120))
        rig.model.receiveFinalTranscript("vad är roten ur hundra", at: Date())
        #expect(await waitUntil { rig.cloud.requests.count == 2 })
    }
}
