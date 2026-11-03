import Foundation
import Observation

/// The two launch languages (STATUS open decision 2: Swedish + English).
enum TranscriptionLanguage: String, CaseIterable, Identifiable, Sendable, Equatable {
    case swedish = "sv-SE"
    case english = "en-US"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    /// Native name — shown as-is in the picker, not localised.
    var nativeName: String {
        switch self {
        case .swedish: "Svenska"
        case .english: "English"
        }
    }

    static func systemDefault(_ locale: Locale = .current) -> TranscriptionLanguage {
        locale.language.languageCode?.identifier == "sv" ? .swedish : .english
    }
}

/// Persisted language setting (UserDefaults). Default follows the phone's language.
@MainActor
@Observable
final class LanguageSettings {
    static let defaultsKey = "transcription.language"

    var selected: TranscriptionLanguage {
        didSet { defaults.set(selected.rawValue, forKey: Self.defaultsKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, systemLocale: Locale = .current) {
        self.defaults = defaults
        self.selected = defaults.string(forKey: Self.defaultsKey).flatMap(TranscriptionLanguage.init(rawValue:))
            ?? TranscriptionLanguage.systemDefault(systemLocale)
    }
}
