import Foundation
import OSLog

/// Logger / signpost categories (Phase 1 §3.7). Extended in later phases for the end-to-end latency budget.
enum Log {
    static let subsystem = "com.rsolutions.lumen"

    static let session = Logger(subsystem: subsystem, category: "audio.session")
    static let capture = Logger(subsystem: subsystem, category: "audio.capture")
    static let playback = Logger(subsystem: subsystem, category: "audio.playback")
    static let diagnostics = Logger(subsystem: subsystem, category: "diagnostics")
    static let transcription = Logger(subsystem: subsystem, category: "transcription")
    static let answer = Logger(subsystem: subsystem, category: "answer")
    static let repetition = Logger(subsystem: subsystem, category: "repetition") // A78 (D142)

    /// Signposts for latency measurements ("play.requested" -> "play.firstAudio", later STT/LLM/TTS stages).
    static let signposter = OSSignposter(subsystem: subsystem, category: "audio.latency")
}
