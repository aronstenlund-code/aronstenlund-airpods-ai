import Foundation

/// A58 (K36): the pure part of `call_contact` and `music_open`, unit-tested: which contact a spoken name means, which
/// number to dial, and the URLs.
enum PhoneCall {
    struct Contact: Equatable, Sendable {
        var given: String
        var family: String
        var nickname: String
        var organization: String
        var numbers: [(label: String, number: String)]

        static func == (lhs: Contact, rhs: Contact) -> Bool {
            lhs.given == rhs.given && lhs.family == rhs.family && lhs.nickname == rhs.nickname
                && lhs.organization == rhs.organization && lhs.numbers.map(\.number) == rhs.numbers.map(\.number)
        }

        var displayName: String {
            let full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            return full.isEmpty ? (nickname.isEmpty ? organization : nickname) : full
        }

        /// The mobile number first (iPhone, mobil), else the first.
        var bestNumber: String? {
            let mobile = numbers.first { $0.label.lowercased().contains("mobile") || $0.label.lowercased().contains("iphone") }
            return (mobile ?? numbers.first).flatMap { PhoneCall.dialable($0.number) }
        }
    }

    /// Lower case, without "min/mitt/mina" and the definite ending that a spoken name may carry ("tandläkaren").
    static func key(_ text: String) -> String {
        let words = text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "sv_SE"))
            .components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty && !["min", "mitt", "mina", "till"].contains($0) }
        return words.joined(separator: " ")
    }

    /// The contacts the spoken name means. An exact match on the nickname, the full name, the given name or the
    /// organisation wins over a first-word match ("Elin" = "Elin Svensson"); "tandläkaren" matches "Tandläkare …".
    static func matches(_ spoken: String, in contacts: [Contact]) -> [Contact] {
        let said = key(spoken)
        guard !said.isEmpty else { return [] }
        let exact = contacts.filter { contact in
            [contact.nickname, contact.displayName, contact.given, contact.organization].map(key).contains(said)
        }
        if !exact.isEmpty { return exact }
        // "tandläkaren" = "tandläkare" + n, "skolan" = "skola" + n, "kontoret" = "kontor" + et.
        var stems = [said]
        if said.count > 4 {
            for ending in ["en", "n", "et", "t"] where said.hasSuffix(ending) { stems.append(String(said.dropLast(ending.count))) }
        }
        return contacts.filter { contact in
            let names = [contact.nickname, contact.given, contact.organization, contact.displayName].map(key).filter { !$0.isEmpty }
            return names.contains { name in stems.contains { name == $0 || name.hasPrefix($0 + " ") } }
        }
    }

    /// Digits and a leading +, at least 3 digits; nil otherwise.
    static func dialable(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var out = ""
        for (index, char) in trimmed.enumerated() {
            if char.isASCII, char.isNumber { out.append(char) } else if char == "+", index == 0 { out.append(char) }
        }
        return out.filter(\.isNumber).count >= 3 ? out : nil
    }

    static func url(_ number: String) -> URL? { URL(string: "tel://\(number)") }
}

enum MusicSearch {
    static func spotifyURL(_ query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "spotify:search:\(encoded)")
    }

    static func webURL(_ query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://open.spotify.com/search/\(encoded)")
    }
}
