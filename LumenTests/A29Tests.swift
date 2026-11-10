import Foundation
import Testing
@testable import Lumen

/// A29 (Toby T7): the recogniser closing and opening around Lumen's speech are events a test can wait for.
@MainActor
@Suite struct ListeningEventTests {
    @Test func theMicrophoneClosesForTheAnswerAndOpensAfter() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Fyrtio. "), .done(AnswerDone(answered: true))])
        let apple = FakeTTSProvider(name: "apple")
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
        var events: [ListeningModel.ListeningEvent] = []
        model.listeningEventObserver = { event, _ in events.append(event) }
        await model.startListening()
        model.receiveFinalTranscript("vad är tjugo plus tjugo?", at: Date())
        #expect(await waitUntil { apple.calls.count == 1 })
        #expect(await waitUntil(timeout: .seconds(5)) { events.contains(.micOpen) })
        let gated = events.firstIndex(of: .micGated)
        let opened = events.lastIndex(of: .micOpen)
        #expect(gated != nil && opened != nil && gated! < opened!, "closed for the answer, open after it: \(events)")
    }

    @Test func theEventsHaveTheLogsWords() {
        #expect(ListeningModel.ListeningEvent.micOpen.rawValue == "mic open")
        #expect(ListeningModel.ListeningEvent.moreWindowOpen.rawValue == "more window open")
    }
}
