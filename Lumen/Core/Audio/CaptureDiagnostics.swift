import AVFAudio
import Foundation

/// One port of the current route.
struct PortInfo: Sendable, Equatable, Codable {
    var portType: String       // AVAudioSession.Port rawValue, e.g. "BluetoothHFP", "MicrophoneBuiltIn"
    var portName: String       // e.g. "Arons AirPods Pro"
    var uid: String
    var channelCount: Int
    var dataSource: String?

    var isBluetooth: Bool { portType.hasPrefix("Bluetooth") }
    /// The iPhone's loudspeaker: the only output that makes the microphone hear Lumen (D82).
    var isBuiltInSpeaker: Bool { portType == AVAudioSession.Port.builtInSpeaker.rawValue }
    /// Headphone-like output whose loss should pause the session.
    var isExternalOutput: Bool { isBluetooth || portType == AVAudioSession.Port.headphones.rawValue }

    var oneLine: String {
        var s = "\(portName) [\(portType), \(channelCount) ch]"
        if let dataSource { s += " ds=\(dataSource)" }
        return s
    }
}

extension PortInfo {
    init(port: AVAudioSessionPortDescription) {
        self.init(portType: port.portType.rawValue,
                  portName: port.portName,
                  uid: port.uid,
                  channelCount: port.channels?.count ?? 0,
                  dataSource: port.selectedDataSource?.dataSourceName)
    }
}

/// Bluetooth high-quality recording capability (Phase 1 §3.11). `isSupported` = the port can do it;
/// `isEnabled` = active in this session. They answer different questions and are always logged together.
struct HQCapability: Sendable, Equatable, Codable {
    var extensionPresent: Bool
    var isSupported: Bool
    var isEnabled: Bool

    static let unavailable = HQCapability(extensionPresent: false, isSupported: false, isEnabled: false)

    var summary: String {
        "HQ supported=\(isSupported) enabled=\(isEnabled)" + (extensionPresent ? "" : " (no BT mic extension)")
    }
}

/// Everything §3.11 asks us to log per test run.
struct SessionSnapshot: Sendable, Equatable {
    var timestamp: Date
    var config: CaptureConfig?
    var category: String
    var mode: String
    var options: [String]
    var inputs: [PortInfo]
    var outputs: [PortInfo]
    var sampleRate: Double
    var ioBufferDuration: TimeInterval
    var inputChannels: Int
    var outputChannels: Int
    var inputLatency: TimeInterval
    var outputLatency: TimeInterval
    var hq: HQCapability
    var preferredInputSucceeded: Bool?
    var engineInputFormat: String?
    var region: String
    var osVersion: String

    /// D82: echo cancellation is needed only then.
    var outputsToBuiltInSpeaker: Bool { outputs.contains(where: \.isBuiltInSpeaker) }

    static func shortName(_ raw: String, prefix: String) -> String {
        guard raw.hasPrefix(prefix) else { return raw }
        let rest = raw.dropFirst(prefix.count)
        guard let first = rest.first else { return raw }
        return first.lowercased() + rest.dropFirst()
    }

    var modeShort: String { Self.shortName(mode, prefix: "AVAudioSessionMode") }
    var categoryShort: String { Self.shortName(category, prefix: "AVAudioSessionCategory") }

    /// "HFP", "BT-HQ", "iPhone mic", … derived from the active input port and HQ state.
    var transport: String {
        guard let input = inputs.first else { return "no input" }
        switch input.portType {
        case AVAudioSession.Port.bluetoothHFP.rawValue: return hq.isEnabled ? "BT-HQ" : "HFP"
        case AVAudioSession.Port.builtInMic.rawValue: return "iPhone mic"
        case AVAudioSession.Port.bluetoothLE.rawValue: return "BT-LE"
        case AVAudioSession.Port.headsetMic.rawValue: return "wired headset mic"
        default: return input.portType
        }
    }

    var sampleRateKHz: String { String(format: "%.4g", sampleRate / 1000) }

    /// e.g. `AirPods Pro 2 · HFP · mode=measurement · 16 kHz · HQ supported=false enabled=false`
    var banner: String {
        let name = inputs.first?.portName ?? "No input"
        return "\(name) · \(transport) · mode=\(modeShort) · \(sampleRateKHz) kHz · HQ supported=\(hq.isSupported) enabled=\(hq.isEnabled)"
    }

