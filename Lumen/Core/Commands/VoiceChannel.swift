import Foundation

/// The name the wearer says to talk to the app (D74). One constant, so a new app name changes one line.
enum WakeWord {
    static let name = "Lumen"
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
        .standard: ["frågor", "frågeläge", "frågorläge", "frågläge", "auto", "questions"],
        .prov: ["provläge", "provläget", "prov"],
        .interview: ["intervjuläge", "intervjuläget", "intervju"],
        .social: ["socialtläge", "socialtläget", "socialläge", "socialaläget", "socialt", "social", "socialmode"],
        .rizz: ["rizzläge", "rizzläget", "rizläge", "risläge", "rissläge", "ritsläge", "rizz", "rizzmode"],
    ]
    /// After the name only, besides the user-editable phrases (A6): too short to be safe without "Lumen".
    private static let namedPauseAliases: Set<String> = ["paus", "pausa dig"]

    /// A turn without the name has no intent and is unchanged. The name alone is neither.
    static func parse(_ text: String) -> VoiceUtterance {
        guard let name = wakeWord(in: text) else {
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
        case .standard: "Frågor."
        case .prov: "Provläge."
        case .interview: "Intervjuläge."
        case .social: "Socialt läge."
        case .rizz: "Rizzläge."
        }
    }

    /// The name as a word of its own, any case, with or without an accent ("Lumén"). "Lumens" is not the name.
    private static func wakeWord(in text: String) -> Range<String.Index>? {
        var from = text.startIndex
        while let range = text.range(of: WakeWord.name, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
            let startsWord = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            let endsWord = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
            if startsWord, endsWord { return range }
            from = range.upperBound
        }
        return nil
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
