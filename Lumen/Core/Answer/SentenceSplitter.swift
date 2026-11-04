import Foundation

/// Turns streamed answer text into whole sentences for sentence-level TTS (item 5). Pure; unit-tested.
/// Splits after `.`, `!`, `?` (and `…`) followed by whitespace or end of text; keeps decimals ("3,14", "3.14"),
/// common Swedish/English abbreviations and single-letter initials together.
struct SentenceSplitter: Sendable {
    static let abbreviations: Set<String> = [
        "t.ex", "bl.a", "dvs", "d.v.s", "ca", "osv", "etc", "m.m", "s.k", "p.g.a", "nr", "st", "kl",
        "e.g", "i.e", "mr", "mrs", "ms", "dr", "prof", "vs", "no", "approx",
    ]

    private var buffer = ""

    init() {}

    /// Feeds streamed text; returns the sentences completed by it (possibly none).
    mutating func feed(_ text: String) -> [String] {
        buffer += text
        var sentences: [String] = []
        while let end = Self.sentenceEnd(in: buffer) {
            let sentence = String(buffer[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = String(buffer[end...])
            // "?" + "!" across two deltas leaves a lone "!": nothing to speak.
            if sentence.contains(where: { $0.isLetter || $0.isNumber }) { sentences.append(sentence) }
        }
        return sentences
    }

    /// Returns the remaining partial sentence (end of stream) and clears the buffer.
    mutating func flush() -> String? {
        let rest = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return rest.isEmpty ? nil : rest
    }

    private static func isTerminator(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character == "…"
    }

    private static func isClosing(_ character: Character) -> Bool {
        "\"')»”’".contains(character)
    }

    /// Index just after the first sentence terminator (plus trailing terminators / closing quotes) that really
    /// ends a sentence, or nil when the text ends before we can tell.
    private static func sentenceEnd(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard isTerminator(character) else {
                index = text.index(after: index)
                continue
            }
            var end = text.index(after: index)
            var extraTerminators = 0
            while end < text.endIndex, isTerminator(text[end]) || isClosing(text[end]) {
                if isTerminator(text[end]) { extraTerminators += 1 }
                end = text.index(after: end)
            }
            // End of text: release it now so the first sentence reaches TTS at once, unless it may continue
            // ("3." + "14", "bl." + "a.") — then wait for more.
            guard end < text.endIndex else {
                return canEndStream(terminator: character, at: index, in: text) ? end : nil
            }
            guard text[end].isWhitespace else {
                index = end // "3.14", "e.g" — keep going
                continue
            }
            if character == ".", extraTerminators == 0, isAbbreviationOrInitial(before: index, in: text) {
                index = end
                continue
            }
            return end
        }
        return nil
    }

    /// A terminator at the very end of the streamed text so far. "?", "!" and "…" end the sentence; "." only
    /// after a real word of three letters or more (Swedish abbreviations stream as "bl." + "a.", "t." + "ex.").
    private static func canEndStream(terminator: Character, at index: String.Index, in text: String) -> Bool {
        guard terminator == "." else { return true }
        let word = lastWord(before: index, in: text)
        return word.count >= 3 && word.allSatisfy(\.isLetter) && !abbreviations.contains(word)
    }

    private static func lastWord(before dot: String.Index, in text: String) -> String {
        var start = dot
        while start > text.startIndex {
            let previous = text.index(before: start)
            if text[previous].isWhitespace { break }
            start = previous
        }
        return text[start..<dot].lowercased()
    }

    private static func isAbbreviationOrInitial(before dot: String.Index, in text: String) -> Bool {
        let word = lastWord(before: dot, in: text)
        if word.count == 1, word.first?.isLetter == true { return true } // "J. Smith"
        if word.allSatisfy(\.isNumber) { return false } // "år 1939."
        return abbreviations.contains(word)
    }
}
