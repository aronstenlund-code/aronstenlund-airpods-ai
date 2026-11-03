import Foundation
import Testing
@testable import Lumen

@MainActor
func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "lumen-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
func makeTestNotes() -> NotesStore { NotesStore(directory: temporaryDirectory()) }

@MainActor
func makeTestPrep() -> PrepStore { PrepStore(directory: temporaryDirectory()) }

@MainActor
@Suite struct NotesStoreTests {
    private let t0 = Date(timeIntervalSince1970: 1_762_300_000)

    private var conversation: Conversation {
        var c = Conversation()
        c.finalize("Idag pratar vi om fotosyntes.", at: t0)
        c.finalize("echo of our answer", at: t0.addingTimeInterval(5), overlapsPlayback: true)
        c.finalize("Vad är fotosyntes?", at: t0.addingTimeInterval(10))
        c.append(AnswerTurn(question: "Vad är fotosyntes?", answer: "Växternas sätt att göra energi av ljus.", createdAt: t0.addingTimeInterval(12), latencyMs: 900, source: "cloud"))
        return c
    }

    @Test func savesLoadsAndDeletes() {
        let directory = temporaryDirectory()
        let store = NotesStore(directory: directory)
        #expect(store.notes.isEmpty)
        #expect(store.save(Conversation(), language: .swedish) == nil, "nothing to save")

        let note = store.save(conversation, language: .swedish, at: t0.addingTimeInterval(20))
        #expect(note != nil)
        #expect(store.notes.count == 1)
        #expect(note?.title == "Vad är fotosyntes?")
        #expect(note?.transcript.map(\.text) == ["Idag pratar vi om fotosyntes.", "Vad är fotosyntes?"], "playback echo is left out")
        #expect(note?.answers.count == 1)
        #expect(note?.language == "sv-SE")

        let reloaded = NotesStore(directory: directory)
        #expect(reloaded.notes == store.notes)
        #expect(reloaded.lastError == nil)

        reloaded.delete(note!)
        #expect(reloaded.notes.isEmpty)
        #expect(NotesStore(directory: directory).notes.isEmpty)
    }

    @Test func markdownHasAnswersThenTranscript() {
        let note = Note(createdAt: t0, language: "sv-SE",
                        transcript: [Note.Line(time: t0, text: "rad ett")],
                        answers: [AnswerTurn(question: "Q?", answer: "A.", createdAt: t0, source: "cloud")])
        let markdown = note.markdown
        #expect(markdown.hasPrefix("# Lumen — "))
        #expect(markdown.contains("## Questions and answers\n\n**Q?**\n\nA.\n"))
        #expect(markdown.contains("## Transcript\n\n- "))
        #expect(markdown.contains(" rad ett"))
        let titleOnlyTranscript = Note(createdAt: t0, language: "sv-SE", transcript: [Note.Line(time: t0, text: String(repeating: "x", count: 80))], answers: [])
        #expect(titleOnlyTranscript.title.count == 58)
        #expect(Note(createdAt: t0, language: "sv-SE", transcript: [], answers: []).title == t0.formatted(date: .abbreviated, time: .shortened))
    }
}

@Suite struct KeyTermExtractorTests {
    private let paragraph = """
    Fotosyntes är processen där växter omvandlar ljusenergi till kemisk energi. Fotosyntesen sker i kloroplasterna, \
    som innehåller klorofyll. Gustav Vasa blev kung 1523 och Gustav Vasa är känd från historien. Växter behöver \
    ljus, vatten och koldioxid. Klorofyll ger bladen deras gröna färg.
    """

    @Test func dropsStopwordsAndShortOrNumericTokens() {
        let terms = KeyTermExtractor().extract(from: paragraph).map { $0.lowercased() }
        for stop in ["är", "där", "till", "som", "och", "i", "från", "deras"] {
            #expect(!terms.contains(stop), "stopword leaked: \(stop)")
        }
        #expect(!terms.contains("1523"))
        #expect(terms.contains("fotosyntes"))
        #expect(terms.contains("klorofyll"))
        #expect(terms.contains("växter"))
    }

    @Test func capitalisedNamesScoreHigherAndKeepTheirCase() {
        let terms = KeyTermExtractor().extract(from: paragraph)
        #expect(terms.first == "Gustav Vasa", "two-word name repeated twice: 2 × 3 = 6 — got \(terms.prefix(5))")
        #expect(terms.contains("Gustav"))
        #expect(terms.contains("Vasa"))
        #expect(terms.contains("fotosyntes"), "sentence-initial capital is not a name")
        #expect(!terms.contains("Fotosyntes"))
    }

    @Test func frequencyOrdersCommonTermsFirstAndLimitApplies() {
        let text = "cell cell cell membran membran kärna"
        #expect(KeyTermExtractor().extract(from: text) == ["cell", "membran", "kärna"])
        #expect(KeyTermExtractor().extract(from: text, limit: 2) == ["cell", "membran"])
        #expect(KeyTermExtractor().extract(from: "och att det").isEmpty)
    }

