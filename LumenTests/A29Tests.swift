import Foundation
import Testing
@testable import Lumen

/// A29 (Toby T7): the recogniser closing and opening around Lumen's speech are events a test can wait for.
@MainActor
@Suite struct ListeningEventTests {
    @Test func theRecognisersGateIsAnEvent() async {
        let h = ControllerHarness()
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(FakeAnswerProvider(name: "cloud", events: [])),
                                   speaker: makeTestSpeaker(h.playback, apple: FakeTTSProvider(name: "apple")),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
        var events: [ListeningModel.ListeningEvent] = []
        model.listeningEventObserver = { event, _ in events.append(event) }
        // The fake playback never reports its end (the real path waits for it), so the gate is driven directly here.
        model.transcription.setInputGated(true)
        model.transcription.setInputGated(true) // no change, no event
        model.transcription.setInputGated(false)
        #expect(events == [.micGated, .micOpen])
    }

    @Test func theEventsHaveTheLogsWords() {
        #expect(ListeningModel.ListeningEvent.micOpen.rawValue == "mic open")
        #expect(ListeningModel.ListeningEvent.moreWindowOpen.rawValue == "more window open")
    }
}
