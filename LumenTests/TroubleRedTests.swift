import Foundation
import Testing
@testable import Lumen

/// Red first against main (existing API only): when the AirPods go and EarMind pauses (the setting on), the card must
/// not say "Svaren hörs nu i telefonens högtalare" with the button "Pausa" – it is already paused.
@MainActor
@Suite struct TroubleRedTests {
    @Test func airPodsGoneAndPausedIsNotTheSpeakerCard() async {
        let h = ControllerHarness()
        let suite = "lumen.tests.troublered.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let microphone = MicrophoneSettings(defaults: defaults)
        microphone.pauseWhenAirPodsLost = true
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(FakeAnswerProvider()), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   microphone: microphone)
        await model.startListening()
        #expect(await waitUntil { model.isListening })
        var speaker = FakeSessionManager.makeSnapshot(config: .bHQ)
        speaker.outputs = [PortInfo(portType: "Speaker", portName: "Speaker", uid: "o", channelCount: 1, dataSource: nil)]
        h.session.eventHandler?(.routeChanged(reason: "oldDeviceUnavailable", outputLost: true, snapshot: speaker))
        #expect(await waitUntil { model.state == .paused(.outputDeviceLost) })
        #expect(model.problem != nil)
        #expect(model.problem?.text != "Svaren hörs nu i telefonens högtalare.", "it is paused, not playing in the speaker")
        #expect(model.problem?.actionTitle != "Pausa", "already paused: the way on is to go on")
        await model.stopListening()
    }
}
