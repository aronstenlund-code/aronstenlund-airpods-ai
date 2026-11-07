import Foundation
import Testing
@testable import Lumen

/// D80: answer ahead and deliver at the pause, the pause per mode, memory, keyterms, voice feedback.
@Suite struct AheadPureTests {
    @Test func theSameWordsAreTheSameTurn() {
        #expect(AheadAnswer.key("Vad är roten ur hundra?") == AheadAnswer.key("vad är  roten ur hundra"))
        #expect(AheadAnswer.key("vad är pi") != AheadAnswer.key("vad är pi och e"))
    }

    @Test func memoryCommandsByVoice() {
        #expect(VoiceChannel.parse("Lumen, kom ihåg att jag har biologiprov fredag 14 nov").intent
                == .remember("jag har biologiprov fredag 14 nov"))
        #expect(VoiceChannel.parse("Lumen, glöm biologiprovet").intent == .forget("biologiprovet"))
        #expect(VoiceChannel.parse("Lumen, regel: svara alltid kort").intent == .rule("svara alltid kort"))
        #expect(VoiceChannel.parse("Lumen, byt till provläge").intent == .switchTo(.prov), "commands still work")
    }

    @Test func complaintsOnlyAsAWholeUtterance() {
        #expect(VoiceCommand.isComplaint("Det där var inte riktigt rätt."))
        #expect(VoiceCommand.isComplaint("det var fel"))
        #expect(VoiceCommand.isComplaint("Dåligt svar!"))
        #expect(VoiceCommand.isComplaint("Det stämmer inte"))
        #expect(!VoiceCommand.isComplaint("jag tror att det var fel tåg vi tog"))
        #expect(!VoiceCommand.isComplaint("det stämmer inte riktigt med vad läraren sa i måndags"))
    }

    @Test func sensitiveThingsAreNeverSavedByThemselves() {
        #expect(SensitiveFilter.isSensitive("Har ADHD-diagnos"))
        #expect(SensitiveFilter.isSensitive("Röstar på Moderaterna"))
        #expect(!SensitiveFilter.isSensitive("Biologiprov fredag 14 nov"))
        #expect(!SensitiveFilter.isSensitive("Går i trean på gymnasiet"))
    }

    @Test func theExtractionCarriesTodayAndKeepsOnlyWhatIsAllowed() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!
        let body = MemoryExtraction.body(question: "Jag har biologiprov på fredag", answer: "Lycka till!", mode: "prov",
                                         memories: [], language: "sv", now: friday,
                                         timeZone: TimeZone(identifier: "Europe/Stockholm")!)
        #expect(body.today == "2026-11-07")
        #expect(body.weekday == "lördag")
        #expect(body.timezone == "Europe/Stockholm")

        let reply = Data(#"{"add":["Biologiprov fredag 14 nov","Har diabetes","biologiprov fredag 14 nov"]}"#.utf8)
        #expect(MemoryExtraction.decode(reply) == ["Biologiprov fredag 14 nov"])
        let objects = Data(#"{"add":[{"text":"Spelar fotboll"}]}"#.utf8)
        #expect(MemoryExtraction.decode(objects) == ["Spelar fotboll"])
        #expect(MemoryExtraction.decode(Data("nope".utf8)).isEmpty)
    }

    @Test func keytermsComeFromTheTopicFirst() {
        let terms = KeytermBuilder.terms(commands: ["fusion"], topic: "Vad är fotosyntes?",
                                         answers: ["Fotosyntes sker i kloroplasterna."], goals: ["cellandning", "mitokondrier"],
                                         memory: ["Biologiprov fredag 14 nov"], prep: ["Pythagoras"])
        #expect(terms.first == "fusion")
        #expect(terms.contains("fotosyntes"))
        #expect(terms.contains("kloroplasterna"))
        #expect(terms.contains("Biologiprov"))
        #expect(terms.count <= KeytermBuilder.limit)
        #expect(terms.filter { $0.lowercased() == "fotosyntes" }.count == 1, "no duplicates")
    }
}

@MainActor
@Suite struct MemoryAndPauseSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "lumen.tests.d80.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func pausePerModeWithTheOwnersDefaults() {
        let defaults = freshDefaults()
        let settings = ModeSettings(defaults: defaults)
        #expect(settings.pause(for: .standard) == 1.0)
        #expect(settings.pause(for: .prov) == 1.2)
        #expect(settings.pause(for: .interview) == 1.5)
        #expect(settings.pause(for: .social) == 0.8)
        #expect(settings.pause(for: .rizz) == 0.8)
        settings.setPause(2.0, for: .prov)
        settings.setPause(9, for: .standard)
        let reopened = ModeSettings(defaults: defaults)
        #expect(reopened.pause(for: .prov) == 2.0)
        #expect(reopened.pause(for: .standard) == ModeSettings.pauseRange.upperBound)
    }

    @Test func rulesFactsAndForgetting() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "lumen-d80-\(UUID().uuidString)")
        let store = MemoryStore(directory: directory)
        store.add("svara alltid kort", kind: .rule, source: .voice)
        store.add("Biologiprov fredag 14 nov", source: .automatic)
        #expect(store.add("Har astma och tar medicin", source: .automatic) == nil, "sensitive: not by itself")
        #expect(store.add("Har astma och tar medicin", source: .manual) != nil, "the user may add it")
        #expect(store.rules.map(\.text) == ["svara alltid kort"])
        #expect(store.backendItems().contains("Regel: svara alltid kort"))
        #expect(store.forget("biologiprov") == 1)
        #expect(!store.facts.contains { $0.text.contains("Biologiprov") })
    }

    @Test func memoriesSavedBeforeD80StillLoad() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "lumen-d80-old-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let old = #"[{"id":"0F0E0D0C-0B0A-0908-0706-050403020100","text":"Går i trean","createdAt":800000000,"confirmedAt":\#(Date().timeIntervalSinceReferenceDate)}]"#
        try Data(old.utf8).write(to: directory.appending(path: MemoryStore.fileName))
        let store = MemoryStore(directory: directory)
        #expect(store.facts.map(\.text) == ["Går i trean"])
        #expect(store.facts.first?.source == .manual)
    }
}

