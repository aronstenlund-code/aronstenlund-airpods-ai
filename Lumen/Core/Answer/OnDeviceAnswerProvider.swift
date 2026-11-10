import Foundation
import FoundationModels

/// A40 (D115): a short answer without the network, from Apple's on-device model (Foundation Models), only on iPhones
/// with Apple Intelligence (iPhone 15 Pro and later) and only when the network is gone. Other iPhones keep "Nätet är
/// borta" exactly as before: this provider then fails with `.offline`, so nothing changes for them. Never a requirement.
final class OnDeviceAnswerProvider: AnswerProvider {
    let name = "on-device"
    static let lead = "Jag svarar kort, nätet är borta."

    static let instructions = """
    Du är Lumen, en pluggkompis för en skolelev i Sverige. Svara på svenska, kort och korrekt: en eller två meningar \
    som går att läsa upp. Inga listor och ingen markdown. Vet du inte säkert, säg det kort i stället för att gissa.
    """

    /// The model is on this iPhone, turned on and ready, and speaks Swedish.
    static var isAvailable: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale(Locale(identifier: "sv_SE"))
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error> {
        let question = request.fragment
        return AsyncThrowingStream { continuation in
            let task = Task {
                guard Self.isAvailable else {
                    continuation.finish(throwing: AnswerError.offline)
                    return
                }
                do {
                    // The whole answer first, so a failing model never leaves the lead said alone.
                    let session = LanguageModelSession(instructions: Self.instructions)
                    let response = try await session.respond(to: question)
                    let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { throw AnswerError.offline }
                    continuation.yield(.meta(AnswerMeta(reconstructedQuestion: question, confidence: 0.8, isQuestion: true)))
                    continuation.yield(.delta(Self.lead + " "))
                    continuation.yield(.delta(text))
                    continuation.yield(.done(AnswerDone(answered: true)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AnswerError.offline) // the model failed: the same as before A40
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
