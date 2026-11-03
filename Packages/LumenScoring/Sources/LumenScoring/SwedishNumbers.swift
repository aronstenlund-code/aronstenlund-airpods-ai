import Foundation

/// Swedish number words <-> digits. Canonical form is digits ("hundra" -> "100").
///
/// Supported: 0–999 999 as single compound tokens ("tjugofem", "etthundra", "nittonhundratrettionio",
/// "tvåtusenfemhundra") and, optionally, adjacent tokens ("tjugo fem", "två tusen", "nittonhundra trettionio").
/// Not converted: bare "en" / "ett" (ambiguous with the indefinite article), ordinals ("första"),
/// decimals written as words ("tre komma fem").
public enum SwedishNumbers {
    static let units: [String: Int] = [
        "noll": 0, "ett": 1, "en": 1, "två": 2, "tre": 3, "fyra": 4, "fem": 5, "sex": 6, "sju": 7,
        "åtta": 8, "nio": 9, "tio": 10, "elva": 11, "tolv": 12, "tretton": 13, "fjorton": 14,
        "femton": 15, "sexton": 16, "sjutton": 17, "arton": 18, "aderton": 18, "nitton": 19,
    ]
    static let tens: [(String, Int)] = [
        ("tjugo", 20), ("tjugu", 20), ("trettio", 30), ("tretti", 30), ("fyrtio", 40), ("förtio", 40),
        ("fyrti", 40), ("femtio", 50), ("femti", 50), ("sextio", 60), ("sexti", 60), ("sjuttio", 70),
        ("sjutti", 70), ("åttio", 80), ("åtti", 80), ("nittio", 90), ("nitti", 90),
    ]

    /// Parses one token. Digit strings parse directly; bare "en"/"ett" return nil.
    public static func value(of token: String) -> Int? {
        if token.isEmpty { return nil }
        if token.allSatisfy(\.isNumber), let v = Int(token) { return v }
        if token == "en" || token == "ett" { return nil }
        return parseWords(token)
    }

    /// Replaces number words by digits and (optionally) merges adjacent number words.
    public static func canonicalize(_ tokens: [String], mergeAdjacent: Bool) -> [String] {
        struct Item { var text: String; var value: Int?; var fromWords: Bool }
        var items: [Item] = tokens.map { tok in
            if tok.allSatisfy(\.isNumber), let v = Int(tok) {
                return Item(text: tok, value: v, fromWords: false)
            }
            if let v = value(of: tok) {
                return Item(text: String(v), value: v, fromWords: true)
            }
            return Item(text: tok, value: nil, fromWords: false)
        }

        if mergeAdjacent {
            var merged: [Item] = []
            for item in items {
                if let last = merged.last, last.fromWords, item.fromWords,
                   let a = last.value, let b = item.value, let combined = combine(a, b) {
                    merged[merged.count - 1] = Item(text: String(combined), value: combined, fromWords: true)
                } else {
                    merged.append(item)
                }
            }
            items = merged
        }
        return items.map(\.text)
    }

    /// "tjugo fem" -> 25, "nittonhundra trettionio" -> 1939, "två tusen" -> 2000, "fem hundra" -> 500.
    static func combine(_ left: Int, _ right: Int) -> Int? {
        if right == 1000 || right == 100 { return left < right ? left * right : nil }
        if left >= 1000, left % 1000 == 0, right < 1000, right > 0 { return left + right }
        if left >= 100, left % 100 == 0, right < 100, right > 0 { return left + right }
        if left >= 20, left % 10 == 0, right < 10, right > 0 { return left + right }
        return nil
    }

    static func parseWords(_ token: String) -> Int? {
        if let r = token.range(of: "tusen") {
            let prefix = String(token[..<r.lowerBound])
            let rest = String(token[r.upperBound...])
            let k: Int
            if prefix.isEmpty || prefix == "et" || prefix == "ett" { k = 1 }
            else if let p = parseHundreds(prefix), p < 1000 { k = p }
            else { return nil }
            if rest.isEmpty { return k * 1000 }
            guard let restValue = parseHundreds(rest) else { return nil }
            return k * 1000 + restValue
        }
        return parseHundreds(token)
    }

    static func parseHundreds(_ token: String) -> Int? {
        if let r = token.range(of: "hundra") {
            let prefix = String(token[..<r.lowerBound])
            let rest = String(token[r.upperBound...])
            let h: Int
            if prefix.isEmpty || prefix == "ett" || prefix == "et" { h = 1 }
            else if let p = parseSmall(prefix), p >= 1, p <= 99 { h = p }
            else { return nil }
            if rest.isEmpty { return h * 100 }
            guard let restValue = parseSmall(rest), restValue < 100 else { return nil }
            return h * 100 + restValue
        }
        return parseSmall(token)
    }

    /// 0–99 as one compound token ("sju", "tjugo", "tjugosju", "tjugoen").
    static func parseSmall(_ token: String) -> Int? {
        if let v = units[token] { return v }
        for (word, tensValue) in tens {
            if token == word { return tensValue }
            if token.hasPrefix(word) {
                let rest = String(token.dropFirst(word.count))
                if let u = units[rest], u >= 1, u <= 9 { return tensValue + u }
            }
        }
        return nil
    }
}
