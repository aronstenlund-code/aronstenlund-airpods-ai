import Foundation

/// Minimal HTTP abstraction so `SupabaseAuth` and `CloudAnswerProvider` are unit-tested without a network.
protocol HTTPStreaming: Sendable {
    /// Whole-body request (auth calls, error bodies).
    func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data)
    /// Line-by-line body for `text/event-stream`, **blank lines included** (they end an SSE event).
    /// The stream ends when the server closes the response.
    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>)
    /// Binary body in chunks as they arrive (streamed audio).
    func bytes(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, any Error>)
}

struct URLSessionHTTP: HTTPStreaming {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnswerError.transport(detail: "not an HTTP response")
        }
        return (http, data)
    }

    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnswerError.transport(detail: "not an HTTP response")
        }
        let stream = AsyncThrowingStream<String, any Error> { continuation in
            let task = Task {
                do {
                    // Not `bytes.lines`: it skips empty lines, and SSELineParser needs them.
                    var line: [UInt8] = []
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            continuation.yield(String(decoding: line, as: UTF8.self))
                            line.removeAll(keepingCapacity: true)
                        } else {
                            line.append(byte)
                        }
                    }
                    if !line.isEmpty { continuation.yield(String(decoding: line, as: UTF8.self)) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (http, stream)
    }

    func bytes(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, any Error>) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnswerError.transport(detail: "not an HTTP response")
        }
        let stream = AsyncThrowingStream<Data, any Error> { continuation in
            let task = Task {
                do {
                    var chunk = Data()
                    chunk.reserveCapacity(4_800)
                    for try await byte in bytes {
                        chunk.append(byte)
                        if chunk.count >= 4_800 {
                            continuation.yield(chunk)
                            chunk = Data()
                            chunk.reserveCapacity(4_800)
                        }
                    }
                    if !chunk.isEmpty { continuation.yield(chunk) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (http, stream)
    }
}

extension AnswerError {
    /// Maps URLSession failures to our error (offline detection for the "answers need internet" message).
    static func from(_ error: any Error) -> AnswerError {
        if let answerError = error as? AnswerError { return answerError }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut:
                return .offline
            case .cancelled:
                return .cancelled
            default:
                return .transport(detail: urlError.localizedDescription)
            }
        }
        return .transport(detail: error.localizedDescription)
    }
}
