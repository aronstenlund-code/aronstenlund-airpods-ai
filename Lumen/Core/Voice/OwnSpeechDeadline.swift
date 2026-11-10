import Foundation

/// A21.3 (Toby T5 finding 3): the recogniser is closed while Lumen speaks (D82) and opens again when the voice reports
/// its end. If that report never comes (seen with Apple's voice in the simulator after a 7-sentence answer: 106 s
/// deaf), the recogniser opens anyway when the speech should have been over: its estimated length + `margin`.
///
/// Every sentence Lumen starts adds its estimated length. Sentences that are queued faster than they are played add
/// up; a sentence that starts after a gap starts from now.
struct OwnSpeechDeadline: Equatable, Sendable {
    /// Extra time after the estimated end before the recogniser is opened anyway.
    static let margin: TimeInterval = 2
    /// Swedish and English TTS at rate 1.0 speak roughly 13–16 characters a second; the slower end, so a long
    /// answer is not cut off by its own safety timer.
    static let charactersPerSecond = 13.0

    private(set) var deadline: Date?
    /// When the estimated speech started, for the log line.
    private(set) var startedAt: Date?

    static func seconds(for text: String, rate: Double) -> TimeInterval {
        Double(text.count) / (charactersPerSecond * min(2, max(0.5, rate)))
    }

    mutating func spoke(_ text: String, rate: Double, at now: Date) {
        let previousEnd = deadline.map { $0.addingTimeInterval(-Self.margin) }
        let start = max(previousEnd ?? now, now)
        if startedAt == nil { startedAt = now }
        deadline = start.addingTimeInterval(Self.seconds(for: text, rate: rate) + Self.margin)
    }

    /// The voice reported its end (or was interrupted): nothing to watch.
    mutating func reset() {
        deadline = nil
        startedAt = nil
    }

    func isOverdue(at now: Date) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }
}
