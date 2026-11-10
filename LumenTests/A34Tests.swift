import Foundation
import Testing
@testable import Lumen

/// A34 (D109): a sound when Lumen starts and stops listening, and one switch that turns them off.
@MainActor
@Suite struct ListeningCueTests {
    private func model(_ h: ControllerHarness, cues: Bool) -> ListeningModel {
        let speaker = makeTestSpeaker(h.playback)
        speaker.settings.listeningCues = cues
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                              activation: makeTestActivation(), answers: makeTestAnswerEngine(FakeAnswerProvider(name: "cloud", events: [])),
                              speaker: speaker, voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    private func cues(_ h: ControllerHarness) -> [String] {
        h.controller.eventLog.map(\.text).filter { $0.hasPrefix("Cue: ") }
    }

    @Test func startAndStopAreHeard() async {
        let h = ControllerHarness()
        let model = model(h, cues: true)
        await model.startListening()
        #expect(await waitUntil { cues(h).contains("Cue: start (A34)") })
        await model.stopListening()
        #expect(cues(h).contains("Cue: stop (A34)"))
        #expect(cues(h).filter { $0 == "Cue: start (A34)" }.count == 1, "once per start")
    }

    @Test func theSwitchTurnsThemOff() async {
        let h = ControllerHarness()
        let model = model(h, cues: false)
        await model.startListening()
        try? await Task.sleep(for: .milliseconds(50))
        await model.stopListening()
        #expect(cues(h).isEmpty)
    }
}
