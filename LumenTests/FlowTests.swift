import Foundation
import Testing
@testable import Lumen

/// The common flow (listen → ask → answer → history), Deangelo 2026-11-26 22:38: what felt cumbersome. These use new
/// API, so they could not be run red against main first (they do not compile there); `FlowRetryTests` could.
@MainActor
@Suite struct FlowTests {
    private func makeModel(_ provider: FakeAnswerProvider, consent: Bool = true) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let suite = "lumen.tests.flow2.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: consent),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: ModeSettings(defaults: defaults))
        return (h, model)
    }

    // MARK: Pausa on the screen pauses, also in the "Mer?" window

    @Test func thePauseButtonPausesWhileMoreIsOffered() async {
        let provider = FakeAnswerProvider(events: [.delta("Oslo."), .done(AnswerDone(answered: true))])
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("vad är huvudstaden i Norge?")
        #expect(await waitUntil(timeout: .seconds(5)) { model.isOfferingMore })
        await model.togglePause(fromScreen: true)
        #expect(!model.isOfferingMore)
        #expect(await waitUntil { model.state == .paused(.user) }, "the button says Pausa: it pauses")
        try? await Task.sleep(for: .milliseconds(200))
        #expect(provider.requests.count == 1, "no long answer was asked for")
        #expect(h.controller.eventLog.contains { $0.text == "More? window closed (pause)" })
        await model.stopListening()
    }

    @Test func anAirPodsPressInTheWindowStillMeansMore() async {
        // A15 stays: the press (no screen to read) means "mer" while the window is open.
        let provider = FakeAnswerProvider(events: [.delta("Oslo."), .done(AnswerDone(answered: true))])
        let (_, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("vad är huvudstaden i Norge?")
        #expect(await waitUntil(timeout: .seconds(5)) { model.isOfferingMore })
        await model.togglePause()
        #expect(await waitUntil { provider.requests.count == 2 })
        #expect(model.state == .listening)
        await model.stopListening()
    }

    @Test func outsideTheWindowThePauseButtonPausesAndResumes() async {
        let (_, model) = makeModel(FakeAnswerProvider())
        await model.startListening()
        await model.togglePause(fromScreen: true)
        #expect(await waitUntil { model.state == .paused(.user) })
        await model.togglePause(fromScreen: true)
        #expect(await waitUntil { model.isListening })
        await model.stopListening()
    }

    // MARK: Försök igen also without network

    @Test func theOfflineCardCanAskTheQuestionAgain() async {
        #expect(LumenProblem.offline.actionTitle == "Försök igen")
        let provider = FakeAnswerProvider(name: "cloud", error: .offline)
        let (_, model) = makeModel(provider)
        await model.startListening()
        model.submitText("vad är pi")
        #expect(await waitUntil { model.problem == .offline })
        provider.error = nil
        provider.events = [.delta("Ungefär 3,14."), .done(AnswerDone(answered: true))]
        model.act(on: .offline)
        #expect(model.problem == nil)
        #expect(await waitUntil { model.conversation.answers.last?.answer == "Ungefär 3,14." })
        #expect(provider.requests.last?.fragment == "vad är pi")
        await model.stopListening()
    }

    // MARK: No red "kom inte igång" behind the consent sheet

    @Test func aStartThatAsksForTheConsentHasNotFailed() async {
        let (_, model) = makeModel(FakeAnswerProvider(), consent: false)
        await model.startSelectedMode()
        #expect(model.asksForListeningConsent)
        #expect(!model.isActiveSession)
        #expect(!model.startDidNotTake, "the sheet asks; nothing failed")
        model.listeningConsentDeclined()
    }

    @Test func aStartThatTookHasNotFailed() async {
        let (_, model) = makeModel(FakeAnswerProvider())
        await model.startSelectedMode()
        #expect(await waitUntil { model.isActiveSession })
        #expect(!model.startDidNotTake)
        await model.stopListening()
    }

    // MARK: Back to Fler lägen after Avsluta

    @Test func theFirstStartsListeningComesBackToTheModesPage() async {
        let (_, model) = makeModel(FakeAnswerProvider(), consent: false)
        #expect(!model.showsMoreModes)
        await model.firstStartConsentGiven()
        #expect(await waitUntil { model.isActiveSession })
        #expect(model.showsMoreModes)
        await model.endSession()
        #expect(!model.isActiveSession)
        #expect(model.showsMoreModes, "Avsluta lands on the page with Starta EarMind, not on the exams")
    }

    @Test func theModesPageStaysOpenThroughASession() async {
        let (_, model) = makeModel(FakeAnswerProvider())
        model.showsMoreModes = true // Fler lägen on Start
        await model.startSelectedMode()
        #expect(await waitUntil { model.isActiveSession })
        await model.endSession()
        #expect(model.showsMoreModes)
    }

    // MARK: Historik: one tap from Lyssnar, and search

    @Test func historyCanBeOpenedFromTheListeningScreen() {
        let (_, model) = makeModel(FakeAnswerProvider())
        #expect(!model.isShowingHistory)
        model.isShowingHistory = true // Lyssnar's ⋯ › Historik
        #expect(model.isShowingHistory)
    }

    @Test func historySearchFindsWordsInTheQuestionAnswerAndSummary() {
        let photosynthesis = HistoryEntry(question: nil, answer: "Fotosyntesen är när växter gör socker av ljus.", summary: nil)
        let pi = HistoryEntry(question: "Vad är pi?", answer: "Ungefär 3,14.", summary: nil)
        let summed = HistoryEntry(question: nil, answer: "Ett långt svar.", summary: "Mitokondrier och cellandning")
        let all = [photosynthesis, pi, summed]
        #expect(HistoryEntry.matching(all, "") == all, "an empty search shows everything")
        #expect(HistoryEntry.matching(all, "   ") == all)
        #expect(HistoryEntry.matching(all, "fotosyntes") == [photosynthesis], "a part of a word, any case")
        #expect(HistoryEntry.matching(all, "VAD PI") == [pi], "every word, in any order")
        #expect(HistoryEntry.matching(all, "ar").contains(photosynthesis), "accents do not matter (ar finds är)")
        #expect(HistoryEntry.matching(all, "cellandning") == [summed], "the summary too")
        #expect(HistoryEntry.matching(all, "fotosyntes pi").isEmpty, "every word must be there")
    }
}
