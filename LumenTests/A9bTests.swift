import Foundation
import Testing
@testable import Lumen

/// A9.2–3 against Kevin's K10 contract.
@Suite struct PreferenceContractTests {
    @Test func appCommandAndAnswerTypeAreRead() throws {
        let meta = "{\"reconstructed_question\":\"kan vi byta till frågor\",\"confidence\":1,\"is_question\":false,\"needs_confirmation\":false,\"answer_type\":\"fact\",\"app_command\":{\"action\":\"switch_mode\",\"mode\":\"fragor\",\"confidence\":0.9}}"
        guard case .meta(let decoded)? = try AnswerSSEDecoder.decode(SSEEvent(name: "meta", data: meta)) else {
            Issue.record("no meta")
            return
        }
        #expect(decoded.appCommand == AppCommand(action: "switch_mode", mode: "fragor", confidence: 0.9))
        #expect(decoded.appCommand?.isSure == true)
        #expect(decoded.answerType == "fact")
        #expect(AppCommand(action: "switch_mode", mode: "prov", confidence: 0.7).isSure == false)
    }

    @Test func preferencesGoWithEveryAnswer() throws {
        var context = AnswerContext()
        context.preferences = [PrefSetting(key: "length", value: "shorter", scope: PrefScope(subject: "Geografi"), n: 2)]
        context.prefProfile = "Användaren vill ha: kortare svar i geografi."
        context.prefSubject = "Geografi"
        context.prefExam = "Geografiprovet"
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "vad är en fjord", mode: "tutor", language: "sv", context: context))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let prefs = try #require(json["preferences"] as? [[String: Any]])
        #expect(prefs.first?["key"] as? String == "length")
        #expect((prefs.first?["scope"] as? [String: Any])?["subject"] as? String == "Geografi")
        #expect(json["pref_profile"] as? String == "Användaren vill ha: kortare svar i geografi.")
        #expect((json["pref_context"] as? [String: Any])?["exam"] as? String == "Geografiprovet")

        let plain = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "x", mode: "text", language: "sv"))
        let plainJSON = try #require(try JSONSerialization.jsonObject(with: plain) as? [String: Any])
        #expect(plainJSON["preferences"] == nil, "nothing learned: nothing sent")
    }

    @Test func linesReadLikeTheBackendsDescribe() {
        #expect(PrefSetting(key: "length", value: "shorter", scope: PrefScope(answerType: "math")).text == "Kortare svar i matte")
        #expect(PrefSetting(key: "examples", value: "more", scope: PrefScope(exam: "Geografiprovet")).text == "Fler exempel inför Geografiprovet")
        #expect(PrefSetting(key: "simplicity", value: "simpler", scope: PrefScope(mode: "prov")).text == "Enklare förklaringar i Provläge")
        #expect(PrefSetting(key: "length", value: "longer", scope: PrefScope()).text == "Längre, utförligare svar")
    }

    @Test func undoWordsAreTheWholeUtterance() {
        #expect(UndoWords.matches("Nej."))
        #expect(UndoWords.matches("ångra"))
        #expect(UndoWords.matches("nej det var fel"))
        #expect(!UndoWords.matches("nej jag menar provläget"))
        #expect(ConversationMode(backendName: "fragor") == .standard)
        #expect(ConversationMode.interview.backendName == "intervju")
    }
}

@MainActor
@Suite struct PreferenceStoreTests {
    private func makeStore() -> (PreferenceStore, UserDefaults) {
        let suite = "lumen.tests.prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (PreferenceStore(defaults: defaults), defaults)
    }

    @Test func listIsKeptEditableAndProfiled() {
        let (store, defaults) = makeStore()
        let math = PrefSetting(key: "length", value: "shorter", scope: PrefScope(answerType: "math"), n: 3)
        let geo = PrefSetting(key: "length", value: "shorter", scope: PrefScope(subject: "Geografi"), n: 2)
        let examples = PrefSetting(key: "examples", value: "more", scope: PrefScope(mode: "prov"))
        store.replace(with: [math, geo, examples])
        #expect(PreferenceStore(defaults: defaults).settings.count == 3, "kept on the phone")
        #expect(store.profile == "Användaren vill ha: kortare svar i matte; kortare svar i geografi; fler exempel i Provläge.")

        store.remove(examples)
        #expect(store.settings.map(\.id) == [math.id, geo.id])
        store.makeGlobal(geo)
        #expect(store.settings.count == 1, "the global setting replaces the narrower ones with the same meaning")
        #expect(store.settings.first?.scope.isGlobal == true)
        #expect(store.settings.first?.text == "Kortare svar")
    }
}

@MainActor
@Suite struct AppCommandModelTests {
    private func makeModel() -> (ControllerHarness, ListeningModel) {
        let h = ControllerHarness()
        let suite = "lumen.tests.a9b.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(),
                                   modeSettings: ModeSettings(defaults: defaults))
        return (h, model)
    }

    @Test func aSureCommandRunsAndNejTakesItBack() async {
        let (h, model) = makeModel()
        await model.startListening()
        model.answerAppCommand(AppCommand(action: "pause", mode: nil, confidence: 0.95))
        #expect(await waitUntil(timeout: .seconds(5)) { !model.isListening })
        #expect(h.controller.eventLog.contains { $0.text == "App command: pause " })

        // "Nej" right after: listening again. (Not heard while paused in real life; the undo path itself is tested.)
        model.receiveFinalTranscript("nej")
        #expect(await waitUntil(timeout: .seconds(5)) { model.isListening })
        #expect(h.controller.eventLog.contains { $0.text == "App command undone: pause" })
    }

    @Test func nejLaterIsJustWords() async {
        let (h, model) = makeModel()
        await model.startListening()
        model.answerAppCommand(AppCommand(action: "unknown", mode: nil, confidence: 0.95))
        model.receiveFinalTranscript("nej")
        try? await Task.sleep(for: .milliseconds(200))
        #expect(!h.controller.eventLog.contains { $0.text.hasPrefix("App command undone") })
    }
}
