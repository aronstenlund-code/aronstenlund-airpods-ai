import Foundation
import Observation

/// A6.4 / A7: the app's spoken actions in one table. Each action has default phrases, the user's own phrases, where
/// it works and how it is confirmed. `docs/COMMANDS.md` describes the same table for people.
enum CommandAction: String, CaseIterable, Codable, Sendable, Identifiable {
    /// "pausa", "spela musik": Lumen lets go of the audio so the music plays (D58).
    case musicHandOff
    /// Back to Lumen after music: Siri "Starta Lumen", the Control or the Lock Screen (D58); the phrase works while
    /// Lumen listens (it then only confirms).
    case backToLumen
    case nextTrack
    case previousTrack
    case pauseMusic
    /// "byt till …" + a mode name.
    case switchMode
    /// "förhör mig (på …)": sent to the tutor as "förhör mig …".
    case quizMe
    case stop
    /// "det där var fel": the last turn goes to /feedback (D80).
    case wrong

    var id: String { rawValue }

    /// Settings › Röstkommandon.
    var title: String {
        switch self {
        case .musicHandOff: "Pausa Lumen och spela musik"
        case .backToLumen: "Tillbaka till Lumen"
        case .nextTrack: "Nästa låt"
        case .previousTrack: "Förra låten"
        case .pauseMusic: "Pausa musiken"
        case .switchMode: "Byt läge (följs av lägets namn)"
        case .quizMe: "Förhör mig"
        case .stop: "Avsluta"
        case .wrong: "Det där var fel"
        }
    }

    /// True: the phrase alone is the whole utterance, "Lumen" not needed. False: only after "Lumen".
    var worksWithoutName: Bool {
        switch self {
        case .musicHandOff, .nextTrack, .previousTrack, .pauseMusic, .wrong: true
        case .backToLumen, .switchMode, .quizMe, .stop: false
        }
    }

    /// The phrase starts the utterance and more words follow (a mode name, a topic).
    var isPrefix: Bool { self == .switchMode || self == .quizMe }

    /// Level 1 runs on the phone (no API call); level 2 goes to /answer as an instruction (A7).
    var level: Int { self == .quizMe ? 2 : 1 }

    /// What Lumen says when the action is done (nil: nothing, or the action says it itself).
    var confirmation: String? {
        switch self {
        case .nextTrack: "Nästa låt."
        case .previousTrack: "Förra låten."
        case .pauseMusic: "Musiken är pausad."
        case .backToLumen: "Jag lyssnar."
        case .musicHandOff, .switchMode, .quizMe, .stop, .wrong: nil
        }
    }

    var defaultPhrases: [String] {
        switch self {
        case .musicHandOff: ["pausa", "pausa lumen", "spela musik", "pause", "pause lumen", "play music"]
        case .backToLumen: ["tillbaka till lumen", "lyssna igen", "fortsätt lyssna", "back to lumen"]
        case .nextTrack: ["nästa låt", "hoppa över låten", "skippa låten", "next song", "skip song"]
        case .previousTrack: ["förra låten", "föregående låt", "spela förra låten", "previous song"]
        case .pauseMusic: ["pausa musiken", "stoppa musiken", "pause the music", "stop the music"]
        case .switchMode: ["byt till", "byta till", "växla till", "gå till", "starta", "switch to"]
        case .quizMe: ["förhör mig", "quiz me"]
        case .stop: ["sluta lyssna", "sluta", "avsluta", "stäng av", "stop listening"]
        case .wrong: [
            "det där var inte riktigt rätt", "det var inte riktigt rätt", "det var fel", "det där var fel", "det är fel",
            "dåligt svar", "dåligt", "det stämmer inte", "det där stämmer inte", "stämmer inte", "fel svar", "helt fel",
            "nej det var fel", "nej det stämmer inte", "det var inte rätt", "det där var inte rätt", "inte rätt",
            "det var ett dåligt svar", "det svaret var fel", "that was wrong", "wrong answer", "thats not right",
        ]
        }
    }
}

