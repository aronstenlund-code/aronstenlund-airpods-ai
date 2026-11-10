import Foundation
import Observation

/// A49 (D123, C5): one night in Sömnläge. Everything stays on the phone: the clips of what was said, the text the
/// phone's own speech recognition made of them, the minutes of snoring and the restless periods. Nothing is sent.
struct SleepTalk: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var at: Date
    var seconds: Double
    /// The phone's transcript; nil when it heard words it could not make out.
    var text: String?
    /// The clip's file name in the night's folder.
    var clip: String
}

struct SleepNight: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date?
    var talks: [SleepTalk] = []
    var snoreSeconds: Double = 0
    /// Noises that are not speech or snoring (coughs, rustling, movement), by time.
    var noises: [Date] = []
    var snores: [Date] = []
    /// Battery used over the night, percent, when iOS said.
    var batteryUsed: Double?

    var snoreMinutes: Int { Int((snoreSeconds / 60).rounded()) }

    /// "Du pratade 3 gånger i sömnen".
    var talkLine: String {
        switch talks.count {
        case 0: return "Du pratade inte i sömnen"
        case 1: return "Du pratade 1 gång i sömnen"
        default: return "Du pratade \(talks.count) gånger i sömnen"
        }
    }

    /// The night in 10-minute parts for the timeline: talk beats snoring beats restless beats calm.
    func timeline(minutes: Int = 10) -> [SleepSlot] {
        guard let end, end > start else { return [] }
        let length = TimeInterval(minutes * 60)
        var slots: [SleepSlot] = []
        var from = start
        while from < end {
            let to = min(end, from.addingTimeInterval(length))
            let inside = { (date: Date) in date >= from && date < to }
            let kind: SleepSlot.Kind
            if talks.contains(where: { inside($0.at) }) {
                kind = .talk
            } else if snores.filter(inside).count >= SleepSlot.snoreLimit {
                kind = .snoring
            } else if noises.filter(inside).count >= SleepSlot.restlessLimit {
                kind = .restless
            } else {
                kind = .calm
            }
            slots.append(SleepSlot(start: from, kind: kind))
            from = to
        }
        return slots
    }

    /// "Oroligt 02:10–02:40" style periods, from the timeline.
    var restlessPeriods: Int {
        var count = 0
        var previous: SleepSlot.Kind?
        for slot in timeline() {
            if slot.kind == .restless, previous != .restless { count += 1 }
            previous = slot.kind
        }
        return count
    }
}

struct SleepSlot: Equatable, Sendable {
    enum Kind: String, Sendable { case calm, restless, snoring, talk }
    static let restlessLimit = 6 // noises in 10 minutes
    static let snoreLimit = 12 // snoring marks (one per 5 s at most) in 10 minutes: a minute of snoring
    var start: Date
    var kind: Kind
}

/// The nights on disk (Application Support/Sleep), one JSON file and a folder of clips per night. A night and its
/// clips are deleted after 30 days, or at once by the user.
@MainActor
@Observable
final class SleepStore {
    static let keepDays = 30
    private(set) var nights: [SleepNight] = []
    let directory: URL

    init(directory: URL = SleepStore.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Sleep", isDirectory: true)
    }

    var latest: SleepNight? { nights.first }

    func folder(for night: SleepNight) -> URL {
        directory.appendingPathComponent(night.id.uuidString, isDirectory: true)
    }

    func clipURL(_ talk: SleepTalk, in night: SleepNight) -> URL {
        folder(for: night).appendingPathComponent(talk.clip)
    }

    func save(_ night: SleepNight) {
        if let index = nights.firstIndex(where: { $0.id == night.id }) { nights[index] = night } else { nights.insert(night, at: 0) }
        nights.sort { $0.start > $1.start }
        persist()
    }

    func delete(_ night: SleepNight) {
        try? FileManager.default.removeItem(at: folder(for: night))
        nights.removeAll { $0.id == night.id }
        persist()
    }

    /// Nights older than 30 days go, with their clips.
    func removeOld(now: Date = Date()) {
        let limit = now.addingTimeInterval(-Double(Self.keepDays) * 86_400)
        for night in nights where (night.end ?? night.start) < limit { delete(night) }
    }

    private var file: URL { directory.appendingPathComponent("nights.json") }

    private func load() {
        guard let data = try? Data(contentsOf: file) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        nights = ((try? decoder.decode([SleepNight].self, from: data)) ?? []).sorted { $0.start > $1.start }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(nights) else { return }
        try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
