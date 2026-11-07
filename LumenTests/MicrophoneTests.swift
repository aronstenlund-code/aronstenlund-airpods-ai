import AVFAudio
import Foundation
import Testing
@testable import Lumen

@Suite struct MicrophoneSourceTests {
    @Test func perModeDefaultsFollowD55() {
        #expect(MicrophoneSource.defaultSource(for: .standard) == .airPods)
        #expect(MicrophoneSource.defaultSource(for: .prov) == .airPods)
        #expect(MicrophoneSource.defaultSource(for: .interview) == .iPhone)
        #expect(MicrophoneSource.defaultSource(for: .rizz) == .iPhone)
        #expect(MicrophoneSource.defaultSource(for: .social) == .iPhone)
    }

    @Test func theIPhoneConfigKeepsMusicQualityInTheAirPods() {
        let config = MicrophoneSource.iPhone.captureConfig()
        #expect(config.inputPreference == .builtInMic)
        #expect(config.options.contains(.allowBluetoothA2DP))
        #expect(!config.options.contains(.allowBluetoothHFP), "HFP would pull the AirPods down to call quality")
        #expect(MicrophoneSource.iPhone.captureConfig(echoCancellation: true) == config, "no such path on the phone")
    }

    @Test func theAirPodsConfigAsksForHighQualityWithHFPFallback() {
        let config = MicrophoneSource.airPods.captureConfig()
        #expect(config.inputPreference == .bluetooth)
        #expect(config.options.contains(.allowBluetoothHFP))
        #expect(MicrophoneSource.airPods.captureConfig(echoCancellation: true) == .cHFPVoiceChat)
    }
}

@MainActor
@Suite struct MicrophoneSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.mic.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func aChoicePersistsPerMode() {
        let defaults = freshDefaults()
        let settings = MicrophoneSettings(defaults: defaults)
        #expect(settings.source(for: .rizz) == .iPhone)

        settings.setSource(.airPods, for: .rizz)

        let reloaded = MicrophoneSettings(defaults: defaults)
        #expect(reloaded.source(for: .rizz) == .airPods)
        #expect(reloaded.source(for: .interview) == .iPhone)
    }

    private func makeModel(_ h: ControllerHarness, microphone: MicrophoneSettings) -> ListeningModel {
        ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                       activation: makeTestActivation(), answers: makeTestAnswerEngine(), speaker: makeTestSpeaker(h.playback),
                       voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                       history: makeTestHistory(), memory: makeTestMemory(), microphone: microphone)
    }

    @Test func startingUsesTheChosenMicrophone() async {
        let h = ControllerHarness()
        let settings = MicrophoneSettings(defaults: freshDefaults())
        settings.setSource(.iPhone, for: .standard)
        let model = makeModel(h, microphone: settings)

        await model.startListening()

        #expect(h.session.activateCalls == [.aRefDefault])
        #expect(model.usesPhoneMicrophone)
        #expect(h.controller.eventLog.contains { $0.text.contains("Microphone iPhone for standard") }, "the route is logged")
    }

    @Test func aRunningSessionMovesToTheNewRoute() async {
        let h = ControllerHarness()
        let settings = MicrophoneSettings(defaults: freshDefaults())
        settings.setSource(.iPhone, for: .prov)
        let model = makeModel(h, microphone: settings)
        await model.startListening()
        #expect(h.session.activateCalls == [.bHQ])

        await model.startStudy()

        #expect(h.session.activateCalls == [.bHQ, .aRefDefault])
        #expect(model.isListening)
        #expect(model.study.isActive)
    }

    @Test func theComparisonScoresWhatWasHeardAndAsksNothing() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud")
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   history: makeTestHistory(), memory: makeTestMemory(), microphone: MicrophoneSettings(defaults: freshDefaults()))
        let comparison = MicComparisonModel(listening: model, settleDelay: .zero)
        comparison.source = .iPhone
        comparison.speaker = .otherPerson

        await comparison.start()
        #expect(comparison.isRecording)
        #expect(h.session.activateCalls == [.aRefDefault])
        model.receiveFinalTranscript("Vad är huvudstaden i", at: Date())
        model.receivePartialTranscript("Österrike", at: Date())
        await comparison.finish()

        #expect(provider.requests.isEmpty, "a test sentence is never sent as a question")
        let trial = comparison.trials[0]
        #expect(trial.heard == "Vad är huvudstaden i Österrike")
        #expect(trial.wer == 0.2, "one word of five is wrong")
        #expect(comparison.sentence == MicComparisonModel.sentences[1])
        #expect(comparison.summaryLines == ["iPhone · other person at 1.5 m: WER 20 % (n=1)"])
        #expect(comparison.markdown.contains("| iPhone | other person at 1.5 m | 0.20 |"))
    }
}
