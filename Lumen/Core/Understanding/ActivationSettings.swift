import Foundation
import Observation

/// How an answer is triggered (MVP item 3). Push-to-talk is the default: fewest false answers, works with a low voice.
enum ActivationMode: String, CaseIterable, Identifiable, Sendable {
    case pushToTalk
    case auto

    var id: String { rawValue }
}

enum ActivationTrigger: String, Sendable, Equatable {
    case pushToTalk
    case auto
    case answerLast
    case text

    /// The backend's `mode` field (`backend/README.md`): manual triggers are deliberate questions.
    var backendMode: String {
        switch self {
        case .pushToTalk, .answerLast: "push_to_talk"
        case .auto: "auto"
        case .text: "text"
        }
    }
}

/// What the answer engine (item 4) receives.
struct ActivationRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    var query: String
    var trigger: ActivationTrigger
    var language: TranscriptionLanguage
    var gate: GateDecision?
    var createdAt: Date

    init(id: UUID = UUID(), query: String, trigger: ActivationTrigger, language: TranscriptionLanguage,
         gate: GateDecision? = nil, createdAt: Date = Date()) {
        self.id = id
        self.query = query
        self.trigger = trigger
        self.language = language
        self.gate = gate
        self.createdAt = createdAt
    }
}

/// Persisted activation settings (UserDefaults).
@MainActor
@Observable
final class ActivationSettings {
    static let modeKey = "activation.mode"
    static let sensitivityKey = "activation.sensitivity"

    var mode: ActivationMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.modeKey) }
    }
    var sensitivity: GateSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Self.sensitivityKey) }
    }
    /// Minimum gap between two automatic answers (R5: false positives).
    var cooldown: TimeInterval = 8
    /// How long after releasing the push-to-talk button we wait for the recogniser to finalise the last words.
    var releaseGrace: TimeInterval = 2
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.mode = defaults.string(forKey: Self.modeKey).flatMap(ActivationMode.init(rawValue:)) ?? .pushToTalk
        self.sensitivity = defaults.string(forKey: Self.sensitivityKey).flatMap(GateSensitivity.init(rawValue:)) ?? .medium
    }
}
