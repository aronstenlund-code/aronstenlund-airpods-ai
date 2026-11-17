import Foundation
import Observation

/// D199 step 6a (A121): what the exam session uses of `ListeningModel`: the model's own calls, unchanged. Nothing
/// here records, routes or plays audio.
@MainActor
protocol ExamSessionHost: ListeningModeHost {
    /// Kevin's `/exam` (hints, grading, the summary). Nil: no hints or grading.
    var examClient: ExamClient? { get }
    func say(_ line: String)
    /// With a voice profile: the words just said were someone else's, not the wearer's.
    func isSomeoneElseSpeakingNow() -> Bool
    /// A38 (K31): a quiz answer today, for the streak.
    func noteQuizAnswer(at date: Date)
    /// The kinds of task without full marks go to Minne, and the recogniser learns their words.
    func rememberToPractise(_ facts: [String])
}

/// D84 (A121, D199 step 6a): the exam session inside Provläge, with the uploaded practice exam. Moved unchanged out of
/// `ListeningModel`. While it runs nothing is answered on its own: only "Lumen, …" exam commands count ("uppgift tre",
/// "ledtråd", "rätta …", "nästa", "starta provtid", "hur gick det", "avsluta"), in the wearer's own voice when there is
/// a voice profile.
///
/// It is the first part of Provläge behind `ListeningModeController`: the model asks it for the turn and for
/// "Lumen, …" while a session runs. `StudySessionController` still decides when a turn ends, and the model starts
/// Provläge before the session begins. Provläge's other parts (the practice exam by voice, the mini test, the silent
/// quiz, the study plan) are still in the model.
@MainActor
@Observable
final class ExamSessionController: ListeningModeController {
    let mode: ConversationMode = .prov
    /// Set by the model right after its own init; weak, the model owns this controller.
    @ObservationIgnored weak var host: (any ExamSessionHost)?
    /// The running session. Nil: none.
    private(set) var session: ExamSession?
    @ObservationIgnored private var timer: Task<Void, Never>?

    var isActive: Bool { session != nil }

    /// A14: Provläge has the same short words as Frågor.
    var spokenKeyterms: [String] { StandardModeController.spokenKeyterms }

    func startBlock() -> ModeStartBlock? { nil }
    func startScreen() -> ModeStartBlock? { nil }

    /// The session begins; Provläge is already running (the model starts it first).
    func begin(paper: ExamPaper) {
        guard let host else { return }
        session = ExamSession(paper: paper)
        host.modeLog("Provsession started (\(paper.tasks.count) tasks)")
        host.say(host.language == .swedish
            ? "Provsession, \(paper.tasks.count) uppgifter. Säg Lumen, uppgift ett. Eller Lumen, starta provtid nittio minuter."
            : "Exam session, \(paper.tasks.count) tasks. Say Lumen, task one.")
    }

    /// A16: the practice exam by voice takes over. The session goes without a summary, as before.
    func drop() {
        session = nil
    }

    /// A turn while the session runs. Auto is off: only "Lumen, …" counts.
    func turn(_ text: String) {
        guard let host else { return }
        host.modeLog("Provsession: not a command, not answered")
        host.study.resumeListening()
    }

    /// Nothing is answered ahead in the exam session.
    func aheadRequest(for text: String) -> (request: ActivationRequest, persona: PersonaRequest?)? { nil }

    /// "Lumen, …" in the session: only exam commands count.
    func instruction(_ text: String) {
        guard let host, var run = session else { return }
        if host.isSomeoneElseSpeakingNow() {
            host.modeLog("Provsession: a command in someone else's voice, ignored")
            return
        }
        guard let command = ExamSession.command(text) else {
            host.say("Säg uppgift, ledtråd, rätta, nästa, starta provtid eller hur gick det.")
            return
        }
        switch command {
        case .task(let no):
            if let task = run.go(to: no) { host.say(ExamSession.spoken(task)) } else { host.say("Hittar ingen uppgift \(no).") }
        case .next:
            if let task = run.next() { host.say(ExamSession.spoken(task)) } else { host.say("Det var sista uppgiften.") }
        case .hint:
            guard let task = run.currentTask, let level = run.nextHintLevel(), let examClient = host.examClient else {
                host.say("Säg först vilken uppgift, till exempel uppgift tre.")
                return
            }
            Task { [weak self] in
                let hint = await examClient.hint(task: task, level: level)
                self?.host?.say(hint ?? "Jag fick ingen ledtråd just nu.")
            }
        case .grade(let answer):
            guard let task = run.currentTask, let examClient = host.examClient else {
                host.say("Säg först vilken uppgift, till exempel uppgift tre.")
                return
            }
            Task { [weak self] in
                guard let graded = await examClient.grade(task: task, answer: answer) else {
                    self?.host?.say("Jag kunde inte rätta just nu.")
                    return
                }
                guard let self, let host = self.host, var current = self.session else { return }
                current.graded(graded.points)
                self.session = current
                host.noteQuizAnswer(at: Date()) // A38
                let got = ExamSession.number(graded.points.total)
                let of = ExamSession.number((graded.max ?? task.points).total)
                host.say("\(got) av \(of) poäng. \(graded.feedback)")
                host.modeLog("Provsession: task \(task.no) graded \(got)/\(of)")
            }
        case .startTimer(let minutes):
            run.startTimer(minutes: minutes, at: Date())
            host.say("Provtid \(minutes) minuter. Lycka till.")
            startTimer()
        case .howDidItGo:
            speakSummary(of: run)
        case .end:
            session = run
            end(speak: true)
            return
        }
        session = run
    }

    private func startTimer() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, var run = self.session, !Task.isCancelled else { return }
                if let warning = run.warning(at: Date()) { self.host?.say(warning) }
                self.session = run
                if run.minutesLeft(at: Date()) == 0 { return }
            }
        }
    }

    private func speakSummary(of run: ExamSession) {
        guard let host else { return }
        let results = run.resultList
        guard !results.isEmpty else {
            host.say("Inga uppgifter rättade än. Säg rätta och ditt svar.")
            return
        }
        guard let examClient = host.examClient else { return }
        let boundaries = run.paper.boundaries
        Task { [weak self] in
            let summary = await examClient.summary(results: results, boundaries: boundaries)
            self?.host?.say(summary?.spoken ?? "Jag kunde inte räkna ihop just nu.")
        }
    }

    /// The exam is over: the tasks without full marks go to Minne as kinds of tasks to practise.
    func end(speak: Bool) {
        timer?.cancel()
        timer = nil
        guard let run = session else { return }
        session = nil
        let weak = run.weakTaskTypes()
        host?.rememberToPractise(weak)
        host?.modeLog("Provsession ended · \(run.results.count) graded · \(weak.count) kinds of task to practise saved")
        if speak { speakSummary(of: run) }
    }
}
