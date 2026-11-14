import Foundation
import Testing
@testable import Lumen

/// A94 (Kelly Ke55): Välkommen is the repetition mode's consent, never the listening consent; a mode that listens
/// asks for its own consent the first time it is started, and only then starts.
@MainActor
@Suite struct A94FirstStartTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.a94.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func welcomeIsNotTheListeningConsent() {
        let defaults = freshDefaults()
        let store = ConsentStore(defaults: defaults)
        #expect(!store.isWelcomeGranted)
        store.grantWelcome()
        #expect(store.isWelcomeGranted)
        #expect(!store.isGranted, "Fortsätt on Välkommen never lets a mode listen")
        #expect(store.record == nil)
        let reloaded = ConsentStore(defaults: defaults)
        #expect(reloaded.isWelcomeGranted && !reloaded.isGranted)
        reloaded.revoke() // withdrawing the listening consent keeps the repetition mode's
        #expect(reloaded.isWelcomeGranted)
    }

    private func model(_ h: ControllerHarness, consent: FakeConsentStore) -> ListeningModel {
        ListeningModel(controller: h.controller, consent: consent, transcription: makeTestCoordinator(h.controller),
                       activation: makeTestActivation(), answers: makeTestAnswerEngine(FakeAnswerProvider(name: "cloud", events: [])),
                       speaker: makeTestSpeaker(h.playback), voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    @Test func aListeningModeAsksForTheConsentFirst() async {
        let h = ControllerHarness()
        let consent = FakeConsentStore(granted: false)
        let model = model(h, consent: consent)
        await model.startListening()
        #expect(model.asksForListeningConsent)
        #expect(!model.isActiveSession, "no microphone before the consent")
        model.listeningConsentDeclined()
        #expect(!model.asksForListeningConsent)
        #expect(consent.record == nil)

        await model.startListening()
        #expect(model.asksForListeningConsent)
        model.listeningConsentGiven()
        #expect(consent.isGranted)
        #expect(!model.asksForListeningConsent)
        #expect(await waitUntil { model.isActiveSession }, "the start that asked goes on after Jag förstår")
        await model.stopListening()
    }
}
