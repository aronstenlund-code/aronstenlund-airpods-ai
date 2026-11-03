import Foundation

/// Typed errors for the audio core (Phase 1 §4). Every case carries text that can be shown in the UI;
/// nothing is swallowed with `try?`.
enum AudioError: Error, Equatable, Sendable, LocalizedError {
    case permissionDenied
    case sessionConfiguration(config: String, detail: String)
    case sessionActivation(detail: String)
    case noInputRoute
    case converterUnavailable(from: String, to: String)
    case conversionFailed(detail: String)
    case engineStart(detail: String)
    case alreadyCapturing
    case notCapturing
    case playbackFormatUnavailable
    case ttsFailed(detail: String)
    case export(detail: String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone permission denied. Enable it in Settings → Privacy → Microphone."
        case .sessionConfiguration(let config, let detail):
            "Could not configure the audio session for \(config): \(detail)"
        case .sessionActivation(let detail):
            "Could not activate the audio session: \(detail)"
        case .noInputRoute:
            "No audio input is available on the current route."
        case .converterUnavailable(let from, let to):
            "No audio converter from [\(from)] to [\(to)]."
        case .conversionFailed(let detail):
            "Audio conversion failed: \(detail)"
        case .engineStart(let detail):
            "The audio engine could not start: \(detail)"
        case .alreadyCapturing:
            "Capture is already running."
        case .notCapturing:
            "Capture is not running."
        case .playbackFormatUnavailable:
            "Could not create the playback audio format or buffer."
        case .ttsFailed(let detail):
            "Text-to-speech failed: \(detail)"
        case .export(let detail):
            "WAV export failed: \(detail)"
        }
    }
}
