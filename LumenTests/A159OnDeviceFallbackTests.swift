import Foundation
import Testing
@testable import Lumen

/// A159 (D258): Aron does not top up the model's credits now, so /answer says 503 `provider_quota`. The phone's own
/// model (Foundation Models, A40) then answers a question, once, as it already does when the network is gone; when
/// the phone has no such model, or it does not speak the language, the app says what it said before (O97).
/// A pretend server and a pretend on-device provider: no model call, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A159OnDeviceFallbackTests {
    static func down(_ code: String, status: Int = 503) -> AnswerError {
        .backend(status: status, failure: AnswerFailure(code: code, message: "LLM credits exhausted", fallback: true))
    }

    private func model(_ h: ControllerHarness, cloud: FakeAnswerProvider, onDevice: FakeAnswerProvider?) -> ListeningModel {
        let engine = makeTestAnswerEngine(cloud)
        engine.offline = onDevice
        return ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                              activation: makeTestActivation(), answers: engine, speaker: makeTestSpeaker(h.playback),
                              voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep())
    }

    private func phoneAnswer(_ text: String) -> FakeAnswerProvider {
        FakeAnswerProvider(name: "on-device", events: [
            .meta(AnswerMeta(reconstructedQuestion: "vad är roten ur hundra", confidence: 0.8, isQuestion: true)),
            .delta("Jag svarar med telefonens egen modell. "), .delta(text), .done(AnswerDone(answered: true)),
        ])
    }

    @Test func thePhonesModelAnswersWhenTheServersModelIsOutOfCredits() async {
        for code in ["provider_quota", "provider_busy", "provider_unconfigured", "provider_unavailable"] {
            let h = ControllerHarness()
            let cloud = FakeAnswerProvider(name: "cloud", error: Self.down(code, status: code == "provider_unavailable" ? 502 : 503))
            let onDevice = phoneAnswer("Tio.")
            let model = model(h, cloud: cloud, onDevice: onDevice)
            await model.startListening()
            model.submitText("vad är roten ur hundra")
            #expect(await waitUntil { model.conversation.answers.last?.answer.hasSuffix("Tio.") == true }, "\(code)")
            #expect(model.conversation.answers.last?.answer.hasPrefix("Jag svarar med telefonens egen modell.") == true, "\(code)")
            #expect(onDevice.requests.count == 1, "\(code): asked once")
            #expect(cloud.requests.count == 1, "\(code): the server is not asked again for that answer")
            #expect(model.problem == nil, "\(code): nothing is wrong on the screen when the phone answered")
        }
    }

    /// An iPhone without Apple Intelligence, or a language its model does not speak: the on-device provider says no,
    /// and the app says what it said before O97's line for the spoken answers ("Jag kan inte svara just nu").
    @Test func withoutAPhoneModelItSaysWhatItSaidBefore() async {
        let h = ControllerHarness()
        let onDevice = FakeAnswerProvider(name: "on-device", error: .offline)
        let model = model(h, cloud: FakeAnswerProvider(name: "cloud", error: Self.down("provider_quota")), onDevice: onDevice)
        await model.startListening()
        model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { model.problem == .overloaded })
        #expect(onDevice.requests.count == 1, "asked once, never in a loop")
        #expect(model.problem != .offline, "the network is fine: it must not say that the network is gone")
    }

    /// Another kind of no from the server (too many questions) is not the model being down.
    @Test func otherRefusalsDoNotWakeThePhonesModel() async {
        let h = ControllerHarness()
        let onDevice = phoneAnswer("Tio.")
        let limit = AnswerError.backend(status: 429, failure: AnswerFailure(code: "rate_limited", message: "För många frågor just nu.", fallback: true))
        let model = model(h, cloud: FakeAnswerProvider(name: "cloud", error: limit), onDevice: onDevice)
        await model.startListening()
        model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { model.problem != nil })
        #expect(onDevice.requests.isEmpty)
    }
}
