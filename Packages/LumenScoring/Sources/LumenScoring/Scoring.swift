import Foundation

/// Result for one reference/hypothesis pair.
public struct ScoreResult: Sendable, Equatable {
    public let referenceTokens: [String]
    public let hypothesisTokens: [String]
    public let wordEdits: EditCounts
    public let characterEdits: EditCounts
    public let referenceCharacterCount: Int

    /// Word error rate = (S + D + I) / reference words. Empty reference: 0 if hypothesis empty, else 1.
    public var wer: Double {
        if referenceTokens.isEmpty { return hypothesisTokens.isEmpty ? 0 : 1 }
        return Double(wordEdits.total) / Double(referenceTokens.count)
    }

    /// Character error rate over the normalised strings (single spaces included).
    public var cer: Double {
        if referenceCharacterCount == 0 { return hypothesisTokens.isEmpty ? 0 : 1 }
        return Double(characterEdits.total) / Double(referenceCharacterCount)
    }

    /// Whole item correct after normalisation (what question detection depends on for short prompts).
    public var exactMatch: Bool { referenceTokens == hypothesisTokens }
}

/// Corpus-level aggregate.
public struct AggregateScore: Sendable, Equatable {
    public let items: Int
    public let referenceWords: Int
    public let wordEdits: EditCounts
    public let referenceCharacters: Int
    public let characterEdits: EditCounts
    public let exactMatches: Int

    /// Corpus WER (total edits / total reference words), not the mean of per-item WERs.
    public var wer: Double { referenceWords == 0 ? 0 : Double(wordEdits.total) / Double(referenceWords) }
    public var cer: Double { referenceCharacters == 0 ? 0 : Double(characterEdits.total) / Double(referenceCharacters) }
    public var exactMatchRate: Double { items == 0 ? 0 : Double(exactMatches) / Double(items) }
}

public struct Scorer: Sendable {
    public let normalizer: TextNormalizer

    public init(normalizer: TextNormalizer = TextNormalizer()) {
        self.normalizer = normalizer
    }

    public func score(reference: String, hypothesis: String) -> ScoreResult {
        let ref = normalizer.tokens(reference)
        let hyp = normalizer.tokens(hypothesis)
        let refChars = Array(ref.joined(separator: " "))
        let hypChars = Array(hyp.joined(separator: " "))
        return ScoreResult(
            referenceTokens: ref,
            hypothesisTokens: hyp,
            wordEdits: EditDistance.counts(reference: ref, hypothesis: hyp),
            characterEdits: EditDistance.counts(reference: refChars, hypothesis: hypChars),
            referenceCharacterCount: refChars.count
        )
    }

    public func aggregate(_ results: [ScoreResult]) -> AggregateScore {
        var words = 0
        var chars = 0
        var exact = 0
        var w = EditCounts()
        var c = EditCounts()
        for r in results {
            words += r.referenceTokens.count
            chars += r.referenceCharacterCount
            if r.exactMatch { exact += 1 }
            w.substitutions += r.wordEdits.substitutions
            w.deletions += r.wordEdits.deletions
            w.insertions += r.wordEdits.insertions
            c.substitutions += r.characterEdits.substitutions
            c.deletions += r.characterEdits.deletions
            c.insertions += r.characterEdits.insertions
        }
        return AggregateScore(items: results.count, referenceWords: words, wordEdits: w,
                              referenceCharacters: chars, characterEdits: c, exactMatches: exact)
    }
}
