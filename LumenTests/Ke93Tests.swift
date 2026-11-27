import Foundation
import Testing
@testable import Lumen

/// Kelly Ke93 (2026-11-27, her pictures of D269 and the first start) and her answer on D269 (a): the card says why
/// once, the activation words wait for the first answer, and what is heard shows under the badge.
@MainActor
@Suite struct Ke93Tests {
    private func model() -> ListeningModel {
        let h = ControllerHarness()
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                              transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                              answers: makeTestAnswerEngine(FakeAnswerProvider()), speaker: makeTestSpeaker(h.playback),
                              voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                              history: makeTestHistory())
    }

    @Test func theBusyCardSaysWhyOnceAndTheButtonSaysTryAgain() {
        #expect(LumenProblem.overloaded.text == "Vår server är upptagen.")
        #expect(LumenProblem.overloaded.actionTitle == "Försök igen")
    }

    @Test func theActivationSentenceIsAronsWhole() {
        #expect(ActivationWordsField.sentence == "Fråga du inte är beredd på? Säg [ … ] så aktiveras vår AI.")
    }

    @Test func theActivationWordsWaitForTheFirstAnswer() {
        let model = model()
        #expect(!model.showsActivationWords, "the very first listening shows only \"Fråga vad du vill.\"")
        model.receiveAnswer(question: "Vad är pi?", answer: "Ungefär 3,14.", source: "cloud")
        #expect(model.showsActivationWords)
    }

    @Test func setWordsAreAlwaysShown() {
        let model = model()
        model.activation.settings.setPhrase("hjälp mig")
        #expect(model.showsActivationWords)
        model.activation.settings.setPhrase("")
    }

    @Test func anEarlierAnswerInTheHistoryShowsThemToo() {
        let model = model()
        model.history.record(HistoryEntry(question: nil, answer: "Tio.", summary: nil))
        #expect(model.showsActivationWords, "not the first time any more")
    }

    @Test func whatIsHeardShowsUntilTheWordsAreFinal() {
        let model = model()
        #expect(model.heardLine == nil)
        model.receivePartialTranscript("vad är foto")
        #expect(model.heardLine == "vad är foto")
        let long = String(repeating: "ord ", count: 60)
        model.receivePartialTranscript(long)
        let shown = model.heardLine ?? ""
        #expect(shown.hasPrefix("…") && shown.count == ListeningModel.heardLineLimit + 1, "the end of it, two lines")
        model.receivePartialTranscript("")
        #expect(model.heardLine == nil, "gone when the words are final")
    }
}
