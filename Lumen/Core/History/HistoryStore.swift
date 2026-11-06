import Foundation
import Observation

/// One saved exchange (D56): the user's own words and the assistant's answer word for word, plus the server's
/// summary. Speech from other people is never stored here: `question` stays nil when the words were not the user's.
struct HistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var createdAt: Date
    var question: String?
    var answer: String
    var summary: String?
    /// Rizzläge: the suggestions that were offered.
    var suggestions: [String]

    init(id: UUID = UUID(), createdAt: Date = Date(), question: String?, answer: String, summary: String?, suggestions: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.question = question
        self.answer = answer
        self.summary = summary
        self.suggestions = suggestions
    }

    /// The list line: the summary, else what was asked, else the answer.
    var title: String {
        let source = summary ?? question ?? suggestions.first ?? answer
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 90 ? String(trimmed.prefix(87)) + "…" : trimmed
    }
}

/// How long history and memories live (D49).
enum Retention {
    static let years = 2

    static func expiry(from date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        calendar.date(byAdding: .year, value: years, to: date) ?? date
    }

    static func isExpired(_ date: Date, at now: Date) -> Bool {
        expiry(from: date) <= now
    }
}

/// Historik: one JSON file in Application Support, complete file protection, never synced or uploaded.
@MainActor
@Observable
final class HistoryStore {
    static let fileName = "history.json"

    /// Newest first.
    private(set) var entries: [HistoryEntry] = []
    private(set) var lastError: String?
    private let file: LocalJSONFile

    init(directory: URL = NotesStore.defaultDirectory, now: Date = Date()) {
        file = LocalJSONFile(url: directory.appending(path: Self.fileName))
        do {
            entries = (try file.load([HistoryEntry].self) ?? []).sorted { $0.createdAt > $1.createdAt }
        } catch {
            lastError = "Could not read history: \(error.localizedDescription)"
        }
        purgeExpired(now: now)
    }

    func record(_ entry: HistoryEntry, now: Date = Date()) {
        entries.insert(entry, at: 0)
        entries.removeAll { Retention.isExpired($0.createdAt, at: now) }
        persist()
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func deleteAll() {
        entries.removeAll()
        persist()
    }

    /// Automatic deletion after two years.
    func purgeExpired(now: Date = Date()) {
        let kept = entries.filter { !Retention.isExpired($0.createdAt, at: now) }
        guard kept.count != entries.count else { return }
        entries = kept
        persist()
    }

    private func persist() {
        do {
            try file.save(entries)
            lastError = nil
        } catch {
            lastError = "Could not save history: \(error.localizedDescription)"
        }
    }
}

/// Reads and writes one Codable value, on this device only.
struct LocalJSONFile: Sendable {
    let url: URL

    func load<Value: Decodable>(_ type: Value.Type) throws -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    func save(_ value: some Encodable) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtection])
    }
}
