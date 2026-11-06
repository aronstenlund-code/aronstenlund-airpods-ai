import Foundation
@testable import Lumen

/// Scripted HTTP: responses are consumed in order; every request is recorded.
final class FakeHTTP: HTTPStreaming, @unchecked Sendable {
    // @unchecked: tests drive it from the main actor only.
    struct Response {
        var status: Int
        var body: String
        var error: (any Error)?
        /// Binary body for `bytes(for:)`, delivered in `chunkSize` pieces (default: whole body at once).
        var bodyData: Data?
        var chunkSize: Int = 0
    }

    private(set) var requests: [URLRequest] = []
    var responses: [Response] = []

    init(_ responses: [Response] = []) {
        self.responses = responses
    }

    private func next(_ request: URLRequest) throws -> Response {
        requests.append(request)
        guard !responses.isEmpty else { throw AnswerError.transport(detail: "FakeHTTP: no scripted response for \(request.url?.path ?? "?")") }
        let response = responses.removeFirst()
        if let error = response.error { throw error }
        return response
    }

    func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        let response = try next(request)
        return (Self.http(request, response.status), Data(response.body.utf8))
    }

    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        let response = try next(request)
        let lines = response.body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let stream = AsyncThrowingStream<String, any Error> { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
        return (Self.http(request, response.status), stream)
    }

    func bytes(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, any Error>) {
        let response = try next(request)
        let data = response.bodyData ?? Data(response.body.utf8)
        let size = response.chunkSize > 0 ? response.chunkSize : max(1, data.count)
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            var offset = 0
            while offset < data.count {
                let end = min(data.count, offset + size)
                continuation.yield(data.subdata(in: offset..<end))
                offset = end
            }
            continuation.finish()
        }
        return (Self.http(request, response.status), stream)
    }

    private static func http(_ request: URLRequest, _ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    }

    /// Request body as a JSON object.
    func json(_ index: Int) -> [String: Any] {
        guard requests.indices.contains(index), let body = requests[index].httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return [:] }
        return object
    }
}

enum Fixtures {
    static func tokenJSON(access: String, refresh: String = "r1", expiresIn: Int = 3600) -> String {
        "{\"access_token\":\"\(access)\",\"token_type\":\"bearer\",\"expires_in\":\(expiresIn),\"refresh_token\":\"\(refresh)\",\"user\":{\"id\":\"u1\"}}"
    }

    static let answerSSE = """
    event: meta
    data: {"reconstructed_question":"Vad är roten ur hundra?","confidence":0.96,"is_question":true,"needs_confirmation":false}

    event: delta
    data: {"text":"Roten ur hundra "}

    event: delta
    data: {"text":"är tio."}

    event: done
    data: {"answered":true,"timing":{"meta_ms":380,"ttft_ms":410,"llm_first_token_ms":300,"total_ms":620},"usage":{"input_tokens":1010,"output_tokens":38,"model":"claude-haiku-5-5"}}

    """

    static let notAQuestionSSE = """
    event: meta
    data: {"reconstructed_question":"","confidence":0.2,"is_question":false,"needs_confirmation":false}

    event: done
    data: {"answered":false}

    """

    static let streamErrorSSE = """
    event: meta
    data: {"is_question":true}

    event: delta
    data: {"text":"Roten "}

    event: error
    data: {"code":"provider_error","message":"upstream closed","fallback":true}

    """
}

/// Answer provider with a scripted event list (and optional error / per-event delay).
@MainActor
final class FakeAnswerProvider: AnswerProvider {
    let name: String
    var events: [AnswerEvent]
    var error: AnswerError?
    var delay: Duration = .zero
    private(set) var requests: [AnswerRequest] = []
    private(set) var cancellations = 0

    init(name: String = "fake", events: [AnswerEvent] = [], error: AnswerError? = nil) {
        self.name = name
        self.events = events
        self.error = error
    }

    func answer(_ request: AnswerRequest) -> AsyncThrowingStream<AnswerEvent, any Error> {
        requests.append(request)
        let events = events
        let error = error
        let delay = delay
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for event in events {
                        if delay > .zero { try await Task.sleep(for: delay) }
                        continuation.yield(event)
                    }
                    if let error { throw error }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [weak self] reason in
                task.cancel()
                if case .cancelled = reason {
                    Task { @MainActor in self?.cancellations += 1 }
                }
            }
        }
    }
}

@MainActor
final class FakeAnswerSink: AnswerSink {
    func answerSuggestions(_ options: [String]) {}
    private(set) var reportRequests = 0
    func answerReportRequested() { reportRequests += 1 }
    private(set) var started: [ActivationRequest] = []
    private(set) var sources: [String] = []
    private(set) var reconstructed: [String] = []
    private(set) var deltas: [String] = []
    private(set) var sentences: [String] = []
    private(set) var completed: [(latencyMs: Double?, done: AnswerDone?)] = []
    private(set) var skipped: [ActivationRequest] = []
    private(set) var failures: [(message: String, wantsFallback: Bool)] = []

    func answerStarted(_ request: ActivationRequest, source: String) { started.append(request); sources.append(source) }
    func answerQuestionReconstructed(_ question: String) { reconstructed.append(question) }
    func answerDelta(_ text: String) { deltas.append(text) }
    func answerSentence(_ sentence: String) { sentences.append(sentence) }
    func answerCompleted(latencyMs: Double?, done: AnswerDone?) { completed.append((latencyMs, done)) }
    func answerSkipped(_ request: ActivationRequest) { skipped.append(request) }
    func answerFailed(_ message: String, wantsFallback: Bool) { failures.append((message, wantsFallback)) }
}

@MainActor
func makeTestAnswerEngine(_ provider: any AnswerProvider = FakeAnswerProvider()) -> AnswerEngine {
    AnswerEngine(provider: provider, mock: MockAnswerProvider())
}
