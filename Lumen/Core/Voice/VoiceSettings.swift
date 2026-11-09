import Foundation
import Observation

/// Voice, speed and "speak answers" (item 5 / item 6 silent mode), persisted in UserDefaults.
@MainActor
@Observable
final class VoiceSettings {
    static let voiceKey = "voice.choice"
    static let rateKey = "voice.rate"
    static let speakKey = "voice.speakAnswers"
    static let gainKey = "voice.gain"
    static let universalKey = "voice.universalCommands"

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
    /// A7 "viska" / "högre": Lumen's own loudness on the player node (0.25…1), not the iPhone's volume.
    var speechGain: Double {
        didSet {
            let clamped = min(1, max(Self.minimumGain, speechGain))
            if clamped != speechGain { speechGain = clamped }
            defaults.set(speechGain, forKey: Self.gainKey)
        }
    }
    static let minimumGain = 0.25
    /// A7: "upprepa", "viska", "kortare", "utveckla" … without "Lumen" in Provläge and Frågor.
    var universalCommands: Bool {
        didSet { defaults.set(universalCommands, forKey: Self.universalKey) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.speechGain = defaults.object(forKey: Self.gainKey) as? Double ?? 1
        self.universalCommands = defaults.object(forKey: Self.universalKey) as? Bool ?? true
        self.voice = defaults.data(forKey: Self.voiceKey).flatMap { try? JSONDecoder().decode(VoiceChoice.self, from: $0) } ?? .appleDefault
        let storedRate = defaults.object(forKey: Self.rateKey) as? Double
        self.rate = Float(storedRate ?? 1.0)
        self.speakAnswers = defaults.object(forKey: Self.speakKey) as? Bool ?? true
    }

    /// Brings the choice in line with `GET /voices`: the server's default until the user has picked a voice
    /// (D32), and never a voice the backend no longer allows (`/tts` would answer `400 invalid_voice`).
    func reconcile(with voices: [VoiceChoice], defaultID: String?) {
        let fallback = voices.first { $0.voiceID == defaultID } ?? voices.first
        if voice.kind == .elevenLabs {
            voice = voices.first { $0.voiceID == voice.voiceID } ?? fallback ?? .appleDefault
        } else if defaults.data(forKey: Self.voiceKey) == nil, let fallback {
            voice = fallback
        }
    }
}

/// The allowlisted ElevenLabs voices from `GET /voices` (D23): `{voices:[{name,id}],default_id}`.
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
    private(set) var defaultID: String?
    private(set) var status: Status = .idle
    /// Called after every successful load.
    var onLoaded: (@MainActor ([VoiceChoice], String?) -> Void)?
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
                if response.statusCode == 401 { auth.invalidate() }
                let failure = AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode)
                throw AnswerError.backend(status: response.statusCode, failure: failure)
            }
            (voices, defaultID) = try Self.decode(data)
            status = .loaded
            onLoaded?(voices, defaultID)
        } catch {
            status = .failed(AnswerError.from(error).localizedDescription)
        }
    }

    static func decode(_ data: Data) throws(AnswerError) -> (voices: [VoiceChoice], defaultID: String?) {
        struct Listing: Decodable {
            struct Entry: Decodable {
                var name: String
                var id: String
            }
            var voices: [Entry]
            var default_id: String?
        }
        do {
            let listing = try JSONDecoder().decode(Listing.self, from: data)
            return (listing.voices.map { VoiceChoice(kind: .elevenLabs, voiceID: $0.id, name: $0.name) }, listing.default_id)
        } catch {
            throw AnswerError.decoding(detail: "voices: \(error.localizedDescription)")
        }
    }
}
