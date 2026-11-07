import Foundation
import Observation

/// How an answer is triggered (MVP item 3). Push-to-talk is the default: fewest false answers, works with a low voice.
enum ActivationTrigger: String, Sendable, Equatable {
    case auto
    case answerLast
    case text
    /// A hands-free Provläge turn (D36): tutor style, whole-session memory.
    case tutor
    /// A hands-free turn in someone else's words: the interviewer's question.
    case overheard
    /// Rizzläge suggestions (D43): sent from the rolling transcript, no question of its own.
    case rizz
    /// Intervjuläge preparation from the role or job ad.
    case interviewPrep

    /// Whether the query is the user's own words. Auto mode and "last sentence" pick up the room (D56).
    var isUsersOwnWords: Bool {
        switch self {
        case .text, .tutor, .interviewPrep: true
        case .auto, .answerLast, .overheard, .rizz: false
        }
    }

    /// The backend's `mode` field (`backend/README.md`): manual triggers are deliberate questions.
    var backendMode: String {
        switch self {
        case .answerLast: "push_to_talk"
        case .auto: "auto"
        case .text: "text"
        case .tutor, .overheard, .rizz: "tutor"
        case .interviewPrep: "interview_prep"
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

/// Persisted activation settings (UserDefaults). Every mode is hands-free (D72): there is no hold-to-ask to choose.
@MainActor
@Observable
final class ActivationSettings {
    static let sensitivityKey = "activation.sensitivity"

    var sensitivity: GateSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Self.sensitivityKey) }
    }
    /// Minimum gap between two automatic answers (R5: false positives). Parrot v0.11.3's minimum interval (D78).
    var cooldown: TimeInterval = 5
    /// A question waits this long for the speaker to finish (Parrot v0.11.3: 1 s). Zero fires at once.
    var questionDebounce: TimeInterval = 1.0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sensitivity = defaults.string(forKey: Self.sensitivityKey).flatMap(GateSensitivity.init(rawValue:)) ?? .medium
    }
}
