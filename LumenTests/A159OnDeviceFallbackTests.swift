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

    /// An answer that has begun and then breaks is not started over by the phone's model.
    @Test func anAnswerThatHasBegunIsNotStartedOver() async {
        let h = ControllerHarness()
        let onDevice = phoneAnswer("Tio.")
        let cloud = FakeAnswerProvider(name: "cloud", events: [
            .meta(AnswerMeta(reconstructedQuestion: "vad är roten ur hundra", confidence: 0.9, isQuestion: true)), .delta("Roten ur hundra "),
        ], error: .backend(status: 200, failure: AnswerFailure(code: "provider_error", message: "upstream closed", fallback: true)))
        let model = model(h, cloud: cloud, onDevice: onDevice)
        await model.startListening()
        model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { model.problem == .overloaded })
        #expect(onDevice.requests.isEmpty)
    }

    /// The phone's provider is told why it is asked, and the server is never told anything about it.
    @Test func thePhoneIsToldWhyAndTheServerIsNotAskedTwice() async {
        let h = ControllerHarness()
        let cloud = FakeAnswerProvider(name: "cloud", error: Self.down("provider_quota"))
        let onDevice = phoneAnswer("Tio.")
        let model = model(h, cloud: cloud, onDevice: onDevice)
        await model.startListening()
        model.submitText("vad är roten ur hundra")
        #expect(await waitUntil { onDevice.requests.count == 1 })
        #expect(onDevice.requests.first?.onDevice == .serverDown)
        #expect(cloud.requests.first?.onDevice == nil)
        #expect(cloud.requests.count == 1, "no credits can be counted for an answer the server never made")
    }

    // MARK: The provider itself, with a pretend model

    private func events(_ provider: OnDeviceAnswerProvider, _ request: AnswerRequest) async -> (events: [AnswerEvent], error: AnswerError?) {
        var events: [AnswerEvent] = []
        do {
            for try await event in provider.answer(request) { events.append(event) }
            return (events, nil)
        } catch {
            return (events, AnswerError.from(error))
        }
    }

    private func request(_ language: String, _ reason: OnDeviceReason?) -> AnswerRequest {
        var request = AnswerRequest(fragment: language == "sv" ? "vad är roten ur hundra" : "what is the square root of a hundred", mode: "tutor", language: language)
        request.onDevice = reason
        return request
    }

    @Test func itAnswersInSwedishWithALineThatSaysItIsThePhonesModel() async {
        let phone = FakeOnDeviceModel(reply: " Tio. ")
        let got = await events(OnDeviceAnswerProvider(model: phone), request("sv", .serverDown))
        #expect(got.error == nil)
        #expect(got.events == [
            .meta(AnswerMeta(reconstructedQuestion: "vad är roten ur hundra", confidence: 0.8, isQuestion: true)),
            .delta("Jag svarar med telefonens egen modell. "), .delta("Tio."), .done(AnswerDone(answered: true)),
        ])
        #expect(phone.asked.first?.instructions.contains("Svara på svenska") == true)
        #expect(phone.languagesChecked == ["sv"])
    }

    @Test func itAnswersInEnglishWhenEnglishWasSpoken() async {
        let phone = FakeOnDeviceModel(reply: "Ten.")
        let got = await events(OnDeviceAnswerProvider(model: phone), request("en", .serverDown))
        #expect(got.events.contains(.delta("Answering with the phone's own model. ")))
        #expect(got.events.contains(.delta("Ten.")))
        #expect(phone.asked.first?.instructions.contains("Answer in English") == true)
        #expect(phone.asked.first?.prompt == "what is the square root of a hundred")
        #expect(phone.languagesChecked == ["en"])
    }

    @Test func withoutTheNetworkItKeepsItsOwnLine() async {
        let swedish = await events(OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: "Tio.")), request("sv", .offline))
        #expect(swedish.events.contains(.delta("Jag svarar kort, nätet är borta. ")))
        // No reason given is the network's case, as before A159.
        let before = await events(OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: "Tio.")), request("sv", nil))
        #expect(before.events.contains(.delta(OnDeviceAnswerProvider.lead + " ")))
        let english = await events(OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: "Ten.")), request("en", .offline))
        #expect(english.events.contains(.delta("A short answer, the network is down. ")))
    }

    @Test func aLanguageTheModelDoesNotSpeakIsANo() async {
        let phone = FakeOnDeviceModel(reply: "Tio.", languages: ["en"]) // Apple Intelligence without Swedish (before iOS 26.1)
        let got = await events(OnDeviceAnswerProvider(model: phone), request("sv", .serverDown))
        #expect(got.error == .offline)
        #expect(got.events.isEmpty)
        #expect(phone.asked.isEmpty, "a model that does not speak the language is not asked")
    }

    @Test func aModelThatFailsOrSaysNothingIsANoAndTheLineIsNeverSaidAlone() async {
        let silent = await events(OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: "  ")), request("sv", .serverDown))
        #expect(silent.error == .offline && silent.events.isEmpty)
        let broken = await events(OnDeviceAnswerProvider(model: FakeOnDeviceModel(reply: nil)), request("en", .serverDown))
        #expect(broken.error == .offline && broken.events.isEmpty)
    }

    @Test func whyThePhoneIsAsked() {
        #expect(OnDeviceReason(.offline) == .offline)
        #expect(OnDeviceReason(Self.down("provider_quota")) == .serverDown)
        #expect(OnDeviceReason(Self.down("provider_unavailable", status: 502)) == .serverDown)
        #expect(OnDeviceReason(.backend(status: 429, failure: AnswerFailure(code: "rate_limited"))) == nil)
        #expect(OnDeviceReason(.unauthorized(detail: "x")) == nil)
        #expect(OnDeviceLanguage.locale(for: "sv").identifier == "sv_SE")
        #expect(OnDeviceLanguage.locale(for: "en").identifier == "en_US")
    }
}

/// A pretend phone model: says `reply` (nil: it fails), and speaks `languages`.
@MainActor
final class FakeOnDeviceModel: OnDeviceModel {
    struct Asked: Equatable { var prompt: String; var instructions: String }
    struct Broken: Error {}
    let reply: String?
    let languages: Set<String>
    private(set) var asked: [Asked] = []
    private(set) var languagesChecked: [String] = []

    init(reply: String?, languages: Set<String> = ["sv", "en"]) {
        self.reply = reply
        self.languages = languages
    }

    func isAvailable(for language: String) -> Bool {
        languagesChecked.append(language)
        return languages.contains(language)
    }

    func respond(to prompt: String, instructions: String) async throws -> String {
        asked.append(Asked(prompt: prompt, instructions: instructions))
        guard let reply else { throw Broken() }
        return reply
    }
}
