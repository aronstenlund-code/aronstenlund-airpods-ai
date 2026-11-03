import Foundation

/// One row of `reports/data/phase1-stt-results.csv`.
/// Carries every §3.11 field so no result is ever attributed to the wrong mic, mode or HQ state.
public struct STTResultRow: Sendable, Equatable {
    public var provider: String            // "apple-speechtranscriber", "apple-dictation", "elevenlabs-scribe-v2", "deepgram-nova-3", "kb-whisper-small", ...
    public var airpodsModel: String        // "AirPods Pro 2"; "iPhone built-in" for A-ref
    public var airpodsFirmware: String
    public var strategy: String            // "B-HQ", "C-HFP-default", ...
    public var mode: String                // "default" / "measurement" / "voiceChat"
    public var inputPort: String           // portType actually active, e.g. "BluetoothHFP"
    public var hqSupported: Bool
    public var hqEnabled: Bool
    public var sampleRateHz: Int
    public var region: String
    public var osVersion: String
    public var distanceMeters: Int?
    public var noise: String               // "quiet" / "noisy"
    public var material: String            // "paragraph" / "short-prompt"
    public var item: String                // "P1", "S07", ...
    public var referenceText: String
    public var hypothesisText: String
    public var wer: Double
    public var cer: Double
    public var exactMatch: Bool
    public var firstPartialLatencyMs: Double?
    public var finalLatencyMs: Double?
    public var realTimeFactor: Double?
    public var notes: String

    public init(provider: String, airpodsModel: String, airpodsFirmware: String, strategy: String, mode: String,
                inputPort: String, hqSupported: Bool, hqEnabled: Bool, sampleRateHz: Int, region: String,
                osVersion: String, distanceMeters: Int?, noise: String, material: String, item: String,
                referenceText: String, hypothesisText: String, wer: Double, cer: Double, exactMatch: Bool,
                firstPartialLatencyMs: Double? = nil, finalLatencyMs: Double? = nil, realTimeFactor: Double? = nil,
                notes: String = "") {
        self.provider = provider
        self.airpodsModel = airpodsModel
        self.airpodsFirmware = airpodsFirmware
        self.strategy = strategy
        self.mode = mode
        self.inputPort = inputPort
        self.hqSupported = hqSupported
        self.hqEnabled = hqEnabled
        self.sampleRateHz = sampleRateHz
        self.region = region
        self.osVersion = osVersion
        self.distanceMeters = distanceMeters
        self.noise = noise
        self.material = material
        self.item = item
        self.referenceText = referenceText
        self.hypothesisText = hypothesisText
        self.wer = wer
        self.cer = cer
        self.exactMatch = exactMatch
        self.firstPartialLatencyMs = firstPartialLatencyMs
        self.finalLatencyMs = finalLatencyMs
        self.realTimeFactor = realTimeFactor
        self.notes = notes
    }

    public static let csvHeader = [
        "provider", "airpods_model", "airpods_firmware", "strategy", "mode", "input_port", "hq_supported",
        "hq_enabled", "sample_rate_hz", "region", "os_version", "distance_m", "noise", "material", "item",
        "reference", "hypothesis", "wer", "cer", "exact_match", "first_partial_ms", "final_ms",
        "real_time_factor", "notes",
    ].joined(separator: ",")

    public var csvLine: String {
        func q(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        func num(_ d: Double?) -> String { d.map { String(format: "%.4f", $0) } ?? "" }
        return [
            q(provider), q(airpodsModel), q(airpodsFirmware), q(strategy), q(mode), q(inputPort),
            hqSupported ? "true" : "false", hqEnabled ? "true" : "false", String(sampleRateHz), q(region),
            q(osVersion), distanceMeters.map(String.init) ?? "", q(noise), q(material), q(item),
            q(referenceText), q(hypothesisText), num(wer), num(cer), exactMatch ? "true" : "false",
            num(firstPartialLatencyMs), num(finalLatencyMs), num(realTimeFactor), q(notes),
        ].joined(separator: ",")
    }
}
