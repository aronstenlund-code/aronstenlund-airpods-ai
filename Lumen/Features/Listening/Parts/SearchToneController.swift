import Foundation

/// D233 (A151): what the search tone uses of `ListeningModel`.
@MainActor
protocol SearchToneHost: AnyObject {
    /// The answer in flight will be spoken into headphones right now, and the mode is not Provläge.
    var searchToneAllowed: Bool { get }
    /// One quiet tone from the playback graph (local, no call).
    func playSearchTone()
    func modeLog(_ line: String)
}

/// D233 (A151): the quiet tone while an answer searches the web. The server says `searching` when the model starts a
/// web search (K104). If the first word has not come 1.5 s later, one short quiet tone tells the listener that the
/// answer is on its way. Never spoken filler (D46), at most once per answer, never in Provläge, and not at all when
/// the first word comes first.
@MainActor
final class SearchToneController {
    /// D233: how long the first word may take after `searching` before the tone.
    static let wait: Duration = .milliseconds(1_500)
    /// The tone itself: C5, a fifth of a second, a third of the other tones' level, with soft ends. Kelly chooses
    /// its character later, as for the listening cues (A34).
    static let tone = (frequency: 523.0, duration: 0.2, level: 0.1)

    weak var host: (any SearchToneHost)?
    /// The wait. Tests open a gate instead of using the clock.
    var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    /// The tone was played for the answer in flight.
    private(set) var played = false
    /// The wait that is running, nil when there is none.
    private(set) var pending: Task<Void, Never>?
    private var heardOfSearch = false
    private var firstWordCame = false

    /// A new answer: nothing of the last one is left.
    func answerBegan() {
        cancel()
        played = false
        heardOfSearch = false
        firstWordCame = false
    }

    /// The answer began to search at `since` (earlier than now when the answer was made ahead of the pause, D80).
    func searching(since: Date, now: Date = Date()) {
        guard !heardOfSearch, !played, !firstWordCame else { return } // at most once per answer
        heardOfSearch = true
        let left = Self.left(since: since, now: now)
        pending = Task { [weak self] in
            if left > .zero { _ = try? await self?.sleep(left) }
            guard !Task.isCancelled else { return }
            self?.fire()
        }
    }

    /// The first word of the answer came: no tone any more.
    func firstWord() {
        firstWordCame = true
        cancel()
    }

    /// The answer ended or was thrown away.
    func answerEnded() { cancel() }

    /// Only where the answer is about to be spoken into headphones: listening (not paused) with an answer in flight,
    /// never in Provläge (D233), not for the live modes' suggestions or the interview preparation (they are not
    /// spoken as answers), and not out of the iPhone's own speaker (the microphone would hear it, as for the cues, A34).
    static func allowed(listening: Bool, mode: ConversationMode, instructing: Bool, answering: Bool,
                        trigger: ActivationTrigger?, builtInSpeaker: Bool) -> Bool {
        guard listening, answering, !instructing, !builtInSpeaker else { return false }
        guard mode != .prov, mode.liveStyle == nil else { return false }
        return trigger != .rizz && trigger != .interviewPrep
    }

    /// What is left of the wait.
    static func left(since: Date, now: Date) -> Duration {
        let waited = Duration.seconds(max(0, now.timeIntervalSince(since)))
        return max(Duration.zero, wait - waited)
    }

    private func cancel() {
        pending?.cancel()
        pending = nil
    }

    private func fire() {
        pending = nil
        guard let host, !played, !firstWordCame else { return }
        guard host.searchToneAllowed else {
            host.modeLog("Search tone: not played (not allowed now) (A151)")
            return
        }
        played = true
        host.playSearchTone()
        host.modeLog("Search tone played (A151)")
    }
}
