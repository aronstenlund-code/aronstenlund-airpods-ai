import Foundation

/// D80: an answer made while the speaker is still pausing. Everything the answer engine sends is kept here, not
/// shown or spoken, until the pause is over and the words did not go on; then it is played back through the normal
/// path at once. If the speaker goes on, it is thrown away and a new one starts with the whole text.
struct AheadAnswer {
    enum Event {
        case started(ActivationRequest, source: String)
        case reconstructed(String)
        case delta(String)
        case sentence(String)
        case completed(latencyMs: Double?, done: AnswerDone?)
        case skipped(ActivationRequest)
        case report

        /// T17 finding 5: text the user would hear or see.
        var carriesWords: Bool {
            switch self {
            case .delta(let text), .sentence(let text): !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default: false
            }
        }
    }

    let key: String
    let request: ActivationRequest
    let persona: PersonaRequest?
    /// When the sentence was heard (the call starts at once).
    let heardAt: Date
    private(set) var events: [Event] = []
    private(set) var firstTokenAt: Date?
    private(set) var doneAt: Date?
    var delivered = false
    /// TTS for the first sentence was fetched ahead.
    var prefetched = false

    init(request: ActivationRequest, persona: PersonaRequest?, heardAt: Date) {
        self.key = Self.key(request.query)
        self.request = request
        self.persona = persona
        self.heardAt = heardAt
    }

    var firstSentence: String? {
        for event in events { if case .sentence(let text) = event { return text } }
        return nil
    }

    var isFinished: Bool {
        events.contains { event in
            switch event {
            case .completed, .skipped, .report: true
            default: false
            }
        }
    }

    mutating func record(_ event: Event, at date: Date) {
        if case .delta = event, firstTokenAt == nil { firstTokenAt = date }
        if case .completed = event { doneAt = date }
        events.append(event)
    }

    /// Two texts are "the same turn" when their words are: case, punctuation and spacing do not matter.
    static func key(_ text: String) -> String {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }
}

/// The per-turn latency log (D80): sentence heard → call → first token → answer done → pause over → first sound.
struct TurnTimeline {
    var heardAt: Date?
    var requestAt: Date
    var firstTokenAt: Date?
    var doneAt: Date?
    var pauseEndAt: Date
    var answeredAhead: Bool

    func line(firstSoundAt: Date) -> String {
        func ms(_ from: Date?, _ to: Date?) -> String {
            guard let from, let to else { return "–" }
            return "\(Int((to.timeIntervalSince(from) * 1000).rounded())) ms"
        }
        return "Turn timing · \(answeredAhead ? "answered ahead" : "answered at the pause")"
            + " · heard→call \(ms(heardAt, requestAt))"
            + " · call→first token \(ms(requestAt, firstTokenAt))"
            + " · call→done \(ms(requestAt, doneAt))"
            + " · heard→pause over \(ms(heardAt, pauseEndAt))"
            + " · pause over→first sound \(ms(pauseEndAt, firstSoundAt))"
    }
}

/// How many calls were made ahead, used and thrown away (D80), for the log and the report.
struct AheadStats: Equatable {
    var started = 0
    var delivered = 0
    var discarded = 0
    var prefetched = 0
    var prefetchWasted = 0
    var since = Date()

    func summary(now: Date = Date()) -> String {
        let minutes = max(1.0 / 60, now.timeIntervalSince(since) / 60)
        return String(format: "ahead %d · used %d · discarded %d (%.1f/min) · TTS ahead %d, wasted %d",
                      started, delivered, discarded, Double(discarded) / minutes, prefetched, prefetchWasted)
    }
}
