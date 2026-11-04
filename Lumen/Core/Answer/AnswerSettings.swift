import Foundation
import Observation

/// Svarslängd (D35): Kort / Anpassad (default) / Utförlig → the backend's `length` field.
enum AnswerLength: String, CaseIterable, Identifiable, Sendable {
    case short
    case adaptive
    case long

    var id: String { rawValue }
}

@MainActor
@Observable
final class AnswerSettings {
    static let lengthKey = "answer.length"

    var length: AnswerLength {
        didSet { defaults.set(length.rawValue, forKey: Self.lengthKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.length = defaults.string(forKey: Self.lengthKey).flatMap(AnswerLength.init(rawValue:)) ?? .adaptive
    }
}
