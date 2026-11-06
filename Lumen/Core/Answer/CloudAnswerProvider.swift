import Foundation

/// Claude via Kevin's `/answer` Edge Function (D19 default). Anonymous Supabase auth, SSE streaming,
/// one automatic re-sign-in on 401. Errors are `AnswerError`; `wantsFallback` tells the engine to answer on device.
@MainActor
final class CloudAnswerProvider: AnswerProvider {
    let name = "cloud"
    let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.run(request, into: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AnswerError.from(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Until Kevin's `/answer` accepts `mode: "tutor"` (D36), a 400 for a tutor request is retried once as
    /// `push_to_talk` so Provläge keeps working; the fallback is logged.
    static let tutorFallbackMode = "push_to_talk"

    private func run(_ original: AnswerRequest, into continuation: AsyncThrowingStream<AnswerEvent, any Error>.Continuation) async throws(AnswerError) {
        var request = original
        var attempt = 0
        var modeFallbackUsed = false
        while true {
            attempt += 1
            let token = try await auth.accessToken()
            let urlRequest = makeURLRequest(request, token: token)
            let response: HTTPURLResponse
            let lines: AsyncThrowingStream<String, any Error>
            do {
                (response, lines) = try await http.lines(for: urlRequest)
            } catch {
                throw AnswerError.from(error)
            }

            if response.statusCode == 401, attempt == 1 {
                auth.invalidate()
                continue
            }
            guard response.statusCode == 200 else {
                let body = await Self.collect(lines)
                let failure = AnswerSSEDecoder.decodeErrorBody(body, status: response.statusCode)
                if response.statusCode == 401 { throw AnswerError.unauthorized(detail: failure.code) }
                if response.statusCode == 400, request.mode == "tutor", !modeFallbackUsed {
                    modeFallbackUsed = true
                    request.mode = Self.tutorFallbackMode
                    Log.answer.info("backend rejected mode tutor (\(failure.message ?? failure.code, privacy: .public)) — retrying as \(Self.tutorFallbackMode, privacy: .public)")
                    continue
                }
                throw AnswerError.backend(status: response.statusCode, failure: failure)
            }

            var parser = SSELineParser()
            do {
                for try await line in lines {
                    try Task.checkCancellation()
                    if let event = parser.feed(line), let answerEvent = try AnswerSSEDecoder.decode(event) {
                        continuation.yield(answerEvent)
                        if case .error(let failure) = answerEvent {
                            throw AnswerError.backend(status: 200, failure: failure)
                        }
                    }
                }
                if let event = parser.flush(), let answerEvent = try AnswerSSEDecoder.decode(event) {
                    continuation.yield(answerEvent)
                }
            } catch {
                throw AnswerError.from(error)
            }
            return
        }
    }

    private func makeURLRequest(_ request: AnswerRequest, token: String) -> URLRequest {
        var urlRequest = URLRequest(url: config.answerURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = 30
        urlRequest.httpBody = Self.encodeBody(request)
        return urlRequest
    }

    /// JSON body in the backend's snake_case shape.
    static func encodeBody(_ request: AnswerRequest) -> Data {
        struct Body: Encodable {
            struct Context: Encodable {
                var transcript: String?
                var recent_qa: [AnswerContext.QA]?
                var prep_terms: [String]?
            }
            var fragment: String
            var mode: String
            var language: String
            var context: Context
            var length: String
            var goals: String?
            var commands: [AnswerContext.Command]?
            var memories: [String]?
        }
        let context = Body.Context(transcript: request.context.transcript.isEmpty ? nil : request.context.transcript,
                                   recent_qa: request.context.recentQA.isEmpty ? nil : request.context.recentQA,
                                   prep_terms: request.context.prepTerms.isEmpty ? nil : request.context.prepTerms)
        let body = Body(fragment: request.fragment, mode: request.mode, language: request.language, context: context, length: request.length,
                        goals: request.context.goals,
                        commands: request.context.commands.isEmpty ? nil : request.context.commands,
                        memories: request.context.memories.isEmpty ? nil : request.context.memories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(body)) ?? Data("{}".utf8)
    }

    private static func collect(_ lines: AsyncThrowingStream<String, any Error>) async -> Data {
        var text = ""
        do {
            for try await line in lines { text += line }
        } catch {}
        return Data(text.utf8)
    }
}

/// Deterministic streamed answers for CI tests and the Simulator (no network, no cost).
@MainActor
final class MockAnswerProvider: AnswerProvider {
    let name = "mock"
    var delayPerChunk: Duration = .milliseconds(40)
    var answerText: (AnswerRequest) -> String = { request in
        request.language == "sv"
            ? "Det här är ett testsvar på frågan \"\(request.fragment)\". Riktiga svar kommer från Claude via servern."
            : "This is a test answer to \"\(request.fragment)\". Real answers come from Claude via the server."
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error> {
        let text = answerText(request)
        let delay = delayPerChunk
        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.meta(AnswerMeta(reconstructedQuestion: request.fragment, confidence: 0.9, isQuestion: true)))
                for word in text.split(separator: " ", omittingEmptySubsequences: false) {
                    try Task.checkCancellation()
                    try await Task.sleep(for: delay)
                    continuation.yield(.delta(String(word) + " "))
                }
                continuation.yield(.done(AnswerDone(answered: true, timing: nil, usage: AnswerDone.Usage(inputTokens: 0, outputTokens: 0, model: "mock"))))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