/// The phrases in force: defaults minus the ones the user removed, plus the user's own. Pure value; matching is by
/// the whole normalised utterance (or its start for a prefix action), so words inside a sentence never match.
struct CommandTable: Equatable, Sendable {
    private(set) var phrases: [CommandAction: [String]]

    static let standard = CommandTable(added: [:], removed: [:])

    init(added: [CommandAction: [String]], removed: [CommandAction: Set<String>]) {
        var table: [CommandAction: [String]] = [:]
        for action in CommandAction.allCases {
            let gone = Set((removed[action] ?? []).map(Self.normalized))
            var list = action.defaultPhrases.map(Self.normalized).filter { !gone.contains($0) }
            for phrase in (added[action] ?? []).map(Self.normalized) where !phrase.isEmpty && !list.contains(phrase) {
                list.append(phrase)
            }
            table[action] = list
        }
        phrases = table
    }

    func phrases(for action: CommandAction) -> [String] { phrases[action] ?? [] }

    /// The action whose phrase is the whole utterance. `named`: the words came after "Lumen".
    func action(forWhole text: String, named: Bool) -> CommandAction? {
        let words = Self.normalized(text)
        guard !words.isEmpty else { return nil }
        for action in CommandAction.allCases where !action.isPrefix && (named || action.worksWithoutName) {
            if phrases(for: action).contains(words) { return action }
        }
        return nil
    }

    /// A prefix action ("byt till", "förhör mig") at the start of the words after "Lumen", and the words after it.
    func prefix(in text: String) -> (action: CommandAction, rest: String)? {
        let words = Self.normalized(text)
        for action in CommandAction.allCases where action.isPrefix {
            // The longest phrase first, so "byta till" is not read as "byt" + "a till".
            for phrase in phrases(for: action).sorted(by: { $0.count > $1.count }) {
                if words == phrase { return (action, "") }
                if words.hasPrefix(phrase + " ") { return (action, String(words.dropFirst(phrase.count + 1))) }
            }
        }
        return nil
    }

    static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
            .split(separator: " ").joined(separator: " ")
    }
}

/// Why a new phrase may cause trouble (A6.4). Shown under the field; the user may still keep it.
enum CommandWarning: Equatable, Sendable {
    case empty
    case tooLong
    /// The phrase already belongs to another action.
    case usedBy(CommandAction)
    /// A word that is common in ordinary questions ("vad", "ja", "tack"): said by accident.
    case commonWords
    /// Starts like a question: the question gate could take it.
    case soundsLikeAQuestion

    var text: String {
        switch self {
        case .empty: "Skriv en fras."
        case .tooLong: "Högst \(CommandPhraseStore.phraseLimit) tecken."
        case .usedBy(let action): "Används redan för \"\(action.title)\"."
        case .commonWords: "Består av vanliga ord. Den kan sägas av misstag mitt i en fråga."
        case .soundsLikeAQuestion: "Låter som början på en fråga. Säg \"Lumen\" före om den krockar."
        }
    }

    /// The phrase cannot be saved.
    var blocks: Bool { self == .empty || self == .tooLong || { if case .usedBy = self { return true }; return false }() }
}

/// What the static parsers (`VoiceChannel`, `VoiceCommand`) read. Set by `CommandPhraseStore` on the main actor,
/// read from anywhere; a lock keeps it consistent.
final class CommandBook: @unchecked Sendable {
    static let shared = CommandBook()
    private let lock = NSLock()
    private var current = CommandTable.standard

