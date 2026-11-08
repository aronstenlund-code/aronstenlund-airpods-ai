import Foundation
import Testing
@testable import Lumen

/// A5: when Lumen cannot answer (credits out, the provider down, too slow), it says so once, in Apple's voice, shows
/// it on the screen, and says it again only after an answer has worked. The codes are in Diagnostik.
@Suite struct CannotAnswerMappingTests {
    @Test func everyFailureIsSaidInSwedish() {
        #expect(ListeningModel.problem(for: .backend(status: 503, failure: AnswerFailure(code: "provider_quota"))) == .overloaded)
        #expect(ListeningModel.problem(for: .backend(status: 502, failure: AnswerFailure(code: "provider_unavailable"))) == .overloaded)
        #expect(ListeningModel.problem(for: .transport(detail: "timed out")) == .overloaded)
        #expect(ListeningModel.problem(for: .offline) == .offline)
        #expect(AnswerError.from(URLError(.timedOut)) == .transport(detail: "timed out"), "too slow is not 'no internet'")
        #expect(AnswerError.from(URLError(.notConnectedToInternet)) == .offline)
        #expect(LumenProblem.overloaded.spoken == "Jag kan inte svara just nu, försök igen om en stund.")
        #expect(LumenProblem.voiceUnavailable.spoken == nil, "the answer is still heard, in the iPhone's voice")
    }
}

@MainActor
@Suite struct CannotAnswerFlowTests {
    private struct Rig {
        let h: ControllerHarness
        let provider: FakeAnswerProvider
        let apple: FakeTTSProvider
        let premium: FakeTTSProvider
        let model: ListeningModel
    }

    private func makeRig(error: AnswerError?, premiumFails: Bool = false) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: error == nil ? [.delta("Tio. "), .done(AnswerDone(answered: true))] : [],
                                          error: error)
        let apple = FakeTTSProvider(name: "apple")
        let premium = FakeTTSProvider(name: "elevenlabs")
        let settings = freshVoiceSettings()
        if premiumFails {
            premium.error = .network(.backend(status: 503, failure: AnswerFailure(code: "quota_exceeded")))
            settings.voice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Test")
        }
        let speaker = Speaker(settings: settings, apple: apple, premium: premium, playback: h.playback)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: speaker, voices: makeTestVoiceCatalog(),
                                   notes: makeTestNotes(), prep: makeTestPrep())
        return Rig(h: h, provider: provider, apple: apple, premium: premium, model: model)
    }

    private let line = "Jag kan inte svara just nu, försök igen om en stund."

    private func said(_ rig: Rig) -> Int { rig.apple.calls.filter { $0.text == line }.count }

    @Test func quotaOutIsSaidOnceUntilAnAnswerWorks() async {
        let rig = makeRig(error: .backend(status: 503, failure: AnswerFailure(code: "provider_quota", message: "credits")))
        await rig.model.startListening()

        rig.model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { rig.model.problem == .overloaded })
        #expect(await waitUntil { said(rig) == 1 }, "said in the ear, in Apple's voice")

        rig.model.submitText("vad är pi")
        #expect(await waitUntil { rig.model.failures.count == 2 })
        try? await Task.sleep(for: .milliseconds(150))
        #expect(said(rig) == 1, "not again while it is still failing")
        #expect(rig.model.failures.last?.detail.contains("provider_quota") == true, "the code is in Diagnostik")

        rig.provider.error = nil
        rig.provider.events = [.delta("Tio. "), .done(AnswerDone(answered: true))]
        rig.model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { rig.model.problem == nil }, "an answer worked: the card goes")

        rig.provider.events = []
        rig.provider.error = .backend(status: 502, failure: AnswerFailure(code: "provider_unavailable"))
        rig.model.submitText("vad är e")
        #expect(await waitUntil { said(rig) == 2 }, "a new outage is said again")
    }

    @Test func tooSlowIsCannotAnswer() async {
        let rig = makeRig(error: .transport(detail: "timed out"))
        await rig.model.startListening()
        rig.model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { rig.model.problem == .overloaded })
        #expect(await waitUntil { said(rig) == 1 })
    }

    @Test func aFailingVoiceFallsBackAndIsShown() async {
        let rig = makeRig(error: nil, premiumFails: true)
        await rig.model.startListening()
        rig.model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { rig.model.problem == .voiceUnavailable })
        #expect(await waitUntil { rig.apple.calls.contains { $0.text == "Tio." } }, "the answer is still heard, in Apple's voice")
        #expect(rig.model.failures.contains { $0.source == "tts" })
    }
}
