import Foundation

/// One piece of recognised speech. Partial results are replaced in place until the recogniser finalises them.
struct TranscriptSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    var isFinal: Bool
    var startedAt: Date
    /// The words were spoken while our own answer was playing (ARCHITECTURE §4.3): never treated as a question.
    var overlapsPlayback: Bool
}

/// One answered question, shown in the history list.
struct AnswerTurn: Identifiable, Equatable, Sendable {
    let id: UUID
    var question: String
    var answer: String
    var createdAt: Date
    /// End of user speech → first answer audio, when measured (MVP item 7).
    var latencyMs: Double?
    /// Which engine answered: "cloud" (Claude via the backend, D19), "on-device", "mock".
    var source: String

    init(id: UUID = UUID(), question: String, answer: String, createdAt: Date = Date(), latencyMs: Double? = nil, source: String) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
        self.latencyMs = latencyMs
        self.source = source
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

    /// Final segments followed by the current partial, for display.
    var segments: [TranscriptSegment] {
        if let partial { return finalSegments + [partial] }
        return finalSegments
    }

    var isEmpty: Bool { finalSegments.isEmpty && partial == nil && answers.isEmpty }

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

    mutating func clear() {
        finalSegments.removeAll()
        partial = nil
        answers.removeAll()
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
