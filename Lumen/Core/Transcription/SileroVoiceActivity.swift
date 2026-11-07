import Foundation
import Observation
#if canImport(LumenVAD)
import LumenVAD

/// Silero through the local `LumenVAD` package (FluidAudio, Apache-2.0, traits off; OSS-2, D78).
struct SileroVoiceActivity: VoiceActivityDetecting {
    let detector: SileroDetector

    static func load() async throws -> SileroVoiceActivity {
        SileroVoiceActivity(detector: try await SileroDetector.load())
    }

    func speechProbability(_ window: [Float]) async throws -> Float {
        try await detector.probability(window)
    }

    func reset() async {
        await detector.reset()
    }
}
#endif

/// Loads the detector once, in the background, and says how it went (shown in Settings).
@MainActor
@Observable
final class VoiceActivityLoader {
    enum Status: Equatable, Sendable {
        case idle, loading, ready
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    private(set) var detector: (any VoiceActivityDetecting)?
    private var task: Task<Void, Never>?

    func loadIfNeeded() {
        guard task == nil else { return }
        #if canImport(LumenVAD)
        status = .loading
        task = Task { [weak self] in
            do {
                let detector = try await SileroVoiceActivity.load()
                self?.detector = detector
                self?.status = .ready
            } catch {
                self?.status = .unavailable(error.localizedDescription)
            }
        }
        #else
        status = .unavailable("LumenVAD not linked")
        #endif
    }

    /// Tests inject a fake detector.
    func use(_ detector: any VoiceActivityDetecting) {
        self.detector = detector
        status = .ready
    }
}
