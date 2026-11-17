import Foundation
import Observation

/// D199 step 6c (A126): what the mini test uses of `ListeningModel`: the model's own calls, unchanged.
@MainActor
protocol MiniTestHost: ListeningModeHost {
    func say(_ line: String)
    /// A38 (K31): a quiz answer today, for the streak.
    func noteQuizAnswer(at date: Date)
    /// D83: the tutor's persona (the profile, the exam, the last turns), for the grading call.
    func tutorPersona() -> PersonaRequest?
    /// Right or wrong on the card itself.
    func markStudyCard(_ id: UUID, right: Bool)
    /// A43 (K33): the mini test's answers count in the study plan too, like the flip cards.
    func recordInStudyPlan(_ card: StudyCard, right: Bool)
}

/// D81 (A126, D199 step 6c): the mini test inside Provläge, five questions by voice on the last session's study cards.
/// Moved unchanged out of `ListeningModel`: Lumen asks a card's question, the student answers aloud, the tutor grades
/// through the ordinary answer pipeline, and the next card follows. The model still picks the cards and starts
/// Provläge before the test begins.
@MainActor
@Observable
final class MiniTestController {
    @ObservationIgnored weak var host: (any MiniTestHost)?
    /// The running mini test. Nil: none.
    private(set) var test: MiniTest?
    /// The card whose answer the tutor is judging.
    @ObservationIgnored private var gradingCardID: UUID?

    var isActive: Bool { test != nil }

    func begin(cards: [StudyCard]) {
        test = MiniTest(cards: cards)
        gradingCardID = nil
        host?.modeLog("Mini test started (\(cards.count) cards)")
        askQuestion()
    }

    /// Another exercise takes over (the exam session, the practice exam): the test goes without a summary, as before.
    func drop() {
        test = nil
    }

    /// Provläge ended. True: a mini test was running and is gone now.
    func endWithSession() -> Bool {
        guard test != nil else { return false }
        test = nil
        gradingCardID = nil
        return true
    }

    private func askQuestion() {
        guard let host, let current = test else { return }
        if let question = current.question(swedish: host.language == .swedish) {
            host.say(question)
            return
        }
        host.say(current.summary(swedish: host.language == .swedish))
        host.modeLog("Mini test done: \(current.rightCount) of \(current.cards.count)")
        test = nil
    }

    /// The student's answer to the card's question: skipped, or sent to the tutor to grade.
    func turn(_ text: String) {
        guard let host, var current = test, let card = current.current else { return }
        if MiniTest.isSkip(text) {
            current.skip()
            host.markStudyCard(card.id, right: false)
            test = current
            host.study.resumeListening()
            askQuestion()
            return
        }
        guard let query = current.gradingQuery(for: text, swedish: host.language == .swedish) else { return }
        gradingCardID = card.id
        host.activated(ActivationRequest(query: query, trigger: .tutor, language: host.language), persona: host.tutorPersona())
    }

    /// An answer from the tutor arrived. True: it was the verdict on the card being graded, so it is no study card
    /// of its own; the next question follows.
    func graded(by answer: String) -> Bool {
        guard let host, let id = gradingCardID, var current = test else { return false }
        gradingCardID = nil
        current.graded(answer)
        let right = current.results[id] ?? false
        host.markStudyCard(id, right: right)
        host.noteQuizAnswer(at: Date()) // A38
        if let card = current.cards.first(where: { $0.id == id }) { host.recordInStudyPlan(card, right: right) } // A43
        test = current
        askQuestion()
        return true
    }
}

/// D199 step 6c (A126): what Provläge's controller uses of `ListeningModel`, beside what its parts use.
@MainActor
protocol ProvModeHost: ExamSessionHost, PracticeExamHost, MiniTestHost {
    /// Provläge's ordinary turn: a question to the tutor, split when several were asked in one breath (A8.4). Still
    /// the model's, with the tutor's persona, the last turns and the queue it shares with Frågor.
    func ordinaryProvTurn(_ text: String)
    /// What follows the name when it is not a command (D74).
    func instruct(_ text: String)
}

/// D36 (A126, D199 step 6c): Provläge behind `ListeningModeController`. It holds Provläge's parts that have left
/// `ListeningModel` (the exam session, the practice exam by voice, the mini test) and the order a turn is offered to
/// them in, which is the order the model had:
/// 1. the practice exam, before the filler filter ("ja" can be an answer, A16);
/// 2. the mini test;
/// 3. the exam session (nothing is answered, only "Lumen, …" counts);
/// 4. the ordinary turn to the tutor.
///
/// The ordinary turn, the tutor's persona, the silent quiz and the study plan are still in the model.
/// `StudySessionController` decides when a turn ends, as before.
@MainActor
final class ProvModeController: ListeningModeController {
    let mode: ConversationMode = .prov
    /// Set by the model right after its own init; weak, the model owns this controller.
    weak var host: (any ProvModeHost)? {
        didSet {
            exam.host = host
            practice.host = host
            miniTest.host = host
        }
    }
    /// D84: the exam session with the uploaded practice exam (step 6a).
    let exam = ExamSessionController()
    /// A16: the practice exam by voice (step 6b).
    let practice = PracticeExamController()
    /// D81: the mini test (step 6c).
    let miniTest = MiniTestController()

    /// A14: Provläge has the same short words as Frågor.
    var spokenKeyterms: [String] { StandardModeController.spokenKeyterms }

    func startBlock() -> ModeStartBlock? { nil }
    func startScreen() -> ModeStartBlock? { nil }

    /// Before the filler filter. True: the practice exam took the turn.
    func takesUnfiltered(_ text: String) -> Bool {
        guard practice.isActive else { return false }
        practice.turn(text)
        return true
    }

    /// A finished turn that is not a command or filler.
    func turn(_ text: String) {
        if miniTest.isActive {
            miniTest.turn(text)
            return
        }
        if exam.isActive {
            exam.turn(text)
            return
        }
        host?.ordinaryProvTurn(text)
    }

    /// D80: in Provläge a turn is answered ahead only while it listens and no exercise runs.
    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? {
        guard let host, host.study.isActive, host.study.phase == .listening,
              !exam.isActive, !practice.isActive, !miniTest.isActive else { return nil }
        return (ActivationRequest(query: text, trigger: .tutor, language: host.language), host.tutorPersona())
    }

    /// "Lumen, …" for a running exercise: the practice exam in Provläge ("Lumen, nästa"), then the exam session.
    /// True: it was taken.
    func takesInstruction(_ text: String, inProv: Bool) -> Bool {
        if practice.isActive, inProv {
            practice.instruction(text)
            return true
        }
        if exam.isActive {
            exam.instruction(text)
            return true
        }
        return false
    }

    /// "Lumen, …" in Provläge: the model's own path, which asks the exercises first.
    func instruction(_ text: String) {
        host?.instruct(text)
    }
}
