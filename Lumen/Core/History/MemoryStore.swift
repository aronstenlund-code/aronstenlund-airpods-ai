import Foundation
import Observation

/// Something the user asked Lumen to remember (D49). Expires two years after it was last confirmed.
struct MemoryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var text: String
    var createdAt: Date
    var confirmedAt: Date
}

/// Minne: only what the user said ("kom ihåg …" → `memory_add`) or typed in Settings; nothing is ever inferred.
/// Stored on this device, sent as `memories` with each request.
@MainActor
@Observable
final class MemoryStore {
    static let fileName = "memories.json"
    /// Backend limits: 413 above these.
    static let maxSent = 30
    static let textLimit = 200

    /// Most recently confirmed first.
    private(set) var items: [MemoryItem] = []
    private(set) var lastError: String?
    private let file: LocalJSONFile

    init(directory: URL = NotesStore.defaultDirectory, now: Date = Date()) {
        file = LocalJSONFile(url: directory.appending(path: Self.fileName))
        do {
            items = (try file.load([MemoryItem].self) ?? []).sorted { $0.confirmedAt > $1.confirmedAt }
        } catch {
            lastError = "Could not read memories: \(error.localizedDescription)"
        }
        purgeExpired(now: now)
    }

    /// What goes to the backend: the newest unexpired items.
    func backendItems(now: Date = Date()) -> [String] {
        Array(items.lazy.filter { !Retention.isExpired($0.confirmedAt, at: now) }.map(\.text).prefix(Self.maxSent))
    }

    /// Adds a memory. Saying the same thing again confirms it, which restarts its two years.
    @discardableResult
    func add(_ text: String, at date: Date = Date()) -> MemoryItem? {
        let clean = Self.clean(text)
        guard !clean.isEmpty else { return nil }
        if let index = items.firstIndex(where: { Self.key($0.text) == Self.key(clean) }) {
            var item = items.remove(at: index)
            item.confirmedAt = date
            items.insert(item, at: 0)
            persist()
            return item
        }
        let item = MemoryItem(id: UUID(), text: clean, createdAt: date, confirmedAt: date)
        items.insert(item, at: 0)
        persist()
        return item
    }

    /// Editing confirms the item. Empty text is ignored; delete is its own action.
    func update(_ item: MemoryItem, text: String, at date: Date = Date()) {
        let clean = Self.clean(text)
        guard !clean.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].text = clean
        items[index].confirmedAt = date
        items.sort { $0.confirmedAt > $1.confirmedAt }
        persist()
    }

    func delete(_ item: MemoryItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func deleteAll() {
        items.removeAll()
        persist()
    }

    func purgeExpired(now: Date = Date()) {
        let kept = items.filter { !Retention.isExpired($0.confirmedAt, at: now) }
        guard kept.count != items.count else { return }
        items = kept
        persist()
    }

    private static func clean(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(textLimit))
    }

    private static func key(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    private func persist() {
        do {
            try file.save(items)
            lastError = nil
        } catch {
            lastError = "Could not save memories: \(error.localizedDescription)"
        }
    }
}
