import Foundation
import FoundationModels

/// A159/A160 (D258): the one place that asks whether Apple's model on the phone (Foundation Models) can be used: it
/// is on this iPhone, turned on and ready, and knows the language. Shared by the answers (`OnDeviceAnswerProvider`,
/// Angela Schrute's A159) and the grading of saved quizzes (`OnDeviceGrader`, A160). Never a requirement: an iPhone
/// without Apple Intelligence gets `false` and everything stays as it was.
enum OnDeviceModel {
    static func isAvailable(for locale: Locale) -> Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale(locale)
    }

    /// The language that is spoken (D257: it wins in the listening modes).
    static func isAvailable(for language: TranscriptionLanguage) -> Bool { isAvailable(for: language.locale) }

    /// The language chosen for the app's texts (D253).
    static func isAvailable(for language: AppLanguage) -> Bool { isAvailable(for: locale(for: language)) }

    static func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: language == .sv ? "sv_SE" : "en_US")
    }
}
