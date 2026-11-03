import Foundation
import Observation

/// A saved session: transcript lines + answers, local only (item 8). Exported as Markdown.
struct Note: Identifiable, Codable, Equatable, Sendable {
    struct Line: Codable, Equatable, Sendable {
        var time: Date
        var text: String
    }

    let id: UUID
    var createdAt: Date
    var language: String
    var transcript: [Line]
    var answers: [AnswerTurn]

    init(id: UUID = UUID(), createdAt: Date, language: String, transcript: [Line], answers: [AnswerTurn]) {
        self.id = id
        self.createdAt = createdAt
        self.language = language
        self.transcript = transcript
        self.answers = answers
    }

    /// First question, else first transcript line, else the date.
    var title: String {
        let source = answers.first?.question ?? transcript.first?.text ?? ""
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
                out.append("**\(turn.question)**")
                out.append("")
                out.append(turn.answer)
                out.append("")
            }
        }
        if !transcript.isEmpty {
            out.append("## Transcript")
            out.append("")
            for line in transcript {
                out.append("- \(line.time.formatted(date: .omitted, time: .standard)) \(line.text)")
            }
            out.append("")
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
        let lines = conversation.finalSegments.filter { !$0.overlapsPlayback }.map { Note.Line(time: $0.startedAt, text: $0.text) }
        guard !lines.isEmpty || !conversation.answers.isEmpty else { return nil }
        let note = Note(createdAt: date, language: language.rawValue, transcript: lines, answers: conversation.answers)
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
