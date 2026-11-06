import Foundation
import Observation

/// What the session is for. Decides the microphone (D55) and, in hands-free modes, the backend persona (D42).
enum ConversationMode: String, CaseIterable, Identifiable, Sendable {
    /// Hold to ask, or auto.
    case standard
    case prov
    case interview
    /// Flirting, 18+ (D63).
    case rizz
    /// Jokes, comebacks, small talk, for everyone (D63).
    case social

    var id: String { rawValue }

    /// The live suggestion loop (D43): its backend style, nil for the other modes.
    var liveStyle: LiveStyle? {
        switch self {
        case .rizz: .flirt
        case .social: .social
        case .standard, .prov, .interview: nil
        }
    }

    var isLive: Bool { liveStyle != nil }
}

/// Mikrofon (D55): the wearer's AirPods, or the iPhone for hearing other people.
enum MicrophoneSource: String, CaseIterable, Identifiable, Sendable {
    /// Favours the wearer's own voice. HFP in the EU, so answers play in call quality.
    case airPods
    /// Built-in microphone; answers stay in A2DP quality in the AirPods. Best on a table near the other person.
    case iPhone

    var id: String { rawValue }

    static func defaultSource(for mode: ConversationMode) -> MicrophoneSource {
        switch mode {
        case .standard, .prov: .airPods
        case .interview, .rizz, .social: .iPhone
        }
    }

    /// The session config for this source. Echo cancellation only exists on the AirPods path.
    func captureConfig(echoCancellation: Bool = false) -> CaptureConfig {
        switch self {
        case .airPods: echoCancellation ? .cHFPVoiceChat : .bHQ
        case .iPhone: .aRefDefault
        }
    }
}

/// The chosen microphone per mode, persisted in UserDefaults.
@MainActor
@Observable
final class MicrophoneSettings {
    static func key(for mode: ConversationMode) -> String { "microphone.\(mode.rawValue)" }

    private var sources: [ConversationMode: MicrophoneSource] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for mode in ConversationMode.allCases {
            sources[mode] = defaults.string(forKey: Self.key(for: mode)).flatMap(MicrophoneSource.init(rawValue:))
        }
    }

    func source(for mode: ConversationMode) -> MicrophoneSource {
        sources[mode] ?? .defaultSource(for: mode)
    }

    func setSource(_ source: MicrophoneSource, for mode: ConversationMode) {
        sources[mode] = source
        defaults.set(source.rawValue, forKey: Self.key(for: mode))
    }
}
