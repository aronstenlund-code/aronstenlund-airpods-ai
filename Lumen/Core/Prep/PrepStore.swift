import Foundation
import Observation

/// One piece of study material: pasted text or an imported PDF/text file, with its extracted terms.
struct PrepMaterial: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var text: String
    var terms: [String]
    var isEnabled: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, text: String, terms: [String], isEnabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.terms = terms
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

/// Prep mode (item 9): materials on disk; the enabled materials' terms feed speech recognition
/// (`AnalysisContext.contextualStrings`, ≤100) and the answer context (`prep_terms`, ≤30).
@MainActor
@Observable
final class PrepStore {
    static let fileName = "prep.json"
    static let sttTermLimit = 100
    static let backendTermLimit = AnswerContext.prepTermLimit
    static let textLimit = 200_000

    private(set) var materials: [PrepMaterial] = []
    private(set) var lastError: String?
    /// Fires after any change so the transcription coordinator can re-apply contextual strings.
    var onChange: (@MainActor () -> Void)?
    private let fileURL: URL
    private let extractor = KeyTermExtractor()

    init(directory: URL = NotesStore.defaultDirectory) {
        fileURL = directory.appending(path: Self.fileName)
        load()
    }

    /// Enabled materials' terms, newest material first, de-duplicated, for the speech recogniser.
    var sttTerms: [String] { terms(limit: Self.sttTermLimit) }
    /// The same, cut to the backend's limit.
    var backendTerms: [String] { terms(limit: Self.backendTermLimit) }

    /// Adds material; nil when the text yields no terms.
    @discardableResult
    func add(title: String, text: String, at date: Date = Date()) -> PrepMaterial? {
        let trimmed = String(text.prefix(Self.textLimit)).trimmingCharacters(in: .whitespacesAndNewlines)
        let terms = extractor.extract(from: trimmed, limit: Self.sttTermLimit)
        guard !terms.isEmpty else { return nil }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let material = PrepMaterial(title: cleanTitle.isEmpty ? Self.defaultTitle(for: trimmed) : cleanTitle,
                                    text: trimmed, terms: terms, createdAt: date)
        materials.insert(material, at: 0)
        persistAndNotify()
        return material
    }

    func setEnabled(_ material: PrepMaterial, _ enabled: Bool) {
        guard let index = materials.firstIndex(where: { $0.id == material.id }) else { return }
        materials[index].isEnabled = enabled
        persistAndNotify()
    }

    func delete(_ material: PrepMaterial) {
        materials.removeAll { $0.id == material.id }
        persistAndNotify()
    }

    static func defaultTitle(for text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 40 ? String(trimmed.prefix(37)) + "…" : trimmed
    }

    private func terms(limit: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for material in materials where material.isEnabled {
            for term in material.terms where seen.insert(term.lowercased()).inserted {
                out.append(term)
                if out.count == limit { return out }
            }
        }
        return out
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            materials = try decoder.decode([PrepMaterial].self, from: data).sorted { $0.createdAt > $1.createdAt }
        } catch {
            lastError = "Could not read prep material: \(error.localizedDescription)"
        }
    }

    private func persistAndNotify() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(materials).write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastError = nil
        } catch {
            lastError = "Could not save prep material: \(error.localizedDescription)"
        }
        onChange?()
    }
}
