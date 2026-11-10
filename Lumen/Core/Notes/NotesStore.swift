import Foundation
import Observation

/// A saved session: the answers and the user's own questions, local only (item 8). Exported as Markdown.
/// The transcript is not saved: it holds other people's speech (D56).
struct Note: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var createdAt: Date
    var language: String
    var answers: [AnswerTurn]

    init(id: UUID = UUID(), createdAt: Date, language: String, answers: [AnswerTurn]) {
        self.id = id
        self.createdAt = createdAt
        self.language = language
        self.answers = answers
    }

    /// First question, else first answer, else the date.
    var title: String {
        let turn = answers.first
        let source = turn.flatMap { $0.question.isEmpty ? $0.answer : $0.question } ?? ""
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return createdAt.formatted(date: .abbreviated, time: .shortened) }
        return trimmed.count > 60 ? String(trimmed.prefix(57)) + "…" : trimmed
    }

    var markdown: String {
        var out: [String] = []
        out.append("# Lumen — \(createdAt.formatted(date: .long, time: .shortened))")
        out.append("")
        if !answers.isEmpty {
            out.append("## Questions and answers")
            out.append("")
            for turn in answers {
                if !turn.question.isEmpty {
                    out.append("**\(turn.question)**")
                    out.append("")
                }
                out.append(turn.answer)
                out.append("")
            }
        }
        return out.joined(separator: "\n")
    }
}

/// Notes on disk as one JSON file in Application Support (never synced, never uploaded).
@MainActor
@Observable
final class NotesStore {
    static let fileName = "notes.json"

    /// Newest first.
    private(set) var notes: [Note] = []
    private(set) var lastError: String?
    private let fileURL: URL

    init(directory: URL = NotesStore.defaultDirectory) {
        fileURL = directory.appending(path: Self.fileName)
        load(from: directory)
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "Lumen", directoryHint: .isDirectory)
    }

    /// Saves the conversation as a note; nil when there is nothing to save.
    @discardableResult
    func save(_ conversation: Conversation, language: TranscriptionLanguage, at date: Date = Date()) -> Note? {
        guard !conversation.answers.isEmpty else { return nil }
        let answers = conversation.answers.map { turn in
            var kept = turn
            if !turn.isOwnQuestion { kept.question = "" }
            return kept
        }
        let note = Note(createdAt: date, language: language.rawValue, answers: answers)
        notes.insert(note, at: 0)
        persist()
        return note
    }

    /// A48 (K35 `note_add`): a note the user dictated to Lumen ("anteckna att …").
    @discardableResult
    func add(text: String, at date: Date = Date()) -> Note {
        let note = Note(createdAt: date, language: "sv",
                        answers: [AnswerTurn(question: "Anteckning", answer: text, createdAt: date, source: "note")])
        notes.insert(note, at: 0)
        persist()
        return note
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        persist()
    }

    private func load(from directory: URL) {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data).sorted { $0.createdAt > $1.createdAt }
        } catch {
            lastError = "Could not read notes: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(notes).write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastError = nil
        } catch {
            lastError = "Could not save notes: \(error.localizedDescription)"
        }
    }
}
