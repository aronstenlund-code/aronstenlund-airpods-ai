import Foundation

/// A4: streamed speech starts only when a little audio is queued, and when the player runs dry mid-sentence it
/// buffers again instead of playing every gap in the network as a hack. Pure: the caller says how much the player
/// still has queued.
struct JitterBuffer: Equatable, Sendable {
    /// Audio to collect before playing (and before playing again after running dry).
    let startSamples: Int
    private(set) var pending: [Int16] = []
    private(set) var playing = false
    /// Times the player ran dry mid-stream (after the start).
    private(set) var underruns = 0

    init(startSamples: Int) {
        self.startSamples = max(1, startSamples)
    }

    /// Adds `samples`; `queuedSamples` is what the player still has to play. Returns what to schedule now (may be
    /// empty: still collecting).
    mutating func push(_ samples: [Int16], queuedSamples: Int) -> [Int16] {
        pending += samples
        if playing, queuedSamples <= 0 {
            playing = false // ran dry: collect again rather than play a stutter
            underruns += 1
        }
        if !playing, pending.count >= startSamples { playing = true }
        guard playing else { return [] }
        defer { pending = [] }
        return pending
    }

    /// The stream ended: whatever is left plays (a short sentence never waits for a full start buffer).
    mutating func finish() -> [Int16] {
        defer { pending = [] }
        return pending
    }
}

/// A4: how smooth one answer's voice was. Logged per answer and shown in Diagnostik.
struct VoiceStreamStats: Equatable, Sendable {
    var sentences = 0
    var underruns = 0
    /// Silence heard because the player ran dry, ms.
    var silenceMs: Double = 0
    /// Time from the first audio arriving to it starting to play (the start buffer's cost), summed, ms.
    var startWaitMs: Double = 0
    /// Sentences whose voice was fetched while the one before played (no gap between them).
    var prefetched = 0

    mutating func add(_ other: VoiceStreamStats) {
        sentences += other.sentences
        underruns += other.underruns
        silenceMs += other.silenceMs
        startWaitMs += other.startWaitMs
        prefetched += other.prefetched
    }

    /// "3 meningar, 1 avbrott, 240 ms tystnad, start 180 ms, 2 förhämtade"
    var summary: String {
        String(format: "%d meningar, %d avbrott, %.0f ms tystnad, startbuffert %.0f ms, %d förhämtade",
               sentences, underruns, silenceMs, startWaitMs, prefetched)
    }
}
