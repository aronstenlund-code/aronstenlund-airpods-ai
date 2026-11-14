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
        #expect(found.unreadable.contains("Rad 1: Här är dina frågor!"))
        #expect(found.unreadable.contains { $0.hasPrefix("Rad 10:") }, "an answer with no question before it")
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