    @Test func keepsInnerHyphensAndSplitsOnPunctuation() {
        let words = KeyTermExtractor.words("Vad är pH-värde, egentligen? (Se kap. 3)")
        #expect(words == ["Vad", "är", "pH-värde", "egentligen", "Se", "kap", "3"])
        #expect(KeyTermExtractor().extract(from: "pH-värde pH-värde").first == "ph-värde")
    }

    @Test func englishStopwordsAreRemovedToo() {
        let terms = KeyTermExtractor().extract(from: "The mitochondria is the powerhouse of the cell. Marie Curie discovered radium.")
        #expect(terms.first == "Marie Curie")
        #expect(terms.contains("mitochondria"))
        #expect(!terms.contains("the"))
        #expect(!terms.contains("of"))
    }
}

@MainActor
@Suite struct PrepStoreTests {
    @Test func addsPersistsTogglesAndUnionsTerms() {
        let directory = temporaryDirectory()
        let store = PrepStore(directory: directory)
        var changes = 0
        store.onChange = { changes += 1 }

        #expect(store.add(title: "", text: "och att det") == nil, "no terms → nothing added")
        let biology = store.add(title: "", text: "Fotosyntes sker i kloroplaster.\nKlorofyll ger grön färg.")
        #expect(biology?.title == "Fotosyntes sker i kloroplaster.", "default title = first line")
        let history = store.add(title: "Historia", text: "Gustav Vasa blev kung 1523. Gustav Vasa grundade Vasaätten.")
        #expect(history?.title == "Historia")
        #expect(changes == 2)
        #expect(store.materials.map(\.title) == ["Historia", "Fotosyntes sker i kloroplaster."], "newest first")
        #expect(PrepStore.defaultTitle(for: String(repeating: "a", count: 60)).count == 38)

        let terms = store.sttTerms
        #expect(terms.first == "Gustav Vasa", "newest material's terms come first")
        #expect(terms.contains("fotosyntes"))
        #expect(Set(terms.map { $0.lowercased() }).count == terms.count, "no duplicates")
        #expect(store.backendTerms.count <= PrepStore.backendTermLimit)

        store.setEnabled(history!, false)
        #expect(!store.sttTerms.contains("Gustav Vasa"))
        #expect(store.sttTerms.contains("fotosyntes"))
        #expect(changes == 3)

        let reloaded = PrepStore(directory: directory)
        #expect(reloaded.materials.map(\.id) == store.materials.map(\.id))
        #expect(reloaded.materials.map(\.isEnabled) == [false, true], "toggle state survives reload")
        #expect(reloaded.materials.first?.terms == store.materials.first?.terms)
        reloaded.delete(biology!)
        #expect(reloaded.materials.count == 1)
        #expect(PrepStore(directory: directory).materials.count == 1)
    }

    @Test func termLimitsAreRespected() {
        let store = PrepStore(directory: temporaryDirectory())
        let text = (0..<150).map { "term\($0)" }.joined(separator: " ")
        store.add(title: "big", text: text)
        #expect(store.sttTerms.count == PrepStore.sttTermLimit)
        #expect(store.backendTerms.count == PrepStore.backendTermLimit)
    }
}

@MainActor
@Suite struct ListeningNotesAndPrepTests {
    @Test func saveNoteAndPrepTermsReachRecognitionAndAnswers() async {
        let h = ControllerHarness()
        let provider = FakeAnswerProvider(name: "cloud", events: [.delta("Tio."), .done(AnswerDone(answered: true))])
        let prep = makeTestPrep()
        let coordinator = makeTestCoordinator(h.controller)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true),
                                   transcription: coordinator, activation: makeTestActivation(),
                                   answers: makeTestAnswerEngine(provider), speaker: makeTestSpeaker(h.playback),
                                   voices: makeTestVoiceCatalog(), notes: makeTestNotes(), prep: prep)

        prep.add(title: "Matte", text: "Kvadratrot kvadratrot Pythagoras sats")
        #expect(coordinator.contextualStrings.contains("kvadratrot"))
        #expect(coordinator.contextualStrings.contains("Pythagoras"))

        #expect(!model.canSaveNote)
        #expect(model.saveNote() == nil)
        model.submitText("roten ur hundra")
        #expect(await waitUntil { model.conversation.answers.count == 1 })
        #expect(provider.requests.first?.context.prepTerms.contains("kvadratrot") == true)

        #expect(model.canSaveNote)
        let note = model.saveNote()
        #expect(note?.answers.first?.answer == "Tio.")
        #expect(model.noteSavedAt == note?.createdAt)
        #expect(model.notes.notes.count == 1)
        model.clearHistory()
        #expect(model.noteSavedAt == nil)
        #expect(model.notes.notes.count == 1, "clearing the screen keeps saved notes")
    }
}
