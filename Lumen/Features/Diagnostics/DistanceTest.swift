import Foundation

enum NoiseCondition: String, CaseIterable, Identifiable, Sendable {
    case quiet
    case noisy
    /// Roadmap Q1 / Track D1: recorded metro or street noise at ~70–80 dB.
    case metro
    var id: String { rawValue }
}

enum SpeakerRole: String, CaseIterable, Identifiable, Sendable {
    case otherPerson = "other person"
    case wearer
    /// Track D1: the wearer whispering 1–5 keywords.
    case wearerWhisper = "wearer whisper"
    /// Track D1: the wearer speaking quietly (library voice).
    case wearerLowVoice = "wearer low voice"
    var id: String { rawValue }
    var fileTag: String {
        switch self {
        case .otherPerson: "other"
        case .wearer: "wearer"
        case .wearerWhisper: "wearer-whisper"
        case .wearerLowVoice: "wearer-low"
        }
    }
}

/// A distance-test recording that is in progress (ring-buffer position mark at start).
struct DistanceRecordingInProgress: Sendable, Equatable {
    var startedAt: Date
    var startMark: Int64
    var config: CaptureConfig
    var distanceMeters: Int
    var noise: NoiseCondition
    var speaker: SpeakerRole

    var fileStem: String { "dist-\(config.rawValue)-\(distanceMeters)m-\(noise.rawValue)-\(speaker.fileTag)" }
}

/// One finished speaker-distance run (Phase 1 §3.6).
struct DistanceTestRun: Identifiable, Sendable, Equatable {
    let id = UUID()
    var time: Date
    var config: CaptureConfig
    var distanceMeters: Int
    var noise: NoiseCondition
    var speaker: SpeakerRole
    var durationSeconds: Double
    var snr: SNREstimate?
    var wavURL: URL?
    var snapshot: SessionSnapshot?

    static let markdownHeader = """
    | Time | Config | Speaker | Dist | Noise | Dur s | Speech dBFS | Floor dBFS | SNR dB | Speech % | Input | Transport | Mode | HQ sup/en | SR Hz | WAV |
    |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
    """

    private static func f1(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "-" }

    var markdownRow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let input = snapshot?.inputs.first?.portName ?? "-"
        let transport = snapshot?.transport ?? "-"
        let mode = snapshot?.modeShort ?? config.modeName
        let hq = snapshot.map { "\($0.hq.isSupported)/\($0.hq.isEnabled)" } ?? "-"
        let sr = snapshot.map { String(Int($0.sampleRate.rounded())) } ?? "-"
        return "| \(formatter.string(from: time)) | \(config.rawValue) | \(speaker.rawValue) | \(distanceMeters) m | \(noise.rawValue) | \(Self.f1(durationSeconds)) | \(Self.f1(snr?.speechRMSDBFS)) | \(Self.f1(snr?.noiseFloorDBFS)) | \(Self.f1(snr?.snrDB)) | \(snr.map { String(format: "%.0f", $0.speechFraction * 100) } ?? "-") | \(input) | \(transport) | \(mode) | \(hq) | \(sr) | \(wavURL?.lastPathComponent ?? "-") |"
    }

    var summaryLine: String {
        let snrText = snr.map { String(format: "SNR %.1f dB (speech %.1f / floor %.1f dBFS)", $0.snrDB, $0.speechRMSDBFS, $0.noiseFloorDBFS) } ?? "SNR n/a (no speech detected)"
        return "\(config.rawValue) · \(speaker.rawValue) · \(distanceMeters) m · \(noise.rawValue) · \(String(format: "%.1f", durationSeconds)) s · \(snrText)"
    }
}
