import Foundation

/// ElevenLabs through Kevin's `POST /tts` proxy (D18/D23): `pcm_24000` streamed straight into the 24 kHz
/// playback graph (D16), so the first words play before the request has finished.
@MainActor
final class ElevenLabsTTSProvider: TTSProvider {
    static let textLimit = 500
    static let sampleRate: Double = 24_000
    /// 100 ms of 16-bit mono at 24 kHz per scheduled buffer.
    static let bufferBytes = 4_800

    let name = "elevenlabs"
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming
    private let playback: any PlaybackServicing

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming, playback: any PlaybackServicing) {
        self.config = config
        self.auth = auth
        self.http = http
        self.playback = playback
    }

    func speak(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice) async throws(TTSError) {
        for piece in Self.pieces(text) {
            try await speakPiece(piece, language: language, voice: voice)
        }
    }

    /// D80: fetched ahead of the pause. One piece only (a first sentence is short); longer text is spoken normally.
    func synthesize(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice) async throws(TTSError) -> (samples: [Int16], sampleRate: Double)? {
        let pieces = Self.pieces(text)
        guard pieces.count == 1, let piece = pieces.first else { return nil }
        var samples: [Int16] = []
        try await stream(piece, language: language, voice: voice) { (chunk: [Int16]) throws(AudioError) -> Void in
            samples += chunk
        }
        return (samples, Self.sampleRate)
    }

    private func speakPiece(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice) async throws(TTSError) {
        var scheduled = 0
        let playback = self.playback
        try await stream(text, language: language, voice: voice) { (samples: [Int16]) throws(AudioError) -> Void in
            try playback.play(samples: samples, sampleRate: Self.sampleRate)
            scheduled += samples.count
        }
        Log.playback.info("ElevenLabs: \(text.count, privacy: .public) chars → \(scheduled, privacy: .public) samples scheduled")
    }

    /// The `/tts` request; every 100 ms of PCM goes to `handle` as it arrives.
    private func stream(_ text: String, language: TranscriptionLanguage, voice: VoiceChoice,
                        handle: ([Int16]) throws(AudioError) -> Void) async throws(TTSError) {
        let token: String
        do {
            token = try await auth.accessToken()
        } catch {
            throw TTSError.network(error)
        }
        var request = URLRequest(url: config.ttsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = Self.encodeBody(text: text, language: language, voiceID: voice.kind == .elevenLabs ? voice.voiceID : nil)

        let response: HTTPURLResponse
        let bytes: AsyncThrowingStream<Data, any Error>
        do {
            (response, bytes) = try await http.bytes(for: request)
        } catch {
            throw TTSError.network(AnswerError.from(error))
        }
        guard response.statusCode == 200 else {
            var body = Data()
            do {
                for try await chunk in bytes { body.append(chunk) }
            } catch {}
            let failure = AnswerSSEDecoder.decodeErrorBody(body, status: response.statusCode)
            if response.statusCode == 401 {
                auth.invalidate()
                throw TTSError.network(.unauthorized(detail: failure.code))
            }
            throw TTSError.network(.backend(status: response.statusCode, failure: failure))
        }

        var assembler = PCM16Assembler()
        do {
            for try await chunk in bytes {
                try Task.checkCancellation()
                for samples in assembler.feed(chunk, minimumBytes: Self.bufferBytes) {
                    try handle(samples)
                }
            }
            try Task.checkCancellation() // a cancelled stream just ends: no stray tail after `playback.stop()`
            if let rest = assembler.flush() {
                try handle(rest)
            }
        } catch let error as AudioError {
            throw TTSError.audio(detail: error.localizedDescription)
        } catch {
            if error is CancellationError { throw TTSError.cancelled }
            throw TTSError.network(AnswerError.from(error))
        }
    }

    static func encodeBody(text: String, language: TranscriptionLanguage, voiceID: String?) -> Data {
        struct Body: Encodable {
            var text: String
            var language: String
            var output_format: String
            var voice_id: String?
        }
        let body = Body(text: text, language: language == .swedish ? "sv" : "en", output_format: "pcm_24000", voice_id: voiceID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(body)) ?? Data("{}".utf8)
    }

    /// Splits text longer than the backend's 500-character limit at word boundaries.
    static func pieces(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > textLimit else { return trimmed.isEmpty ? [] : [trimmed] }
        var pieces: [String] = []
        var current = ""
        for word in trimmed.split(separator: " ") {
            if current.count + word.count + 1 > textLimit, !current.isEmpty {
                pieces.append(current)
                current = ""
            }
            current += current.isEmpty ? String(word) : " \(word)"
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}

/// Reassembles little-endian 16-bit PCM from arbitrary byte chunks (a sample may straddle two chunks).
struct PCM16Assembler: Sendable {
    private var pending = Data()

    init() {}

    /// Appends `chunk`; returns whole-sample buffers of at least `minimumBytes` bytes each.
    mutating func feed(_ chunk: Data, minimumBytes: Int) -> [[Int16]] {
        pending.append(chunk)
        var out: [[Int16]] = []
        while pending.count >= max(2, minimumBytes) {
            let take = pending.count - (pending.count % 2)
            let count = max(2, minimumBytes) <= take ? take : 0
            guard count > 0 else { break }
            out.append(Self.samples(pending.prefix(count)))
            pending.removeFirst(count)
        }
        return out
    }

    /// Whatever is left (dropping a trailing odd byte).
    mutating func flush() -> [Int16]? {
        let count = pending.count - (pending.count % 2)
        defer { pending = Data() }
        guard count > 0 else { return nil }
        return Self.samples(pending.prefix(count))
    }

    private static func samples(_ data: Data) -> [Int16] {
        var samples = [Int16](repeating: 0, count: data.count / 2)
        var index = data.startIndex
        for i in 0..<samples.count {
            let low = UInt16(data[index])
            let high = UInt16(data[data.index(after: index)])
            samples[i] = Int16(bitPattern: low | (high << 8))
            index = data.index(index, offsetBy: 2)
        }
        return samples
    }
}
