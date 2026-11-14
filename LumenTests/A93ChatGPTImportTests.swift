import Foundation
import Testing
@testable import Lumen

/// A93 (D169, K58): the answer pasted from ChatGPT is read on the phone, nothing shortened.
struct A93ChatGPTImportTests {
    static let pasted = """
    Fråga: Varför behöver växter ljus?
    Svar: Växter behöver ljus för fotosyntesen, där de gör socker av koldioxid och vatten. Ljuset ger energin, t.ex. från solen. Sockret blir sedan växtens mat och byggmaterial.

    Fråga: Vad gör klorofyllet?
    Svar: Klorofyllet fångar ljuset. Det är grönt och sitter i kloroplasterna.
    """

    @Test func readsQuestionsShortAndLong() throws {
        let found = try #require(ChatGPTImport.read(Self.pasted))
        #expect(found.items.count == 2)
        #expect(found.unreadable.isEmpty)
        let first = found.items[0]
        #expect(first.question == "Varför behöver växter ljus?")
        #expect(first.short == "Växter behöver ljus för fotosyntesen, där de gör socker av koldioxid och vatten.")
        #expect(first.long.hasPrefix(first.short), "D145: the long starts with the short word for word")
        #expect(first.long.hasSuffix("byggmaterial."), "nothing is shortened")
        #expect(first.long.contains("t.ex. från solen"))
    }

    @Test func toleratesChatGPTsExtrasAndListsTheRest() throws {
        let text = """
        Här är dina frågor!

        **Fråga 1:** Vad är fotosyntes
        **Svar:** Fotosyntes är när växter gör socker med hjälp av ljus. Det sker i bladen.

        1. Fråga: Vad är 3.5 gånger 2?
        Svar: Det är 7. Man kan räkna 3.5 plus 3.5.
        Svar: ett svar till på samma fråga.

        Svar: Ett svar utan fråga.
        """
        let found = try #require(ChatGPTImport.read(text))
        #expect(found.items.map(\.question) == ["Vad är fotosyntes?", "Vad är 3.5 gånger 2?"])
        #expect(found.items[1].short == "Det är 7.")
        #expect(found.unreadable.contains { $0.hasPrefix("Rad 1: Här är dina frågor!") })
        // A96: a blank line no longer ends the answer, so the last "Svar:" is the answer's next paragraph.
        #expect(found.items[1].long.hasSuffix("Ett svar utan fråga."))
        #expect(found.unreadable.count == 1)
    }

    @Test func anAnswerWithNoQuestionBeforeItIsListed() throws {
        let found = try #require(ChatGPTImport.read("Svar: Ett svar utan fråga.\n\nFråga: Vad är DNA?\nSvar: DNA är arvsmassan."))
        #expect(found.items.count == 1)
        #expect(found.unreadable.first?.hasPrefix("Rad 1:") == true)
    }

    /// A96 (Oscar O58, Kevin K60): Oscar's 20 variants give exactly the expected questions, short and long answers,
    /// the same file Kevin's `import_text` test reads (`testdata/import/o58-cases.json`).
    @Test func oscarsTwentyVariantsAsTheServer() throws {
        struct Case: Decodable {
            struct Item: Decodable, Equatable { var question: String; var short: String; var long: String }
            var name: String
            var text: String
            var status: Int
            var items: [Item]
        }
        let url = try #require(Bundle(for: FixtureToken.self).url(forResource: "o58-cases", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        #expect(cases.count == 20)
        for c in cases {
            let found = ChatGPTImport.read(c.text)
            if c.status == 422 {
                #expect(found == nil, "\(c.name): nothing to read")
                continue
            }
            let got = (found?.items ?? []).map { Case.Item(question: $0.question, short: $0.short, long: $0.long) }
            #expect(got == c.items, "\(c.name)")
        }
        let byName = Dictionary(uniqueKeysWithValues: cases.map { ($0.name.prefix(2), $0.text) })
        let unlabelled = try #require(ChatGPTImport.read(byName["14"] ?? ""))
        #expect(unlabelled.warnings.contains { $0.hasSuffix("Frågan saknade Fråga:.") })
        let long = try #require(ChatGPTImport.read(byName["18"] ?? ""))
        #expect(long.warnings.contains { $0.contains("långt att lyssna på") })
        let twice = try #require(ChatGPTImport.read(byName["19"] ?? ""))
        #expect(twice.warnings.contains { $0.hasSuffix("Frågan finns redan.") })
        let signOff = try #require(ChatGPTImport.read(byName["02"] ?? ""))
        #expect(signOff.unreadable.contains { $0.contains("Avslutning") })
    }

