import Foundation
import Testing
@testable import Lumen

/// Toby T59 (2026-11-27, four low findings through the app's wiring). (1) When the voice service's quota is out, Lyssnar
/// says the phone's own voice reads (not A45's "hör och pratar lite sämre"). (4) "quiz me" in English reaches the
/// server in English. (2) was K124's 10-minute pause, already on main; (3) is in the report (the Simulator).
@MainActor
@Suite struct TobyT59Tests {
    private let premiumVoice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Astrid")

    private func model(premium: FakeTTSProvider) -> ListeningModel {
        let h = ControllerHarness()
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                              transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                              answers: makeTestAnswerEngine(FakeAnswerProvider()),
                              speaker: makeTestSpeaker(h.playback, apple: FakeTTSProvider(name: "apple"), premium: premium),
                              voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    @Test func theQuotaOutSaysThePhonesVoiceReads() async {
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = .network(.backend(status: 503, failure: AnswerFailure(code: "tts_quota", message: nil, fallback: true)))
        let model = model(premium: premium)
        model.speaker.settings.voice = premiumVoice
        model.speaker.enqueue("Roten ur hundra är tio.", language: .swedish)
        #expect(await waitUntil { model.fallbackNotice != nil })
        #expect(model.fallbackNotice == "Telefonens röst läser just nu.")
        #expect(model.visibleNotices.contains("Telefonens röst läser just nu."))
    }

    @Test func anotherVoiceTroubleStillSaysTheCalmLine() async {
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.error = .network(.offline)
        let model = model(premium: premium)
        model.speaker.settings.voice = premiumVoice
        model.speaker.enqueue("Roten ur hundra är tio.", language: .swedish)
        #expect(await waitUntil { model.fallbackNotice != nil })
        #expect(model.fallbackNotice != "Telefonens röst läser just nu.", "A45's line for a dropped connection")
    }

    @Test func quizMeInEnglishStaysEnglish() {
        #expect(VoiceChannel.parse("Lumen, quiz me on photosynthesis").intent == .instruction("quiz me on photosynthesis"))
        #expect(VoiceChannel.parse("Lumen, quiz me").intent == .instruction("quiz me"))
        #expect(VoiceChannel.parse("Lumen, förhör mig på fotosyntes").intent == .instruction("förhör mig på fotosyntes"))
    }
}
