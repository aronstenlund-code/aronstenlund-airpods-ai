import Foundation
import Observation

/// Receives the answer as it streams (the Listening screen's model; TTS joins in item 5).
@MainActor
protocol AnswerSink: AnyObject {
    func answerStarted(_ request: ActivationRequest, source: String)
    func answerQuestionReconstructed(_ question: String)
    func answerDelta(_ text: String)
    /// A whole sentence is ready (sentence-level TTS).
    func answerSentence(_ sentence: String)
    /// Rizzläge: the options, best first.
    func answerSuggestions(_ options: [String])
    func answerCompleted(latencyMs: Double?, done: AnswerDone?)
    /// Auto mode: the backend decided it was not a question.
    func answerSkipped(_ request: ActivationRequest)
    /// The spoken report command (D57): the previous turn should go to the developers.
    func answerReportRequested()
    func answerFailed(_ message: String, wantsFallback: Bool)
}

/// Runs one answer at a time: a new question interrupts the current answer (assignment item 5), streams
/// deltas and sentences to the sink, measures activation → first delta.
@MainActor
@Observable
final class AnswerEngine {
    enum Status: Equatable, Sendable {
        case idle
        case answering(query: String)
        case failed(String)
    }

    private(set) var status: Status = .idle
    /// Activation → first streamed text, for the last answer (item 7 adds the full overlay).
    private(set) var lastLatencyMs: Double?
    /// D86: the kind of the last failure, so the app can say it in Swedish with what to do (never the code).
    private(set) var lastError: AnswerError?
    private(set) var answersCompleted = 0
    weak var sink: (any AnswerSink)?
    /// Debug switch: deterministic local answers instead of the backend (no network, no cost).
    var useMock = false

    private let cloud: any AnswerProvider
    private let mock: any AnswerProvider
    /// Svarslängd (D35).
    let settings: AnswerSettings
    /// A7 "svara kortare" / "längre svar": this session's length, over the setting. Nil: the setting.
    var sessionLength: AnswerLength?
    private var task: Task<Void, Never>?

    var activeProvider: any AnswerProvider { useMock ? mock : cloud }

    init(provider: any AnswerProvider, mock: any AnswerProvider = MockAnswerProvider(), settings: AnswerSettings = AnswerSettings()) {
        self.settings = settings
        self.cloud = provider
        self.mock = mock
    }

    func answer(_ request: ActivationRequest, context: AnswerContext, persona: PersonaRequest? = nil) {
        task?.cancel()
        let provider = activeProvider
        status = .answering(query: request.query)
        Log.signposter.emitEvent("answer.requested")
        task = Task { await run(request, context: context, persona: persona, provider: provider) }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if case .answering = status { status = .idle }
    }

    private func run(_ request: ActivationRequest, context: AnswerContext, persona: PersonaRequest?, provider: any AnswerProvider) async {
        let start = ContinuousClock.now
        sink?.answerStarted(request, source: provider.name)
        var splitter = SentenceSplitter()
        var firstDeltaMs: Double?
        var done: AnswerDone?
        var notAQuestion = false
        do {
            for try await event in provider.answer(AnswerRequest(activation: request, context: context, length: sessionLength ?? settings.length, persona: persona)) {
                if Task.isCancelled { return }
                switch event {
                case .meta(let meta):
                    // `done` follows at once and says whether this was the report command.
                    notAQuestion = !meta.isQuestion
                    if let question = meta.reconstructedQuestion, !meta.needsConfirmation, !question.isEmpty {
                        sink?.answerQuestionReconstructed(question)
                    }
                case .delta(let text):
                    if notAQuestion { break }
                    if firstDeltaMs == nil {
                        firstDeltaMs = Self.milliseconds(since: start)
                        Log.signposter.emitEvent("answer.firstDelta")
                    }
                    sink?.answerDelta(text)
                    for sentence in splitter.feed(text) {
                        sink?.answerSentence(sentence)
                    }
                case .suggestions(let options):
                    sink?.answerSuggestions(options)
                case .done(let finished):
                    done = finished
                case .error:
                    break // the provider throws right after yielding this
                }
            }
            if Task.isCancelled { return }
            if notAQuestion {
                status = .idle
                if done?.report == true {
                    sink?.answerReportRequested()
                } else {
                    Log.answer.info("auto: not a question")
                    sink?.answerSkipped(request)
                }
                return
            }
            if let rest = splitter.flush() {
                sink?.answerSentence(rest)
            }
            lastLatencyMs = firstDeltaMs
            lastError = nil
            answersCompleted += 1
            status = .idle
            Log.answer.info("answer done · first delta \(firstDeltaMs ?? -1, privacy: .public) ms · provider \(provider.name, privacy: .public)")
            sink?.answerCompleted(latencyMs: firstDeltaMs, done: done)
        } catch {
            if Task.isCancelled { return }
            let answerError = AnswerError.from(error)
            if answerError == .cancelled { return }
            Log.answer.error("answer failed: \(answerError.localizedDescription, privacy: .public)")
            status = .failed(answerError.localizedDescription)
            lastError = answerError
            sink?.answerFailed(answerError.localizedDescription, wantsFallback: answerError.wantsFallback)
        }
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: .now)
        let components = elapsed.components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
