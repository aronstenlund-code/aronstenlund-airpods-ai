import Foundation

/// Why the phone's own model is asked instead of the server's.
enum OnDeviceReason: Equatable, Sendable {
    /// A40: the network is gone.
    case offline
    /// A159 (D258): the server's model is out of credits, busy or down (`provider_*`, O97).
    case serverDown

    init?(_ error: AnswerError) {
        switch error {
        case .offline: self = .offline
        case .backend(_, let failure) where ServerTrouble.isProvider(failure.code): self = .serverDown
        default: return nil
        }
    }
}

/// A40 (D115) and A159 (D258): a short answer from Apple's on-device model (Foundation Models), only on iPhones with
/// Apple Intelligence, and only when the server cannot answer: the network is gone, or the server's model is out of
/// credits, busy or down. It answers in the language that was spoken (`request.language`, D257), Swedish or English,
/// and begins with one short line that says why it sounds different. Other iPhones, and a language the model does not
/// speak, keep what the app said before: this provider then fails with `.offline`, and the engine reports the first
/// error. Never a requirement. Nothing is sent to the server for such an answer, and no credits are counted.
final class OnDeviceAnswerProvider: AnswerProvider {
    let name = "on-device"
    /// A40's line, kept as it was.
    static let lead = "Jag svarar kort, nätet är borta."

    private let model: any OnDeviceModel

    init(model: any OnDeviceModel = SystemOnDeviceModel()) {
        self.model = model
    }

    /// The first thing said, in the answer's language (it is spoken, so it follows the speech, not the app's choice).
    static func lead(_ reason: OnDeviceReason, language: String) -> String {
        switch (reason, language == "sv") {
        case (.offline, true): lead
        case (.offline, false): "A short answer, the network is down."
        case (.serverDown, true): "Jag svarar med telefonens egen modell."
        case (.serverDown, false): "Answering with the phone's own model."
        }
    }

    static func instructions(language: String) -> String {
        language == "sv"
            ? """
            Du är EarMind, en pluggkompis för en skolelev. Svara på svenska, kort och korrekt: en eller två meningar \
            som går att läsa upp. Inga listor och ingen markdown. Vet du inte säkert, säg det kort i stället för att gissa.
            """
            : """
            You are EarMind, a study companion for a school student. Answer in English, briefly and correctly: one or \
            two sentences that can be read aloud. No lists and no markdown. If you are not sure, say so briefly instead \
            of guessing.
            """
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error> {
        let question = request.fragment
        let language = request.language == "sv" ? "sv" : "en"
        let reason = request.onDevice ?? .offline
        let model = model
        return AsyncThrowingStream { continuation in
            let task = Task {
                guard model.isAvailable(for: language) else {
                    continuation.finish(throwing: AnswerError.offline)
                    return
                }
                do {
                    // The whole answer first, so a failing model never leaves the lead said alone.
                    let reply = try await model.respond(to: question, instructions: Self.instructions(language: language))
                    let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { throw AnswerError.offline }
                    continuation.yield(.meta(AnswerMeta(reconstructedQuestion: question, confidence: 0.8, isQuestion: true)))
                    continuation.yield(.delta(Self.lead(reason, language: language) + " "))
                    continuation.yield(.delta(text))
                    continuation.yield(.done(AnswerDone(answered: true)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AnswerError.offline) // the model failed: the same as without one
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
