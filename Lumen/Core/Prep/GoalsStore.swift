import Foundation
import Observation

/// Course goals (Målbeskrivning, D37): pasted or imported text, stored locally; a compact version (≤ 1 500 chars
/// plus key terms) goes to `/answer` as `goals` so answers match the course level.
@MainActor
@Observable
final class GoalsStore {
    static let fileName = "goals.json"
    static let compactLimit = 1_500
    static let termCount = 15

    struct Stored: Codable, Equatable, Sendable {
        var text: String
        var isEnabled: Bool
        var updatedAt: Date
    }

    private(set) var stored: Stored?
    private(set) var lastError: String?
    private let fileURL: URL
    private let extractor = KeyTermExtractor()

    init(directory: URL = NotesStore.defaultDirectory) {
        fileURL = directory.appending(path: Self.fileName)
        load()
    }

    var text: String { stored?.text ?? "" }
    var isEnabled: Bool { stored?.isEnabled ?? false }
    var terms: [String] { stored.map { extractor.extract(from: $0.text, limit: Self.termCount) } ?? [] }

    /// What the backend receives, or nil when there are no goals or they are switched off.
    var compact: String? {
        guard let stored, stored.isEnabled else { return nil }
        return Self.compact(stored.text, terms: terms, limit: Self.compactLimit)
    }

    func set(text: String, at date: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }
        stored = Stored(text: String(trimmed.prefix(PrepStore.textLimit)), isEnabled: true, updatedAt: date)
        persist()
    }

    func setEnabled(_ enabled: Bool) {
        guard var current = stored else { return }
        current.isEnabled = enabled
        stored = current
        persist()
    }

    func clear() {
        stored = nil
        persist()
    }

    /// Whole text when it fits; otherwise the first sentences that fit, then "Nyckelord: …" with the key terms.
    static func compact(_ text: String, terms: [String], limit: Int) -> String {
        let collapsed = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        let keywords = terms.isEmpty ? "" : "Nyckelord: " + terms.joined(separator: ", ")
        if collapsed.count + (keywords.isEmpty ? 0 : keywords.count + 1) <= limit {
            return keywords.isEmpty ? collapsed : collapsed + "\n" + keywords
        }
        let budget = max(0, limit - min(keywords.count + 1, limit / 3))
        var head = ""
        for sentence in KeyTermExtractor.sentences(collapsed) {
            let piece = sentence.trimmingCharacters(in: .whitespaces) + "."
            if head.count + piece.count + 1 > budget { break }
            head += head.isEmpty ? piece : " " + piece
        }
        if head.isEmpty { head = String(collapsed.prefix(budget)) }
        let tail = keywords.isEmpty ? "" : "\n" + String(keywords.prefix(limit - head.count - 1))
        return String((head + tail).prefix(limit))
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            stored = try decoder.decode(Stored.self, from: data)
        } catch {
            lastError = "Could not read the course goals: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let stored {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(stored).write(to: fileURL, options: [.atomic, .completeFileProtection])
            } else if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            lastError = nil
        } catch {
            lastError = "Could not save the course goals: \(error.localizedDescription)"
        }
    }
}
