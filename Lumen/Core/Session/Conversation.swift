import Foundation

/// One piece of recognised speech. Partial results are replaced in place until the recogniser finalises them.
struct TranscriptSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    var isFinal: Bool
    var startedAt: Date
    /// The words were spoken while our own answer was playing (ARCHITECTURE §4.3): never treated as a question.
    var overlapsPlayback: Bool
    /// D81: "Du", "Talare 1" … when the speaker labels are on and the voice is known.
    var speakerLabel: String? = nil
}

/// One answered question, shown in the history list.
struct AnswerTurn: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var question: String
    var answer: String
    var createdAt: Date
    /// End of user speech → first answer audio, when measured (MVP item 7).
    var latencyMs: Double?
    /// Which engine answered: "cloud" (Claude via the backend, D19), "on-device", "mock".
    var source: String
    /// False when `question` is someone else's speech (auto mode, "last sentence"): never saved word for word (D56).
    var isOwnQuestion: Bool
    /// D81: stopped by the wearer; `answer` is only what had been said. Optional, so older history still decodes.
    var interrupted: Bool?
    /// A19 (K19): the link Lumen sent with this answer (opens in Safari).
    var link: LearningLink?
    /// A53 (K37): the student's own saved answer ("Mina svar"), said word for word. Its `MyAnswer.id`.
    var savedAnswerID: String?
    /// Ke35: the mode was switched after this turn, while Lumen listened ("Bytte till Provläge" on Lyssnar).
    var switchedAfter: String?

    init(id: UUID = UUID(), question: String, answer: String, createdAt: Date = Date(), latencyMs: Double? = nil, source: String,
         isOwnQuestion: Bool = true) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
        self.latencyMs = latencyMs
        self.source = source
        self.isOwnQuestion = isOwnQuestion
    }
}

/// Live transcript + answer history. Pure value type (unit-tested); the STT and answer providers of later
/// sprint items feed it through `ListeningModel`.
struct Conversation: Equatable, Sendable {
    static let maxSegments = 200
    static let maxAnswers = 50

    private(set) var finalSegments: [TranscriptSegment] = []
    private(set) var partial: TranscriptSegment?
    private(set) var answers: [AnswerTurn] = []
    /// The answer currently being streamed (item 4); moves into `answers` when complete.
    private(set) var streamingAnswer: AnswerTurn?

    /// Final segments followed by the current partial, for display.
    var segments: [TranscriptSegment] {
        if let partial { return finalSegments + [partial] }
        return finalSegments
    }

    var isEmpty: Bool { finalSegments.isEmpty && partial == nil && answers.isEmpty && streamingAnswer == nil }

    // MARK: Answers

    /// Starts a new streaming answer (replacing any unfinished one — a new question interrupts the current answer).
    mutating func beginAnswer(question: String, source: String, at date: Date = Date(), isOwnQuestion: Bool = true) {
        streamingAnswer = AnswerTurn(question: question, answer: "", createdAt: date, source: source, isOwnQuestion: isOwnQuestion)
    }

    mutating func appendAnswerText(_ text: String) {
        streamingAnswer?.answer += text
    }

    /// Replaces the question shown for the streaming answer (the backend's reconstructed question).
    mutating func setAnswerQuestion(_ question: String) {
        streamingAnswer?.question = question
    }

    /// Moves the streaming answer into the session's answers and returns it. Empty answers are dropped.
    @discardableResult
    mutating func completeAnswer(latencyMs: Double? = nil) -> AnswerTurn? {
        guard var turn = streamingAnswer else { return nil }
        streamingAnswer = nil
        turn.answer = turn.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        turn.latencyMs = latencyMs
        guard !turn.answer.isEmpty else { return nil }
        append(turn)
        return turn
    }

    mutating func cancelAnswer() {
        streamingAnswer = nil
    }

    /// A19: the link that came with an answer.
    mutating func attach(_ link: LearningLink, to id: UUID) {
        guard let index = answers.lastIndex(where: { $0.id == id }) else { return }
        answers[index].link = link
    }

