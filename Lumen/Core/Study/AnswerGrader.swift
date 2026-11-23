import Foundation
import FoundationModels

/// A160 (D258): a grade from the phone's own model: right, partly or wrong, and one sentence about why.
struct LocalGrade: Equatable, Sendable {
    enum Verdict: String, Sendable, CaseIterable {
        case right
        case partly
        case wrong
    }

    var verdict: Verdict
    var sentence: String
}

/// What grades an answer on the phone when the server's model cannot (503 `provider_*`). Nothing is sent anywhere
/// and no credits are counted. The tests use a pretend one; the real one is `OnDeviceGrader`.
@MainActor
protocol AnswerGrading: Sendable {
    /// The model is on this phone, ready, and knows the language.
    func isAvailable(for language: TranscriptionLanguage) -> Bool
    /// nil when the model gave nothing to go by; the answer key is shown then.
    func grade(question: String, key: String, answer: String, language: TranscriptionLanguage) async -> LocalGrade?
}

/// Apple's on-device model (Foundation Models) with guided generation: the model must give one of three verdicts
/// and one sentence, nothing else. Only on iPhones with Apple Intelligence; not in the CI Simulator (D258 point 5).
/// Whether the model is there is asked through `OnDeviceModel` (Angela Schrute's A159), the same door the answers
/// use, so a test or a test build can put a pretend model in its place.
@MainActor
struct OnDeviceGrader: AnswerGrading {
    let model: any OnDeviceModel

    init(model: any OnDeviceModel = SystemOnDeviceModel()) {
        self.model = model
    }

    /// The grader of this launch: the real model, or in the test builds the pretend one the launch asked for
    /// (`-OnDeviceMock sv,en` | `none`, T57), the same argument as for the answers.
    static func forThisLaunch() -> OnDeviceGrader {
        #if LUMEN_TESTMODE
        OnDeviceGrader(model: PretendOnDeviceModel.requested() ?? SystemOnDeviceModel())
        #else
        OnDeviceGrader()
        #endif
    }

    /// `sv` | `en`, as `OnDeviceModel` names the languages.
    static func code(_ language: TranscriptionLanguage) -> String { language == .swedish ? "sv" : "en" }

    @Generable
    enum Kind {
        case right
        case partly
        case wrong
    }

    @Generable
    struct Output {
        @Guide(description: "right if the answer says what the answer key says, partly if something important is missing, wrong otherwise")
        var verdict: Kind
        @Guide(description: "One short sentence to the student about why, in the student's language")
        var sentence: String
    }

    func isAvailable(for language: TranscriptionLanguage) -> Bool {
        model.isAvailable(for: Self.code(language))
    }

    static func instructions(_ language: TranscriptionLanguage) -> String {
        language == .swedish
            ? "Du rättar en elevs svar på en provfråga mot facit. Var rättvis och kortfattad. Svara på svenska."
            : "You grade a student's answer to a quiz question against the answer key. Be fair and brief. Answer in English."
    }

    /// For a model that only gives text (not Foundation Models' guided generation): the verdict first, a colon,
    /// then the sentence ("partly: Energin saknas."). Anything else is no grade, and the answer key is shown.
    static func parsed(_ text: String) -> LocalGrade? {
        let parts = text.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, !parts[1].isEmpty else { return nil }
        let verdict: LocalGrade.Verdict
        switch parts[0].lowercased() {
        case "right", "rätt": verdict = .right
        case "partly", "delvis": verdict = .partly
        case "wrong", "fel": verdict = .wrong
        default: return nil
        }
        return LocalGrade(verdict: verdict, sentence: parts[1])
    }

    static func prompt(question: String, key: String, answer: String, language: TranscriptionLanguage) -> String {
        language == .swedish
            ? "Fråga: \(question)\nFacit: \(key)\nElevens svar: \(answer)"
            : "Question: \(question)\nAnswer key: \(key)\nThe student's answer: \(answer)"
    }

    func grade(question: String, key: String, answer: String, language: TranscriptionLanguage) async -> LocalGrade? {
        guard isAvailable(for: language), !key.isEmpty else { return nil }
        let prompt = Self.prompt(question: question, key: key, answer: answer, language: language)
        #if LUMEN_TESTMODE
        // T57: the pretend model of the test builds always says the same sentence; it stands as a right answer, so
        // the way through the app can be seen in the Simulator. Never in Release.
        if model is PretendOnDeviceModel {
            guard let text = try? await model.respond(to: prompt, instructions: Self.instructions(language)) else { return nil }
            return LocalGrade(verdict: .right, sentence: text)
        }
        #endif
        guard model is SystemOnDeviceModel else {
            // Another model behind the door (a test's): text in the fixed form.
            let form = language == .swedish ? " Börja med rätt, delvis eller fel och ett kolon." : " Start with right, partly or wrong and a colon."
            guard let text = try? await model.respond(to: prompt, instructions: Self.instructions(language) + form) else { return nil }
            return Self.parsed(text)
        }
        do {
            let session = LanguageModelSession(instructions: Self.instructions(language))
            let output = try await session.respond(to: prompt, generating: Output.self).content
            let sentence = output.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return nil }
            let verdict: LocalGrade.Verdict = switch output.verdict {
            case .right: .right
            case .partly: .partly
            case .wrong: .wrong
            }
            return LocalGrade(verdict: verdict, sentence: sentence)
        } catch {
            Log.answer.error("on-device grading: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// The words around a grade from the phone, and around the answer key when nothing can grade. Said and shown in the
/// language that is spoken (the listening modes' rule, D257), so they are not looked up in the app's language.
enum PhoneGradeText {
    static func lead(_ language: TranscriptionLanguage) -> String {
        language == .swedish ? "Telefonens modell:" : "The phone's model:"
    }

    static func verdict(_ verdict: LocalGrade.Verdict, _ language: TranscriptionLanguage) -> String {
        switch (verdict, language == .swedish) {
        case (.right, true): "Rätt."
        case (.partly, true): "Delvis rätt."
        case (.wrong, true): "Inte rätt."
        case (.right, false): "Right."
        case (.partly, false): "Partly right."
        case (.wrong, false): "Not right."
        }
    }

    /// Deangelo's words (A160).
    static func keyOnly(_ language: TranscriptionLanguage) -> String {
        language == .swedish
            ? "Facit visas – rättningen är tillbaka när EarMind kan svara igen."
            : "Showing the answer – grading is back when EarMind can answer again."
    }

    static func key(_ key: String, _ language: TranscriptionLanguage) -> String {
        let text = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return language == .swedish ? "Den här frågan har inget facit." : "This question has no answer key." }
        let ended = text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?") ? text : text + "."
        return (language == .swedish ? "Facit: " : "Answer: ") + ended
    }
}
