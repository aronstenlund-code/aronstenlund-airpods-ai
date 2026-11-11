import Foundation

/// The name the wearer says to talk to the app (D74). One constant, so a new app name changes one line.
enum WakeWord {
    static let name = "Lumen"

    /// A75 (Aron 20:41): how Scribe and the phone mishear the name, per name, so a new name (Earmind?) is one row.
    /// Grows from the A76 recordings and the "Name-like word not taken" log lines.
    static let variantsByName: [String: [String]] = [
        "lumen": ["lumen", "lumin", "lummen", "lomen", "lymen", "limen", "loomen", "lumens", "lumén", "luman", "lumon",
                  "lumne", "lumem", "lumel", "lumet", "lune", "lumi", "loumen", "luumen", "lu men", "lu-men"],
        "earmind": ["earmind", "earmand", "irmind", "ir mind", "ear mind", "iirmind", "ermind", "earminde"],
    ]
    /// Real Swedish words one letter from the name that must never wake it.
    static let notTheName: Set<String> = ["lumpen", "tumen", "rummen", "lumpa", "limmen", "lumes", "linen", "lunen", "luren", "lumpe", "humen"]

    static var variants: [String] { variantsByName[name.lowercased()] ?? [name.lowercased()] }

    /// A75: a word (or two, "lu men") that is the name as heard: a known variant, or one edit from the name.
    static func matches(_ heard: String) -> Bool {
        let word = fold(heard)
        guard !word.isEmpty, !notTheName.contains(word) else { return false }
        if variants.map(fold).contains(word) { return true }
        let target = fold(name)
        guard !word.contains(" "), abs(word.count - target.count) <= 1, word.first == target.first else { return false }
        return editDistance(word, target) <= 1
    }

    /// A75: close to the name but not taken (two edits), for the log that grows the list.
    static func isNearMiss(_ heard: String) -> Bool {
        let word = fold(heard)
        guard !word.isEmpty, !matches(word), !word.contains(" ") else { return false }
        let target = fold(name)
        return word.first == target.first && abs(word.count - target.count) <= 2 && editDistance(word, target) == 2
    }

    static func fold(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "sv_SE"))
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var previous = row[0]
            row[0] = i
            for j in 1...b.count {
                let old = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = old
            }
        }
        return row[b.count]
    }
}

/// What the wearer asked for after the name (D74).
enum VoiceIntent: Equatable, Sendable {
    case switchTo(ConversationMode)
    /// "pausa": let go of the microphone so music can play.
    case pause
    /// "sluta lyssna": stop completely.
    case stopListening
    /// "kom ihåg …", "glöm …", "regel: …" (D80): straight into Minne, never sent as a question.
    case remember(String)
    case forget(String)
    case rule(String)
    /// A6: the music ("nästa låt", "förra låten", "pausa musiken") and "tillbaka till Lumen".
    case music(CommandAction)
    /// A6: "det där var fel" after the name: the last turn goes to /feedback.
    case complaint
    /// A7: a level-1 action the phone does itself ("upprepa", "viska", "spara det", "vilket prov har jag härnäst").
    case command(CommandAction)
    /// Anything else. In Socialt läge and Rizzläge an instruction to the AI (D69 calibration, "ge mig tre"),
    /// in the other modes a question to Lumen. Never a line of the conversation.
    case instruction(String)
}

/// A recognised turn split at the name: the words before it stay conversation, the rest is for Lumen.
struct VoiceUtterance: Equatable, Sendable {
    var before: String?
    var intent: VoiceIntent?
}

/// The one voice path for every mode (D74; D69 uses it for calibration and "ge mig tre"). Pure; unit-tested.
enum VoiceChannel {
    /// The backend keeps an instruction at most this long (D69).
    static let instructionLimit = 300

    private static let modeNames: [ConversationMode: Set<String>] = [
        .standard: ["standardläge", "standardläget", "standard", "frågor", "frågeläge", "frågorläge", "frågläge", "auto", "questions"], // A37: the new name first, the old still heard
        .prov: ["provläge", "provläget", "prov"],
        .interview: ["intervjuläge", "intervjuläget", "intervju"],
        .social: ["socialtläge", "socialtläget", "socialläge", "socialaläget", "socialt", "social", "socialmode"],
        .rizz: ["rizzläge", "rizzläget", "rizläge", "risläge", "rissläge", "ritsläge", "rizz", "rizzmode"],
    ]
    /// After the name only, besides the user-editable phrases (A6): too short to be safe without "Lumen".
    private static let namedPauseAliases: Set<String> = ["paus", "pausa dig"]