    var table: CommandTable {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

/// Settings › Röstkommandon (A6.4): the user's own phrases per action, in UserDefaults.
@MainActor
@Observable
final class CommandPhraseStore {
    static let addedKey = "commands.phrases.added"
    static let removedKey = "commands.phrases.removed"
    static let phraseLimit = 40
    private static let commonWords: Set<String> = [
        "ja", "nej", "okej", "ok", "tack", "hej", "vad", "hur", "när", "var", "vem", "varför", "och", "eller", "det", "den",
        "en", "ett", "jag", "du", "vi", "är", "så", "bra", "nu", "igen", "mer", "yes", "no", "what", "how", "the", "a",
    ]

    private(set) var added: [CommandAction: [String]] = [:]
    private(set) var removed: [CommandAction: Set<String>] = [:]
    private let defaults: UserDefaults
    private let book: CommandBook

    init(defaults: UserDefaults = .standard, book: CommandBook = .shared) {
        self.defaults = defaults
        self.book = book
        if let data = defaults.data(forKey: Self.addedKey), let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            added = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in CommandAction(rawValue: key).map { ($0, value) } })
        }
        if let data = defaults.data(forKey: Self.removedKey), let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            removed = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in CommandAction(rawValue: key).map { ($0, Set(value)) } })
        }
        book.table = table
    }

    var table: CommandTable { CommandTable(added: added, removed: removed) }

    func phrases(for action: CommandAction) -> [String] { table.phrases(for: action) }

    func isDefault(_ phrase: String, for action: CommandAction) -> Bool {
        action.defaultPhrases.map(CommandTable.normalized).contains(CommandTable.normalized(phrase))
    }

    /// The user's phrases, for Scribe's keyterms (A6.4): the defaults are already common words to it.
    var userPhrases: [String] { CommandAction.allCases.flatMap { added[$0] ?? [] } }

    func warnings(for raw: String, action: CommandAction) -> [CommandWarning] {
        let phrase = CommandTable.normalized(raw)
        guard !phrase.isEmpty else { return [.empty] }
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines).count <= Self.phraseLimit else { return [.tooLong] }
        var out: [CommandWarning] = []
        let current = table
        if let other = CommandAction.allCases.first(where: { $0 != action && current.phrases(for: $0).contains(phrase) }) {
            out.append(.usedBy(other))
        }
        let words = phrase.split(separator: " ").map(String.init)
        if action.worksWithoutName, words.allSatisfy({ Self.commonWords.contains($0) }) { out.append(.commonWords) }
        if action.worksWithoutName, let first = words.first, QuestionGate.interrogativeWords.contains(first) { out.append(.soundsLikeAQuestion) }
        return out
    }

    /// Adds a phrase unless a warning blocks it. Returns the warnings either way.
    @discardableResult
    func add(_ raw: String, to action: CommandAction) -> [CommandWarning] {
        let found = warnings(for: raw, action: action)
        guard !found.contains(where: \.blocks) else { return found }
        let phrase = CommandTable.normalized(raw)
        if isDefault(phrase, for: action) {
            removed[action]?.remove(phrase)
        } else if !(added[action] ?? []).contains(phrase) {
            added[action, default: []].append(phrase)
        }
        persist()
        return found
    }

    func remove(_ raw: String, from action: CommandAction) {
        let phrase = CommandTable.normalized(raw)
        if isDefault(phrase, for: action) {
            removed[action, default: []].insert(phrase)
        } else {
            added[action]?.removeAll { $0 == phrase }
        }
        persist()
    }

    func reset(_ action: CommandAction) {
        added[action] = nil
        removed[action] = nil
        persist()
    }

    private func persist() {
        let addedRaw = Dictionary(uniqueKeysWithValues: added.map { ($0.key.rawValue, $0.value) })
        let removedRaw = Dictionary(uniqueKeysWithValues: removed.map { ($0.key.rawValue, Array($0.value).sorted()) })
        defaults.set(try? JSONEncoder().encode(addedRaw), forKey: Self.addedKey)
        defaults.set(try? JSONEncoder().encode(removedRaw), forKey: Self.removedKey)
        book.table = table
    }
}
