import Foundation
import Observation

/// A98 (D173, Aron's phone test 12:29): "Spela in" in Mina svar in two steps. The recording used to start as soon as
/// the sheet opened, so a typed question ended up in the recording and Klar said "EarMind kunde inte höra något svar".
/// Now:
/// 1. **Fråga:** chosen from the exam (`choices`), typed into `question`, or spoken (`recordQuestion` /
///    `finishQuestion`, written out on the phone like the answer, the audio deleted).
/// 2. **Spela in svaret** (`recordAnswer`) starts the microphone, only when there is a question; Stoppa (`stopAnswer`)
///    keeps the audio for Klar; Spela in igen (`recordAgain`) deletes it.
/// 3. **Klar** (`canFinish`) only with a recorded answer, then the phone writes it out and `/my-answers compress`
///    makes one answer of it (D126: no audio leaves the phone).
/// The view is Angela Fable's; this is the flow.
@MainActor
@Observable
final class MyAnswerRecording {
    var question = ""
    /// "Välj ur provet": the questions of the exams in Starta prov for this subject that have no own answer yet.
    let choices: [String]
    let questionRecorder = AnswerRecorder()
    let answerRecorder = AnswerRecorder()
    private(set) var isCompressing = false
    /// What went wrong after Klar ("EarMind kunde inte göra ett svar just nu. Försök igen.").
    private(set) var problem: String?

    /// Shortest answer that counts as an answer (a tap on Spela in svaret and Stoppa at once is not one).
    nonisolated static let shortestAnswer: TimeInterval = 1

    init(choices: [String] = []) {
        self.choices = choices
    }

    var hasQuestion: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The question is being spoken or written out: the answer waits.
    var isWorkingOnQuestion: Bool {
        questionRecorder.state == .recording || questionRecorder.state == .recorded
            || questionRecorder.state == .transcribing
    }

    /// Spela in svaret: only with a question, never while the question is being recorded or the answer already is.
    var canRecordAnswer: Bool {
        hasQuestion && !isWorkingOnQuestion && !isCompressing && !Self.isAnswerStarted(answerRecorder.state)
    }

    var isRecordingAnswer: Bool { answerRecorder.state == .recording }

    /// The question can be changed until the answer is recorded.
    var canEditQuestion: Bool { !Self.isAnswerStarted(answerRecorder.state) && !isCompressing }

    /// Klar: only when an answer has been recorded.
    var canFinish: Bool {
        !isCompressing && Self.hasAnswer(state: answerRecorder.state, elapsed: answerRecorder.elapsed)
    }

    nonisolated static func hasAnswer(state: AnswerRecorder.State, elapsed: TimeInterval) -> Bool {
        (state == .recording || state == .recorded) && elapsed >= shortestAnswer
    }

    nonisolated static func isAnswerStarted(_ state: AnswerRecorder.State) -> Bool {
        state == .recording || state == .recorded || state == .transcribing
    }

    // MARK: The question

    func choose(_ choice: String) {
        guard canEditQuestion else { return }
        question = choice
    }

    /// "Spela in frågan": the microphone for the question (the answer is not recording).
    func recordQuestion() async {
        guard canEditQuestion, !isWorkingOnQuestion else { return }
        await questionRecorder.start()
    }

    /// Stoppa on the question: written out on the phone into `question` (the audio is deleted).
    func finishQuestion() async {
        guard let text = await questionRecorder.finish() else { return }
        question = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: The answer

    func recordAnswer() async {
        guard canRecordAnswer else { return }
        problem = nil
        await answerRecorder.start()
    }

    func stopAnswer() {
        answerRecorder.stop()
    }

    /// Spela in igen: the recorded answer is deleted; Spela in svaret starts a new one.
    func recordAgain() {
        answerRecorder.cancel()
        problem = nil
    }

    /// Klar: written out on the phone, then made one answer by `compress` (`/my-answers compress`). Nil when it
    /// failed; `problem` or the recorder's state says why.
    func finish(compress: (_ transcript: String, _ question: String) async -> MyAnswersClient.Suggestion?) async
        -> MyAnswerDraft? {
        guard canFinish else { return nil }
        let seconds = answerRecorder.elapsed
        guard let transcript = await answerRecorder.finish() else { return nil }
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        isCompressing = true
        let reply = await compress(transcript, asked)
        isCompressing = false
        guard let reply, !reply.answer.isEmpty else {
            problem = reply == nil ? "EarMind kunde inte göra ett svar just nu. Försök igen."
                                   : "EarMind hörde inget svar i inspelningen."
            return nil
        }
        return MyAnswerDraft(question: reply.q.isEmpty ? asked : reply.q, answer: reply.answer,
                             transcript: transcript, seconds: seconds)
    }

    /// Avbryt: both recordings are deleted, nothing is sent.
    func cancel() {
        questionRecorder.cancel()
        answerRecorder.cancel()
    }

    // MARK: Choices

    /// The exams' questions for `subject` (all exams when nil or none match), without the ones that already have an
    /// own answer, each once, in the exams' order.
    nonisolated static func choices(drills: [Drill], subject: String?, answered: [String]) -> [String] {
        let wanted = subject?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let matching = drills.filter { !wanted.isEmpty && $0.summary.subject.lowercased() == wanted }
        let source = matching.isEmpty ? drills : matching
        var seen = Set(answered.map(key))
        var result: [String] = []
        for item in source.flatMap(\.items) where seen.insert(key(item.question)).inserted {
            result.append(item.question)
        }
        return Array(result.prefix(100))
    }

    nonisolated private static func key(_ question: String) -> String {
        question.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

extension ListeningModel {
    /// A98: a new two-step recording for the exam in Mina svar.
    func myAnswerRecording(examID: UUID?) -> MyAnswerRecording {
        let subject = examPlans?.plans.first { $0.id == examID }?.subject
        let answered = (myAnswers?.answers ?? []).filter { $0.examID == examID }.map(\.question)
        return MyAnswerRecording(choices: MyAnswerRecording.choices(drills: repetition?.drills ?? [], subject: subject,
                                                                   answered: answered))
    }

    /// A98: `/my-answers compress` for Klar, with the exam's subject.
    func compressMyAnswer(transcript: String, question: String, examID: UUID?) async -> MyAnswersClient.Suggestion? {
        let subject = examPlans?.plans.first { $0.id == examID }?.subject
        return await myAnswersClient?.compress(transcript: transcript, question: question, subject: subject)
    }
}
