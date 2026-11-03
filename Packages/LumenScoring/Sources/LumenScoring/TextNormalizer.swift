import Foundation

/// Shared normalisation applied to BOTH reference and hypothesis before scoring (Phase 1 §3.9).
///
/// Rules (documented, deterministic):
/// 1. Lowercase with Swedish locale rules (å/ä/ö kept).
/// 2. `%` becomes the word "procent".
/// 3. Every character that is not a letter or digit becomes a word boundary, except
///    `,` and `.` between two digits (decimals such as "3,5" or "3.5" stay one token).
///    A hyphen is a word boundary too: "ph-värde" -> ["ph", "värde"].
/// 4. Whitespace is collapsed.
/// 5. Swedish number words are converted to digits (canonical form is digits), see `SwedishNumbers`.
///    Bare "en" / "ett" are NOT converted (ambiguous with the article).
public struct TextNormalizer: Sendable {
    public struct Options: Sendable, Equatable {
        /// Convert Swedish number words to digits ("hundra" -> "100").
        public var numbersToDigits: Bool = true
        /// Merge adjacent number words ("tjugo fem" -> "25", "två tusen" -> "2000").
        public var mergeAdjacentNumberWords: Bool = true
        public init() {}
    }

    public var options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    /// Normalised tokens.
    public func tokens(_ text: String) -> [String] {
        var lowered = text.lowercased(with: Locale(identifier: "sv_SE"))
        lowered = lowered.replacingOccurrences(of: "%", with: " procent ")

        let chars = Array(lowered)
        var out = String()
        out.reserveCapacity(chars.count)
        for (index, c) in chars.enumerated() {
            if c.isLetter || c.isNumber {
                out.append(c)
            } else if (c == "," || c == "."),
                      index > 0, index + 1 < chars.count,
                      chars[index - 1].isNumber, chars[index + 1].isNumber {
                out.append(c)
            } else {
                out.append(" ")
            }
        }

        var tokens = out.split(whereSeparator: { $0 == " " }).map(String.init)
        if options.numbersToDigits {
            tokens = SwedishNumbers.canonicalize(tokens, mergeAdjacent: options.mergeAdjacentNumberWords)
        }
        return tokens
    }

    /// Normalised text with single spaces (used for CER).
    public func normalizedString(_ text: String) -> String {
        tokens(text).joined(separator: " ")
    }
}
