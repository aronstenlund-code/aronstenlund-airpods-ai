import Foundation

// MARK: - A93 (D169, K58): "Gör med ChatGPT" and the answer pasted under "Skriv text"

/// The answer pasted from ChatGPT in K58's format ("Fråga: …" / "Svar: …" / empty line, repeated), read on the phone
/// with no server call and nothing shortened. The same rules as Kevin's `drill/import_text.ts`: the short answer is the
/// first sentence of the answer as written, the long answer is the whole answer (D145). ChatGPT's usual extras
/// ("**Fråga 3:**", "1. Fråga:", "F:", an intro line) are tolerated; lines that are not part of a question or an
/// answer are listed in `unreadable`.
struct ChatGPTImport: Equatable, Sendable {
    var items: [DrillItem]
    /// "Rad 1: Här är dina frågor! – skälet" – lines that could not be read.
    var unreadable: [String]
    /// A96: read, but worth a look ("Rad 4: Frågan saknade Fråga:.", a long answer, a question asked twice).
    var warnings: [String] = []

    static let maxItems = 60
    static let maxQuestionChars = 300
    /// A96 (K60): an answer is never cut. Over 3 000 characters it gets a warning, over 4 000 it is left out
    /// (every character costs voice credits, D120).
    static let longAnswerChars = 3_000
    static let maxAnswerChars = 4_000

    /// One question being read: its answer as paragraphs (A96: a blank line no longer ends the answer).
    private struct Reading {
        struct Paragraph {
            var line: Int
            var text: [String]
            /// Came after a blank line (only such a paragraph can be the sign-off, rule 1).
            var afterBlankLine: Bool
        }
        enum State { case question, answer, closed }

        var line: Int
        var question: String
        var paragraphs: [Paragraph] = []
        var state = State.question
        var blankLine = false

        /// "Svar:" starts a paragraph of its own (also a second "Svar:", and after a heading closed the answer).
        mutating func answer(_ text: String, at line: Int) {
            paragraphs.append(Paragraph(line: line, text: text.isEmpty ? [] : [text], afterBlankLine: false))
            state = .answer
            blankLine = false
        }

        /// A line without a label inside the answer: on over more lines, and over a blank line (rule 1).
        mutating func goOn(_ text: String, at line: Int) {
            if blankLine || paragraphs.isEmpty {
                paragraphs.append(Paragraph(line: line, text: [text], afterBlankLine: blankLine))
            } else {
                paragraphs[paragraphs.count - 1].text.append(text)
            }
            blankLine = false
        }
    }

