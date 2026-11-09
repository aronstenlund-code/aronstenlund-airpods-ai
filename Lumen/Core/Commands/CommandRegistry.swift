import Foundation
import Observation

/// A6.4 / A7: the app's spoken actions in one table. Each action has default phrases, the user's own phrases, where
/// it works and how it is confirmed. `docs/COMMANDS.md` describes the same table for people.
enum CommandAction: String, CaseIterable, Codable, Sendable, Identifiable {
    // MARK: Level 1, on the phone (A6, A7): no API call
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
    case stop
    /// "det där var fel": the last turn goes to /feedback (D80).
    case wrong
    /// A7: the last answer's audio again, from memory.
    case repeatAnswer
    /// A7: Lumen's own voice quieter / louder (the player node, not the iPhone volume), remembered.
    case whisper
    case louder
    /// A7: a standing length for this session ("svara kortare"), sent as `length`.
    case shorter
    case longer
    /// A7: the last answer into Anteckningar.
    case saveAnswer
    /// A7: the next exam from the exam plans, read on the phone.
    case nextExam

    // MARK: Level 2, in the same /answer call (A7 + Kevin's K9): the phrase goes as an instruction
    /// "förhör mig (på …)".
    case quizMe
    case moreDetail
    case simpler
    case example
    case summary
    case aLevel
    case harderQuestion
    case quickQuiz
    case weakAreas
    case careful
    case catchUp
    case discreet
    case asUsual
    case interviewHelp
    case interviewBetter
    case interviewConfident
    case interviewCounter
    case interviewStuck
    case socialReply
    case funnier
    case moreNatural
    case changeTopic
    case followUp
    case whatMeant
    case rizz
    case moreConfident
    case flirtier
    case subtler
    case cockier
    case rescue
    case lessCringe
    case threeOptions

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
        case .stop: "Avsluta"
        case .wrong: "Det där var fel"
        case .repeatAnswer: "Upprepa senaste svaret"
        case .whisper: "Viska (tystare röst)"
        case .louder: "Högre röst"
        case .shorter: "Kortare svar resten av passet"
        case .longer: "Längre svar resten av passet"
        case .saveAnswer: "Spara svaret i Anteckningar"
        case .nextExam: "Vilket prov har jag härnäst?"
        case .quizMe: "Förhör mig (på …)"
        case .moreDetail: "Utveckla svaret"
        case .simpler: "Förklara enklare"
        case .example: "Ge ett exempel"
        case .summary: "Sammanfatta det viktigaste"
        case .aLevel: "Förklaring på A-nivå"
        case .harderQuestion: "Ställ en svår fråga"
        case .quickQuiz: "Snabbförhör (5 frågor)"
        case .weakAreas: "Testa mina svagaste områden"
        case .careful: "Var säker (starkare modell)"
        case .catchUp: "Vad missade jag?"
        case .discreet: "Hjälp mig diskret (en mening)"
        case .asUsual: "Svara som jag brukar"
        case .interviewHelp: "Intervju: hjälp mig svara"
        case .interviewBetter: "Intervju: bättre svar"
        case .interviewConfident: "Intervju: mer självsäkert"
        case .interviewCounter: "Intervju: motfråga"
        case .interviewStuck: "Intervju: jag fastnar"
        case .socialReply: "Vad ska jag svara?"
        case .funnier: "Roligare"
        case .moreNatural: "Mer naturligt"
        case .changeTopic: "Byt ämne"
        case .followUp: "Smart följdfråga"
        case .whatMeant: "Vad menade personen?"
        case .rizz: "Ge mig lite rizz"
        case .moreConfident: "Mer självsäker"
        case .flirtier: "Flirtigare"
        case .subtler: "Mer subtil"
        case .cockier: "Kaxigare"
        case .rescue: "Rädda mig"
        case .lessCringe: "Mindre cringe"
        case .threeOptions: "Tre alternativ"
        }
    }

    /// True: the phrase alone is the whole utterance, "Lumen" not needed, in every mode. False: only after "Lumen"
    /// (or as a universal word, see `universalPhrases`).
    var worksWithoutName: Bool {
        switch self {
        case .musicHandOff, .nextTrack, .previousTrack, .pauseMusic, .wrong: true
        default: false
        }
    }

    /// A7: short words that count without "Lumen" when they are the whole utterance, only in Provläge and Frågor
    /// (there the speaker is the user) and only while the setting is on. Not editable.
    var universalPhrases: [String] {
        switch self {
        case .repeatAnswer: ["upprepa"]
        case .whisper: ["viska"]
        case .louder: ["högre"]
        case .shorter: ["kortare", "snabbare"]
        case .moreDetail: ["utveckla"]
        default: []
        }
    }

    /// The phrase starts the utterance and more words follow (a mode name, a topic).
    var isPrefix: Bool { self == .switchMode || self == .quizMe }

    /// Level 1 runs on the phone (no API call); level 2 goes to /answer as an instruction (A7, K9).
    var level: Int {
        switch self {
        case .musicHandOff, .backToLumen, .nextTrack, .previousTrack, .pauseMusic, .switchMode, .stop, .wrong,
             .repeatAnswer, .whisper, .louder, .shorter, .longer, .saveAnswer, .nextExam: 1
        default: 2
        }
    }

    /// Where the action means something; nil = every mode. Level-2 phrases outside their modes still go to the
    /// backend as an ordinary instruction, which is what they were before.
    var modes: Set<ConversationMode>? {
        switch self {
        case .quizMe, .harderQuestion, .quickQuiz, .weakAreas, .aLevel: [.prov, .standard]
        case .interviewHelp, .interviewBetter, .interviewConfident, .interviewCounter, .interviewStuck: [.interview]
        case .socialReply, .funnier, .moreNatural, .changeTopic, .followUp, .whatMeant, .threeOptions: [.social, .rizz]
        case .rizz, .moreConfident, .flirtier, .subtler, .cockier, .rescue, .lessCringe: [.rizz, .social]
        default: nil
        }
    }

    /// What Lumen says when a level-1 action is done (nil: nothing, or the action says it itself). Said only when
    /// nothing else is heard (A7).
    var confirmation: String? {
        switch self {
        case .nextTrack: "Nästa låt."
        case .previousTrack: "Förra låten."
        case .pauseMusic: "Musiken är pausad."
        case .backToLumen: "Jag lyssnar."
        case .whisper: "Tystare."
        case .louder: "Högre."
        case .shorter: "Kortare."
        case .longer: "Längre."
        case .saveAnswer: "Sparat."
        default: nil
        }
    }

    /// The instruction a level-2 action sends: its first default phrase, so a user phrase ("testa mig") reaches
    /// the backend in the words K9's table knows.
    var instruction: String { defaultPhrases.first ?? rawValue }

    var defaultPhrases: [String] {
        switch self {
        case .musicHandOff: ["pausa", "pausa lumen", "spela musik", "pause", "pause lumen", "play music"]
        case .backToLumen: ["tillbaka till lumen", "lyssna igen", "fortsätt lyssna", "back to lumen"]
        case .nextTrack: ["nästa låt", "hoppa över låten", "skippa låten", "next song", "skip song"]
        case .previousTrack: ["förra låten", "föregående låt", "spela förra låten", "previous song"]
        case .pauseMusic: ["pausa musiken", "stoppa musiken", "pause the music", "stop the music"]
        case .switchMode: ["byt till", "byta till", "växla till", "gå till", "starta", "lyssna efter", "switch to"]
        case .stop: ["sluta lyssna", "sluta", "avsluta", "stäng av", "stop listening"]
        case .wrong: [
            "det där var inte riktigt rätt", "det var inte riktigt rätt", "det var fel", "det där var fel", "det är fel",
            "dåligt svar", "dåligt", "det stämmer inte", "det där stämmer inte", "stämmer inte", "fel svar", "helt fel",
            "nej det var fel", "nej det stämmer inte", "det var inte rätt", "det där var inte rätt", "inte rätt",
            "det var ett dåligt svar", "det svaret var fel", "that was wrong", "wrong answer", "thats not right",
        ]
        case .repeatAnswer: ["upprepa", "upprepa svaret", "säg det igen", "repetera", "vad sa du", "kan du upprepa", "repeat", "say that again"]
        case .whisper: ["viska", "tystare", "prata tystare", "lägre", "sänk volymen", "whisper", "quieter"]
        case .louder: ["högre", "prata högre", "höj volymen", "louder"]
        case .shorter: ["svara kortare", "kortare", "kortare svar", "snabbare", "kortare tack", "shorter"]
        case .longer: ["svara längre", "längre svar", "längre", "utförligare svar", "longer answers"]
        case .saveAnswer: ["spara det", "spara svaret", "spara det där", "spara i anteckningar", "save that"]
        case .nextExam: ["vilket prov har jag härnäst", "när är nästa prov", "nästa prov", "vilket är nästa prov", "next exam"]
        case .quizMe: ["förhör mig", "testa mig", "quiz me"]
        case .moreDetail: ["utveckla", "utveckla svaret", "berätta mer", "mer", "mer om det", "tell me more"]
        case .simpler: ["förklara enklare", "förklara", "enklare", "förklara det enklare", "simpler"]
        case .example: ["ge ett exempel", "ge mig ett exempel", "exempel", "give an example"]
        case .summary: ["sammanfatta det viktigaste", "sammanfatta", "summera", "summarize"]
        case .aLevel: ["förklara på a-nivå", "a-nivå", "som för ett a"]
        case .harderQuestion: ["ställ en svår fråga", "en svårare fråga", "svårare fråga"]
        case .quickQuiz: ["snabbförhör", "fem snabba frågor", "snabbförhör mig"]
        case .weakAreas: ["testa mina svagaste områden", "hur bra kan jag det här", "vad kan jag sämst"]
        case .careful: ["var säker", "dubbelkolla", "var noggrann"]
        case .catchUp: ["vad missade jag", "vad har jag missat", "vad sa de"]
        case .discreet: ["hjälp mig diskret", "diskret", "kort och diskret"]
        case .asUsual: ["svara som jag brukar", "som vanligt"]
        case .interviewHelp: ["hjälp mig svara professionellt", "vad borde jag säga", "hjälp mig svara"]
        case .interviewBetter: ["bättre svar", "ge mig ett bättre svar"]
        case .interviewConfident: ["mer självsäkert", "låt mer säker"]
        case .interviewCounter: ["motfråga", "ge mig en motfråga"]
        case .interviewStuck: ["hjälp jag fastnar", "jag fastnar", "hjälp"]
        case .socialReply: ["vad ska jag svara", "vad svarar jag"]
        case .funnier: ["roligare", "gör det roligare"]
        case .moreNatural: ["mer naturligt", "naturligare"]
        case .changeTopic: ["byt ämne", "nytt ämne"]
        case .followUp: ["smart följdfråga", "följdfråga", "ge mig en följdfråga"]
        case .whatMeant: ["vad menade personen", "vad menade hon", "vad menade han", "vad menade de"]
        case .rizz: ["ge mig lite rizz", "lite rizz", "rizz"]
        case .moreConfident: ["mer självsäker", "säkrare"]
        case .flirtier: ["flirtigare", "mer flirtig"]
        case .subtler: ["mer subtil", "subtilare"]
        case .cockier: ["kaxigare", "mer kaxig"]
        case .rescue: ["rädda mig", "hjälp mig ur det här"]
        case .lessCringe: ["mindre cringe", "inte så cringe"]
        case .threeOptions: ["tre alternativ", "ge mig tre", "tre förslag"]
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

    /// A7: a universal word ("upprepa", "viska", "kortare", "utveckla") as the whole utterance, without "Lumen".
    /// The caller allows it only in Provläge and Frågor with the setting on.
    func universal(_ text: String) -> CommandAction? {
        let words = Self.normalized(text)
        guard !words.isEmpty else { return nil }
        return CommandAction.allCases.first { $0.universalPhrases.contains(words) }
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
    nonisolated static let phraseLimit = 40
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
