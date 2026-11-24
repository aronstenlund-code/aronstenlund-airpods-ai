import Foundation
import Testing
@testable import Lumen

/// A162 (D259): the user's own activation words. Heard in a turn, they make the app answer the question that was
/// just asked; they are never sent as a question themselves; an empty field is off.
/// A pretend transcript and a pretend answer provider: no model call, no sound, 0 ElevenLabs characters (D180).
@MainActor
@Suite struct A162ActivationPhraseTests {
    // MARK: Finding the words in what was heard

    @Test func oneWordIsHeardWhateverTheCaseAndThePunctuation() {
        #expect(ActivationPhrase.match("banan", in: "Vad är fotosyntes? Banan.") == ActivationPhrase.Match(before: "Vad är fotosyntes?", after: ""))
        #expect(ActivationPhrase.match("Banan", in: "vad är fotosyntes, BANAN!") == ActivationPhrase.Match(before: "vad är fotosyntes", after: ""))
        #expect(ActivationPhrase.match("banan", in: "banan") == ActivationPhrase.Match(before: "", after: ""))
    }

    @Test func severalWordsAreHeardInOrderNextToEachOther() {
        #expect(ActivationPhrase.match("låt mig tänka", in: "Vad är en cell? Låt mig, tänka...") == ActivationPhrase.Match(before: "Vad är en cell?", after: ""))
        #expect(ActivationPhrase.match("let me think", in: "Let me think. What is a cell?") == ActivationPhrase.Match(before: "", after: "What is a cell?"))
        #expect(ActivationPhrase.match("låt mig tänka", in: "låt mig inte tänka") == nil)
        #expect(ActivationPhrase.match("låt mig tänka", in: "tänka mig låt") == nil)
    }

    @Test func onlyWholeWordsCount() {
        #expect(ActivationPhrase.match("banan", in: "jag gillar bananer") == nil)
        #expect(ActivationPhrase.match("ja", in: "jag vet inte") == nil)
        #expect(ActivationPhrase.match("cell", in: "en cellkärna") == nil)
    }

    @Test func anEmptyFieldIsOff() {
        #expect(ActivationPhrase.match("", in: "vad är fotosyntes") == nil)
        #expect(ActivationPhrase.match("   ", in: "vad är fotosyntes") == nil)
        #expect(ActivationPhrase.match("?!", in: "vad är fotosyntes?!") == nil)
    }

    @Test func theLastPlaceCountsBecauseTheWordsComeAfterTheQuestion() {
        #expect(ActivationPhrase.match("banan", in: "är en banan en frukt? banan") == ActivationPhrase.Match(before: "är en banan en frukt?", after: ""))
    }

    @Test func whatIsTypedIsKeptTidy() {
        #expect(ActivationPhrase.cleaned("  låt   mig\ntänka  ") == "låt mig tänka")
        #expect(ActivationPhrase.cleaned("") == "")
        #expect(ActivationPhrase.cleaned(String(repeating: "ord ", count: 30)).count <= ActivationPhrase.limit)
    }

    // MARK: Which question is answered

    @Test func theQuestionJustAskedIsTheOneAnswered() {
        let sameTurn = ActivationPhrase.Match(before: "Vad är fotosyntes?", after: "")
        #expect(ActivationPhrase.question(for: sameTurn, earlier: ["Något annat sades förut."]) == "Vad är fotosyntes?")
        // The words alone: someone else asked, in the turn before.
        let alone = ActivationPhrase.Match(before: "", after: "")
        #expect(ActivationPhrase.question(for: alone, earlier: ["Hej allihopa.", "Vad är en cell egentligen?"]) == "Vad är en cell egentligen?")
        // The words first, then the question.
        let wordsFirst = ActivationPhrase.Match(before: "", after: "What is a cell?")
        #expect(ActivationPhrase.question(for: wordsFirst, earlier: ["An older question here?"]) == "What is a cell?")
        // Nothing to answer.
        #expect(ActivationPhrase.question(for: alone, earlier: []) == nil)
        #expect(ActivationPhrase.question(for: ActivationPhrase.Match(before: "eh", after: ""), earlier: ["ok"]) == nil)
    }

    // MARK: The setting

    @Test func theWordsAreKeptBetweenStarts() throws {
        let suite = "lumen.tests.a162.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ActivationSettings(defaults: defaults)
        #expect(first.phrase == "", "off until the user writes something")
        first.setPhrase("  Låt mig   tänka ")
        #expect(first.phrase == "Låt mig tänka")
        #expect(ActivationSettings(defaults: defaults).phrase == "Låt mig tänka")
        first.setPhrase("")
        #expect(ActivationSettings(defaults: defaults).phrase == "")
    }
}
