import Foundation
import Testing
@testable import Lumen

/// A166: from a new install to the first answer on the shortest way. Välkommen, the listening consent (whole, with the
/// one button that starts EarMind), iOS's question about the microphone, and Lyssnar. What can wait, waits: Nytt prov
/// is on Start, and the question about sharing the history comes when the first listening is over.
@MainActor
@Suite struct A166FirstStartTests {
    private func model(_ h: ControllerHarness, consent: FakeConsentStore) -> ListeningModel {
        ListeningModel(controller: h.controller, consent: consent, transcription: makeTestCoordinator(h.controller),
                       activation: makeTestActivation(), answers: makeTestAnswerEngine(FakeAnswerProvider(name: "cloud", events: [])),
                       speaker: makeTestSpeaker(h.playback), voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    // MARK: The steps

    @Test func aNewInstallHasTwoScreensBeforeTheMicrophone() {
        var steps: [FirstStartStep] = [.welcome]
        while let next = FirstStartPath.step(after: steps[steps.count - 1], returning: false, listeningConsented: false) {
            steps.append(next)
            if steps.count > 5 { break }
        }
        #expect(steps == [.welcome, .listeningConsent], "Välkommen, then the consent; nothing else before the first answer")
    }

    @Test func theConsentIsNeverSkippedForSomeoneWhoHasNotGivenIt() {
        #expect(FirstStartPath.step(after: .welcome, returning: false, listeningConsented: false) == .listeningConsent)
        #expect(FirstStartPath.step(after: .listeningConsent, returning: false, listeningConsented: false) == nil)
    }

    @Test func theOneWhoAlreadyUsesTheAppOnlySeesWelcome() {
        // Finished the old first start: Välkommen once, then Start, as before (A94).
        #expect(FirstStartPath.step(after: .welcome, returning: true, listeningConsented: false) == nil)
        // The consent is already given: it is not asked again.
        #expect(FirstStartPath.step(after: .welcome, returning: false, listeningConsented: true) == nil)
    }

    // MARK: "Jag förstår, starta EarMind" in the first start

    @Test func theConsentButtonStartsStandardlagetAtOnce() async {
        let h = ControllerHarness()
        let consent = FakeConsentStore(granted: false)
        let model = model(h, consent: consent)
        model.selectedMode = .prov // left by an earlier account on the phone: the first answer is Standardläget's
        await model.firstStartConsentGiven()
        #expect(consent.isGranted)
        #expect(await waitUntil { model.isActiveSession }, "one press: the consent, and EarMind listens")
        #expect(model.selectedMode == .standard)
        #expect(model.showsListeningScreen, "Lyssnar, where the indicator and the answer are")
        #expect(!model.asksForListeningConsent, "the consent was just given; it is not asked twice")
        await model.stopListening()
    }

    @Test func nothingListensWithoutTheConsent() async {
        let h = ControllerHarness()
        let consent = FakeConsentStore(granted: false)
        let model = model(h, consent: consent)
        // "Senare" in the first start calls nothing on the model: no consent, no microphone.
        #expect(!consent.isGranted && !model.isActiveSession)
        await model.startListening()
        #expect(model.asksForListeningConsent && !model.isActiveSession, "a later start asks for the consent, as before (A94)")
        model.listeningConsentDeclined()
    }

    // MARK: The question about sharing waits

    @Test func theSharingQuestionWaitsUntilTheFirstListeningIsOver() async {
        let h = ControllerHarness()
        let consent = FakeConsentStore(granted: false)
        let model = model(h, consent: consent)
        #expect(model.sharingQuestionIsFree, "nothing holds it before the consent (and without the consent it is never asked)")
        await model.firstStartConsentGiven()
        #expect(await waitUntil { model.isActiveSession })
        #expect(!model.sharingQuestionIsFree, "not on top of Lyssnar before the first answer")
        await model.stopListening()
        #expect(model.sharingQuestionIsFree, "the listening is over: now it may be asked")
    }

    @Test func theSharingQuestionAlsoWaitsAfterTheConsentSheet() async {
        let h = ControllerHarness()
        let consent = FakeConsentStore(granted: false)
        let model = model(h, consent: consent)
        await model.startListening()
        model.listeningConsentGiven()
        #expect(!model.sharingQuestionIsFree, "held from the press itself, before the microphone has started")
        #expect(await waitUntil { model.isActiveSession })
        #expect(!model.sharingQuestionIsFree)
        await model.stopListening()
        #expect(model.sharingQuestionIsFree)
    }

    @Test func aLaterSessionDoesNotHoldTheQuestionBack() async {
        // The consent was given on an earlier day and the question never answered: it comes when the app opens, as
        // before, and a session that runs keeps it away.
        let h = ControllerHarness()
        let model = model(h, consent: FakeConsentStore(granted: true))
        #expect(model.sharingQuestionIsFree)
        await model.startListening()
        #expect(await waitUntil { model.isActiveSession })
        #expect(!model.sharingQuestionIsFree)
        await model.stopListening()
        #expect(model.sharingQuestionIsFree)
    }
}
