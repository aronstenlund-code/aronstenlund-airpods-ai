import Foundation
import Testing
@testable import Lumen

/// A46 (N6): flip cards from the study cards, counted like quiz answers.
@MainActor
@Suite struct FlipCardsTests {
    private static func card(_ question: String, _ answer: String = "Ett svar som är långt nog att spara.", subject: String? = "Biologi",
                             right: Int = 0, wrong: Int = 0, age: Double = 0) -> StudyCard {
        var card = StudyCard(question: question, answer: answer, subject: subject, examDate: nil,
                             createdAt: Date(timeIntervalSince1970: 1_762_000_000 + age))
        card.right = right
        card.wrong = wrong
        return card
    }

    @Test func theExamsCardsTheMostMissedFirstThenTheOldest() throws {
        let cards = [Self.card("Nyast utan fel", age: 300),
                     Self.card("Ofta fel", wrong: 3, age: 200),
                     Self.card("Äldst utan fel", age: 100),
                     Self.card("Engelska ordet", subject: "Engelska", wrong: 5),
                     Self.card("Utan ämne", subject: nil, age: 400)]
        let deck = try #require(FlipDeck(from: cards, subject: "biologi"))
        #expect(deck.cards.map(\.question) == ["Ofta fel", "Äldst utan fel", "Nyast utan fel", "Utan ämne"])
        #expect(FlipDeck(from: [Self.card("Engelska ordet", subject: "Engelska")], subject: "Biologi") == nil)
        #expect(FlipDeck(cards: (0..<30).map { Self.card("Fråga \($0)") }).cards.count == FlipDeck.maxCards)
    }

    @Test func aCardIsMarkedOnlyAfterItsAnswerWasSeen() {
        var deck = FlipDeck(cards: [Self.card("Första"), Self.card("Andra")])
        let early = deck.mark(knew: true)
        #expect(early == nil, "the answer has not been seen")
        #expect(deck.position == "1 av 2")
        deck.flip()
        let first = deck.mark(knew: true)
        #expect(first?.question == "Första")
        #expect(!deck.isFlipped && deck.position == "2 av 2")
        deck.flip()
        deck.flip()
        #expect(!deck.isFlipped, "turned back to the question")
        deck.flip()
        deck.mark(knew: false)
        #expect(deck.isFinished && deck.current == nil)
        #expect(deck.summary == "Du kunde 1 av 2.")
        #expect(deck.missed.map(\.question) == ["Andra"])
        deck.flip()
        #expect(!deck.isFlipped, "nothing to turn at the end")
    }

    @Test func anotherRoundWithTheMissedOnes() throws {
        var deck = FlipDeck(cards: [Self.card("A"), Self.card("B"), Self.card("C")])
        for knew in [false, true, false] {
            deck.flip()
            deck.mark(knew: knew)
        }
        let again = try #require(deck.againWithMissed())
        #expect(again.cards.map(\.question) == ["A", "C"])
        #expect(again.index == 0 && again.knew.isEmpty)
        var all = FlipDeck(cards: [Self.card("A")])
        all.flip()
        all.mark(knew: true)
        #expect(all.againWithMissed() == nil)
    }

    @Test func theConceptIsTheExamsTopicElseTheQuestion() {
        let topics = "fotosyntes, cellandning och klorofyll"
        #expect(FlipDeck.concept(for: Self.card("Vad behöver fotosyntesen?"), topics: topics) == "fotosyntes")
        #expect(FlipDeck.concept(for: Self.card("Var sker den?", "Cellandningen sker i mitokondrierna."), topics: topics) == "cellandning")
        #expect(FlipDeck.concept(for: Self.card("  Vad är osmos?  "), topics: topics) == "Vad är osmos?")
        #expect(FlipDeck.concept(for: Self.card(String(repeating: "lång ", count: 30)), topics: "").count == 60)
    }
}
