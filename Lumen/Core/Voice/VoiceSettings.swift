import Foundation
import Observation

/// Voice, speed and "speak answers" (item 5 / item 6 silent mode), persisted in UserDefaults.
@MainActor
@Observable
final class VoiceSettings {
    static let voiceKey = "voice.choice"
    static let rateKey = "voice.rate"
    static let speakKey = "voice.speakAnswers"

    var voice: VoiceChoice {
        didSet {
            if let data = try? JSONEncoder().encode(voice) { defaults.set(data, forKey: Self.voiceKey) }
        }
    }
    /// Playback rate without pitch change, 0.5…2.0.
    var rate: Float {
        didSet {
            let clamped = min(2.0, max(0.5, rate))
            if clamped != rate { rate = clamped }
            defaults.set(Double(rate), forKey: Self.rateKey)
        }
    }
    /// Off = silent mode: answers are only shown (item 6).
    var speakAnswers: Bool {
        didSet { defaults.set(speakAnswers, forKey: Self.speakKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.voice = defaults.data(forKey: Self.voiceKey).flatMap { try? JSONDecoder().decode(VoiceChoice.self, from: $0) } ?? .appleDefault
        let storedRate = defaults.object(forKey: Self.rateKey) as? Double
        self.rate = Float(storedRate ?? 1.0)
        self.speakAnswers = defaults.object(forKey: Self.speakKey) as? Bool ?? true
    }
}

/// The three allowlisted ElevenLabs voices from `GET /voices` (D23). Tolerant of the exact JSON shape
/// (`{voices:[{name,id}]}` or `{voices:[{name,voice_id}]}`), because the endpoint is being built by Kevin.
@MainActor
@Observable
final class VoiceCatalog {
    enum Status: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var voices: [VoiceChoice] = []
    private(set) var status: Status = .idle
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    /// Loads once per app run (or again after a failure).
    func refreshIfNeeded() async {
        switch status {
        case .loaded, .loading: return
        case .idle, .failed: await refresh()
        }
    }

    func refresh() async {
        status = .loading
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.voicesURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.timeoutInterval = 15
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                let failure = AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode)
                throw AnswerError.backend(status: response.statusCode, failure: failure)
            }
            voices = try Self.decode(data)
            status = .loaded
        } catch {
            status = .failed(AnswerError.from(error).localizedDescription)
        }
    }

    static func decode(_ data: Data) throws(AnswerError) -> [VoiceChoice] {
        struct Entry: Decodable {
            var name: String
            var id: String?
            var voice_id: String?
            var voiceId: String?
        }
        struct Wrapped: Decodable { var voices: [Entry] }
        let entries: [Entry]
        if let wrapped = try? JSONDecoder().decode(Wrapped.self, from: data) {
            entries = wrapped.voices
        } else if let list = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = list
        } else {
            throw AnswerError.decoding(detail: "voices: unexpected JSON")
        }
        return entries.compactMap { entry in
            guard let id = entry.id ?? entry.voice_id ?? entry.voiceId, !id.isEmpty else { return nil }
            return VoiceChoice(kind: .elevenLabs, voiceID: id, name: entry.name)
        }
    }
}
