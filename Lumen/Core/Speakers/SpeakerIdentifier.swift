import Foundation
import Observation

/// D81: who is speaking, from the voice. Every embedding runs beside the answer path, never in it: a turn that
/// is not identified yet is decided by the level as before (the answer time never grows, D80).
@MainActor
@Observable
final class SpeakerIdentifier {
    let loader: SpeakerEmbedderLoader
    let profiles: VoiceProfileStore
    private let defaults: UserDefaults
    static let labelsKey = "speakers.labels"

    /// "Du" / "Talare 1" / "Talare 2" in the live transcript.
    var showsLabels: Bool {
        didSet { defaults.set(showsLabels, forKey: Self.labelsKey) }
    }
    private(set) var labeler = SpeakerLabeler()
    /// The last few results, newest last.
    private(set) var recent: [(at: Date, identity: VoiceIdentity)] = []
    /// Called on the main actor when a stretch has been identified (labels the transcript).
    var onIdentified: (@MainActor (VoiceIdentity, Date) -> Void)?
    /// For the 10-minute resource log.
    private(set) var embeddings = 0
    private(set) var embeddingMilliseconds: Double = 0
    private var running = 0

    /// Shortest stretch worth embedding, and the longest used.
    static let minimumSeconds: Double = 1.0
    static let maximumSeconds: Double = 6.0
    /// Quieter than this is no voice.
    static let silenceDBFS: Double = -50

    init(loader: SpeakerEmbedderLoader = SpeakerEmbedderLoader(), profiles: VoiceProfileStore = VoiceProfileStore(),
         defaults: UserDefaults = .standard) {
        self.loader = loader
        self.profiles = profiles
        self.defaults = defaults
        self.showsLabels = defaults.object(forKey: Self.labelsKey) as? Bool ?? true
    }

    /// Something to do: a profile to compare with, or labels to show.
    var isWanted: Bool { profiles.isEnrolled || showsLabels }
    var isReady: Bool { loader.embedder != nil }

    /// A session starts: load the models in the background if anything needs them.
    func sessionStarted() {
        labeler.reset()
        recent = []
        if isWanted { loader.loadIfNeeded() }
    }

    /// Identify the stretch that just ended at `at`. Fire and forget; the result lands in `recent`.
    func identify(_ samples: [Int16], at date: Date) {
        guard isWanted, let embedder = loader.embedder, running < 2 else { return }
        let floats = VoiceMath.floats(samples)
        guard Double(floats.count) >= Self.minimumSeconds * LumenAudioFormat.sampleRate,
              VoiceMath.rmsDBFS(floats) > Self.silenceDBFS else { return }
        running += 1
        let started = ContinuousClock.now
        Task { [weak self] in
            let embedding = try? await embedder.embedding(floats)
            guard let self else { return }
            self.running -= 1
            guard let embedding else { return }
            let elapsed = ContinuousClock.now - started
            self.embeddings += 1
            self.embeddingMilliseconds += Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
            let identity = self.showsLabels ? self.labeler.assign(embedding, profile: self.profiles.profile)
                                            : SpeakerLabeler.match(embedding, profile: self.profiles.profile)
            self.recent.append((date, identity))
            if self.recent.count > 20 { self.recent.removeFirst(self.recent.count - 20) }
            self.onIdentified?(identity, date)
        }
    }

    /// The newest result for speech that ended within `window` seconds before `date`. Nil: not known (yet).
    func identity(near date: Date = Date(), window: TimeInterval = 6) -> VoiceIdentity? {
        recent.last { $0.at <= date.addingTimeInterval(1) && date.timeIntervalSince($0.at) <= window }?.identity
    }

    /// Barge-in (D81): is the voice that broke in the wearer's? Nil without a profile or the models.
    func isWearer(_ samples: [Int16]) async -> Bool? {
        guard let profile = profiles.profile, let embedder = loader.embedder else { return nil }
        let floats = VoiceMath.floats(samples)
        guard VoiceMath.rmsDBFS(floats) > Self.silenceDBFS,
              let embedding = try? await embedder.embedding(floats) else { return nil }
        return SpeakerLabeler.match(embedding, profile: profile) == .wearer
    }

    // MARK: - "Lär dig min röst"

    enum EnrollResult: Equatable, Sendable {
        case saved(seconds: Double)
        case tooLittleSpeech
        case modelsUnavailable
    }

    /// ~10 s of the wearer reading aloud → windows of 3 s → one averaged embedding, saved on the phone.
    func enroll(_ samples: [Int16]) async -> EnrollResult {
        loader.loadIfNeeded()
        for _ in 0..<600 where loader.embedder == nil {
            if case .unavailable = loader.status { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard let embedder = loader.embedder else { return .modelsUnavailable }
        let floats = VoiceMath.floats(samples)
        let window = Int(3 * LumenAudioFormat.sampleRate)
        var vectors: [[Float]] = []
        var speechSamples = 0
        var coveredUntil = 0
        var start = 0
        while start + window <= floats.count {
            let slice = Array(floats[start..<(start + window)])
            if VoiceMath.rmsDBFS(slice) > Self.silenceDBFS, let embedding = try? await embedder.embedding(slice) {
                vectors.append(embedding)
                speechSamples += start + window - max(start, coveredUntil) // overlapping windows count once
                coveredUntil = start + window
            }
            start += window * 3 / 4 // 2.25 s steps: the windows overlap a little
        }
        let speechSeconds = Double(speechSamples) / LumenAudioFormat.sampleRate
        guard vectors.count >= 2, let mean = VoiceMath.mean(vectors) else { return .tooLittleSpeech }
        profiles.save(VoiceProfile(embedding: mean, createdAt: Date(), seconds: speechSeconds))
        return .saved(seconds: speechSeconds)
    }

    func deleteProfile() {
        profiles.delete()
        labeler.reset()
        recent = []
    }

    /// Counts for the resource log, then zero.
    func takeStats() -> (count: Int, averageMs: Double) {
        defer { embeddings = 0; embeddingMilliseconds = 0 }
        return (embeddings, embeddings > 0 ? embeddingMilliseconds / Double(embeddings) : 0)
    }
}
