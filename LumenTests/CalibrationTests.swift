import Foundation
import Testing
@testable import Lumen

/// D69 on the D74 voice path: "Lumen, …" in Socialt läge and Rizzläge is an instruction, never conversation.
@MainActor
@Suite struct LiveRequestTests {
    private func session(_ style: LiveStyle) -> RizzSession {
        var session = RizzSession(style: style)
        let now = Date()
        session.add(.other, text: "Någon skämtar", at: now)
        session.add(.other, text: "En annan svarar", at: now)
        session.add(.user, text: "Jag skrattar", at: now)
        session.add(.other, text: "En tredje frågar", at: now)
        return session
    }

    @Test func severalOtherSpeakersAreAllKeptInOrder() {
        let request = LiveRequest.suggestions(for: session(.social), trigger: "other_spoke", interests: [], profile: "",
                                              calibration: nil, adultConfirmed: false)
        #expect(request?.social?.transcript.map(\.text) == ["Någon skämtar", "En annan svarar", "Jag skrattar", "En tredje frågar"])
        #expect(request?.social?.transcript.map(\.speaker) == ["other", "other", "user", "other"])
    }

    @Test func anInstructionIsNeverSentAsConversation() throws {
        let request = try #require(LiveRequest.instruction("ge mig tre pickup lines", for: session(.social), interests: [],
                                                           profile: "", calibration: "Kort.", adultConfirmed: false))
        let social = try #require(request.social)
        #expect(social.calibrate == "ge mig tre pickup lines")
        #expect(social.calibration == "Kort.")
        #expect(social.transcript.count == 4, "the conversation so far, so there is something to build on")
        #expect(!social.transcript.contains { $0.text.contains("pickup") }, "the instruction is not a line")

        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "", mode: "tutor", language: "sv", persona: request))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let body = try #require(json["social"] as? [String: Any])
        #expect(body["calibrate"] as? String == "ge mig tre pickup lines")
        #expect(body["calibration"] as? String == "Kort.")
    }

    @Test func everySuggestionRequestCarriesTheCalibration() {
        let request = LiveRequest.suggestions(for: session(.flirt), trigger: "stall", interests: [], profile: "",
                                              calibration: "Mindre kaxig.", adultConfirmed: true)
        #expect(request?.social?.calibration == "Mindre kaxig.")
        #expect(request?.social?.calibrate == nil)
        #expect(request?.adultConfirmed == true)
    }

    @Test func rizzWithoutTheAgeConfirmationBuildsNothing() {
        #expect(LiveRequest.suggestions(for: session(.flirt), trigger: "stall", interests: [], profile: "",
                                        calibration: nil, adultConfirmed: false) == nil)
        #expect(LiveRequest.instruction("mer skämt", for: session(.flirt), interests: [], profile: "", calibration: nil,
                                        adultConfirmed: false) == nil)
    }

    @Test func theCalibrationDecodesFromDone() throws {
        let event = SSEEvent(name: "done", data: "{\"answered\":false,\"calibration\":\"Mer skämt.\"}")
        guard case .done(let done) = try AnswerSSEDecoder.decode(event) else {
            Issue.record("not a done event")
            return
        }
        #expect(done.calibration == "Mer skämt.")
    }
}

@MainActor
@Suite struct CalibrationStorageTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.calibration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func keptPerModeOnThisPhoneUntilReset() {
        let defaults = freshDefaults()
        let settings = ModeSettings(defaults: defaults)
        settings.setCalibration("Mindre kaxig.", for: .rizz)
        settings.setCalibration("Mer ordvitsar.", for: .social)

        let reopened = ModeSettings(defaults: defaults)
        #expect(reopened.calibration(for: .rizz) == "Mindre kaxig.")
        #expect(reopened.calibration(for: .social) == "Mer ordvitsar.")

        reopened.resetCalibration(for: .rizz)
        #expect(reopened.calibration(for: .rizz) == nil)
        #expect(ModeSettings(defaults: defaults).calibration(for: .social) == "Mer ordvitsar.")
    }

    @Test func emptyClearsAndLongIsCut() {
        let settings = ModeSettings(defaults: freshDefaults())
        settings.setCalibration(String(repeating: "b", count: 500), for: .social)
        #expect(settings.calibration(for: .social)?.count == VoiceChannel.instructionLimit)
        settings.setCalibration("", for: .social) // the backend's answer to "återställ"
        #expect(settings.calibration(for: .social) == nil)
    }
}