    /// A turn without the name has no intent and is unchanged. The name alone is neither.
    static func parse(_ text: String) -> VoiceUtterance {
        guard let name = wakeWord(in: text), isAddress(text, nameAt: name) else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return VoiceUtterance(before: trimmed.isEmpty ? nil : trimmed, intent: nil)
        }
        let before = text[..<name.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-–")))
        let after = text[name.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return VoiceUtterance(before: before.isEmpty ? nil : before, intent: after.isEmpty ? nil : intent(for: after))
    }

    /// The words after the name.
    static func intent(for command: String) -> VoiceIntent {
        let words = normalized(command)
        let original = command.trimmingCharacters(in: .whitespacesAndNewlines)
        for (prefix, make) in memoryPrefixes where words.hasPrefix(prefix) {
            let rest = stripPrefix(original, words: prefix.split(separator: " ").count)
            if !rest.isEmpty { return make(String(rest.prefix(instructionLimit))) }
        }
        // A6.4: the phrases come from the command table, so the user's own phrases work here too.
        let table = CommandBook.shared.table
        if namedPauseAliases.contains(words) { return .pause }
        switch table.action(forWhole: words, named: true) {
        case .musicHandOff: return .pause
        case .stop: return .stopListening
        case .nextTrack: return .music(.nextTrack)
        case .previousTrack: return .music(.previousTrack)
        case .pauseMusic: return .music(.pauseMusic)
        case .backToLumen: return .music(.backToLumen)
        case .wrong: return .complaint
        case .switchMode, .quizMe, nil: break
        case let action?:
            // A7: level 1 on the phone; level 2 to the backend in the words K9 knows.
            return action.level == 1 ? .command(action) : .instruction(action.instruction)
        }
        let prefixed = table.prefix(in: words)
        if let prefixed, prefixed.action == .quizMe {
            // "testa mig på fotosyntes" (a user phrase) reaches the tutor as "förhör mig på fotosyntes".
            let rest = prefixed.rest.isEmpty ? "" : " " + prefixed.rest
            return .instruction(String(("förhör mig" + rest).prefix(instructionLimit)))
        }
        let target = prefixed?.action == .switchMode ? prefixed?.rest ?? words : words
        let compact = target.replacingOccurrences(of: " ", with: "")
        if let mode = modeNames.first(where: { $0.value.contains(compact) })?.key {
            return .switchTo(mode)
        }
        return .instruction(String(command.trimmingCharacters(in: .whitespacesAndNewlines).prefix(instructionLimit)))
    }

    private static let memoryPrefixes: [(String, @Sendable (String) -> VoiceIntent)] = [
        ("kom ihåg att ", { .remember($0) }), ("kom ihåg ", { .remember($0) }), ("remember that ", { .remember($0) }),
        // A7: "glöm inte …" is remembering, so it comes before "glöm …".
        ("glöm inte att ", { .remember($0) }), ("glöm inte ", { .remember($0) }),
        ("glöm att ", { .forget($0) }), ("glöm ", { .forget($0) }), ("forget ", { .forget($0) }),
        ("regel ", { .rule($0) }), ("ny regel ", { .rule($0) }), ("rule ", { .rule($0) }),
    ]

    /// The original words after the first `count` words (keeps case and punctuation of the rest).
    private static func stripPrefix(_ text: String, words count: Int) -> String {
        var rest = Substring(text)
        for _ in 0..<count {
            rest = rest.drop(while: { !$0.isLetter && !$0.isNumber })
            rest = rest.drop(while: { $0.isLetter || $0.isNumber })
        }
        return rest.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    /// What a mode is called out loud, for the confirmation in the AirPods.
    static func spokenName(_ mode: ConversationMode) -> String {
        switch mode {
        case .standard: "Standardläge."
        case .prov: "Provläge."
        case .interview: "Intervjuläge."
        case .social: "Socialt läge."
        case .rizz: "Rizzläge."
        }
    }

    /// A14 (Toby T6: "Jag berättade om Lumen för min kompis" became an instruction, 5 of 68): the name addresses Lumen
    /// only at the start of the utterance, after a sentence end ("Ja precis. Lumen, …") or after a greeting alone.
    private static let greetings: Set<String> = ["hej", "hallå", "okej", "ok", "ja", "nej", "du", "hörru", "hey", "hi", "okay"]

    static func isAddress(_ text: String, nameAt name: Range<String.Index>) -> Bool {
        let before = text[..<name.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:-–")))
        if before.isEmpty { return true }
        if let last = before.last, ".?!".contains(last) { return true }
        return greetings.contains(normalized(before))
    }

    /// The name as a word of its own (A75: or as it is misheard, "Lumin", "Lummen", "Lu men"), any case, with or
    /// without an accent. Only where it addresses Lumen counts (`isAddress`); the first such word wins.
    static func wakeWord(in text: String) -> Range<String.Index>? {
        let words = wordRanges(in: text)
        for (index, range) in words.enumerated() {
            if index + 1 < words.count {
                let pair = text[range.lowerBound..<words[index + 1].upperBound]
                // "Lu men": two short words with only a space or hyphen between them.
                if pair.count <= 8, WakeWord.matches(String(pair)), String(text[range]).count <= 3 {
                    return range.lowerBound..<words[index + 1].upperBound
                }
            }
            if WakeWord.matches(String(text[range])) { return range }
        }
        return nil
    }

    /// A75: the first word, when it looks like the name but was not taken (for the log).
    static func nearMissName(in text: String) -> String? {
        guard let first = wordRanges(in: text).first else { return nil }
        let word = String(text[first])
        return WakeWord.isNearMiss(word) ? word : nil
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index].isLetter else { index = text.index(after: index); continue }
            let start = index
            while index < text.endIndex, text[index].isLetter { index = text.index(after: index) }
            ranges.append(start..<index)
        }
        return ranges
    }

    static func normalized(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
            .split(separator: " ").joined(separator: " ")
    }
}

/// D74: turns that are only filler ("äh", "ja", "kom igen") are never sent as a question or a reason to answer.
enum FillerFilter {
    private static let phrases = ["kom igen", "eller hur", "du vet"]
    private static let words: Set<String> = ["äh", "ähm", "öh", "öhm", "eh", "ehm", "hm", "hmm", "mm", "mmm", "mhm", "ja",
                                             "jaa", "jo", "joo", "aa", "a", "okej", "ok", "okay", "alltså", "typ",
                                             "liksom", "precis", "så", "va", "nä", "nää", "asså", "ba", "bara", "uh", "um"]

    static func isOnlyFiller(_ text: String) -> Bool {
        var rest = " " + VoiceChannel.normalized(text) + " "
        for phrase in phrases { rest = rest.replacingOccurrences(of: " \(phrase) ", with: " ") }
        let tokens = rest.split(separator: " ").map(String.init)
        return tokens.allSatisfy { words.contains($0) }
    }
}