    /// Nil when the text is not K58's format (no "Fråga:" followed by a "Svar:"): then it is material as before.
    /// A96 (Oscar O58, Kevin K60): the same rules and the same result as `drill/import_text.ts`, checked by both
    /// sides against `testdata/import/o58-cases.json`.
    static func read(_ text: String) -> ChatGPTImport? {
        let lines = String(text.prefix(60_000)).replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var items: [DrillItem] = []
        var unreadable: [String] = []
        var warnings: [String] = []
        var current: Reading?

        func skip(_ line: Int, _ text: String, _ reason: String) {
            unreadable.append("Rad \(line): \(String(text.trimmingCharacters(in: .whitespaces).prefix(120))) – \(reason)")
        }
        func warn(_ line: Int, _ reason: String) {
            warnings.append("Rad \(line): \(reason)")
        }
        func flush(atEnd: Bool = false) {
            guard var reading = current else { return }
            current = nil
            // Rule 1: after the last answer, a paragraph of its own that ends in "?" or "!" is ChatGPT's sign-off
            // ("Lycka till på provet! Vill du att jag gör fler frågor?"), not part of the answer.
            if atEnd {
                while reading.paragraphs.count > 1, let last = reading.paragraphs.last, last.afterBlankLine {
                    let text = clean(last.text.joined(separator: " "), limit: Int.max)
                    let end = text.reversed().first { !"\"”')".contains($0) }
                    guard let end, end == "?" || end == "!" else { break }
                    skip(last.line, text, "Avslutning, inte en del av svaret.")
                    warn(last.line, "Texten efter sista svaret lästes inte in.")
                    reading.paragraphs.removeLast()
                }
            }
            let questionText = clean(reading.question, limit: maxQuestionChars)
            let answerText = clean(reading.paragraphs.map { $0.text.joined(separator: " ") }.joined(separator: " "),
                                   limit: Int.max)
            // The prompt's own example ("Fråga: <frågan>") pasted instead of ChatGPT's answer is not a question.
            if questionText.hasPrefix("<") && questionText.hasSuffix(">") || answerText.hasPrefix("<") && answerText.hasSuffix(">") {
                skip(reading.line, "Fråga: \(questionText)", "Exemplet ur prompten, inte ett svar.")
                return
            }
            guard !questionText.isEmpty, !answerText.isEmpty else {
                skip(reading.line, "Fråga: \(questionText)", "Frågan har inget svar.")
                return
            }
            guard items.count < maxItems else {
                skip(reading.line, "Fråga: \(questionText)", "Högst \(maxItems) frågor.")
                return
            }
            guard answerText.count <= maxAnswerChars else {
                skip(reading.line, "Fråga: \(questionText)", "Svaret är för långt (högst 4 000 tecken).")
                return
            }
            if answerText.count > longAnswerChars {
                warn(reading.line, "Svaret har \(answerText.count) tecken, långt att lyssna på.")
            }
            var short = firstSentence(answerText)
            let rest = String(answerText.dropFirst(short.count)).trimmingCharacters(in: .whitespaces)
            if let last = short.last, !".!?".contains(last) { short += "." }
            let asked = questionText.last.map { "?.!".contains($0) } == true ? questionText : questionText + "?"
            if items.contains(where: { $0.question.lowercased() == asked.lowercased() }) {
                warn(reading.line, "Frågan finns redan.")
            }
            items.append(DrillItem(question: asked, short: short, long: DrillItem.long(rest, startingWith: short)))
        }

        for (index, line) in lines.enumerated() {
            let number = index + 1
            if let found = label(line) {
                let (kind, rest) = found
                if kind == .question {
                    flush()
                    current = Reading(line: number, question: rest)
                } else if current != nil {
                    current?.answer(rest, at: number)
                } else {
                    skip(number, line, "Ett svar utan fråga före.")
                }
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                current?.blankLine = true
                continue
            }
            // Rule 2: a heading, a code fence or a rule is never answer text. It ends the answer, which stays open
            // for the sign-off check if it was the last one (as Kevin's `closed`).
            if isFormatting(trimmed) {
                skip(number, trimmed, "Rubrik eller formatering, inte en del av svaret.")
                if current?.state == .answer { current?.state = .closed }
                continue
            }
            // Rule 3: a question without "Fråga:" ("**1. Vad är magma?**") right before a "Svar:" line.
            if current?.state != .question, index + 1 < lines.count,
               label(lines[index + 1])?.0 == .answer, let question = unlabelledQuestion(trimmed) {
                flush()
                current = Reading(line: number, question: question)
                warn(number, "Frågan saknade Fråga:.")
                continue
            }
            if current?.state == .answer {
                current?.goOn(withoutBullet(trimmed), at: number)
            } else if current?.state == .question, current?.blankLine == false {
                current?.question += " " + trimmed // the question went on over a second line
            } else {
                skip(number, trimmed, "Raden börjar inte med Fråga: eller Svar:.")
            }
        }
        flush(atEnd: true)
        return items.isEmpty ? nil : ChatGPTImport(items: items, unreadable: unreadable, warnings: warnings)
    }

    /// A line inside the answer that ChatGPT made a list item: "- …", "• …", "* …", "1. …".
    private static func withoutBullet(_ line: String) -> String {
        var s = Substring(line)
        if let first = s.first, "-•*".contains(first), s.dropFirst().first?.isWhitespace == true {
            return String(s.dropFirst().drop { $0.isWhitespace })
        }
        let digits = s.prefix { $0.isNumber }
        if !digits.isEmpty, let after = s.dropFirst(digits.count).first, ".)".contains(after),
           s.dropFirst(digits.count + 1).first?.isWhitespace == true {
            s = s.dropFirst(digits.count + 1).drop { $0.isWhitespace }
        }
        return String(s)
    }

