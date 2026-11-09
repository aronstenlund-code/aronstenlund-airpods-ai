import Foundation

/// A8.3: one row per turn that could have been answered: what was sent, what the backend said, and what the user got.
/// Aron's Diagnostics export then shows why a question went unanswered without a second test. Kept in memory for the
/// session only (the same place as the event log); nothing is stored or sent.
struct TurnRecord: Equatable, Sendable, Identifiable {
    enum Outcome: String, Equatable, Sendable {
        /// Sent, no verdict yet.
        case pending
        /// The answer was shown and handed to the voice.
        case answered
        /// The backend said it was no question (`not_question`) or withdrew the answer (`retract`).
        case silent
        /// Answered ahead and thrown away before the pause was over (the reason says why).
        case discarded
        /// Never sent: the app dropped it (the reason says why).
        case dropped
        /// The call failed.
        case failed
        /// A newer turn cut it off before it finished.
        case interrupted
    }

    let id: UUID
    var at: Date
    var mode: String
    var trigger: String
    var fragment: String
    /// The end of `context.transcript` as it was sent (at most `transcriptTail` characters).
    var transcriptTail: String
    var ahead: Bool
    var isQuestion: Bool?
    /// `ok`, `not_question`, `retract` or the failure.
    var status: String?
    var outcome: Outcome
    var reason: String?

    static let transcriptTail = 160
}

struct TurnLedger: Equatable, Sendable {
    static let limit = 60
    private(set) var records: [TurnRecord] = []

    @discardableResult
    mutating func begin(fragment: String, mode: String, trigger: String, transcript: String = "", ahead: Bool = false,
                        at: Date = Date()) -> UUID {
        let id = UUID()
        records.append(TurnRecord(id: id, at: at, mode: mode, trigger: trigger, fragment: fragment,
                                  transcriptTail: String(transcript.suffix(TurnRecord.transcriptTail)), ahead: ahead,
                                  isQuestion: nil, status: nil, outcome: .pending, reason: nil))
        if records.count > Self.limit { records.removeFirst(records.count - Self.limit) }
        return id
    }

    /// A turn the app never sent.
    mutating func dropped(_ fragment: String, mode: String, trigger: String, reason: String, at: Date = Date()) {
        let id = begin(fragment: fragment, mode: mode, trigger: trigger, at: at)
        finish(id, outcome: .dropped, reason: reason)
    }

    mutating func setStatus(_ id: UUID?, status: String, isQuestion: Bool?) {
        guard let index = index(id) else { return }
        records[index].status = status
        if let isQuestion { records[index].isQuestion = isQuestion }
    }

    /// Sets the outcome once; later calls for the same turn change nothing.
    mutating func finish(_ id: UUID?, outcome: TurnRecord.Outcome, reason: String? = nil) {
        guard let index = index(id), records[index].outcome == .pending else { return }
        records[index].outcome = outcome
        records[index].reason = reason
    }

    func record(_ id: UUID?) -> TurnRecord? {
        index(id).map { records[$0] }
    }

    private func index(_ id: UUID?) -> Int? {
        guard let id else { return nil }
        return records.lastIndex { $0.id == id }
    }

    /// Asked / answered for the report's before–after numbers.
    var summary: String {
        let sent = records.filter { $0.outcome != .dropped }
        let answered = records.filter { $0.outcome == .answered }.count
        return "\(records.count) turns · \(sent.count) sent · \(answered) answered · "
            + "\(records.filter { $0.outcome == .silent }.count) silent · \(records.filter { $0.outcome == .discarded }.count) discarded · "
            + "\(records.filter { $0.outcome == .dropped }.count) dropped · \(records.filter { $0.outcome == .failed }.count) failed"
    }

    var markdown: String {
        guard !records.isEmpty else { return "_no turns_" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        func cell(_ text: String) -> String {
            text.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
        }
        var out = ["- " + summary, "",
                   "| Time | Mode | Trigger | Ahead | Fragment | is_question | Status | Outcome | Why | Transcript (end) |",
                   "|---|---|---|---|---|---|---|---|---|---|"]
        for r in records {
            let question = r.isQuestion.map { $0 ? "true" : "false" } ?? "–"
            out.append("| \(f.string(from: r.at)) | \(r.mode) | \(r.trigger) | \(r.ahead ? "yes" : "no") | \(cell(r.fragment)) | "
                + "\(question) | \(cell(r.status ?? "–")) | \(r.outcome.rawValue) | \(cell(r.reason ?? "")) | \(cell(r.transcriptTail)) |")
        }
        return out.joined(separator: "\n")
    }
}
