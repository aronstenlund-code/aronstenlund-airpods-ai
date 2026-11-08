import Foundation
import Observation
#if canImport(LumenVAD)
import LumenVAD
#endif

/// D81: a voice embedding, from 16 kHz mono samples in −1…1. On the phone only.
protocol SpeakerEmbedding: Sendable {
    func embedding(_ samples: [Float]) async throws -> [Float]
}

#if canImport(LumenVAD)
/// WeSpeaker (CC-BY-4.0) + pyannote segmentation (MIT) through FluidAudio (Apache-2.0), `LumenVAD`.
struct WeSpeakerEmbedding: SpeakerEmbedding {
    let embedder: SpeakerEmbedder

    static func load() async throws -> WeSpeakerEmbedding {
        WeSpeakerEmbedding(embedder: try await SpeakerEmbedder.load())
    }

    func embedding(_ samples: [Float]) async throws -> [Float] {
        try await embedder.embedding(samples)
    }
}
#endif

/// Loads the embedding models once, in the background (the first time they are downloaded, ~30 MB).
@MainActor
@Observable
final class SpeakerEmbedderLoader {
    enum Status: Equatable, Sendable {
        case idle, loading, ready
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    private(set) var embedder: (any SpeakerEmbedding)?
    private var task: Task<Void, Never>?

    func loadIfNeeded() {
        guard task == nil, embedder == nil else { return }
        #if canImport(LumenVAD)
        status = .loading
        task = Task { [weak self] in
            do {
                let embedder = try await WeSpeakerEmbedding.load()
                self?.embedder = embedder
                self?.status = .ready
            } catch {
                self?.status = .unavailable(error.localizedDescription)
                self?.task = nil // tried again next session
            }
        }
        #else
        status = .unavailable("LumenVAD not linked")
        #endif
    }

    /// Tests inject a fake.
    func use(_ embedder: any SpeakerEmbedding) {
        self.embedder = embedder
        status = .ready
    }
}

/// The wearer's voice (D81): one averaged embedding. Never leaves the phone, never in a backup, deleted with one tap.
struct VoiceProfile: Codable, Equatable, Sendable {
    var embedding: [Float]
    var createdAt: Date
    /// Seconds of speech it was made from.
    var seconds: Double
}

enum VoiceMath {
    /// Cosine similarity, 1 = the same direction.
    static func similarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    /// The mean direction of several embeddings, L2-normalised.
    static func mean(_ vectors: [[Float]]) -> [Float]? {
        guard let first = vectors.first, !first.isEmpty, vectors.allSatisfy({ $0.count == first.count }) else { return nil }
        var sum = [Float](repeating: 0, count: first.count)
        for v in vectors { for i in v.indices { sum[i] += v[i] } }
        return normalized(sum)
    }

    static func normalized(_ v: [Float]) -> [Float] {
        let norm = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }

    static func floats(_ samples: [Int16]) -> [Float] {
        samples.map { Float($0) / 32768 }
    }

    /// Root mean square in dBFS, to tell speech from silence before anything is embedded.
    static func rmsDBFS(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return -120 }
        let mean = samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count)
        return mean > 0 ? 10 * log10(mean) : -120
    }
}

@MainActor
@Observable
final class VoiceProfileStore {
    private(set) var profile: VoiceProfile?
    private let file: URL

    var isEnrolled: Bool { profile != nil }

    init(file: URL? = nil) {
        self.file = file ?? Self.defaultFile
        if let data = try? Data(contentsOf: self.file) {
            profile = try? JSONDecoder().decode(VoiceProfile.self, from: data)
        }
    }

    static var defaultFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("VoiceProfile", isDirectory: true).appendingPathComponent("profile.json")
    }

    func save(_ profile: VoiceProfile) {
        self.profile = profile
        do {
            var directory = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true // on this phone only, not in iCloud or computer backups
            try? directory.setResourceValues(values)
            try JSONEncoder().encode(profile).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.session.error("Voice profile not saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    func delete() {
        profile = nil
        try? FileManager.default.removeItem(at: file)
    }
}

/// Who spoke one stretch of audio (D81).
enum VoiceIdentity: Equatable, Sendable {
    /// The voice profile's owner.
    case wearer
    /// Someone else; `label` is 1, 2, … when the speaker labels are on.
    case other(label: Int?)
    /// Too close to call, or no profile: the level decides as before.
    case uncertain

    var isWearer: Bool { self == .wearer }
    var isOther: Bool { if case .other = self { true } else { false } }
}

/// "Du" / "Talare 1" / "Talare 2": online clustering of the turn embeddings (D81). LS-EEND's licence could not be
/// read (the model card needs a login), so the shipped path clusters WeSpeaker embeddings instead. Pure, tested.
struct SpeakerLabeler: Equatable, Sendable {
    /// Above this the voice is the wearer's (cosine, WeSpeaker). Tuned on device.
    static let wearerSimilarity: Float = 0.5
    /// Below this it is certainly someone else; between the two, uncertain.
    static let otherSimilarity: Float = 0.3
    /// A turn this close to a known speaker is that speaker; otherwise a new one.
    static let sameSpeakerSimilarity: Float = 0.45
    static let maxSpeakers = 6

    struct Cluster: Equatable, Sendable {
        var label: Int
        var centroid: [Float]
        var turns: Int
    }

    private(set) var clusters: [Cluster] = []

    /// The wearer or not, from the profile alone.
    static func match(_ embedding: [Float], profile: VoiceProfile?) -> VoiceIdentity {
        guard let profile else { return .uncertain }
        let similarity = VoiceMath.similarity(embedding, profile.embedding)
        if similarity >= wearerSimilarity { return .wearer }
        if similarity <= otherSimilarity { return .other(label: nil) }
        return .uncertain
    }

    /// The wearer, or a numbered other speaker (labels on).
    mutating func assign(_ embedding: [Float], profile: VoiceProfile?) -> VoiceIdentity {
        let byProfile = Self.match(embedding, profile: profile)
        if byProfile == .wearer { return .wearer }
        if byProfile == .uncertain, profile != nil { return .uncertain }
        let best = clusters.indices.max { VoiceMath.similarity(embedding, clusters[$0].centroid) < VoiceMath.similarity(embedding, clusters[$1].centroid) }
        if let best, VoiceMath.similarity(embedding, clusters[best].centroid) >= Self.sameSpeakerSimilarity {
            var cluster = clusters[best]
            let weight = Float(cluster.turns)
            cluster.centroid = VoiceMath.normalized(zip(cluster.centroid, embedding).map { ($0 * weight + $1) / (weight + 1) })
            cluster.turns += 1
            clusters[best] = cluster
            return .other(label: cluster.label)
        }
        if clusters.count >= Self.maxSpeakers {
            // A seventh voice joins the closest one rather than growing the list.
            return .other(label: best.map { clusters[$0].label })
        }
        let label = (clusters.map(\.label).max() ?? 0) + 1
        clusters.append(Cluster(label: label, centroid: VoiceMath.normalized(embedding), turns: 1))
        return .other(label: label)
    }

    mutating func reset() { clusters = [] }

    static func text(_ identity: VoiceIdentity, swedish: Bool) -> String? {
        switch identity {
        case .wearer: swedish ? "Du" : "You"
        case .other(let label?): swedish ? "Talare \(label)" : "Speaker \(label)"
        case .other(.none), .uncertain: nil
        }
    }
}
