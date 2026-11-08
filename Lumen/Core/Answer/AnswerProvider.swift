import Foundation

/// What the answer engine sends (mirrors `backend/README.md` `POST /answer`).
struct AnswerContext: Equatable, Sendable {
    struct QA: Equatable, Sendable, Codable {
        var q: String
        var a: String
        /// D81: the wearer stopped this answer; `a` is what had been said by then. Never repeated by the backend.
        var interrupted: Bool? = nil
    }

    /// Last ~60 s of final transcript, excluding words spoken over our own playback.
    var transcript: String = ""
    /// Last 3 question/answer pairs.
    var recentQA: [QA] = []
    /// Prep topics (item 9), ≤30.
    var prepTerms: [String] = []
    /// Course goals, compact (D37), ≤1 500 chars.
    var goals: String?
    /// Personal commands triggered by this question (D37), ≤10 × 300 chars.
    var commands: [Command] = []
    /// What the user asked Lumen to remember (D49), ≤30 × 200 chars.
    var memories: [String] = []

    struct Command: Equatable, Sendable, Codable {
        var keyword: String
        var instruction: String
    }

    static let transcriptLimit = 6000
    static let qaLimit = 6
    static let qaFieldLimit = 400
    static let prepTermLimit = 50 // Kevin D84: up to 50 (30 before)
    static let prepTermLength = 60
    static let goalsLimit = 1_500
    static let commandLimit = 10
    static let commandFieldLimit = 300
    static let memoryLimit = 30
    static let memoryFieldLimit = 200

    /// Trimmed to the backend's limits (413 otherwise).
    var clamped: AnswerContext {
        AnswerContext(transcript: String(transcript.suffix(Self.transcriptLimit)),
                      recentQA: recentQA.suffix(Self.qaLimit).map {
                          QA(q: String($0.q.prefix(Self.qaFieldLimit)), a: String($0.a.prefix(Self.qaFieldLimit)), interrupted: $0.interrupted)
                      },
                      prepTerms: prepTerms.prefix(Self.prepTermLimit).map { String($0.prefix(Self.prepTermLength)) },
                      goals: goals.flatMap { $0.isEmpty ? nil : String($0.prefix(Self.goalsLimit)) },
                      commands: commands.prefix(Self.commandLimit).map {
                          Command(keyword: String($0.keyword.prefix(Self.commandFieldLimit)),
                                  instruction: String($0.instruction.prefix(Self.commandFieldLimit)))
                      },
                      memories: memories.prefix(Self.memoryLimit).map { String($0.prefix(Self.memoryFieldLimit)) })
    }
}

/// `social` in the request (D43): what Rizzläge sends instead of a question.
struct SocialRequest: Equatable, Sendable, Encodable {
    struct Line: Equatable, Sendable, Encodable {
        var speaker: String
        var text: String
        /// D81: "Talare 1" … when the voice is known (Kevin's contract: an `other` line may carry `label`).
        var label: String? = nil
    }

    var style: String
    /// `other_spoke` | `stall` | `opener`.
    var trigger: String
    var transcript: [Line]
    var interests: [String]
    var profile: String
    /// The wearer's instruction after "Lumen, …" (D69): merged into the calibration, or "ge mig tre" (D72). Never in
    /// `transcript`.
    var calibrate: String? = nil
    /// The stored calibration for this mode, sent with every request (D69).
    var calibration: String? = nil
    /// D81: the label of whoever said the latest words ("Talare 2"), when the voice is known.
    var speaker: String? = nil
}

/// Who the assistant is in a mode (D42): `persona` + `persona_setup`, and for interviews whose turn it is.
struct PersonaRequest: Equatable, Sendable {
    var persona: String
    var setup: String?
    /// Intervjuläge: `question` | `user_answer`.
    var turn: String?
    var social: SocialRequest?
    /// Rizzläge only: the backend refuses `flirt` without it (D63).
    var adultConfirmed: Bool?
}

struct AnswerRequest: Equatable, Sendable {
    static let fragmentLimit = 1000

    var fragment: String
    /// `push_to_talk` | `auto` | `text` (`ActivationTrigger.backendMode`).
    var mode: String
    /// `sv` | `en`.
    var language: String
    var context: AnswerContext
    /// `short` | `adaptive` | `long` (D35, Svarslängd).
    var length: String
    var persona: PersonaRequest?

    init(fragment: String, mode: String, language: String, context: AnswerContext = AnswerContext(), length: AnswerLength = .adaptive,
         persona: PersonaRequest? = nil) {
        self.fragment = String(fragment.prefix(Self.fragmentLimit))
        self.mode = mode
        self.language = language
        self.context = context.clamped
        self.length = length.rawValue
        self.persona = persona
    }

    init(activation: ActivationRequest, context: AnswerContext = AnswerContext(), length: AnswerLength = .adaptive,
         persona: PersonaRequest? = nil) {
        self.init(fragment: activation.query,
                  mode: activation.trigger.backendMode,
                  language: activation.language == .swedish ? "sv" : "en",
                  context: context,
                  length: length,
                  persona: persona)
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
    /// One or two sentences for Historik, written in the same call (D48/D50). Null for Rizz and truncated answers.
    var summary: String?
    /// "kom ihåg …": the fact to store on the phone (D50). Never inferred by the server.
    var memoryAdd: String?
    /// The user said "rapportera" (D57): send the previous turn to `/feedback`. Nothing was answered.
    var report: Bool?
    /// After `social.calibrate`: the merged calibration to store for this mode, "" after a reset. Null otherwise (D69).
    var calibration: String?
    /// The model said [[TYST]] after text it had already streamed: drop the answer, say nothing more (Kevin, D82).
    var retract: Bool?
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
    /// Rizzläge: 2–3 options, best first (D45).
    case suggestions([String])
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