    /// "### Fråga 2", "Fråga 2", "```", "---", "***".
    private static func isFormatting(_ line: String) -> Bool {
        if line.hasPrefix("#") || line.hasPrefix("```") { return true }
        let compact = line.filter { !$0.isWhitespace }
        if compact.count >= 3, compact.allSatisfy({ "-*_=".contains($0) }) { return true }
        let plain = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces).lowercased()
        for word in ["fråga", "question"] where plain.hasPrefix(word) {
            let rest = plain.dropFirst(word.count).drop { $0 == " " }
            guard let first = rest.first, first.isNumber else { return false }
            let tail = rest.drop { $0.isNumber }
            return tail.isEmpty || tail == "." || tail == ")"
        }
        return false
    }

    /// "**1. Vad är magma?**" → "Vad är magma?"; nil unless it ends in "?".
    private static func unlabelledQuestion(_ line: String) -> String? {
        var text = Substring(clean(line, limit: maxQuestionChars))
        let digits = text.prefix { $0.isNumber }
        if !digits.isEmpty, let after = text.dropFirst(digits.count).first, ".)".contains(after) {
            text = text.dropFirst(digits.count + 1).drop { $0 == " " }
        }
        return text.hasSuffix("?") && text.count > 1 ? String(text) : nil
    }

    /// Cheap check while typing: the text has a "Fråga:" line and a "Svar:" line.
    static func looksLikeImport(_ text: String) -> Bool {
        var question = false
        for line in text.split(whereSeparator: \.isNewline) {
            guard let kind = label(String(line))?.0 else { continue }
            if kind == .question { question = true } else if question { return true }
        }
        return false
    }

    // MARK: Reading

    private enum Kind { case question, answer }

    /// "Fråga:", "**Fråga 3:**", "1. Fråga:", "- F:", "Svar:", "S:" … and the text after it.
    private static func label(_ line: String) -> (Kind, String)? {
        // "**Fråga" is emphasis, not a "*" bullet (Kevin's regex backtracks; here the emphasis is dropped first).
        var s = dropEmphasis(Substring(line).drop { $0.isWhitespace })
        s = s.drop { $0 == "#" }.drop { $0.isWhitespace } // "### Fråga 1: …" is a question (A96, case 21)
        s = dropEmphasis(s)
        if let first = s.first, "-*•>".contains(first) { s = s.dropFirst().drop { $0.isWhitespace } }
        let digits = s.prefix { $0.isNumber }
        if !digits.isEmpty, let after = s.dropFirst(digits.count).first, ".)".contains(after) {
            s = s.dropFirst(digits.count + 1).drop { $0.isWhitespace }
        }
        s = dropEmphasis(s)
        let lower = s.lowercased()
        let kind: Kind
        let word: Int
        if lower.hasPrefix("fråga") { (kind, word) = (.question, 5) }
        else if lower.hasPrefix("svar") { (kind, word) = (.answer, 4) }
        else if lower.hasPrefix("f") { (kind, word) = (.question, 1) }
        else if lower.hasPrefix("s") { (kind, word) = (.answer, 1) }
        else { return nil }
        s = s.dropFirst(word).drop { $0 == " " }
        s = s.drop { $0.isNumber }.drop { $0 == " " } // "Fråga 3:"
        s = dropEmphasis(s)
        guard let colon = s.first, colon == ":" || colon == "：" else { return nil }
        var rest = dropEmphasis(s.dropFirst().drop { $0.isWhitespace }).drop { $0.isWhitespace }
        while rest.hasSuffix("**") || rest.hasSuffix("__") { rest = rest.dropLast(2) }
        return (kind, String(rest).trimmingCharacters(in: .whitespaces))
    }

    private static func dropEmphasis(_ s: Substring) -> Substring {
        var s = s
        while s.hasPrefix("**") || s.hasPrefix("__") { s = s.dropFirst(2) }
        return s
    }

    /// One line of text to read aloud: no markdown, single spaces.
    private static func clean(_ text: String, limit: Int) -> String {
        let plain = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
        let single = plain.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(single.prefix(limit)).trimmingCharacters(in: .whitespaces)
    }

    /// Swedish abbreviations whose full stop does not end a sentence.
    private static let abbreviations: Set<String> = [
        "t.ex", "bl.a", "t.o.m", "s.k", "d.v.s", "dvs", "osv", "m.m", "m.fl", "ca", "kl", "nr", "resp", "jfr", "el",
        "o.d", "e.d", "f.d", "f.kr", "e.kr", "ff", "s", "st", "tex",
    ]

    /// The first sentence: up to ". ", "! " or "? " followed by a capital letter or a digit, not after an
    /// abbreviation ("t.ex. Sverige") and not inside a decimal number ("3.5").
    static func firstSentence(_ answer: String) -> String {
        let text = Array(answer.trimmingCharacters(in: .whitespacesAndNewlines))
        var i = 0
        while i < text.count {
            let c = text[i]
            if ".!?".contains(c) {
                var end = i + 1
                while end < text.count, "\"”')".contains(text[end]) { end += 1 }
                var next = end
                while next < text.count, text[next].isWhitespace { next += 1 }
                if next > end, next < text.count {
                    var start = next
                    while start < text.count, "\"”(".contains(text[start]) { start += 1 }
                    let opensSentence = start < text.count && (text[start].isUppercase || text[start].isNumber)
                    if opensSentence, !(c == "." && endsWithAbbreviation(text, before: i)) {
                        return String(text[..<end]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            i += 1
        }
        return String(text).trimmingCharacters(in: .whitespaces)
    }

    private static func endsWithAbbreviation(_ text: [Character], before dot: Int) -> Bool {
        var start = dot
        while start > 0, !text[start - 1].isWhitespace { start -= 1 }
        let word = String(text[start..<dot]).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "(\"”"))
        return abbreviations.contains(word)
    }
}

// MARK: - The prompt (K58 `Shared/chatgpt-prompt.txt`)

@MainActor
enum ChatGPTPrompt {
    /// The template with {{AMNE}}, {{ARSKURS}}, {{ANTAL}} and {{FRAGOR}}, bundled from `Shared/chatgpt-prompt.txt`.
    static func template(bundle: Bundle = .main) -> String {
        if let url = bundle.url(forResource: "chatgpt-prompt", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8), text.contains("{{ANTAL}}") {
            return text
        }
        return fallback
    }

    static func filled(_ template: String, subject: String, grade: StudyProfile.Grade?, questions: Int,
                       practised: [String]) -> String {
        let subjectText = subject.trimmingCharacters(in: .whitespaces)
        let practisedText = practised.isEmpty ? "(inga än)" : practised.map { "- \($0)" }.joined(separator: "\n")
        return template
            .replacingOccurrences(of: "{{AMNE}}", with: subjectText.isEmpty ? "det här ämnet" : subjectText)
            .replacingOccurrences(of: "{{ARSKURS}}", with: grade.map { GradeChoice.label($0) } ?? "min årskurs")
            .replacingOccurrences(of: "{{ANTAL}}", with: String(questions))
            .replacingOccurrences(of: "{{FRAGOR}}", with: practisedText)
    }

    /// Used only if the bundled file is missing: the same text as K58's template.
    static let fallback = """
    Du hjälper mig plugga till ett prov i {{AMNE}} för {{ARSKURS}}. Läs alla filer jag har bifogat. Läs också frågorna nedan som jag redan har övat på.

    Frågor jag har övat på:
    {{FRAGOR}}

    Gör {{ANTAL}} provfrågor med svar. Regler:
    1. Frågorna ska bara bygga på det som står i filerna och i frågorna ovan. Hitta inte på något som inte står där.
    2. Ta med frågorna ovan om de finns i materialet, och fyll på med nya tills det är {{ANTAL}}. Finns det inte stoff till {{ANTAL}} frågor, gör färre.
    3. Varje fråga ska vara kort, helst högst 5 ord, och fråga efter förståelse: varför, hur, vad betyder, vad är skillnaden. Till exempel "Varför behöver växter ljus?".
    4. Varje svar ska vara ett fullständigt svar som ger högsta betyg, på ungefär 90 ord.
    5. Den första meningen i varje svar ska ensam vara ett fullgott kort svar på frågan, högst 25 ord. Den ska svara direkt, inte inleda ("Det finns flera orsaker" räcker inte). Resten av svaret förklarar mer.
    6. Skriv i hela meningar som går att läsa högt. Inga listor, inga punkter, ingen fetstil, inga rubriker, ingen markdown.

    Svara BARA i det här formatet, utan något före eller efter (ingen inledning, ingen avslutning):

    Fråga: <frågan>
    Svar: <svaret>

    Fråga: <frågan>
    Svar: <svaret>

    En tom rad mellan varje fråga. Varje svar på en enda rad efter "Svar:".
    """
}

extension RepetitionModel {
    /// K58's template filled in; `drill` = an existing exam whose questions go into {{FRAGOR}}.
    func chatGPTPrompt(title: String, grade: StudyProfile.Grade?, questions: Int, drill: Drill?) -> String {
        let subject = drill.map { $0.summary.subject.isEmpty ? $0.title : $0.summary.subject } ?? title
        return ChatGPTPrompt.filled(ChatGPTPrompt.template(), subject: subject, grade: grade ?? preferredGrade,
                                    questions: questions, practised: drill?.items.map(\.question) ?? [])
    }

    /// Saves a new exam, or adds to `drill` (questions it already has are left out). The sound is made as for any
    /// saved exam. Nil = the month's questions are used up (D155), nothing is saved.
    @discardableResult
    /// `voice` (D151): "A", "B" or "C" for a new exam, locked at this first save; ignored when adding to `drill`.
    func saveImport(_ found: ChatGPTImport, title: String, grade: StudyProfile.Grade?, voice: String? = nil,
                    into drill: Drill?) -> Drill? {
        if let quota, quota.left == 0 { return nil }
        if let grade { preferredGrade = grade }
        if var existing = drill.flatMap({ store.drill($0.id) }) ?? drill {
            let known = Set(existing.items.map { Self.key($0.question) })
            existing.items += found.items.filter { !known.contains(Self.key($0.question)) }
            return save(existing)
        }
        let name = title.trimmingCharacters(in: .whitespaces)
        var made = Drill(title: name.isEmpty ? "Nytt prov" : name,
                         summary: DrillSummary(subject: "", grade: grade.map { GradeChoice.label($0) } ?? "", covers: ""),
                         items: found.items, questionCount: found.items.count)
        made.voiceModel = voice
        return save(made)
    }

    private static func key(_ question: String) -> String {
        question.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