    @Test func overFourThousandIsLeftOutNotCut() throws {
        let long = String(repeating: "Lava blir sten. ", count: 300)
        let found = try #require(ChatGPTImport.read("Fråga: Kort?\nSvar: Ja.\n\nFråga: Lång?\nSvar: \(long)"))
        #expect(found.items.count == 1)
        #expect(found.unreadable.contains { $0.contains("för långt") })
    }

    @Test func answerOverSeveralLines() throws {
        let found = try #require(ChatGPTImport.read("Fråga: Vad är DNA?\nSvar: DNA är arvsmassan.\nDen finns i cellkärnan.\n"))
        #expect(found.items[0].long == "DNA är arvsmassan. Den finns i cellkärnan.")
    }

    @Test func ordinaryTextIsMaterial() {
        #expect(ChatGPTImport.read("Fotosyntesen sker i kloroplasterna. Svaret är ljus.") == nil)
        #expect(ChatGPTImport.read("Fråga: Bara en fråga utan svar") == nil)
        #expect(!ChatGPTImport.looksLikeImport("Svar: inget"))
        #expect(ChatGPTImport.read("Fråga: <frågan>\nSvar: <svaret>\n\nFråga: <frågan>\nSvar: <svaret>") == nil,
                "the prompt pasted instead of the answer")
        #expect(ChatGPTImport.looksLikeImport(Self.pasted))
    }

    @Test func firstSentenceSkipsAbbreviationsAndDecimals() {
        #expect(ChatGPTImport.firstSentence("Det finns bl.a. Sverige. Och mer.") == "Det finns bl.a. Sverige.")
        #expect(ChatGPTImport.firstSentence("Svaret är 3.5 kg. Mer.") == "Svaret är 3.5 kg.")
        #expect(ChatGPTImport.firstSentence("En mening utan slut") == "En mening utan slut")
    }

    @MainActor @Test func promptIsFilledIn() {
        let prompt = ChatGPTPrompt.filled(ChatGPTPrompt.fallback, subject: "Biologi", grade: .y8, questions: 20,
                                          practised: ["Vad är DNA?"])
        #expect(prompt.contains("ett prov i Biologi för åk 8"))
        #expect(prompt.contains("Gör 20 provfrågor"))
        #expect(prompt.contains("- Vad är DNA?"))
        #expect(!prompt.contains("{{"))
        let empty = ChatGPTPrompt.filled(ChatGPTPrompt.fallback, subject: "", grade: nil, questions: 10, practised: [])
        #expect(empty.contains("(inga än)") && empty.contains("min årskurs") && !empty.contains("{{"))
        #expect(ChatGPTPrompt.template().contains("{{ANTAL}}"))
    }
}

/// Toby 1 T15b findings 6 and 7.
struct T15bFindingsTests {
    @Test func firstClearQuestionAlone() {
        #expect(QuestionSplitter.firstClearQuestion(in: "Vilka är de största? Barieneva-") == "Vilka är de största?")
        #expect(QuestionSplitter.firstClearQuestion(in: "Vilka är de största?") == nil, "nothing follows: nothing to retry")
        #expect(QuestionSplitter.firstClearQuestion(in: "Vad? Jo, alltså") == nil, "one word is not a clear question")
        #expect(QuestionSplitter.firstClearQuestion(in: "inget frågetecken här") == nil)
    }

    @Test func aSumAfterAndIsAQuestion() {
        let gate = QuestionGate(sensitivity: .medium)
        #expect(gate.evaluate("Och 23 gånger 4.").fires)
        #expect(gate.evaluate("Och sedan 12 plus 5").fires)
        #expect(!gate.evaluate("Jag har tränat 3 gånger i veckan.").fires, "a statement with a number stays quiet")
        #expect(!gate.evaluate("Och sen gick vi hem.").fires)
    }
}

/// A96: finds the test bundle, where `o58-cases.json` is copied (project.yml).
private final class FixtureToken {}

/// A96: Kevin's `closed` state – a heading or fence after the last answer ends it but the sign-off is still left out.
struct A96ImportEdgeTests {
    @Test func signOffBeforeAFenceIsLeftOut() throws {
        let text = "Fråga: Vad är lava?\nSvar: Lava är smält berg på ytan.\n\nLycka till! Vill du ha fler?\n```"
        let found = try #require(ChatGPTImport.read(text))
        #expect(found.items.first?.long == "Lava är smält berg på ytan.")
        #expect(found.unreadable.contains { $0.contains("Avslutning") })
    }

    @Test func listItemsInsideTheAnswerLoseTheirBullet() throws {
        let found = try #require(ChatGPTImport.read("Fråga: Vad finns i en cell?\nSvar: En cell har flera delar.\n- Cellkärnan styr cellen.\n- Mitokondrierna ger energi."))
        #expect(found.items.first?.long == "En cell har flera delar. Cellkärnan styr cellen. Mitokondrierna ger energi.")
    }
}
