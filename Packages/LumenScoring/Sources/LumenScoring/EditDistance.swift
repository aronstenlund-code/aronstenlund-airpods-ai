/// Levenshtein alignment with operation counts (substitutions / deletions / insertions).
public struct EditCounts: Sendable, Equatable {
    public var substitutions: Int
    public var deletions: Int
    public var insertions: Int

    public init(substitutions: Int = 0, deletions: Int = 0, insertions: Int = 0) {
        self.substitutions = substitutions
        self.deletions = deletions
        self.insertions = insertions
    }

    public var total: Int { substitutions + deletions + insertions }
}

public enum EditDistance {
    /// Minimum edits turning `reference` into `hypothesis`.
    /// Deletions = reference items missing from the hypothesis; insertions = extra hypothesis items.
    /// Ties are resolved substitution > deletion > insertion so counts are deterministic.
    public static func counts<T: Equatable>(reference: [T], hypothesis: [T]) -> EditCounts {
        let n = reference.count
        let m = hypothesis.count
        if n == 0 { return EditCounts(insertions: m) }
        if m == 0 { return EditCounts(deletions: n) }

        // dp[i][j] = cost of aligning reference[0..<i] with hypothesis[0..<j]
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }
        for i in 1...n {
            for j in 1...m {
                let cost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
                dp[i][j] = min(dp[i - 1][j - 1] + cost, dp[i - 1][j] + 1, dp[i][j - 1] + 1)
            }
        }

        var counts = EditCounts()
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                let cost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
                if dp[i][j] == dp[i - 1][j - 1] + cost {
                    if cost == 1 { counts.substitutions += 1 }
                    i -= 1
                    j -= 1
                    continue
                }
            }
            if i > 0, dp[i][j] == dp[i - 1][j] + 1 {
                counts.deletions += 1
                i -= 1
                continue
            }
            counts.insertions += 1
            j -= 1
        }
        return counts
    }

    public static func distance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        counts(reference: a, hypothesis: b).total
    }
}
