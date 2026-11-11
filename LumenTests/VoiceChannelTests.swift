import Foundation
import os
import Testing
@testable import Lumen

/// D74: "Lumen, …" in every mode, filler that is never sent, and the AirPods press.
@Suite struct VoiceChannelParseTests {
    @Test func switchCommandsForEveryMode() {
        #expect(VoiceChannel.parse("Lumen, byt till provläge").intent == .switchTo(.prov))
        #expect(VoiceChannel.parse("Lumén byt till Socialt läge.").intent == .switchTo(.social))
        #expect(VoiceChannel.parse("lumen, byt till rizz-läge").intent == .switchTo(.rizz))
        #expect(VoiceChannel.parse("Lumen, växla till intervjuläge").intent == .switchTo(.interview))
        #expect(VoiceChannel.parse("Lumen, byt till frågor").intent == .switchTo(.standard))
        #expect(VoiceChannel.parse("Lumen, provläge").intent == .switchTo(.prov))
    }

    @Test func pauseAndStop() {
        #expect(VoiceChannel.parse("Lumen, pausa").intent == .pause)
        #expect(VoiceChannel.parse("Lumen, spela musik.").intent == .pause)
        #expect(VoiceChannel.parse("Lumen, sluta lyssna").intent == .stopListening)
    }

    @Test func anythingElseIsAnInstructionAndTheWordsBeforeStayConversation() {
        let utterance = VoiceChannel.parse("Ja precis. Lumen, mer skämt")
        #expect(utterance.before == "Ja precis.")
        #expect(utterance.intent == .instruction("mer skämt"))
        #expect(VoiceChannel.parse("Lumen, ge mig tre pickup lines").intent == .instruction("ge mig tre pickup lines"))
    }

    @Test func noNameNoIntent() {
        #expect(VoiceChannel.parse("byt till provläge").intent == nil, "only with the name")
        #expect(VoiceChannel.parse("Det här är Lumens ljus").intent == nil) // A75: "Lumens" first in an utterance wakes it now (a mishearing)
        #expect(VoiceChannel.parse("Lumen.") == VoiceUtterance(before: nil, intent: nil))
        #expect(VoiceChannel.parse("Vad är fotosyntes?") == VoiceUtterance(before: "Vad är fotosyntes?", intent: nil))
    }

    @Test func theNameIsOneConstant() {
        #expect(WakeWord.name == "Lumen")
        #expect(VoiceChannel.parse("\(WakeWord.name), pausa").intent == .pause)
    }

    @Test func fillerIsRecognised() {
        #expect(FillerFilter.isOnlyFiller("äh"))
        #expect(FillerFilter.isOnlyFiller("Ja."))
        #expect(FillerFilter.isOnlyFiller("kom igen"))
        #expect(FillerFilter.isOnlyFiller("Äh, ja, kom igen"))
        #expect(!FillerFilter.isOnlyFiller("ja det stämmer"))
        #expect(!FillerFilter.isOnlyFiller("Vad är pi"))
        #expect(!FillerFilter.isOnlyFiller("nej"))
    }
}

@Suite struct RemoteCommandIsolationTests {
    /// The AirPods press arrives on a queue iOS picks; the handler body must not be main-actor isolated.
    @Test func theHandlerRunsOnAnotherQueue() async {
        let called = OSAllocatedUnfairLock(initialState: false)
        let ok: Bool = await withCheckedContinuation { done in
            DispatchQueue(label: "lumen.tests.remote").async {
                let status = RemoteCommandHub.run { called.withLock { $0 = true } }
                done.resume(returning: status == .success)
            }
        }
        #expect(ok)
        #expect(called.withLock { $0 })
    }
}

