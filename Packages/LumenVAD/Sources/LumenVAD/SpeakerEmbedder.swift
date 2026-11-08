import FluidAudio
import Foundation

/// D81: a 256-dim WeSpeaker voice embedding (pyannote/wespeaker-voxceleb-resnet34-LM, CC-BY-4.0) through FluidAudio's
/// diarizer (Apache-2.0), with pyannote segmentation-3.0 (MIT). The models are fetched once from Hugging Face
/// (FluidInference/speaker-diarization-coreml) and cached; audio never leaves the phone.
public actor SpeakerEmbedder {
    private let manager: DiarizerManager

    private init(models: DiarizerModels) {
        let manager = DiarizerManager()
        manager.initialize(models: models)
        self.manager = manager
    }

    /// Loads (and the first time downloads) the models.
    public static func load() async throws -> SpeakerEmbedder {
        let models = try await DiarizerModels.downloadIfNeeded()
        return SpeakerEmbedder(models: models)
    }

    /// The voice in 16 kHz mono samples (−1…1) of one speaker, about a second or more. L2-normalised.
    public func embedding(_ samples: [Float]) throws -> [Float] {
        try manager.extractSpeakerEmbedding(from: samples)
    }
}
