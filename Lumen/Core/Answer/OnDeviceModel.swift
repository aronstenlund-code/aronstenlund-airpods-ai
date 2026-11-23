import Foundation
import FoundationModels

/// The phone's own model (Apple's Foundation Models), behind one small door so that the answers (A159) and the
/// grading of saved exams (A160) ask it the same way and the tests can put a pretend model in its place.
/// It is only there on iPhones with Apple Intelligence, turned on and downloaded; nothing may depend on it.
/// Nothing leaves the phone and no credits are counted for what it says.
@MainActor
protocol OnDeviceModel: Sendable {
    /// The model is on this iPhone, turned on and ready, and speaks `language` (`sv` | `en`).
    func isAvailable(for language: String) -> Bool
    /// One reply as text. Throws when the model does not answer.
    func respond(to prompt: String, instructions: String) async throws -> String
}

enum OnDeviceLanguage {
    /// `sv` → Swedish (Apple Intelligence has it since iOS 26.1), anything else → English.
    static func locale(for language: String) -> Locale {
        Locale(identifier: language == "sv" ? "sv_SE" : "en_US")
    }
}

/// Foundation Models as it is on the phone.
@MainActor
struct SystemOnDeviceModel: OnDeviceModel {
    func isAvailable(for language: String) -> Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale(OnDeviceLanguage.locale(for: language))
    }

    func respond(to prompt: String, instructions: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: prompt).content
    }
}

#if LUMEN_TESTMODE
/// T57 (Toby): a pretend phone model for the Simulator, which has no Foundation Models. Only in the test builds
/// (Debug and Beta), never in Release. `-OnDeviceMock sv,en` gives a model that speaks those languages and always
/// says the same sentence; `-OnDeviceMock none` is a phone without Apple Intelligence. Without the argument the app
/// asks the real model, as on a phone.
@MainActor
struct PretendOnDeviceModel: OnDeviceModel {
    static let swedish = "Det här är ett låtsassvar från telefonens modell."
    static let english = "This is a pretend answer from the phone's model."

    let languages: Set<String>

    /// What the launch asked for; nil when it asked for nothing.
    static func requested(_ defaults: UserDefaults = .standard) -> (any OnDeviceModel)? {
        guard let value = defaults.string(forKey: "OnDeviceMock") else { return nil }
        let asked = value.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return PretendOnDeviceModel(languages: Set(asked).intersection(["sv", "en"]))
    }

    func isAvailable(for language: String) -> Bool {
        languages.contains(language)
    }

    func respond(to prompt: String, instructions: String) async throws -> String {
        instructions.contains("Svara på svenska") ? Self.swedish : Self.english
    }
}
#endif