@MainActor
@Suite struct VoiceFlowTests {
    private struct Rig {
        let h: ControllerHarness
        let provider: FakeAnswerProvider
        let model: ListeningModel
        let apple: FakeTTSProvider
        let settings: ModeSettings
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.voice.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeRig(adult: Bool = true) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Svar."), .done(AnswerDone(answered: true))])
        let apple = FakeTTSProvider(name: "apple")
        let settings = ModeSettings(defaults: freshDefaults())
        settings.interviewSetup = "Säljare"
        if adult { settings.confirmAdult() }
        let microphones = MicrophoneSettings(defaults: freshDefaults())
        for mode in ConversationMode.allCases { microphones.setSource(.iPhone, for: mode) }
        let study = StudySessionController(settings: StudySettings(defaults: freshDefaults()), session: h.controller)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), study: study,
                                   history: makeTestHistory(), memory: makeTestMemory(), microphone: microphones, modeSettings: settings)
        return Rig(h: h, provider: provider, model: model, apple: apple, settings: settings)
    }

    private func spoke(_ rig: Rig, _ text: String) -> Bool {
        rig.apple.calls.contains { $0.text == text }
    }

    @Test func switchesFromQuestionsToProvlageByVoice() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, byt till provläge", at: Date())

        #expect(await waitUntil { rig.model.study.isActive && rig.model.mode == .prov })
        #expect(await waitUntil { spoke(rig, "Provläge.") }, "a short confirmation in the AirPods")
        #expect(rig.model.selectedMode == .prov)
        #expect(rig.provider.requests.isEmpty, "a command, never a question")
    }

    @Test func rizzByVoiceAsksNoAge() async {
        // D112 / A35: no 18+ question; like Socialt läge, Rizzläge is started in the app the first time.
        let rig = makeRig(adult: false)
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, byt till rizzläge", at: Date())

        #expect(await waitUntil { rig.apple.calls.contains { $0.text.hasSuffix("startas i appen första gången.") } })
        #expect(!rig.apple.calls.contains { $0.text.contains("18 år") })
    }

    @Test func aLiveModeByVoiceNeedsItsStartScreenOnce() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, byt till socialt läge", at: Date())

        #expect(await waitUntil { spoke(rig, "Socialt läge startas i appen första gången.") })
        #expect(!rig.model.study.isActive)
    }

    @Test func aConfirmedLiveModeStartsByVoice() async {
        let rig = makeRig()
        rig.settings.confirmLiveStart(.social)
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, byt till socialt läge", at: Date())

        #expect(await waitUntil { rig.model.mode == .social && rig.model.rizz != nil })
    }

    @Test func pauseByVoiceLetsGoOfTheMicrophone() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, pausa", at: Date())

        #expect(await waitUntil { rig.model.state == .paused(.user) })
    }

    @Test func stopByVoiceEndsListening() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, sluta lyssna", at: Date())

        #expect(await waitUntil { rig.model.state == .idle })
    }

    @Test func anythingElseInQuestionsModeIsAQuestion() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, vad är pi", at: Date())

        #expect(await waitUntil { rig.provider.requests.count == 1 })
        #expect(rig.provider.requests[0].fragment == "vad är pi")
        #expect(rig.provider.requests[0].mode == "text")
    }

    @Test func afterAnInterruptionTheSameModeComesBack() async {
        let rig = makeRig()
        await rig.model.startHandsFree(.prov)
        #expect(rig.model.study.isActive)

        await rig.h.controller.apply(.interruptionBegan)
        #expect(!rig.model.study.isActive)
        await rig.h.controller.apply(.interruptionEnded(shouldResume: false))

        #expect(await waitUntil { rig.model.study.isActive && rig.model.mode == .prov })
        #expect(rig.model.isListening)
    }

    @Test func theAirPodsPressPausesAndResumesInTheSameMode() async {
        let rig = makeRig()
        await rig.model.startHandsFree(.prov)

        await rig.model.togglePause() // what the AirPods press calls
        #expect(rig.model.state == .paused(.user))
        #expect(!rig.model.study.isActive)

        await rig.model.togglePause()
        #expect(await waitUntil { rig.model.study.isActive && rig.model.mode == .prov })
    }

    @Test func fillerIsNotSentInProvlage() async {
        let rig = makeRig()
        await rig.model.startHandsFree(.prov)
        rig.model.study.level(-70, at: Date())
        var time = Date().addingTimeInterval(-4)
        for _ in 0..<15 {
            rig.model.study.level(-25, at: time)
            time = time.addingTimeInterval(0.04)
        }
        rig.model.receiveFinalTranscript("Äh, kom igen", at: time)
        for _ in 0..<45 {
            rig.model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(rig.provider.requests.isEmpty)
        #expect(rig.model.study.isActive)
    }
}
