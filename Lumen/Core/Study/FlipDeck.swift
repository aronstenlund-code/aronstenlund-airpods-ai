import Foundation

/// A46 (N6): the study cards as flip cards on the screen, without the voice. The question shows; a tap turns the card;
/// the wearer says whether they knew it ("Kunde" / "Kunde inte"). Each answer counts like a quiz answer: the card's own
/// right/wrong, the concept stats the tutor gets, and the study plan's history (A19).
struct FlipDeck: Equatable, Sendable {
    static let maxCards = 20

    private(set) var cards: [StudyCard]
    private(set) var index = 0
    private(set) var isFlipped = false
    private(set) var knew: [UUID: Bool] = [:]

    init(cards: [StudyCard]) {
        self.cards = Array(cards.prefix(Self.maxCards))
    }

    /// The exam's cards (a card without a subject belongs to every exam), the most often missed first, then the
    /// oldest. Nil when there is none.
    init?(from cards: [StudyCard], subject: String) {
        let mine = cards.filter { card in
            guard let own = card.subject, !own.isEmpty else { return true }
            return own.caseInsensitiveCompare(subject) == .orderedSame
        }
        guard !mine.isEmpty else { return nil }
        self.init(cards: mine.sorted { ($0.wrong - $0.right, $1.createdAt) > ($1.wrong - $1.right, $0.createdAt) })
    }

    var current: StudyCard? { index < cards.count ? cards[index] : nil }
    var isFinished: Bool { index >= cards.count }
    var knewCount: Int { knew.values.filter { $0 }.count }
    var missed: [StudyCard] { cards.filter { knew[$0.id] == false } }

    /// "3 av 12": the card being shown.
    var position: String { "\(min(index + 1, cards.count)) av \(cards.count)" }

    /// Turns the card both ways (the answer can be hidden again).
    mutating func flip() {
        guard !isFinished else { return }
        isFlipped.toggle()
    }

    /// Only once the answer has been seen. Returns the card that was marked, for the stores.
    @discardableResult
    mutating func mark(knew didKnow: Bool) -> StudyCard? {
        guard isFlipped, let card = current else { return nil }
        knew[card.id] = didKnow
        index += 1
        isFlipped = false
        return card
    }

    /// "Öva på de 4 igen": a new round with the cards that were missed.
    func againWithMissed() -> FlipDeck? {
        let missed = missed
        return missed.isEmpty ? nil : FlipDeck(cards: missed)
    }

    var summary: String { "Du kunde \(knewCount) av \(cards.count)." }

    /// The concept a card counts for: the exam's topic it mentions ("fotosyntes" in "Vad behöver fotosyntesen?"),
    /// else the question itself, shortened. Cards have no concept of their own yet.
    static func concept(for card: StudyCard, topics: String) -> String {
        let text = (card.question + " " + card.answer).lowercased()
        let topic = StudyPlanAPI.topics(topics).first { topic in
            let key = topic.lowercased()
            return !key.isEmpty && (text.contains(key) || (key.count > 5 && text.contains(key.prefix(key.count - 1))))
        }
        return topic ?? String(card.question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    }
}