@MainActor
@Suite struct AnswerAheadFlowTests {
    private struct Rig {
        let h: ControllerHarness
        let provider: FakeAnswerProvider
        let model: ListeningModel
        let apple: FakeTTSProvider
        let memory: MemoryStore
    }

    private func makeRig() -> Rig {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tio. "), .done(AnswerDone(answered: true))])
        let apple = FakeTTSProvider(name: "apple")
        let memory = makeTestMemory()
        let suite = "lumen.tests.d80flow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let study = StudySessionController(settings: StudySettings(defaults: defaults), session: h.controller)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller),
                                   activation: makeTestActivation(), answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback, apple: apple),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: makeTestPrep(), study: study, memory: memory,
                                   modeSettings: ModeSettings(defaults: defaults))
        return Rig(h: h, provider: provider, model: model, apple: apple, memory: memory)
    }

    private func spoken(_ rig: Rig) -> [String] { rig.apple.calls.map(\.text) }

    @Test func theAnswerIsMadeAheadAndOnlySpokenWhenThePauseIsOver() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveSentenceHeard("vad är roten ur hundra", at: Date())

        #expect(await waitUntil { rig.provider.requests.count == 1 }, "the call starts before the pause")
        try? await Task.sleep(for: .milliseconds(80))
        #expect(spoken(rig).isEmpty, "nothing is spoken while the speaker may go on")
        #expect(rig.model.conversation.answers.isEmpty)

        rig.model.receiveFinalTranscript("vad är roten ur hundra", at: Date()) // the pause is over

        #expect(await waitUntil { spoken(rig) == ["Tio."] })
        #expect(rig.provider.requests.count == 1, "no second call: the answer was ready")
        #expect(await waitUntil { rig.model.conversation.answers.count == 1 })
        #expect(rig.model.aheadStats.delivered == 1)
    }

    @Test func wordsBeforeThePauseReplaceTheCall() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveSentenceHeard("vad är roten ur", at: Date())
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        rig.model.receiveSentenceHeard("vad är roten ur hundra delat med fem", at: Date())
        #expect(await waitUntil { rig.provider.requests.count == 2 })
        #expect(rig.provider.requests[1].fragment == "vad är roten ur hundra delat med fem")
        #expect(rig.model.aheadStats.discarded == 1)

        rig.model.receiveFinalTranscript("vad är roten ur hundra delat med fem", at: Date())

        #expect(await waitUntil { spoken(rig) == ["Tio."] })
        #expect(rig.provider.requests.count == 2)
    }

    @Test func anAnswerToSomethingThatWentOnIsNeverSpoken() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveSentenceHeard("vad är pi", at: Date())
        #expect(await waitUntil { rig.provider.requests.count == 1 })
        try? await Task.sleep(for: .milliseconds(50))

        rig.model.receiveFinalTranscript("vad är pi och hur räknar man ut det", at: Date())

        #expect(await waitUntil { rig.provider.requests.count == 2 }, "asked again with the whole text")
        #expect(rig.provider.requests[1].fragment == "vad är pi och hur räknar man ut det")
        #expect(await waitUntil { spoken(rig).count == 1 })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(spoken(rig).count == 1, "the first answer is never read")
    }

    @Test func memoryByVoice() async {
        let rig = makeRig()
        await rig.model.startListening()

        rig.model.receiveFinalTranscript("Lumen, kom ihåg att jag har biologiprov fredag 14 nov", at: Date())
        #expect(await waitUntil { rig.memory.facts.contains { $0.text == "jag har biologiprov fredag 14 nov" } })
        #expect(await waitUntil { spoken(rig).contains("Sparat.") })

        rig.model.receiveFinalTranscript("Lumen, regel: svara alltid kort", at: Date().addingTimeInterval(1))
        #expect(await waitUntil { rig.memory.rules.map(\.text) == ["svara alltid kort"] })

        rig.model.receiveFinalTranscript("Lumen, glöm biologiprov", at: Date().addingTimeInterval(2))
        #expect(await waitUntil { rig.memory.facts.isEmpty })
        #expect(rig.provider.requests.isEmpty, "never sent as a question")
    }

    @Test func aComplaintRightAfterAnAnswerIsFeedbackNotAQuestion() async {
        let rig = makeRig()
        await rig.model.startListening()
        rig.model.receiveFinalTranscript("vad är roten ur hundra", at: Date())
        #expect(await waitUntil { rig.model.conversation.answers.count == 1 })

        rig.model.receiveFinalTranscript("Det där var inte riktigt rätt", at: Date())

        #expect(await waitUntil { rig.h.controller.eventLog.contains { $0.text.hasPrefix("Voice feedback") } })
        #expect(rig.provider.requests.count == 1, "not asked as a new question")
    }

    @Test func theModesPauseEndsTheTurn() async {
        let rig = makeRig()
        await rig.model.startHandsFree(.prov)
        #expect(rig.model.study.machine.tuning.endpointSilence == 1.2)
        rig.model.endStudy(bySilence: false)
        rig.model.setPause(1.8, for: .prov)
        await rig.model.startHandsFree(.prov)
        #expect(rig.model.study.machine.tuning.endpointSilence == 1.8)
    }
}
