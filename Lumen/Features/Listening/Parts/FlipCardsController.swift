import Foundation

/// D221 (A138, G7 step 7d): what the flip cards use of `ListeningModel`: the model's own calls, unchanged.
@MainActor
protocol FlipCardsHost: AnyObject {
    var studyCards: StudyCardStore? { get }
    /// A38 (K31): a quiz answer today, for the streak.
    func noteQuizAnswer(at date: Date)
    /// Right or wrong for the concept: the tutor's concept stats (A16) and the study plan's history for the exam (A19).
    func recordFlippedConcept(_ concept: String, right: Bool, exam: UUID)
    func modeLog(_ line: String)
}

/// A46 (N6; A138, G7 step 7d): flip cards, on the screen without the voice. Moved unchanged out of `ListeningModel`:
/// the exam's study cards as a deck, and one card answered counts like a quiz answer.
@MainActor
final class FlipCardsController {
    weak var host: (any FlipCardsHost)?

    /// The exam's study cards as flip cards, nil when there is none.
    func deck(for plan: ExamPlan) -> FlipDeck? {
        guard let cards = host?.studyCards?.current() else { return nil }
        return FlipDeck(from: cards, subject: plan.subject)
    }

    /// One flip card answered: it counts like a quiz answer (the card, the tutor's concept stats, the study plan).
    func record(_ card: StudyCard, knew: Bool, for plan: ExamPlan) {
        guard let host else { return }
        host.studyCards?.mark(card.id, right: knew)
        host.noteQuizAnswer(at: Date()) // A38
        host.recordFlippedConcept(FlipDeck.concept(for: card, topics: plan.topics), right: knew, exam: plan.id)
        host.modeLog("Flip card: \(knew ? "knew" : "missed") (A46)")
    }
}
