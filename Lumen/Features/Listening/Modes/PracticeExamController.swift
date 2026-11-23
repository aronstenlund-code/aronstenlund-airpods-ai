import Foundation
import Observation

/// D199 step 6b (A125): what the practice exam by voice uses of `ListeningModel`: the model's own calls, unchanged.
/// Nothing here records, routes or plays audio.
@MainActor
protocol PracticeExamHost: ListeningModeHost {
    /// Kevin's `/exam` (grading). Nil: nothing is graded.
    var examClient: ExamClient? { get }
    func say(_ line: String)
    /// A38 (K31): a quiz answer today, for the streak.
    func noteQuizAnswer(at date: Date)
    /// A16, A19: right or wrong for the concept, for `concept_stats` and the study plan's history.
    func recordConcept(_ topic: String, right: Bool)
    /// What went wrong in the run goes to Minne.
    func rememberPractice(_ fact: String)
}

/// A16, K15 (A125, D199 step 6b): the practice exam by voice inside Provläge ("Kör övningsprovet", "Förhör mig på
/// provet"). Moved unchanged out of `ListeningModel`: the uploaded practice exam is read one question at a time, the
/// student answers aloud, Kevin's `/exam` grades, and the result stays on the listening screen.
///
/// It is the second part of Provläge behind `ListeningModeController`, after `ExamSessionController`. While a run
/// goes, the model asks it for the turn (before the filler filter: "ja" can be an answer) and for "Lumen, …".
/// `StudySessionController` still decides when a turn ends, and the model starts Provläge before the run begins.
@MainActor
@Observable
final class PracticeExamController: ListeningModeController {
    let mode: ConversationMode = .prov
    /// Set by the model right after its own init; weak, the model owns this controller.
    @ObservationIgnored weak var host: (any PracticeExamHost)?
    /// The running practice exam. Nil: none.
    private(set) var run: PracticeRun?
    /// The last run's result for the listening screen (right, wrong, what to practise).
    private(set) var result: PracticeRun.Summary?

    var isActive: Bool { run != nil }

    /// A14: Provläge has the same short words as Frågor.
    var spokenKeyterms: [String] { StandardModeController.spokenKeyterms }

    func startBlock() -> ModeStartBlock? { nil }
    func startScreen() -> ModeStartBlock? { nil }

    /// The run begins; Provläge is already running (the model starts it first).
    func begin(_ new: PracticeRun) {
        guard let host else { return }
        result = nil
        run = new
        host.modeLog("Practice exam started (\(new.count) questions)")
        host.say("Provfrågor, \(new.count) frågor. Svara högt. Säg nästa, förra, fråga sju, hoppa över eller upprepa. "
            + new.spokenQuestion)
    }

    /// What the student said during the run: Kevin's navigation (ported, `PracticeNav`), else an answer to grade.
    func turn(_ text: String) {
        guard let host, var current = run else { return }
        host.study.resumeListening() // the turn is handled here; Lumen's next words are spoken with `say`
        if current.isGrading {
            host.modeLog("Practice exam: still grading, not heard as an answer")
            return
        }
        let nav = PracticeNav.decide(text, current: current.index, nos: current.nos)
        host.modeLog("Practice exam: \(nav)")
        switch nav {
        case .next(let index):
            guard index != current.index else {
                host.say("Det var sista frågan. Säg resultatet, eller avsluta.")
                return
            }
            current.move(to: index)
            run = current
            host.say(current.spokenQuestion)
        case .go(let index), .previous(let index), .repeatQuestion(let index):
            current.move(to: index)
            run = current
            host.say(current.spokenQuestion)
        case .skip(let index):
            current.skip()
            run = current
            guard index != current.index else {
                finish(speak: true)
                return
            }
            current.move(to: index)
            run = current
            host.say(current.spokenQuestion)
        case .stop:
            finish(speak: true)
        case .results:
            host.say(current.spokenSummary)
        case .answer:
            grade(text, in: current)
        }
    }

    /// Nothing is answered ahead in the practice exam.
    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? { nil }

    /// A16: "Lumen, nästa" works as well as "nästa".
    func instruction(_ text: String) {
        turn(text)
    }

    private func grade(_ answer: String, in answered: PracticeRun) {
        guard let host else { return }
        guard let examClient = host.examClient else {
            host.say("Jag kan inte rätta just nu.")
            return
        }
        var grading = answered
        grading.isGrading = true
        run = grading
        let task = grading.task
        host.modeLog("Practice exam: question \(task.no) answered, grading")
        let language = host.language // A160: the phone grades in the language that is spoken
        Task { [weak self] in
            let graded = await examClient.grade(task: task, answer: answer, practice: true, language: language)
            guard let self, let host = self.host, var current = self.run, current.task.no == task.no else { return }
            current.isGrading = false
            guard let graded else {
                self.run = current
                host.say("Jag kunde inte rätta just nu. Säg svaret igen, eller nästa.")
                return
            }
            if graded.isKeyOnly {
                // A160 (D258): the model is down and the phone cannot grade. The answer key is shown and said with
                // one line about why; the question is not counted as answered.
                current.skip()
                current.lastFeedback = graded.feedback
                current.lastFeedbackNo = task.no
                host.modeLog("Practice exam: question \(task.no): the answer key without a grade (the model is down)")
                if let next = current.nextOpenIndex {
                    current.move(to: next)
                    self.run = current
                    host.say(graded.feedback + " " + current.spokenQuestion)
                } else {
                    self.run = current
                    host.say(graded.feedback)
                    self.finish(speak: true)
                }
                return
            }
            let max = (graded.max ?? task.points).total
            current.graded(points: graded.points.total, max: max)
            host.noteQuizAnswer(at: Date()) // A38
            let right = current.outcomes[task.no]?.isRight ?? false
            if let topic = task.topic, !topic.isEmpty { host.recordConcept(topic, right: right) }
            current.lastFeedback = graded.feedback
            current.lastFeedbackNo = task.no
            var spoken = graded.feedback
            if task.isOwnAnswer, !right { spoken += " Provet hade inget facit, så det rätta svaret är EarMinds eget." }
            host.modeLog("Practice exam: question \(task.no) graded \(graded.points.total)/\(max)")
            if let next = current.nextOpenIndex {
                current.move(to: next)
                self.run = current
                host.say(spoken + " " + current.spokenQuestion)
            } else {
                self.run = current
                host.say(spoken)
                self.finish(speak: true)
            }
        }
    }

    /// The run is over: the result is said and stays on the listening screen; what went wrong goes to Minne.
    func finish(speak: Bool) {
        guard let ended = run else { return }
        run = nil
        result = ended.summary
        let practise = ended.summary.practise
        if !practise.isEmpty {
            host?.rememberPractice("Provfrågor: öva på " + PracticeRun.list(Array(practise.prefix(5))))
        }
        host?.modeLog("Practice exam ended · \(ended.outcomes.count) graded · \(practise.count) to practise")
        if speak { host?.say(ended.spokenSummary) }
    }

    func dismissResult() {
        result = nil
    }

    #if DEBUG
    /// A30 (Kelly Ke20): the practice exam on Lyssnar for screenshots, without a microphone or network.
    func stage(_ staged: PracticeRun?, result shown: PracticeRun.Summary?) {
        run = staged
        result = shown
    }
    #endif
}
