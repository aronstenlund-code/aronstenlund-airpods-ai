import Foundation
import LumenScoring

/// A user-defined keyword → instruction (D37): "fission" → "förklara fission, resonera kring för- och nackdelar …".
struct UserCommand: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var keyword: String
    var instruction: String
    var createdAt: Date

    init(id: UUID = UUID(), keyword: String, instruction: String, createdAt: Date = Date()) {
        self.id = id
        self.keyword = keyword
        self.instruction = instruction
        self.createdAt = createdAt
    }
}

/// Finds saved keywords in recognised speech, tolerant to STT errors, and parses the spoken
/// "spara kommando <ord>: <instruktion>" form. Pure; unit-tested.
struct CommandMatcher: Sendable {
    private let normalizer: TextNormalizer

    init() {
        var options = TextNormalizer.Options()
        options.numbersToDigits = false
        normalizer = TextNormalizer(options: options)
    }

    /// Allowed character edits per keyword token: none for short words (false matches), 1 from 5 letters, 2 from 9.
    static func tolerance(forTokenLength length: Int) -> Int {
        if length >= 9 { return 2 }
        if length >= 5 { return 1 }
        return 0
    }

    /// Commands whose keyword (one or more words) occurs in `text`, in the order they occur.
    func matches(in text: String, commands: [UserCommand]) -> [UserCommand] {
        let tokens = normalizer.tokens(text)
        guard !tokens.isEmpty else { return [] }
        var found: [(position: Int, command: UserCommand)] = []
        for command in commands {
            let keyword = normalizer.tokens(command.keyword)
            guard !keyword.isEmpty, keyword.count <= tokens.count else { continue }
            for start in 0...(tokens.count - keyword.count) {
                if Self.matches(keyword, at: start, in: tokens) {
                    found.append((start, command))
                    break
                }
            }
        }
        return found.sorted { $0.position < $1.position }.map(\.command)
    }

    private static func matches(_ keyword: [String], at start: Int, in tokens: [String]) -> Bool {
        for (offset, word) in keyword.enumerated() {
            let token = tokens[start + offset]
            if token == word { continue }
            let tolerance = tolerance(forTokenLength: word.count)
            guard tolerance > 0, abs(token.count - word.count) <= tolerance else { return false }
            if EditDistance.distance(Array(word), Array(token)) > tolerance { return false }
        }
        return true
    }

    /// "spara kommando fission: förklara fission och jämför med fusion" → ("fission", "förklara …").
    /// Also accepts a comma or no separator (first word = keyword), and English "save command".
    static func parseSaveCommand(_ text: String) -> (keyword: String, instruction: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let prefixes = ["spara kommandot", "spara kommando", "save the command", "save command"] // longest first
        guard let prefix = prefixes.first(where: { lower.hasPrefix($0) }) else { return nil }
        var rest = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix(":") { rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces) }
        guard !rest.isEmpty else { return nil }

        let keyword: String
        let instruction: String
        if let separator = rest.firstIndex(where: { $0 == ":" || $0 == "," || $0 == ";" }) {
            keyword = String(rest[..<separator])
            instruction = String(rest[rest.index(after: separator)...])
        } else {
            let words = rest.split(separator: " ", omittingEmptySubsequences: true)
            guard words.count >= 2 else { return nil }
            keyword = String(words[0])
            instruction = words.dropFirst().joined(separator: " ")
        }
        let cleanKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        let cleanInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        guard !cleanKeyword.isEmpty, !cleanInstruction.isEmpty else { return nil }
        return (cleanKeyword, cleanInstruction)
    }
}
