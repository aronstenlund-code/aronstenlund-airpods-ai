import AVFAudio

/// The capture strategies measured in Phase 1 (assignment §3.2, ARCHITECTURE §4.1).
///
/// `.bluetoothHighQualityRecording` may only be requested in `.default` mode (Apple docs), so B-HQ has no
/// measurement/voiceChat variants. `.allowBluetoothHFP` is the documented fallback when HQ is unavailable
/// (Apple: not currently supported in the EU).
enum CaptureConfig: String, CaseIterable, Identifiable, Sendable, Codable {
    case bHQ = "B-HQ"
    case cHFPDefault = "C-HFP-default"
    case cHFPMeasurement = "C-HFP-measurement"
    case cHFPVoiceChat = "C-HFP-voiceChat"
    case aRefDefault = "A-ref-default"
    case aRefMeasurement = "A-ref-measurement"

    var id: String { rawValue }

    enum InputPreference: String, Sendable {
        case bluetooth
        case builtInMic
    }

    /// "A" (iPhone mic reference), "B" (AirPods HQ) or "C" (AirPods HFP).
    var strategy: String {
        switch self {
        case .bHQ: "B"
        case .cHFPDefault, .cHFPMeasurement, .cHFPVoiceChat: "C"
        case .aRefDefault, .aRefMeasurement: "A"
        }
    }

    var category: AVAudioSession.Category { .playAndRecord }

    var mode: AVAudioSession.Mode {
        switch self {
        case .bHQ, .cHFPDefault, .aRefDefault: .default
        case .cHFPMeasurement, .aRefMeasurement: .measurement
        case .cHFPVoiceChat: .voiceChat
        }
    }

    var modeName: String {
        switch self {
        case .bHQ, .cHFPDefault, .aRefDefault: "default"
        case .cHFPMeasurement, .aRefMeasurement: "measurement"
        case .cHFPVoiceChat: "voiceChat"
        }
    }

    var options: AVAudioSession.CategoryOptions {
        switch self {
        case .bHQ: [.bluetoothHighQualityRecording, .allowBluetoothHFP]
        case .cHFPDefault, .cHFPMeasurement, .cHFPVoiceChat: [.allowBluetoothHFP]
        case .aRefDefault, .aRefMeasurement: [.allowBluetoothA2DP]
        }
    }

    var optionNames: [String] {
        switch self {
        case .bHQ: ["bluetoothHighQualityRecording", "allowBluetoothHFP"]
        case .cHFPDefault, .cHFPMeasurement, .cHFPVoiceChat: ["allowBluetoothHFP"]
        case .aRefDefault, .aRefMeasurement: ["allowBluetoothA2DP"]
        }
    }

    var inputPreference: InputPreference {
        switch self {
        case .aRefDefault, .aRefMeasurement: .builtInMic
        default: .bluetooth
        }
    }

    /// One-line explanation shown under the picker.
    var summary: String {
        switch self {
        case .bHQ:
            "AirPods mic, high-quality request (.default only) + HFP fallback. Apple: not supported in the EU → expect HFP in Sweden."
        case .cHFPDefault:
            "AirPods mic over HFP, mode .default. Baseline available everywhere."
        case .cHFPMeasurement:
            "AirPods mic over HFP, mode .measurement. Does it reduce iOS-side processing?"
        case .cHFPVoiceChat:
            "AirPods mic over HFP, mode .voiceChat. Reference with full voice processing."
        case .aRefDefault:
            "iPhone built-in mic, AirPods output over A2DP, mode .default. Reference only."
        case .aRefMeasurement:
            "iPhone built-in mic, AirPods output over A2DP, mode .measurement. Reference only."
        }
    }
}
