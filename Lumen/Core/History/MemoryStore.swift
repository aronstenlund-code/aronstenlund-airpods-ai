import Foundation
import Observation

/// Something Lumen remembers about the user (D49/D80). Expires two years after it was last confirmed.
struct MemoryItem: Identifiable, Codable, Equatable, Sendable {
    /// A fact about the user, or a rule for how Lumen answers ("svara alltid kort").
    enum Kind: String, Codable, Sendable { case fact, rule }
    /// Said ("Lumen, kom ihåg …"), typed in Settings, or found in a turn by the backend's extraction (D80).
    enum Source: String, Codable, Sendable { case voice, manual, automatic }

    let id: UUID
    var text: String
    var createdAt: Date
    var confirmedAt: Date
    var kind: Kind
    var source: Source

    init(id: UUID, text: String, createdAt: Date, confirmedAt: Date, kind: Kind = .fact, source: Source = .manual) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.kind = kind
        self.source = source
    }

    /// Items saved before D80 have no kind or source.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        confirmedAt = try container.decode(Date.self, forKey: .confirmedAt)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .fact
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .manual
    }
}

/// Minne: what the user said or typed, and since D80 what the backend found about the user in a turn (shown, editable,
/// deletable; never a sensitive category). Rules are kept here too. Stored on this device, sent as `memories`.
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

    /// What goes to the backend: the newest unexpired items; rules marked as rules.
    func backendItems(now: Date = Date()) -> [String] {
        Array(items.lazy.filter { !Retention.isExpired($0.confirmedAt, at: now) }
            .map { $0.kind == .rule ? "Regel: \($0.text)" : $0.text }.prefix(Self.maxSent))
    }

    var facts: [MemoryItem] { items.filter { $0.kind == .fact } }
    var rules: [MemoryItem] { items.filter { $0.kind == .rule } }

    /// "Lumen, glöm …": removes every item that contains the words. Returns how many.
    @discardableResult
    func forget(_ words: String) -> Int {
        let needle = Self.key(words)
        guard !needle.isEmpty else { return 0 }
        let before = items.count
        items.removeAll { Self.key($0.text).contains(needle) }
        let removed = before - items.count
        if removed > 0 { persist() }
        return removed
    }

    /// Adds a memory. Saying the same thing again confirms it, which restarts its two years.
    @discardableResult
    func add(_ text: String, at date: Date = Date(), kind: MemoryItem.Kind = .fact, source: MemoryItem.Source = .manual) -> MemoryItem? {
        let clean = Self.clean(text)
        guard !clean.isEmpty else { return nil }
        if source == .automatic, SensitiveFilter.isSensitive(clean) { return nil } // D80: never saved by itself
        if let index = items.firstIndex(where: { Self.key($0.text) == Self.key(clean) }) {
            var item = items.remove(at: index)
            item.confirmedAt = date
            items.insert(item, at: 0)
            persist()
            return item
        }
        let item = MemoryItem(id: UUID(), text: clean, createdAt: date, confirmedAt: date, kind: kind, source: source)
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
