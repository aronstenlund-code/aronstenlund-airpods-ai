import Foundation
import Testing
@testable import Lumen

/// A15: "Mer?" after a short answer.
@Suite struct MoreOfferTests {
    @Test func yesNoAndEverythingElse() {
        for yes in ["Ja.", "mer", "Utveckla", "gärna", "ja tack", "Lumen, mer"] { #expect(MoreOffer.verdict(yes) == true, "\(yes)") }
        for no in ["Nej.", "nej tack", "det räcker"] { #expect(MoreOffer.verdict(no) == false, "\(no)") }
        for other in ["ja men vad är fotosyntes", "jag sa ja till henne", "vad är pi", "mer än tio"] {
            #expect(MoreOffer.verdict(other) == nil, "a 'ja' inside a sentence is no answer: \(other)")
        }
    }

    @Test func onlyShortAnswersWithoutAQuestion() {
        #expect(MoreOffer.isShort("Huvudstaden i Norge är Oslo."))
        #expect(MoreOffer.isShort("Fotosyntes är när växter gör socker av ljus. Det sker i bladen."))
        #expect(!MoreOffer.isShort("Ett. Två. Tre meningar är för många."))
        #expect(!MoreOffer.isShort("Vet du vad klorofyll gör?"), "a check question is answered with 'ja' itself")
        #expect(!MoreOffer.isShort(String(repeating: "ord ", count: 45)))
        #expect(!MoreOffer.isShort(""))
    }
}

@MainActor
@Suite struct MoreOfferModelTests {
    private func makeModel(_ provider: FakeAnswerProvider) -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let suite = "lumen.tests.a15.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: ModeSettings(defaults: defaults))
        return (h, model)
    }

    @Test func aShortAnswerOpensTheWindowAndJaAsksForMore() async {
        let provider = FakeAnswerProvider(events: [.delta("Oslo."), .done(AnswerDone(answered: true))])
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("vad är huvudstaden i Norge?")
        #expect(await waitUntil(timeout: .seconds(5)) { model.isOfferingMore })

        model.receiveFinalTranscript("Ja.")
        #expect(!model.isOfferingMore)
        #expect(h.controller.eventLog.contains { $0.text == "More? window closed (yes, voice)" })
        #expect(await waitUntil { provider.requests.count == 2 })
        #expect(provider.requests.last?.fragment == "utveckla")
    }

    @Test func nejClosesTheWindow() async {
        let provider = FakeAnswerProvider(events: [.delta("Oslo."), .done(AnswerDone(answered: true))])
        let (h, model) = makeModel(provider)
        await model.startListening()
        model.receiveFinalTranscript("vad är huvudstaden i Norge?")
        #expect(await waitUntil(timeout: .seconds(5)) { model.isOfferingMore })
        model.receiveFinalTranscript("nej")
        #expect(!model.isOfferingMore)
        #expect(h.controller.eventLog.contains { $0.text == "More? window closed (no)" })
        try? await Task.sleep(for: .milliseconds(200))
        #expect(provider.requests.count == 1)
    }
}