    var markdown: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var lines: [String] = []
        lines.append("| Field | Value |")
        lines.append("|---|---|")
        lines.append("| time | \(f.string(from: timestamp)) |")
        lines.append("| config | \(config?.rawValue ?? "-") |")
        lines.append("| category / mode | \(categoryShort) / \(modeShort) |")
        lines.append("| options | \(options.joined(separator: ", ")) |")
        lines.append("| inputs | \(inputs.map(\.oneLine).joined(separator: "; ")) |")
        lines.append("| outputs | \(outputs.map(\.oneLine).joined(separator: "; ")) |")
        lines.append("| transport | \(transport) |")
        lines.append("| sample rate | \(Int(sampleRate.rounded())) Hz |")
        lines.append("| IO buffer | \(String(format: "%.1f", ioBufferDuration * 1000)) ms |")
        lines.append("| input / output channels | \(inputChannels) / \(outputChannels) |")
        lines.append("| input / output latency | \(String(format: "%.1f", inputLatency * 1000)) / \(String(format: "%.1f", outputLatency * 1000)) ms |")
        lines.append("| HQ extension present | \(hq.extensionPresent) |")
        lines.append("| HQ isSupported / isEnabled | \(hq.isSupported) / \(hq.isEnabled) |")
        lines.append("| setPreferredInput | \(preferredInputSucceeded.map { $0 ? "succeeded" : "FAILED" } ?? "not attempted") |")
        lines.append("| engine input format | \(engineInputFormat ?? "-") |")
        lines.append("| device region | \(region) |")
        lines.append("| OS | \(osVersion) |")
        return lines.joined(separator: "\n")
    }
}

extension SessionSnapshot {
    /// Reads the live session state. Main actor because `AVAudioSession` is not Sendable.
    @MainActor
    static func read(from session: AVAudioSession, config: CaptureConfig?,
                     preferredInputSucceeded: Bool?, engineInputFormat: String?) -> SessionSnapshot {
        let route = session.currentRoute
        let inputs = route.inputs.map(PortInfo.init(port:))
        let outputs = route.outputs.map(PortInfo.init(port:))

        var hq = HQCapability.unavailable
        if let firstInput = route.inputs.first, let bluetoothMic = firstInput.bluetoothMicrophoneExtension {
            hq = HQCapability(extensionPresent: true,
                              isSupported: bluetoothMic.highQualityRecording.isSupported,
                              isEnabled: bluetoothMic.highQualityRecording.isEnabled)
        }

        return SessionSnapshot(
            timestamp: Date(),
            config: config,
            category: session.category.rawValue,
            mode: session.mode.rawValue,
            options: optionNames(session.categoryOptions),
            inputs: inputs,
            outputs: outputs,
            sampleRate: session.sampleRate,
            ioBufferDuration: session.ioBufferDuration,
            inputChannels: session.inputNumberOfChannels,
            outputChannels: session.outputNumberOfChannels,
            inputLatency: session.inputLatency,
            outputLatency: session.outputLatency,
            hq: hq,
            preferredInputSucceeded: preferredInputSucceeded,
            engineInputFormat: engineInputFormat,
            region: Locale.current.region?.identifier ?? "?",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    static func optionNames(_ options: AVAudioSession.CategoryOptions) -> [String] {
        let table: [(AVAudioSession.CategoryOptions, String)] = [
            (.mixWithOthers, "mixWithOthers"),
            (.duckOthers, "duckOthers"),
            (.allowBluetoothHFP, "allowBluetoothHFP"),
            (.defaultToSpeaker, "defaultToSpeaker"),
            (.interruptSpokenAudioAndMixWithOthers, "interruptSpokenAudioAndMixWithOthers"),
            (.allowBluetoothA2DP, "allowBluetoothA2DP"),
            (.allowAirPlay, "allowAirPlay"),
            (.overrideMutedMicrophoneInterruption, "overrideMutedMicrophoneInterruption"),
            (.bluetoothHighQualityRecording, "bluetoothHighQualityRecording"),
        ]
        var names = table.filter { options.contains($0.0) }.map(\.1)
        var known = AVAudioSession.CategoryOptions()
        for (option, _) in table { known.formUnion(option) }
        let unknown = options.rawValue & ~known.rawValue
        if unknown != 0 { names.append("unknown(0x\(String(unknown, radix: 16)))") }
        return names
    }
}
