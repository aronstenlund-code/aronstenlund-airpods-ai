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
    /// D87, Provläge: the wearer's last three turns before this one, answered or not, oldest first.
    var recentTurns: [Turn] = []
    /// D87, Provläge: the active exam (`ExamPlan.id`), so the backend knows which exam the turns belong to.
    var examID: String?
    /// A9.3 / K10: the learned settings, their profile, and what the backend checks their scope against.
    var preferences: [PrefSetting] = []
    var prefProfile: String?
    var prefSubject: String?
    var prefExam: String?
    /// A16: right and wrong per concept from practice runs (Provläge), for "testa mina svagaste" (K9, K17).
    var conceptStats: [ConceptStat] = []
    /// A19 (K17): the last call of a Provläge session: the backend says the session's summary instead of answering.
    var sessionEnd = false
    /// A48 (D116, K30): the consent with D116's text (version 5) is accepted, so the backend may log the question and
    /// answer for Aron's analysis (masked, deleted after delivery). False: never logged.
    var qaLog = false
    /// A48 (K35): the phone tools this phone can run; empty = none offered.
    var toolsAvailable: [String] = []
    /// A48 (K35): the second call after a tool ran (or was declined).
    var toolRound: ToolRound?
    /// A53 (K37, D126): the student's own answers for the exam, in Provläge ("Mina svar"); empty = none.
    var savedAnswers: [SavedAnswerPayload] = []
    /// A56 (K13, D100): short answer first, the developed one in `done.more` (Standardläge and Provläge).
    var twoLevel = false
    /// A59 (K36): the services the user has connected ("spotify"), for the server's tools.
    var connections: [String] = []
    /// A62 (K40): the answer key of the last check question (`done.quiz_key`), sent back with the student's answer.
    var quizKey: QuizKey?
    /// A74 (K42.5): how long the last utterance was spoken, first heard word to last (nil when unknown).
    var utteranceSeconds: Double?

    struct ConceptStat: Equatable, Sendable, Codable {
        var concept: String
        var right: Int
        var wrong: Int
    }

    struct Turn: Equatable, Sendable, Codable {
        var text: String
        /// Lumen answered it (false: silence, filler, a command, or cut off).
        var answered: Bool
    }

    static let turnLimit = 3

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
                      memories: memories.prefix(Self.memoryLimit).map { String($0.prefix(Self.memoryFieldLimit)) },
                      recentTurns: recentTurns.suffix(Self.turnLimit).map { Turn(text: String($0.text.prefix(Self.qaFieldLimit)), answered: $0.answered) },
                      examID: examID,
                      preferences: Array(preferences.prefix(PreferenceStore.limit)),
                      prefProfile: prefProfile.map { String($0.prefix(300)) },
                      prefSubject: prefSubject,
                      prefExam: prefExam,
                      conceptStats: Array(conceptStats.prefix(ConceptStats.limit)),
                      sessionEnd: sessionEnd,
                      qaLog: qaLog, // A48: dropped here at first (the unit test caught it)
                      toolsAvailable: toolsAvailable,
                      toolRound: toolRound,
                      savedAnswers: savedAnswers.prefix(SavedAnswerPayload.itemLimit).map { // A53: in `clamped` too (A48's lesson)
                          SavedAnswerPayload(id: String($0.id.prefix(64)), q: String($0.q.prefix(SavedAnswerPayload.questionLimit)),
                                             a: String($0.a.prefix(SavedAnswerPayload.answerLimit)))
                      },
                      twoLevel: twoLevel,
                      connections: Array(connections.prefix(5)),
                      quizKey: quizKey.map { QuizKey(answer: String($0.answer.prefix(120)),
                                                      alternatives: $0.alternatives.map { Array($0.prefix(6).map { String($0.prefix(120)) }) }) },
                      utteranceSeconds: utteranceSeconds.map { min(max($0, 0), 120) })
    }
}

/// A62 (K40): `done.quiz_key` and `context.quiz_key`: the right answer and the likely wrong ones.
struct QuizKey: Codable, Equatable, Sendable {
    var answer: String
    var alternatives: [String]?

    /// The words for Scribe's keyterms, the answer first.
    var terms: [String] { Array(([answer] + (alternatives ?? [])).filter { !$0.isEmpty }.prefix(4)) }
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

    /// K10.1: a request to control the app in the user's own words.
    var appCommand: AppCommand?
    /// `fact` | `study` (K10.2: study = explanation in a correction's context).
    var answerType: String?

    private enum CodingKeys: String, CodingKey {
        case reconstructedQuestion, confidence, isQuestion, needsConfirmation, appCommand, answerType
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reconstructedQuestion = try container.decodeIfPresent(String.self, forKey: .reconstructedQuestion)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        isQuestion = try container.decodeIfPresent(Bool.self, forKey: .isQuestion) ?? true
        needsConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsConfirmation) ?? false
        appCommand = try? container.decodeIfPresent(AppCommand.self, forKey: .appCommand)
        answerType = try? container.decodeIfPresent(String.self, forKey: .answerType)
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
    /// K10.1: the app command again at the end (sure ones come with nothing answered).
    var appCommand: AppCommand? = nil
    /// K19 / A19: a checked link to a film or page about what is studied.
    var resource: LearningLink? = nil
    /// A53 (K37): the student's saved answer was said word for word ("Ditt svar" on Lyssnar).
    var savedAnswer: SavedAnswerHit? = nil
    /// A56 (K13): with `two_level`, the developed answer after the short one; not spoken until "ja".
    var more: String? = nil
    /// A59 (K36): a tool the server ran (Spotify); the sentence about it is the answer.
    var serverTool: ServerToolResult? = nil
    /// A62 (K40): after a check question, its answer and likely alternatives (never spoken).
    var quizKey: QuizKey? = nil
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
    /// A48 (K35): the model wants a phone tool run.
    case toolCall(PhoneToolCall)
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
