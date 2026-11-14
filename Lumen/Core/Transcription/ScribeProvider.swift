import Foundation
import Observation

/// Taligenkänning (D44): Scribe in the cloud by default, or only on the phone.
@MainActor
@Observable
final class STTSettings {
    static let cloudKey = "stt.useCloud"
    static let localVADKey = "stt.localVAD"
    static let focusKey = "stt.focusOnWearer"

    var useCloud: Bool {
        didSet { defaults.set(useCloud, forKey: Self.cloudKey) }
    }
    /// Silero on the phone decides what is speech before anything goes to Scribe (D78). On by default.
    var useLocalVAD: Bool {
        didSet { defaults.set(useLocalVAD, forKey: Self.localVADKey) }
    }
    /// A10: in Provläge and Frågor only the wearer's (louder) voice reaches Scribe. On by default.
    var focusOnWearer: Bool {
        didSet { defaults.set(focusOnWearer, forKey: Self.focusKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.focusOnWearer = defaults.object(forKey: Self.focusKey) as? Bool ?? true
        self.useCloud = defaults.object(forKey: Self.cloudKey) as? Bool ?? true
        self.useLocalVAD = defaults.object(forKey: Self.localVADKey) as? Bool ?? true
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
    func url(language: TranscriptionLanguage, keyterms: [String], tuning: ScribeTuning = .standard) -> URL? {
        guard var components = URLComponents(string: ws_url) else { return nil }
        var items = [URLQueryItem(name: "model_id", value: model_id),
                     URLQueryItem(name: "token", value: token),
                     URLQueryItem(name: "language_code", value: language == .swedish ? "swe" : "eng"),
                     URLQueryItem(name: "audio_format", value: "pcm_16000"),
                     URLQueryItem(name: "commit_strategy", value: "vad")]
        items += tuning.queryItems // D78: pause detection per mode
        items += ScribeKeyterms.sanitized(keyterms).map { URLQueryItem(name: "keyterms", value: $0) } // A8.5
        items += URLComponents(string: "?" + (extra_query ?? ""))?.queryItems ?? []
        components.queryItems = items
        return components.url
    }
}

/// A8.5: Scribe closes the whole session (1008 `invalid_request`) when one keyterm is longer than 20 characters,
/// and `/study-profile` sends terms up to 40. Every term that reaches the socket goes through here. Pure.
enum ScribeKeyterms {
    static let maxLength = 20
    static let maxCount = 20
    /// Words that carry nothing for the recogniser when a long term has to be split.
    private static let fillers: Set<String> = ["och", "i", "av", "på", "en", "ett", "den", "det", "de", "för", "med", "till",
                                               "om", "som", "the", "of", "and", "a", "an", "in", "on", "to", "for"]

    /// At most 20 terms of at most 20 characters, each once (case-insensitive), in the given order. A longer term is
    /// split into runs of whole words that fit ("Kristendomens införande" → "Kristendomens", "införande"), filler
    /// words dropped; a single word that is still too long is cut at 20.
    static func sanitized(_ terms: [String]) -> [String] {
        var out: [String] = []
        func add(_ raw: String) {
            let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty, out.count < maxCount,
                  !out.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else { return }
            out.append(term)
        }
        for raw in terms {
            guard out.count < maxCount else { break }
            let term = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if term.count <= maxLength {
                add(term)
                continue
            }
            let words = term.split(separator: " ").map(String.init).filter { !fillers.contains($0.lowercased()) }
            var run = ""
            for word in words {
                let piece = word.count > maxLength ? String(word.prefix(maxLength)) : word
                if run.isEmpty {
                    run = piece
                } else if run.count + 1 + piece.count <= maxLength {
                    run += " " + piece
                } else {
                    add(run)
                    run = piece
                }
            }
            if !run.isEmpty, run.count >= 2 { add(run) }
        }
        return out
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
            if lowered.contains("error") || lowered.contains("quota") || lowered.contains("limit") || lowered.contains("invalid") {
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

/// The server closed the socket; `code` 1008 is a policy close (`invalid_request`).
struct ScribeClosed: Error, LocalizedError, Equatable {
    var code: Int
    var reason: String
    var errorDescription: String? { "closed \(code) \(reason)" }
    var isInvalidRequest: Bool { code == 1008 || reason.contains("invalid_request") }
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
        do {
            switch try await task.receive() {
            case .string(let text): return text
            case .data(let data): return String(decoding: data, as: UTF8.self)
            @unknown default: return ""
            }
        } catch {
            // A8.5: the close code and reason say why Scribe ended (1008 `invalid_request` for a bad keyterm).
            guard task.closeCode != .invalid else { throw error }
            let reason = task.closeReason.map { String(decoding: $0, as: UTF8.self) } ?? ""
            throw ScribeClosed(code: task.closeCode.rawValue, reason: reason)
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
    private var tuning = ScribeTuning.standard
    private var token: ScribeToken?
    private var socket: (any ScribeSocket)?
    private var feedTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var streamedFrames = 0
    private var keepAliveTask: Task<Void, Never>?
    private var lastSentAt = Date()
    /// A11: with the local VAD in front, minutes of silence send nothing, and Scribe ends a session that gets no
    /// audio for about 20 s (Toby T2: 21–32 s, again and again, once the VAD was ready). A quarter second of silence
    /// every `keepAliveInterval` keeps it open (≈ 3 % of the silent time billed).
    nonisolated static let keepAliveInterval: TimeInterval = 8
    private static let keepAliveSamples = [Int16](repeating: 0, count: 4_000)
    /// Why the session ended by itself, for the coordinator (A8.5). Nil while it runs or after a normal stop.
    private(set) var endReason: String?
    /// The server refused the request (1008 / `invalid_request`): reopening with the same keyterms fails again.
    var endedAsInvalidRequest: Bool {
        guard let endReason else { return false }
        return endReason.contains("1008") || endReason.lowercased().contains("invalid") || endReason.lowercased().contains("keyterm")
    }

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
        guard let url = token?.url(language: language, keyterms: keyterms, tuning: tuning) else {
            throw .startFailed(detail: "no token")
        }
        token = nil // single use
        let socket = makeSocket(url)
        self.socket = socket
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(socket)
        }
        lastSentAt = Date()
        feedTask = Task { [weak self] in
            for await chunk in audio {
                guard let self else { return }
                self.streamedFrames += chunk.frameCount
                self.lastSentAt = Date()
                do {
                    try await socket.send(ScribeMessage.audio(chunk.samples, commit: false))
                } catch {
                    return // the receive loop sees the same failure
                }
            }
        }
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard Date().timeIntervalSince(self.lastSentAt) >= Self.keepAliveInterval else { continue }
                self.lastSentAt = Date()
                self.streamedFrames += Self.keepAliveSamples.count
                try? await socket.send(ScribeMessage.audio(Self.keepAliveSamples, commit: false))
            }
        }
    }

    /// Hold-to-ask released: ask for the final now instead of waiting for the pause detection.
    func commit() {
        guard let socket else { return }
        Task { try? await socket.send(ScribeMessage.audio(Self.commitTail, commit: true)) }
    }

    func stop() async {
        keepAliveTask?.cancel()
        keepAliveTask = nil
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

    func setScribeTuning(_ tuning: ScribeTuning) {
        self.tuning = tuning
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
                    endReason = detail
                    Log.transcription.error("Scribe: \(detail, privacy: .public)")
                    resultsContinuation.finish()
                    return
                case .other:
                    break
                }
            }
        } catch {
            if endReason == nil { endReason = error.localizedDescription }
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
        request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
        request.timeoutInterval = 8
        return request
    }
}
