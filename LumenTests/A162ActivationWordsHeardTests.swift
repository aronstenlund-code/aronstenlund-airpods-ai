import Foundation
import Testing
@testable import Lumen

/// A162 (D259), the whole way: a turn is heard through the same level and transcript paths as the microphone, with
/// the user's own activation words in it. The question just asked is answered; the words are never sent.
/// A pretend transcript and a pretend answer provider: no model call, no sound, 0 ElevenLabs characters (D180).
/// These tests only use what the app had before A162 (the words are put straight into its settings store), so they
/// could be run red before the feature was written.
@MainActor
@Suite struct A162ActivationWordsHeardTests {
    private struct Rig {
        let h: ControllerHarness
        let provider: FakeAnswerProvider
        let model: ListeningModel
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.a162.heard.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// `words`: what the user wrote in the field (nil: nothing, the feature is off).
    private func makeRig(words: String?) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Växter gör socker av ljus."), .done(AnswerDone(answered: true))])
        let activationDefaults = freshDefaults()
        if let words { activationDefaults.set(words, forKey: "activation.phrase") }
        let activation = ActivationController(settings: ActivationSettings(defaults: activationDefaults))
        let microphones = MicrophoneSettings(defaults: freshDefaults())
        for mode in ConversationMode.allCases { microphones.setSource(.airPods, for: mode) }
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: activation, answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: FakeTTSProvider(name: "apple")),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), activity: FakeActivityPresenter(),
                                   history: makeTestHistory(), memory: makeTestMemory(), microphone: microphones, modeSettings: ModeSettings(defaults: freshDefaults()))
        return Rig(h: h, provider: provider, model: model)
    }

    /// One spoken turn, as in the mode tests: sound, the final transcript, then quiet.
    private func speak(_ text: String, rig: Rig) {
        var time = Date().addingTimeInterval(-3)
        for _ in 0..<15 {
            rig.model.study.level(-40, at: time)
            time = time.addingTimeInterval(0.04)
        }
        rig.model.receiveFinalTranscript(text, at: time)
        for _ in 0..<45 {
            rig.model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }
    }

    @Test func theQuestionBeforeTheWordsIsAnsweredAndTheWordsAreNotSent() async {
        let rig = makeRig(words: "banan")
        await rig.model.startHandsFree(.standard)
        rig.model.study.level(-70, at: Date())
        speak("Vad är fotosyntes? Banan.", rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests.first?.fragment == "Vad är fotosyntes?")
        #expect(rig.provider.requests.first?.mode == "push_to_talk", "answered as a question, whatever the gate thinks")
        #expect(rig.provider.requests.allSatisfy { !$0.fragment.lowercased().contains("banan") }, "the words themselves are never sent")
    }

    @Test func severalWordsAreHeardWhateverTheCaseAndThePunctuation() async {
        let rig = makeRig(words: "låt mig tänka")
        await rig.model.startHandsFree(.standard)
        rig.model.study.level(-70, at: Date())
        speak("Vad är mitos? LÅT MIG, TÄNKA!", rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests.first?.fragment == "Vad är mitos?")
        #expect(rig.provider.requests.first?.mode == "push_to_talk")
    }

    /// An empty field is off: the turn goes the ordinary way, word for word.
    @Test func withAnEmptyFieldNothingChanges() async {
        let rig = makeRig(words: nil)
        await rig.model.startHandsFree(.standard)
        rig.model.study.level(-70, at: Date())
        speak("Berätta om fotosyntes och banan", rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests.first?.fragment == "Berätta om fotosyntes och banan")
        #expect(rig.provider.requests.first?.mode != "push_to_talk")
    }
}