@MainActor
@Suite struct CalibrationFlowTests {
    private struct Rig {
        let provider: FakeAnswerProvider
        let model: ListeningModel
        let apple: FakeTTSProvider
        let settings: ModeSettings
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.calibrationflow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeRig(events: [AnswerEvent]) -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: events)
        let apple = FakeTTSProvider(name: "apple")
        let settings = ModeSettings(defaults: freshDefaults())
        settings.confirmAdult()
        let microphones = MicrophoneSettings(defaults: freshDefaults())
        for mode in ConversationMode.allCases { microphones.setSource(.iPhone, for: mode) }
        let study = StudySessionController(settings: StudySettings(defaults: freshDefaults()), session: h.controller)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), study: study,
                                   history: makeTestHistory(), memory: makeTestMemory(), microphone: microphones, modeSettings: settings)
        return Rig(provider: provider, model: model, apple: apple, settings: settings)
    }

    /// One spoken turn at `level` that ended a moment ago (same paths as the microphone).
    private func speak(_ text: String, level: Double, rig: Rig) {
        var time = Date().addingTimeInterval(-4)
        for _ in 0..<15 {
            rig.model.study.level(level, at: time)
            time = time.addingTimeInterval(0.04)
        }
        rig.model.receiveFinalTranscript(text, at: time)
        for _ in 0..<45 {
            rig.model.study.level(-70, at: time)
            time = time.addingTimeInterval(0.04)
        }
    }

    private func quiet(_ rig: Rig) async {
        _ = await waitUntil { !rig.model.speaker.isSpeaking && !rig.model.speaker.hasPendingSpeech }
        rig.model.study.resumeListening()
        rig.model.study.level(-70, at: Date())
    }

    @Test func lumenCommaIsStoredAndSentWithEveryRequest() async {
        let rig = makeRig(events: [.done(AnswerDone(answered: false, calibration: "Mer skämt."))])
        await rig.model.startHandsFree(.rizz)
        rig.model.study.level(-70, at: Date())

        rig.model.receiveFinalTranscript("Lumen, mer skämt", at: Date())

        #expect(await waitUntil { rig.settings.calibration(for: .rizz) == "Mer skämt." })
        let instruction = rig.provider.requests[0].persona?.social
        #expect(instruction?.calibrate == "mer skämt")
        #expect(rig.model.rizz?.transcript.isEmpty == true, "never a line of the conversation")
        #expect(await waitUntil { rig.apple.calls.contains { $0.text == "Okej." } })

        rig.provider.events = [.suggestions(["Bästa"]), .done(AnswerDone(answered: true))]
        await quiet(rig)
        speak("Jag älskar chili", level: -40, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 2 })
        let next = rig.provider.requests[1].persona?.social
        #expect(next?.calibration == "Mer skämt.")
        #expect(next?.calibrate == nil)
        #expect(next?.transcript == [SocialRequest.Line(speaker: "other", text: "Jag älskar chili")])
        #expect(rig.settings.calibration(for: .social) == nil, "per mode")
    }

    @Test func askingForMoreShowsAndSpeaksAllThisTimeOnly() async {
        let rig = makeRig(events: [.suggestions(["Ett", "Två", "Tre"]), .done(AnswerDone(answered: true))])
        await rig.model.startHandsFree(.social)
        rig.model.study.level(-70, at: Date())

        rig.model.receiveFinalTranscript("Lumen, ge mig tre pickup lines", at: Date())

        #expect(await waitUntil { rig.model.rizz?.suggestions == ["Ett", "Två", "Tre"] }, "all of them on screen")
        #expect(await waitUntil { ["Ett", "Två", "Tre"].allSatisfy { line in rig.apple.calls.contains { $0.text == line } } },
                "and all of them spoken")
        #expect(rig.provider.requests[0].persona?.social?.calibrate == "ge mig tre pickup lines")
        #expect(rig.settings.calibration(for: .social) == nil, "a request for more is not a calibration")

        // The next ordinary suggestion is one again (D72).
        await quiet(rig)
        speak("Vad gör ni i helgen", level: -40, rig: rig)
        #expect(await waitUntil { rig.provider.requests.count == 2 })
        #expect(await waitUntil { rig.model.rizz?.suggestions == ["Ett"] })
    }

    @Test func theWordsBeforeTheNameStayConversation() async {
        let rig = makeRig(events: [.done(AnswerDone(answered: false, calibration: "Mer skämt."))])
        await rig.model.startHandsFree(.social)
        rig.model.study.level(-70, at: Date())

        speak("Ja precis. Lumen, mer skämt", level: -40, rig: rig)

        #expect(await waitUntil { rig.settings.calibration(for: .social) == "Mer skämt." })
        #expect(rig.provider.requests[0].persona?.social?.calibrate == "mer skämt")
        #expect(!(rig.provider.requests[0].persona?.social?.transcript.contains { $0.text.contains("skämt") } ?? true))
    }

    @Test func resetIsStoredAsNothing() async {
        let rig = makeRig(events: [.done(AnswerDone(answered: false, calibration: ""))])
        rig.settings.setCalibration("Mindre kaxig.", for: .social)
        await rig.model.startHandsFree(.social)

        rig.model.receiveFinalTranscript("Lumen, återställ", at: Date())

        #expect(await waitUntil { rig.settings.calibration(for: .social) == nil })
        #expect(rig.provider.requests[0].persona?.social?.calibration == "Mindre kaxig.")
    }
}
