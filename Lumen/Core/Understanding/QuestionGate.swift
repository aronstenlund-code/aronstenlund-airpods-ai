import Foundation
import LumenScoring

/// User-adjustable sensitivity of auto mode = the score a segment needs to trigger an answer (ARCHITECTURE §6).
enum GateSensitivity: String, CaseIterable, Identifiable, Sendable {
    case low, medium, high

    var id: String { rawValue }

    var threshold: Double {
        switch self {
        case .low: 0.7
        case .medium: 0.5
        case .high: 0.3
        }
    }
}

struct GateDecision: Equatable, Sendable {
    enum Signal: String, Sendable, Equatable {
        case questionMark, interrogativeStart, interrogativeInside, imperativeCue, mathPattern, shortFragment
        case statementCue, tooLong, unfinished, overlapsPlayback, empty
    }

    var score: Double
    var signals: [Signal]
    var threshold: Double

    var fires: Bool {
        !signals.contains(.overlapsPlayback) && !signals.contains(.empty) && score >= threshold
    }
}

/// Stage 1 of question detection (ARCHITECTURE §6): a cheap local gate over every final transcript segment.
/// Swedish and English cues; numbers are normalised with the scoring package so "fem plus två" and "5 plus 2"
/// score the same. Pure and unit-tested against `testdata/scripts/sv-short-prompts.md`.
struct QuestionGate: Sendable {
    var sensitivity: GateSensitivity
    private let normalizer = TextNormalizer()

    init(sensitivity: GateSensitivity = .medium) {
        self.sensitivity = sensitivity
    }

    static let interrogativeWords: Set<String> = [
        // Swedish
        "vad", "vem", "var", "när", "hur", "varför", "vilken", "vilket", "vilka", "vart", "varifrån", "vems",
        // English
        "what", "who", "where", "when", "how", "why", "which", "whose", "whom",
    ]
    static let interrogativePhrases: [[String]] = [
        ["kan", "någon"], ["kan", "du"], ["kan", "ni"], ["vet", "någon"], ["vet", "du"], ["finns", "det"],
        ["är", "det"], ["stämmer", "det"], ["har", "någon"],
        ["can", "someone"], ["can", "anyone"], ["can", "you"], ["does", "anyone"], ["do", "you"],
        ["is", "it"], ["is", "there"], ["are", "there"], ["could", "you"],
    ]
    static let imperativeWords: Set<String> = [
        "förklara", "berätta", "beskriv", "definiera", "sammanfatta", "översätt", "jämför",
        "explain", "describe", "define", "summarize", "summarise", "translate", "compare",
    ]
    static let imperativePhrases: [[String]] = [["tell", "me"], ["säg", "mig"]]
    static let mathOperators: Set<String> = [
        "plus", "minus", "gånger", "delat", "dividerat", "multiplicerat", "roten", "kvadrat", "kvadraten",
        "procent", "derivatan", "integralen", "upphöjt", "kubik",
        "times", "divided", "multiplied", "squared", "root", "percent", "derivative", "integral", "power", "cubed",
    ]
    static let mathOperands: Set<String> = [
        "x", "y", "pi",
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
        "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty",
        "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "million",
    ]
    static let statementStarts: Set<String> = [
        "jag", "vi", "det", "idag", "nu", "så", "sen", "sedan", "också", "men", "och", "ni", "han", "hon", "dom", "de",
        "i", "we", "today", "now", "so", "then", "also", "but", "and", "let", "lets", "you", "he", "she", "they",
    ]
    /// Toby 1 T15b finding 7: "Och 23 gånger 4." is a sum to work out, not a statement. A sentence that only opens
    /// with one of these words and holds a sum is not penalised as a statement.
    static let openingConjunctions: Set<String> = ["och", "men", "så", "sen", "sedan", "också", "and", "but", "so", "then", "also"]
    static let maxComfortableTokens = 14
    /// A sentence that ends on one of these is not finished ("vad finns det i", "kan du förklara och"): no trigger.
    static let unfinishedEndings: Set<String> = [
        "och", "eller", "men", "att", "som", "om", "för", "till", "med", "på", "i", "av", "från", "så", "när", "eftersom",
        "and", "or", "but", "to", "of", "the", "a", "an", "that", "if", "with", "because",
    ]

    func evaluate(_ text: String, overlapsPlayback: Bool = false) -> GateDecision {
        let threshold = sensitivity.threshold
        if overlapsPlayback {
            return GateDecision(score: 0, signals: [.overlapsPlayback], threshold: threshold)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizer.tokens(trimmed)
        guard !tokens.isEmpty else {
            return GateDecision(score: 0, signals: [.empty], threshold: threshold)
        }

        var score = 0.0
        var signals: [GateDecision.Signal] = []
        func add(_ signal: GateDecision.Signal, _ delta: Double) {
            signals.append(signal)
            score += delta
        }

        let questionMark = trimmed.hasSuffix("?")
        if questionMark { add(.questionMark, 0.6) }

        if Self.startsWith(tokens, words: Self.interrogativeWords, phrases: Self.interrogativePhrases) {
            add(.interrogativeStart, 0.55)
        } else if tokens.dropFirst().contains(where: { Self.interrogativeWords.contains($0) }) {
            add(.interrogativeInside, 0.2)
        }

        if Self.startsWith(tokens, words: Self.imperativeWords, phrases: Self.imperativePhrases)
            || tokens.dropFirst().prefix(2).contains(where: { Self.imperativeWords.contains($0) }) {
            add(.imperativeCue, 0.5)
        }

        let math = Self.hasMathPattern(tokens)
        if math { add(.mathPattern, 0.6) }

        let statement = Self.statementStarts.contains(tokens[0])
            && !(math && Self.openingConjunctions.contains(tokens[0]))
        if tokens.count <= 3 && !statement { add(.shortFragment, 0.35) }
        if statement && !questionMark { add(.statementCue, -0.3) }
        if tokens.count > Self.maxComfortableTokens { add(.tooLong, -0.25) }
        if !questionMark, let last = tokens.last, Self.unfinishedEndings.contains(last) { add(.unfinished, -0.6) }

        return GateDecision(score: min(1, max(0, score)), signals: signals, threshold: threshold)
    }

    private static func startsWith(_ tokens: [String], words: Set<String>, phrases: [[String]]) -> Bool {
        if words.contains(tokens[0]) { return true }
        return phrases.contains { phrase in Array(tokens.prefix(phrase.count)) == phrase }
    }

    private static func hasMathPattern(_ tokens: [String]) -> Bool {
        let hasOperator = tokens.contains { mathOperators.contains($0) }
        let hasOperand = tokens.contains { mathOperands.contains($0) || isNumber($0) }
        return hasOperator && hasOperand
    }

    private static func isNumber(_ token: String) -> Bool {
        guard let first = token.first, first.isNumber else { return false }
        return token.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
    }
}
