import Foundation
import Observation

/// Taligenkänning (D44): Scribe in the cloud by default, or only on the phone.
@MainActor
@Observable
final class STTSettings {
    static let cloudKey = "stt.useCloud"

    var useCloud: Bool {
        didSet { defaults.set(useCloud, forKey: Self.cloudKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.useCloud = defaults.object(forKey: Self.cloudKey) as? Bool ?? true
    }
}

/// `GET /stt-token`: a single-use token, so no ElevenLabs key is ever in the app (D2).
struct ScribeToken: Decodable, Equatable, Sendable {
    var token: String
    var model_id: String
    var ws_url: String
    var language_code: String?
    var extra_query: String?

    /// `commit_strategy=vad`: finals follow the speaker's pauses during continuous listening (the web test commits
    /// by hand on release). The token sits in the URL: never log it.
    func url(language: TranscriptionLanguage, keyterms: [String]) -> URL? {
        guard var components = URLComponents(string: ws_url) else { return nil }
        var items = [URLQueryItem(name: "model_id", value: model_id),
                     URLQueryItem(name: "token", value: token),
                     URLQueryItem(name: "language_code", value: language == .swedish ? "swe" : "eng"),
                     URLQueryItem(name: "audio_format", value: "pcm_16000"),
                     URLQueryItem(name: "commit_strategy", value: "vad")]
        items += keyterms.prefix(ScribeProvider.keytermLimit).map { URLQueryItem(name: "keyterms", value: $0) }
        items += URLComponents(string: "?" + (extra_query ?? ""))?.queryItems ?? []
        components.queryItems = items
        return components.url
    }
}

/// The socket's JSON messages. Pure, unit-tested. Field names follow `backend/webtest/index.html`.
enum ScribeMessage: Equatable, Sendable {
    case partial(String)
    case committed(String)
    case failure(String)
    /// `session_started`, warnings (zero retention is refused on our plan and the socket carries on).
    case other

    static func parse(_ text: String) -> ScribeMessage {
        struct Body: Decodable {
            var message_type: String?
            var type: String?
            var text: String?
            var error: String?
        }
        guard let body = try? JSONDecoder().decode(Body.self, from: Data(text.utf8)) else { return .other }
        let kind = body.message_type ?? body.type ?? ""
        switch kind {
        case "partial_transcript":
            return .partial(body.text ?? "")
        case "committed_transcript", "committed_transcript_with_timestamps":
            return .committed(body.text ?? "")
        default:
            let lowered = kind.lowercased()
            if lowered.contains("error") || lowered.contains("quota") || lowered.contains("limit") {
                return .failure(body.error.map { "\(kind): \($0)" } ?? kind)
            }
            return .other
        }
    }

    /// One 16 kHz mono Int16 chunk (D4), little-endian as on the phone.
    static func audio(_ samples: [Int16], commit: Bool) -> String {
        let base64 = samples.withUnsafeBytes { Data($0).base64EncodedString() }
        return "{\"message_type\":\"input_audio_chunk\",\"audio_base_64\":\"\(base64)\",\"commit\":\(commit),\"sample_rate\":16000}"
    }
}

protocol ScribeSocket: Sendable {
    func send(_ text: String) async throws
    /// The next text message; throws when the connection ends.
    func receive() async throws -> String
    func close()
}

/// Sendable: `URLSessionWebSocketTask` is thread-safe.
final class URLSessionScribeSocket: ScribeSocket, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(url: URL, session: URLSession = .shared) {
        task = session.webSocketTask(with: url)
        task.resume()
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        switch try await task.receive() {
        case .string(let text): return text
        case .data(let data): return String(decoding: data, as: UTF8.self)
        @unknown default: return ""
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

/// Scribe v2 Realtime over a WebSocket (D44/D47). When the connection fails `results` simply ends, and
/// `TranscriptionCoordinator` falls back to the on-device chain.
@MainActor
final class ScribeProvider: STTProvider {
    nonisolated static let keytermLimit = 20
    /// 200 ms of silence behind a commit flushes the last word (same as the web test).
    private static let commitTail = [Int16](repeating: 0, count: 3_200)

    let engine: STTEngine = .scribe
    let locale: Locale
    let results: AsyncStream<STTResult>

    private let language: TranscriptionLanguage
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming
    private let makeSocket: @Sendable (URL) -> any ScribeSocket
    private let resultsContinuation: AsyncStream<STTResult>.Continuation
    private var keyterms: [String] = []
    private var token: ScribeToken?
    private var socket: (any ScribeSocket)?
    private var feedTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var streamedFrames = 0

    init(locale: Locale, language: TranscriptionLanguage, config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming,
         makeSocket: @escaping @Sendable (URL) -> any ScribeSocket = { URLSessionScribeSocket(url: $0) }) {
        self.locale = locale
        self.language = language
        self.config = config
        self.auth = auth
        self.http = http
        self.makeSocket = makeSocket
        let (stream, continuation) = AsyncStream<STTResult>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.results = stream
        self.resultsContinuation = continuation
    }

    func prepare() async throws(STTError) {
        do {
            var request = try await authorizedRequest()
            request.httpMethod = "GET"
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                if response.statusCode == 401 { auth.invalidate() }
                let failure = AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode)
                throw STTError.startFailed(detail: "\(failure.code) (HTTP \(response.statusCode))")
            }
            token = try JSONDecoder().decode(ScribeToken.self, from: data)
        } catch let error as STTError {
            throw error
        } catch {
            throw .startFailed(detail: error.localizedDescription)
        }
    }

    func start(audio: AsyncStream<AudioChunk>) async throws(STTError) {
        guard let url = token?.url(language: language, keyterms: keyterms) else {
            throw .startFailed(detail: "no token")
        }
        token = nil // single use
        let socket = makeSocket(url)
        self.socket = socket
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(socket)
        }
        feedTask = Task { [weak self] in
            for await chunk in audio {
                guard let self else { return }
                self.streamedFrames += chunk.frameCount
                do {
                    try await socket.send(ScribeMessage.audio(chunk.samples, commit: false))
                } catch {
                    return // the receive loop sees the same failure
                }
            }
        }
    }

    /// Hold-to-ask released: ask for the final now instead of waiting for the pause detection.
    func commit() {
        guard let socket else { return }
        Task { try? await socket.send(ScribeMessage.audio(Self.commitTail, commit: true)) }
    }

    func stop() async {
        feedTask?.cancel()
        feedTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        socket?.close()
        socket = nil
        resultsContinuation.finish()
        let seconds = streamedFrames / Int(LumenAudioFormat.sampleRate)
        streamedFrames = 0
        if seconds > 0 { await reportUsage(seconds: seconds) }
    }

    func setContextualStrings(_ strings: [String]) {
        keyterms = strings
    }

    private func receiveLoop(_ socket: any ScribeSocket) async {
        do {
            while !Task.isCancelled {
                switch ScribeMessage.parse(try await socket.receive()) {
                case .partial(let text):
                    resultsContinuation.yield(STTResult(text: text, isFinal: false))
                case .committed(let text):
                    resultsContinuation.yield(STTResult(text: text, isFinal: true))
                case .failure(let detail):
                    Log.transcription.error("Scribe: \(detail, privacy: .public)")
                    resultsContinuation.finish()
                    return
                case .other:
                    break
                }
            }
        } catch {
            Log.transcription.error("Scribe connection ended: \(error.localizedDescription, privacy: .public)")
            resultsContinuation.finish()
        }
    }

    /// Billing is per second; the backend logs what we streamed (D47). Losing one report is harmless.
    private func reportUsage(seconds: Int) async {
        guard var request = try? await authorizedRequest() else { return }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{\"seconds\":\(min(3_600, seconds))}".utf8)
        _ = try? await http.data(for: request)
    }

    private func authorizedRequest() async throws -> URLRequest {
        let accessToken = try await auth.accessToken()
        var request = URLRequest(url: config.sttTokenURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 8
        return request
    }
}