    /// Ke35: a mode switch while listening keeps the answers, with a divider after the last one.
    mutating func markModeSwitch(to title: String) {
        guard !answers.isEmpty else { return }
        answers[answers.count - 1].switchedAfter = title
    }

    /// A53: the answer was the student's own ("Ditt svar"). `text` is their exact text (the spoken form has numbers
    /// as words, K37), shown instead.
    mutating func markSaved(_ savedID: String, text: String? = nil, on id: UUID) {
        guard let index = answers.lastIndex(where: { $0.id == id }) else { return }
        answers[index].savedAnswerID = savedID
        if let text, !text.isEmpty { answers[index].answer = text }
    }

    /// D81: the wearer broke in. What had been said stays as an interrupted turn, so the next answer never repeats it.
    mutating func interruptAnswer(said: String) {
        guard var turn = streamingAnswer else { return }
        streamingAnswer = nil
        let spoken = said.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        turn.answer = spoken
        turn.interrupted = true
        answers.append(turn)
        if answers.count > Self.maxAnswers { answers.removeFirst(answers.count - Self.maxAnswers) }
    }

    /// Last `limit` answered turns as the backend's `recent_qa`, oldest first.
    func recentQA(limit: Int = 3) -> [AnswerContext.QA] {
        answers.suffix(limit).map { AnswerContext.QA(q: $0.question, a: $0.answer, interrupted: $0.interrupted) }
    }

    /// Replaces the current partial result (or creates one). Empty text clears the partial.
    mutating func updatePartial(_ text: String, at date: Date = Date(), overlapsPlayback: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            partial = nil
            return
        }
        if var current = partial {
            current.text = trimmed
            current.overlapsPlayback = current.overlapsPlayback || overlapsPlayback
            partial = current
        } else {
            partial = TranscriptSegment(id: UUID(), text: trimmed, isFinal: false, startedAt: date, overlapsPlayback: overlapsPlayback)
        }
    }

    /// Appends a final segment, keeping the partial's identity and start time so the row does not flicker.
    mutating func finalize(_ text: String, at date: Date = Date(), overlapsPlayback: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = partial?.id ?? UUID()
        let startedAt = partial?.startedAt ?? date
        let overlaps = (partial?.overlapsPlayback ?? false) || overlapsPlayback
        partial = nil
        guard !trimmed.isEmpty else { return }
        finalSegments.append(TranscriptSegment(id: id, text: trimmed, isFinal: true, startedAt: startedAt, overlapsPlayback: overlaps))
        if finalSegments.count > Self.maxSegments {
            finalSegments.removeFirst(finalSegments.count - Self.maxSegments)
        }
    }

    mutating func append(_ turn: AnswerTurn) {
        answers.append(turn)
        if answers.count > Self.maxAnswers {
            answers.removeFirst(answers.count - Self.maxAnswers)
        }
    }

    /// The session ended: the words heard go, the answers on screen stay until cleared (D48).
    /// D81: the voice of speech that ended at `date` is known: label the newest unlabelled final segment that
    /// began in the 8 s before it (the voice result can come just before or just after the final).
    mutating func label(_ label: String, near date: Date, window: TimeInterval = 8) {
        guard let index = finalSegments.lastIndex(where: {
            $0.speakerLabel == nil && $0.startedAt <= date.addingTimeInterval(1) && date.timeIntervalSince($0.startedAt) <= window
        }) else { return }
        finalSegments[index].speakerLabel = label
    }

    mutating func clearTranscript() {
        finalSegments.removeAll()
        partial = nil
    }

    mutating func clear() {
        finalSegments.removeAll()
        partial = nil
        answers.removeAll()
        streamingAnswer = nil
    }

    /// Final transcript from the last `seconds`, excluding words spoken over our own playback
    /// (the context-pack input for the question gate and answer engine, items 3–4).
    func recentText(seconds: TimeInterval, now: Date = Date()) -> String {
        finalSegments
            .filter { now.timeIntervalSince($0.startedAt) <= seconds && !$0.overlapsPlayback }
            .map(\.text)
            .joined(separator: " ")
    }
}
