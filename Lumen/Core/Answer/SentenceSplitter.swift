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
            if !sentence.isEmpty { sentences.append(sentence) }
        }
        return sentences
    }

    /// Returns the remaining partial sentence (end of stream) and clears the buffer.
    mutating func flush() -> String? {
        let rest = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return rest.isEmpty ? nil : rest
    }

    /// Index just after the first sentence terminator that really ends a sentence, or nil.
    private static func sentenceEnd(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "." || character == "!" || character == "?" || character == "…" {
                let next = text.index(after: index)
                // Need whitespace (or more terminators) after it; end of text means "wait for more".
                guard next < text.endIndex else { return nil }
                if text[next] == "." || text[next] == "!" || text[next] == "?" || text[next] == "…" || text[next] == "\"" || text[next] == ")" {
                    index = next
                    continue
                }
                guard text[next].isWhitespace else {
                    index = next // "3.14", "e.g" — keep going
                    continue
                }
                if character == "." && isAbbreviationOrInitial(before: index, in: text) {
                    index = next
                    continue
                }
                return next
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func isAbbreviationOrInitial(before dot: String.Index, in text: String) -> Bool {
        var start = dot
        while start > text.startIndex {
            let previous = text.index(before: start)
            if text[previous].isWhitespace { break }
            start = previous
        }
        let word = text[start..<dot].lowercased()
        if word.count == 1, word.first?.isLetter == true { return true } // "J. Smith"
        if word.allSatisfy(\.isNumber) { return false } // "år 1939."
        return abbreviations.contains(word)
    }
}
