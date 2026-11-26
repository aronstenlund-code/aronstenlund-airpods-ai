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
    /// K10.1 / A9.2: the backend is sure the words were an app command ("kan vi byta till frågor"); nothing is answered.
    func answerAppCommand(_ command: AppCommand)
    func answerFailed(_ message: String, wantsFallback: Bool)
    /// A48 (K35): the model asked for a phone tool; the sink confirms and runs it.
    func answerToolCall(_ call: PhoneToolCall)
    /// K104 (D233): the answer is searching the web; its first word will take a while.
    func answerSearching()
}

extension AnswerSink {
    func answerAppCommand(_ command: AppCommand) {}
    func answerToolCall(_ call: PhoneToolCall) {}
    func answerSearching() {}
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
    /// A9.3: the kind of the last answer (`fact` | `study`), for a correction's context.
    private(set) var lastAnswerType: String?
    private var task: Task<Void, Never>?

    var activeProvider: any AnswerProvider { useMock ? mock : cloud }

    /// A40 (D115) and A159 (D258): asked once when the server cannot answer, for questions only (not the live modes'
    /// suggestions): the network is gone (`AnswerError.offline`), or the server's model is out of credits, busy or
    /// down (`provider_*`, O97). In the app: `OnDeviceAnswerProvider`, which fails itself on iPhones without Apple
    /// Intelligence or when its model does not speak the language; the first error is then reported, so those phones
    /// behave exactly as before. The server is not asked again for that answer.
    var offline: (any AnswerProvider)?

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

    /// T57 (Toby): the same question was refused a moment ago (the answer made ahead: the server's model is down, and
    /// the phone could not answer either). It gets that same no now, through the ordinary failure path, without the
    /// server being asked the same thing once more.
    func answer(_ request: ActivationRequest, context: AnswerContext, persona: PersonaRequest? = nil, refusedJustNow error: AnswerError) {
        task?.cancel()
        let refused = RefusedAnswerProvider(name: activeProvider.name, error: error)
        status = .answering(query: request.query)
        Log.answer.info("answer: refused a moment ago for the same words, not asked again (T57)")
        task = Task { await run(request, context: context, persona: persona, provider: refused) }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if case .answering = status { status = .idle }
    }

    /// `after`: the server's error that made the phone's own model the one to ask (nil for the first try).
    private func run(_ request: ActivationRequest, context: AnswerContext, persona: PersonaRequest?, provider: any AnswerProvider,
                     after first: AnswerError? = nil) async {
        let start = ContinuousClock.now
        sink?.answerStarted(request, source: provider.name)
        var splitter = SentenceSplitter()
        var firstDeltaMs: Double?
        var done: AnswerDone?
        var notAQuestion = false
        do {
            var asked = AnswerRequest(activation: request, context: context, length: sessionLength ?? settings.length, persona: persona)
            asked.onDevice = first.flatMap(OnDeviceReason.init)
            for try await event in provider.answer(asked) {
                if Task.isCancelled { return }
                switch event {
                case .meta(let meta):
                    // `done` follows at once and says whether this was the report command.
                    notAQuestion = !meta.isQuestion
                    if let kind = meta.answerType { lastAnswerType = kind }
                    if let command = meta.appCommand, command.isSure { sink?.answerAppCommand(command) }
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
                case .toolCall(let call):
                    sink?.answerToolCall(call)
                case .searching(let search):
                    Log.answer.info("searching: \(search.tool ?? "?", privacy: .public)")
                    if firstDeltaMs == nil { sink?.answerSearching() } // K104: it comes before the first word
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
            var answerError = AnswerError.from(error)
            if answerError == .cancelled { return }
            if let first {
                // The phone's own model could not answer either (no Apple Intelligence, a language it does not
                // speak): what the server said is what the app says, as before A159.
                answerError = first
            } else if let reason = OnDeviceReason(answerError), let offline, provider !== offline,
                      persona.map({ $0.persona == "tutor" }) ?? true,
                      reason == .offline || firstDeltaMs == nil { // an answer that has begun is not started over
                Log.answer.info("answer: \(reason == .offline ? "offline" : "the server's model is down", privacy: .public), asking the on-device model (A40, A159)")
                await run(request, context: context, persona: persona, provider: offline, after: answerError)
                return
            }
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

/// T57: stands in for the server when its answer is already known to be a no. Asks nothing of anyone.
@MainActor
final class RefusedAnswerProvider: AnswerProvider {
    let name: String
    private let error: AnswerError

    init(name: String, error: AnswerError) {
        self.name = name
        self.error = error
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error> {
        let error = error
        return AsyncThrowingStream { $0.finish(throwing: error) }
    }
}
