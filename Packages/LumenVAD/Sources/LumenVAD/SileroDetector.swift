import FluidAudio
import Foundation

/// Silero VAD v6 (Core ML, MIT; FluidInference/silero-vad-coreml) through FluidAudio (Apache-2.0), D78.
/// The model is fetched once from Hugging Face and cached. Only the model is downloaded; no audio leaves the phone.
public actor SileroDetector {
    /// Silero's window: 4096 samples at 16 kHz = 256 ms.
    public static let windowSamples = VadManager.chunkSize

    private let manager: VadManager
    private var state: VadStreamState

    private init(manager: VadManager) {
        self.manager = manager
        self.state = VadStreamState.initial()
    }

    /// Loads (and the first time downloads) the model. Throws if it cannot.
    public static func load() async throws -> SileroDetector {
        let manager = try await VadManager(config: VadConfig(defaultThreshold: 0.5))
        return SileroDetector(manager: manager)
    }

    /// Speech probability (0–1) of one window of 16 kHz mono samples in −1…1. Keeps the model's state between calls.
    public func probability(_ window: [Float]) async throws -> Float {
        let result = try await manager.processStreamingChunk(window, state: state)
        state = result.state
        return result.probability
    }

    /// A new stream (Silero's `reset_states`).
    public func reset() {
        state = VadStreamState.initial()
    }
}
