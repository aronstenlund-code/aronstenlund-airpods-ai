import Foundation
import Observation

/// Personal keyword commands (D37), persisted locally (JSON in Application Support). Sync comes later.
@MainActor
@Observable
final class CommandStore {
    static let fileName = "commands.json"
    static let keywordLimit = 60
    static let instructionLimit = 300
    static let maxSent = 10

    private(set) var commands: [UserCommand] = []
    private(set) var lastError: String?
    private let fileURL: URL
    private let matcher = CommandMatcher()

    init(directory: URL = NotesStore.defaultDirectory) {
        fileURL = directory.appending(path: Self.fileName)
        load()
    }

    /// Adds or replaces (same keyword, case-insensitive). Nil when keyword or instruction is empty.
    @discardableResult
    func save(keyword: String, instruction: String, at date: Date = Date()) -> UserCommand? {
        let cleanKeyword = String(keyword.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.keywordLimit))
        let cleanInstruction = String(instruction.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.instructionLimit))
        guard !cleanKeyword.isEmpty, !cleanInstruction.isEmpty else { return nil }
        if let index = commands.firstIndex(where: { $0.keyword.lowercased() == cleanKeyword.lowercased() }) {
            commands[index].instruction = cleanInstruction
            commands[index].keyword = cleanKeyword
            persist()
            return commands[index]
        }
        let command = UserCommand(keyword: cleanKeyword, instruction: cleanInstruction, createdAt: date)
        commands.insert(command, at: 0)
        persist()
        return command
    }

    func delete(_ command: UserCommand) {
        commands.removeAll { $0.id == command.id }
        persist()
    }

    /// Commands triggered by `text`, at most `maxSent`, as the backend wants them.
    func matches(in text: String) -> [UserCommand] {
        Array(matcher.matches(in: text, commands: commands).prefix(Self.maxSent))
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            commands = try decoder.decode([UserCommand].self, from: data)
        } catch {
            lastError = "Could not read commands: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(commands).write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastError = nil
        } catch {
            lastError = "Could not save commands: \(error.localizedDescription)"
        }
    }
}
