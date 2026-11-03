import Foundation

/// What the answer engine sends (mirrors `backend/README.md` `POST /answer`).
struct AnswerContext: Equatable, Sendable {
    struct QA: Equatable, Sendable, Codable {
        var q: String
        var a: String
    }

    /// Last ~60 s of final transcript, excluding words spoken over our own playback.
    var transcript: String = ""
    /// Last 3 question/answer pairs.
    var recentQA: [QA] = []
    /// Prep topics (item 9), ≤30.
    var prepTerms: [String] = []

    static let transcriptLimit = 6000
    static let qaLimit = 6
    static let qaFieldLimit = 400
    static let prepTermLimit = 30
    static let prepTermLength = 60

    /// Trimmed to the backend's limits (413 otherwise).
    var clamped: AnswerContext {
        AnswerContext(transcript: String(transcript.suffix(Self.transcriptLimit)),
                      recentQA: recentQA.suffix(Self.qaLimit).map {
                          QA(q: String($0.q.prefix(Self.qaFieldLimit)), a: String($0.a.prefix(Self.qaFieldLimit)))
                      },
                      prepTerms: prepTerms.prefix(Self.prepTermLimit).map { String($0.prefix(Self.prepTermLength)) })
    }
}

struct AnswerRequest: Equatable, Sendable {
    static let fragmentLimit = 1000

    var fragment: String
    /// `push_to_talk` | `auto` | `text` (`ActivationTrigger.backendMode`).
    var mode: String
    /// `sv` | `en`.
    var language: String
    var context: AnswerContext

    init(fragment: String, mode: String, language: String, context: AnswerContext = AnswerContext()) {
        self.fragment = String(fragment.prefix(Self.fragmentLimit))
        self.mode = mode
        self.language = language
        self.context = context.clamped
    }

    init(activation: ActivationRequest, context: AnswerContext = AnswerContext()) {
        self.init(fragment: activation.query,
                  mode: activation.trigger.backendMode,
                  language: activation.language == .swedish ? "sv" : "en",
                  context: context)
    }
}

struct AnswerMeta: Equatable, Sendable, Codable {
    var reconstructedQuestion: String?
    var confidence: Double?
    var isQuestion: Bool
    /// The streamed text is a short confirmation question ("Menar du …?"), not an answer.
    var needsConfirmation: Bool

    init(reconstructedQuestion: String? = nil, confidence: Double? = nil, isQuestion: Bool, needsConfirmation: Bool = false) {
        self.reconstructedQuestion = reconstructedQuestion
        self.confidence = confidence
        self.isQuestion = isQuestion
        self.needsConfirmation = needsConfirmation
    }

    private enum CodingKeys: String, CodingKey {
        case reconstructedQuestion, confidence, isQuestion, needsConfirmation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reconstructedQuestion = try container.decodeIfPresent(String.self, forKey: .reconstructedQuestion)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        isQuestion = try container.decodeIfPresent(Bool.self, forKey: .isQuestion) ?? true
        needsConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsConfirmation) ?? false
    }
}

struct AnswerDone: Equatable, Sendable, Codable {
    struct Timing: Equatable, Sendable, Codable {
        var metaMs: Double?
        var ttftMs: Double?
        var llmFirstTokenMs: Double?
        var totalMs: Double?
    }

    struct Usage: Equatable, Sendable, Codable {
        var inputTokens: Int?
        var outputTokens: Int?
        var model: String?
    }

    var answered: Bool
    var timing: Timing?
    var usage: Usage?
}

/// `event: error` after the stream started, or the JSON error body before it.
struct AnswerFailure: Equatable, Sendable, Codable, Error {
    var code: String
    var message: String?
    /// The backend says: answer on device / use Apple TTS for this request.
    var fallback: Bool?
}

enum AnswerEvent: Equatable, Sendable {
    case meta(AnswerMeta)
    case delta(String)
    case done(AnswerDone)
    case error(AnswerFailure)
}

enum AnswerError: Error, Equatable, Sendable, LocalizedError {
    /// No network (URLError not-connected family).
    case offline
    case unauthorized(detail: String)
    /// HTTP error with the backend's `{error:{code,message,fallback}}` body, or an `event: error`.
    case backend(status: Int, failure: AnswerFailure)
    case transport(detail: String)
    case decoding(detail: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .offline: "Answers need an internet connection"
        case .unauthorized(let detail): "Could not sign in to the answer service: \(detail)"
        case .backend(let status, let failure):
            "Answer service: \(failure.code)\(failure.message.map { " — \($0)" } ?? "") (HTTP \(status))"
        case .transport(let detail): "Network problem: \(detail)"
        case .decoding(let detail): "Unexpected reply from the answer service: \(detail)"
        case .cancelled: "Cancelled"
        }
    }

    /// Whether the backend asked for the on-device fallback (D19: Foundation Models where available).
    var wantsFallback: Bool {
        if case .backend(_, let failure) = self { return failure.fallback == true }
        return self == .offline
    }
}

/// An answer engine (D19: `CloudAnswerProvider` default; `MockAnswerProvider` in CI; Foundation Models later).
@MainActor
protocol AnswerProvider: AnyObject {
    var name: String { get }
    /// Streams `meta` → `delta`* → `done`; throws `AnswerError`. Cancelling the consuming task cancels the request.
    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error>
}
