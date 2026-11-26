import Foundation

/// D142: a repetition exam ("prov" in the app). Questions with a short answer and a long A+ answer, played in AirPods
/// by `RepetitionPlayer`. D145: the long answer always begins with the short answer word for word, so the short one
/// is the long file up to the end of its first sentence.
struct Drill: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var summary: DrillSummary
    var items: [DrillItem]
    var createdAt: Date = Date()
    /// D146: 20 questions and long answers of about 90 words by default; the user may change both.
    var questionCount: Int = Drill.defaultQuestionCount
    var longWords: Int = Drill.defaultLongWords
    /// A81 (D143): the share code this copy came from, if any.
    var sharedFrom: String?
    /// K46: the exam's id on the server (per account). Nil until the first save reached the server.
    var serverID: String?
    /// K46: changed on the phone since the server last saw it (an edit made offline is sent on the next open).
    var needsUpload: Bool?
    /// Toby 2 T24: the account that holds `serverID` on the server, set once its list showed the exam. Only that
    /// account's list may delete the exam here.
    var ownerID: String?
    /// Kelly N1, K51: "Tryck en gång för svaret." in the exam's own voice (`<hash>.mp3` in the cache).
    var cueAudio: String?
    /// A83 (K49): this exam is published at a school (kept on the phone; the server does not say it in `get`).
    var publication: DrillPublication?
    /// A83: the publication this copy was added from ("played" is counted on it).
    var fromPublication: String?
    /// A84 (D151): "A", "B" or "C", chosen before the sound is made; locked after the first save (K50).
    var voiceModel: String?
    /// A105 (D185, K70): a running text read aloud instead of questions. Nil = questions (every exam before K70).
    /// Locked at the first save (the server answers 409 `kind_locked`).
    var kind: DrillKind?

    /// A107 (D190, K71): false while the server has made no sound for this exam (saved with `defer_audio`, never
    /// started). Nil = started, or an exam from before K71. Starta prov starts it (`RepetitionModel.startAudio`).
    var audioStarted: Bool?

    /// A132 (D215): a text from "Säg i AirPods". It is never "Nästa prov" and never among "Andra prov"; it is kept as
    /// "Senaste" under the field.
    var said: Bool?

    /// A132: said in the field. A text saved before the mark existed is known by what the field made of it: a text
    /// without subject and grade, named after its own first words.
    var isSaid: Bool {
        if let said { return said }
        guard isText, summary.subject.isEmpty, summary.grade.isEmpty, summary.covers.isEmpty, !items.isEmpty else { return false }
        return title == SaidText.title(saidText)
    }

    /// A132: the text as it was written in the field (one line per part).
    var saidText: String { items.map(\.long).joined(separator: "\n") }

    /// A135 (D219.5; Angela Schrute's finding): some of this exam's sound was removed from the phone to stay under the
    /// storage ceiling. It is on the server and is fetched again when the exam is opened or started, not before
    /// (else Start would remove and fetch the same files over and over).
    var audioTrimmed: Bool?

    /// A131 (D213, K90): what Starta prov costs in credits, as the server last said it. Never counted in the app.
    var startCost: Int?

    /// A136 (D220.2, K95): "Hur ska det låta?" in the user's own words (at most 80 characters). Nil = no style.
    var style: String?
    /// A136 (D220.3, K96): the voice from the server's catalog, chosen before the first save and locked after it.
    /// Nil = the server's own voice.
    var voiceID: String?

    /// A136: how this text sounds (its voice and style). The same text with another sound is another exam, since the
    /// server locks both per exam.
    var sound: SaySound { SaySound(voiceID: voiceID, style: style, mix: mixVoices == true) }

    /// A140 (D223, K99): "Blanda röster": the server draws a voice per part when the text is first saved (the same at
    /// every lap). Locked after the first save. Nil = one voice.
    var mixVoices: Bool?
    /// A140 (K99): the voice was chosen by the server from the style ("Hur ska det låta?"), not by the user, and why
    /// (a short Swedish sentence).
    var voicePicked: Bool?
    var voiceReason: String?

    /// A136: the style as it is sent and compared: trimmed, at most what the server takes; nil when empty.
    static func cleanStyle(_ style: String?) -> String? {
        let trimmed = (style ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(SaidText.maxStyleChars))
    }

    /// A107: the sound is not asked for yet; Starta prov asks for it.
    var awaitsAudioStart: Bool { audioStarted == false }

    /// A105: the items are the text's parts (headings and paragraphs), read in order.
    var isText: Bool { kind == .text }

    /// A154 (D239, Oscar O90): 12, not 20. Twenty questions cost about 9 800 credits, and a new account has 1 500.
    static let defaultQuestionCount = 12
    static let defaultLongWords = 90

    /// "Ljud: 36 av 40 klara" (Kelly Ke49 §4.7): with D145 two files per question, the question and the long answer.
    /// A105 (K70): a text has one file per part.
    var audioFileCount: Int { isText ? items.count : items.count * 2 }

    /// A105 (D185): the text as the reading player and the screen see it.
    var readingParts: [ReadingParagraph] {
        items.map { ReadingParagraph(sentences: $0.readingSentences, isHeading: $0.part == .heading) }
    }

    /// A105: "Mening 5 av 9".
    var sentenceCount: Int { items.reduce(0) { $0 + $1.readingSentences.count } }

    /// A105 (D185): a new text from `/exam read`'s parts, saved like an exam (`RepetitionModel.save`).
    static func text(title: String, summary: DrillSummary, parts: [DrillItem]) -> Drill {
        var drill = Drill(title: title, summary: summary, items: parts)
        drill.kind = .text
        drill.questionCount = parts.count
        return drill
    }
}

/// A105 (D185, K70): what an exam is: questions (D142) or a text read aloud.
enum DrillKind: String, Codable, Sendable {
    case questions
    case text
}

/// A105 (K70): a text's part: a heading (one sentence, read as a heading) or a paragraph.
enum DrillPart: String, Codable, Sendable {
    case heading
    case para
}

/// A99 (D176): how long a question is to listen to, from the server (≤ 800 characters normal, 801–1 600 a bit longer,
/// over 1 600 too long; the limits are on the server). Nothing is charged yet (D157).
enum DrillLengthClass: String, Codable, Sendable {
    case normal
    case longer
    case tooLong = "too_long"

    /// Kelly (A99): the quiet line on the question's row; nil for a normal one.
    var label: String? {
        switch self {
        case .normal: nil
        case .longer: String(localized: "Lite längre än vanligt")
        case .tooLong: String(localized: "Mycket lång")
        }
    }

    /// Kelly (A99): the editor's footer under the answer; nil for a normal one.
    var editorNote: String? {
        switch self {
        case .normal: nil
        case .longer: String(localized: "Frågan och svaret är lite längre än vanligt.")
        case .tooLong: String(localized: "Frågan och svaret är mycket långa. Korta svaret om du vill.")
        }
    }
}

/// What EarMind made of the material (K45 `summary`). The user may correct it with a line of text.
struct DrillSummary: Codable, Equatable, Sendable {
    var subject: String
    var grade: String
    var covers: String
}

struct DrillItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var question: String
    var short: String
    var long: String
    /// K46: the item's id on the server, kept so a saved list keeps its rows.
    var serverID: String?
    /// K46: the downloaded files (`<hash>.mp3` in Application Support, A103 D186), and where the short answer ends in the long file
    /// (D145, from ElevenLabs' character timestamps). Nil until downloaded; a changed text gets new ones.
    var questionAudio: String?
    var longAudio: String?
    var shortEndMs: Int?
    /// K61 (D176): the server's length class (question + long answer in characters to ElevenLabs). Nil until the
    /// server has seen the item, and after the text is changed.
    var lengthClass: DrillLengthClass?
    /// A102 (K66 point 4): the text to show where it differs from the spoken one (numbers and formulas as in a
    /// textbook: "1850", "a² + b²"). The voice always reads `question`, `short` and `long`. Nil when they are the same.
    var screen: DrillScreenText?
    /// A105 (D185, K70): a text's part. The part's text is `long` (as on the server); `question` and `short` are empty.
    var part: DrillPart?
    /// A105 (K70): the part's sentences as the server split them (the screen's sentences, the same number as the
    /// times). Nil until the server has seen the part.
    var sentences: [String]?
    /// A105 (K70): [start_ms, end_ms] per sentence in the part's file (`longAudio`), from the download.
    var sentenceTimesMs: [[Int]]?
    /// A136 (D220.1): [start_ms, end_ms] per spoken word in the part's file, for "Skriv i takt". Nil for a file made
    /// before the server kept them; the pauses then come after each sentence.
    var wordTimesMs: [[Int]]?
    /// A140 (K99): the voice of this part when the text's voices are mixed.
    var voiceID: String?

    init(id: UUID = UUID(), question: String, short: String, long: String, serverID: String? = nil) {
        self.id = id
        self.question = question
        self.short = short
        self.long = long
        self.serverID = serverID
    }

    /// A102: what the screen shows. Old exams without `screen` show the spoken text, as before.
    var shownQuestion: String { screen?.question ?? question }
    var shownShort: String { DrillItem.shownShort(screen?.short ?? short) }
    var shownLong: String { screen?.long ?? long }
    /// The whole answer as the editor shows it (the short answer first).
    var shownAnswer: String { DrillItem.long(shownLong, startingWith: shownShort) }

    /// A102: the item after the editor, which showed `shownQuestion` and `shownAnswer`. A field the user did not
    /// change keeps its spoken and its shown text; a changed one is spoken and shown as written (its old screen text
    /// would show the old words). Everything else (ids, sound) stays; `RepetitionModel.save` drops the sound of a
    /// changed text.
    func edited(question newQuestion: String, answer newAnswer: String) -> DrillItem {
        var item = self
        let q = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = newAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        var screen = self.screen ?? DrillScreenText()
        if q != shownQuestion.trimmingCharacters(in: .whitespacesAndNewlines) {
            item.question = q
            screen.question = nil
        }
        if a != shownAnswer.trimmingCharacters(in: .whitespacesAndNewlines) {
            item.short = DrillItem.firstSentence(a)
            item.long = a
            screen.short = nil
            screen.long = nil
        }
        item.screen = screen.isEmpty ? nil : screen
        if !item.sameText(as: self) { item.lengthClass = nil }
        return item
    }

    /// Kelly Ke61 F1: a short answer that is only a number or a formula is shown without its full stop, as in a
    /// maths book ("1856", "a² + b² = c²"); a sentence keeps it ("Runt 1850."). The shown text only, never the voice.
    static func shownShort(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasSuffix("."), !t.hasSuffix("..") else { return t }
        let body = String(t.dropLast()).trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty, body.contains(where: { $0.isNumber || "=+−-·×÷/²³√π^<>≈".contains($0) }) else { return t }
        // A word of two letters or more makes it a sentence ("Runt 1850", "pH 7").
        var run = 0
        for char in body {
            run = char.isLetter ? run + 1 : 0
            if run >= 2 { return t }
        }
        return body
    }

    /// A105 (D185): a text's part, before the server has split it.
    static func textPart(_ text: String, part: DrillPart) -> DrillItem {
        var item = DrillItem(question: "", short: "", long: text)
        item.part = part
        return item
    }

    /// A105: the sentences the reader steps through. The server's split when it has one; before that the part is
    /// one sentence (a heading always is).
    var readingSentences: [String] {
        if let sentences, !sentences.isEmpty { return sentences }
        return [long]
    }

    /// A105 (K70): the part's sentence times in seconds, nil while unknown.
    var sentenceTimes: [ClosedRange<TimeInterval>]? { Self.ranges(sentenceTimesMs) }
    /// A136: the spoken words' times in seconds.
    var wordTimes: [ClosedRange<TimeInterval>]? { Self.ranges(wordTimesMs) }

    private static func ranges(_ ms: [[Int]]?) -> [ClosedRange<TimeInterval>]? {
        guard let ms, !ms.isEmpty else { return nil }
        return ms.map { pair in
            let start = Double(pair.first ?? 0) / 1000
            let end = max(start, Double(pair.count > 1 ? pair[1] : pair.first ?? 0) / 1000)
            return start...end
        }
    }

    /// The same texts (an item whose texts did not change keeps its sound).
    func sameText(as other: DrillItem) -> Bool {
        question == other.question && short == other.short && long == other.long
    }

    /// D145 in the editor (Kelly Ke49 "Redigera en fråga": two fields): the short answer is the answer's first
    /// sentence. A sentence ends at ".", "!" or "?" followed by a space or the end.
    static func firstSentence(_ answer: String) -> String {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        var previous: Character?
        for (offset, char) in text.enumerated() {
            if let p = previous, ".!?".contains(p), char.isWhitespace {
                return String(text.prefix(offset)).trimmingCharacters(in: .whitespaces)
            }
            previous = char
        }
        return text
    }

    /// D145: the long answer with the short one in front, word for word. Applied when the user edits either.
    static func long(_ long: String, startingWith short: String) -> String {
        let s = short.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = long.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return l }
        if l.hasPrefix(s) { return l }
        return l.isEmpty ? s : s + " " + l
    }
}

/// A102 (K66 point 4): the shown text of a question and its answers, only the fields that differ from the spoken one.
struct DrillScreenText: Codable, Equatable, Sendable {
    var question: String?
    var short: String?
    var long: String?

    var isEmpty: Bool { question == nil && short == nil && long == nil }

    /// From /exam (`drill`, `drill_answers`, `drill_one`): the long answer is shown like the spoken one, starting with
    /// the short answer, so a shown short answer goes first in the shown long one too.
    static func made(question: String?, short: String?, long: String?, spokenShort: String, spokenLong: String) -> DrillScreenText? {
        func clean(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            return t
        }
        let q = clean(question), s = clean(short), l = clean(long)
        var shownLong: String?
        if l != nil || s != nil {
            var rest = l ?? spokenLong.trimmingCharacters(in: .whitespacesAndNewlines)
            let spoken = spokenShort.trimmingCharacters(in: .whitespacesAndNewlines)
            if l == nil, !spoken.isEmpty, rest.hasPrefix(spoken) {
                rest = String(rest.dropFirst(spoken.count)).trimmingCharacters(in: .whitespaces)
            }
            shownLong = DrillItem.long(rest, startingWith: s ?? spoken)
        }
        let text = DrillScreenText(question: q, short: s, long: shownLong)
        return text.isEmpty ? nil : text
    }
}

/// One item's sound: where the question and the long answer are, and where the short answer ends in the long file
/// (word timestamps from K46). Without a timestamp the short answer has a file of its own (the free iPhone voice
/// used until K46 is live).
struct RepetitionTrack: Equatable, Sendable {
    let question: URL
    let long: URL
    let short: Short
    /// A91 (D164): where the long file's sentences start, in seconds (K46's sentence times when the server sends
    /// them). Without them: the start, and the short answer's end (D145: the first sentence).
    var longSentenceStarts: [TimeInterval] = []

    /// The start of the sentence that was playing at `time` in the long file.
    func longSentenceStart(at time: TimeInterval) -> TimeInterval {
        var starts = longSentenceStarts
        if starts.isEmpty {
            starts = [0]
            if case .prefix(let end) = short, end.isFinite, end > 0 { starts.append(end) }
        }
        return starts.filter { $0 <= time + 0.05 }.max() ?? 0
    }

    enum Short: Equatable, Sendable {
        /// D145: the long file from the start up to this second.
        case prefix(ofLongUntil: TimeInterval)
        case file(URL)
    }
}

/// D143: "Betänketid" after a question: 6 s for exams of at most 20 questions, 4 s from 40, linear between.
enum ThinkingTime {
    static let key = "repetition.thinkingSeconds"

    static func seconds(questionCount n: Int) -> Double {
        if n <= 20 { return 6 }
        if n >= 40 { return 4 }
        return 6 - 2 * Double(n - 20) / 20
    }

    /// The user's own setting (Inställningar) wins when set.
    static func seconds(questionCount n: Int, defaults: UserDefaults) -> Double {
        let own = defaults.double(forKey: key)
        return own > 0 ? own : seconds(questionCount: n)
    }
}

/// R8: where the repetition was, saved after every step, so "Fortsätt där du var?" works after iOS closed the app.
struct RepetitionProgress: Codable, Equatable, Sendable {
    let drillID: UUID
    let index: Int
    let savedAt: Date

    static let key = "repetition.progress"

    static func load(_ defaults: UserDefaults = .standard) -> RepetitionProgress? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(RepetitionProgress.self, from: $0) }
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Kelly Ke50: the repetition mode's counted words ("1 fråga" / "20 frågor", never "1 frågor").
enum DrillText {
    /// The sound's problem as the card on Start says it: the first sentence without its full stop ("Ljudet kan inte
    /// göras just nu", Kelly A100). T55: when the credits do not cover it the first sentence alone ("Det här kostar
    /// 1 909 krediter") reads like a price, so what is left comes with it ("… Du har 1 500 kvar").
    static func cardProblem(_ problem: String, creditsShort: Bool) -> String {
        let sentences = problem.components(separatedBy: ". ")
        let kept = creditsShort && sentences.count >= 2 ? sentences.prefix(2).joined(separator: ". ") : (sentences.first ?? problem)
        return kept.hasSuffix(".") ? String(kept.dropLast()) : kept
    }

    static func questions(_ n: Int) -> String { n == 1 ? String(localized: "1 fråga") : String(localized: "\(n) frågor") }
    static func things(_ n: Int) -> String { n == 1 ? String(localized: "1 sak") : String(localized: "\(n) saker") }

    /// "cirka {m} min per varv": the question (about 3 s) and the thinking time, without answers.
    static func minutesPerLap(_ drill: Drill) -> Int {
        let seconds = Double(drill.items.count) * (3 + ThinkingTime.seconds(questionCount: drill.items.count))
        return max(1, Int((seconds / 60).rounded(.up)))
    }
}

/// A115 (D203): the free text of "Säg i AirPods" as a text read aloud: exactly what was written, one part per
/// paragraph, named after its first words.
/// A136 (D220): the voice and the style of a text from "Säg i AirPods". Two are the same when the voice is the same
/// and the cleaned styles are the same.
struct SaySound: Equatable, Hashable, Sendable {
    var voiceID: String?
    var style: String?
    /// A140 (D223): "Blanda röster". No single voice is chosen then.
    var mix: Bool

    init(voiceID: String? = nil, style: String? = nil, mix: Bool = false) {
        self.voiceID = mix ? nil : voiceID
        self.style = Drill.cleanStyle(style)
        self.mix = mix
    }

    /// A140 (K99): no voice is chosen but there is a style: the server chooses a voice from it.
    var serverPicksVoice: Bool { voiceID == nil && !mix && style != nil }

    static let plain = SaySound()

    /// Ke75 §2: a suggestion is written into the style: alone, or after a comma when there is text already.
    static func adding(_ word: String, to style: String) -> String {
        let trimmed = style.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return word }
        let joined = trimmed.hasSuffix(",") ? "\(trimmed) \(word.lowercased())" : "\(trimmed), \(word.lowercased())"
        return String(joined.prefix(SaidText.maxStyleChars))
    }

    static var suggestions: [String] { [String(localized: "Tydligt"), String(localized: "Lugnt"), String(localized: "Glatt"), String(localized: "Viskande")] }
}

enum SaidText {
    /// The server reads at most this much (K70).
    static let maxChars = 40_000
    /// A136 (K95): the server takes a style of at most this many characters.
    static let maxStyleChars = 80

    static func parts(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The characters that are read (what the month's questions are counted on).
    static func chars(_ text: String) -> Int { parts(text).reduce(0) { $0 + $1.count } }

    /// D185: one question per started 800 characters.
    static func countsAs(_ text: String) -> Int { DrillTextDraft.countsAs(chars: chars(text)) }
    /// A131 (K90): the characters the server counts as credits while a text is still being written: per line, every run
    /// of blanks is one space and the line is trimmed. An estimate that can only be too high (a part whose exact text
    /// already has sound costs 0); the server's `cost` is shown as soon as there is one.
    static func creditChars(_ text: String) -> Int {
        parts(text).reduce(0) { $0 + $1.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ").count }
    }

    /// A130 (D212): counted with the server's own number of characters per question (`/drill quota`, K82) when it is
    /// known, so the line under the field says what the server will say.
    static func countsAs(_ text: String, perQuestion: Int?) -> Int {
        DrillTextDraft.countsAs(chars: chars(text), perQuestion: max(1, perQuestion ?? 800))
    }

    /// A130 (D212): what stands under the field when Spela did not start anything.
    static func refusalLine(problem: String?, quotaExceeded: Bool, refill: String?) -> String {
        let said = (problem ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let base = said.isEmpty ? (quotaExceeded ? String(localized: "Du har inga frågor kvar den här månaden.") : String(localized: "Det gick inte att spela just nu. Försök igen om en stund.")) : said
        // A131 (K90): in credits the server's own line already says when ("Nya krediter 1 december.").
        guard quotaExceeded, let refill, !base.contains(refill), !base.contains("Nya krediter"),
              !base.contains("New credits") else { return base } // A157 (K114): the server's line in either language
        return "\(base) \(refill)"
    }

    static func title(_ text: String) -> String {
        guard let first = parts(text).first else { return String(localized: "Text") }
        let words = first.split(separator: " ").prefix(5).joined(separator: " ")
        let cut = words.count > 32 ? String(words.prefix(31)) + "…" : words
        return cut.count < first.count && !cut.hasSuffix("…") ? cut + " …" : cut
    }
}


/// A131 (D213, Aron 2026-11-17; Kelly Ke71): the month in credits. 1 credit = 1 character of new sound, repeating and
/// sound that already exists cost nothing. Every number comes from the server; these are only the words.
enum CreditText {
    /// Ke91 (Kelly): an account that counts credits hears about credits, never about "questions this month".
    static func usedUp(credits: Bool) -> String {
        credits ? String(localized: "Du har inga krediter kvar. Nya krediter kommer den 1 \(ChatGPTImportView.nextMonth()).")
            : String(localized: "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 \(ChatGPTImportView.nextMonth()).")
    }

    static func usedUpShort(credits: Bool) -> String {
        credits ? String(localized: "Inga krediter kvar.") : String(localized: "Inga frågor kvar den här månaden.")
    }

    /// "1 236": thousands with a space that does not break the line.
    static func number(_ n: Int) -> String {
        let digits = String(abs(n))
        let grouping = AppLanguage.current.grouping // A157: "1 236" in Swedish, "1,236" in English
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append(grouping) }
            out.append(ch)
        }
        return n < 0 ? "-" + out : out
    }

    /// A139 (D222, Aron 2026-11-17): short numbers. Under 1 000 as it is ("764"); from 1 000 one decimal and k
    /// ("5,3k"); from 10 000 no decimal ("12k"). What one has is rounded down and what something costs is rounded
    /// up, so the app never shows more than there is or less than it costs. The exact number is in the credits sheet.
    enum Rounding { case down, up }
    static func short(_ n: Int, _ rounding: Rounding) -> String {
        guard n >= 1000 else { return String(max(0, n)) }
        // Tenths of a thousand, rounded the way asked for.
        let tenths = rounding == .down ? n / 100 : (n + 99) / 100
        if tenths >= 100 { // 10 000 and up: whole thousands
            let thousands = rounding == .down ? n / 1000 : (n + 999) / 1000
            return String(localized: "\(number(thousands))k")
        }
        return "\(tenths / 10)\(AppLanguage.current.decimalSign)\(tenths % 10)k" // A157: "5,3k" / "5.3k"
    }

    /// What one has: "88 krediter", "5,3k krediter" (rounded down).
    static func have(_ n: Int) -> String { n == 1 ? String(localized: "1 kredit") : String(localized: "\(short(n, .down)) krediter") }
    /// What something costs: "764 krediter", "1,3k krediter" (rounded up).
    static func credits(_ n: Int) -> String { n == 1 ? String(localized: "1 kredit") : String(localized: "\(short(n, .up)) krediter") }
    /// The exact number with its word, for the credits sheet: "1 500 krediter".
    static func exact(_ n: Int) -> String { n == 1 ? String(localized: "1 kredit") : String(localized: "\(number(n)) krediter") }

    /// The capsule: "764 krediter kvar", "5,3k krediter kvar".
    static func capsule(_ left: Int) -> String { String(localized: "\(have(left)) kvar") }

    /// Under the field in Säg i AirPods, before Spela.
    static func sayLine(cost: Int) -> String {
        cost == 0 ? String(localized: "Kostar inget. Ljudet finns redan.") : String(localized: "Kostar \(credits(cost)). Upprepningar kostar inget.")
    }

    /// On the exam's card and screen: "Kostar 2 340 krediter".
    static func cardLine(cost: Int) -> String { cost == 0 ? String(localized: "Kostar inget") : String(localized: "Kostar \(credits(cost))") }

    /// A154 (D241): Nytt prov, when the credits cover fewer questions than the standard: "Krediterna räcker till 5 frågor."
    static func examFits(_ questions: Int) -> String { String(localized: "Krediterna räcker till \(DrillText.questions(questions)).") }
    /// A154 (D241): Nytt prov, when they cover no exam at all (said with "Fyll på", before anything is made).
    /// Kelly (kop.md §7): what the smallest exam costs, and what one has.
    static func examHasNoRoom(cost: Int, left: Int, minQuestions: Int) -> String {
        String(localized: "Ett prov med \(DrillText.questions(minQuestions)) kostar cirka \(credits(cost)). Du har \(short(left, .down)).")
    }

    /// The credits do not cover it (said before anything is saved or started).
    static func notEnough(cost: Int, left: Int, resetsDay: String?) -> String {
        String(localized: "Det här kostar \(credits(cost)). Du har \(short(left, .down)) kvar.") + (resetsDay.map { String(localized: " Nya krediter den \($0).") } ?? "")
    }

    /// The sheet's rows ("Så räknas det").
    static var rows: [(title: String, value: String)] { [
        (String(localized: "1 tecken nytt ljud"), String(localized: "1 kredit")), (String(localized: "Ljud som redan finns"), "0"), (String(localized: "Upprepa samma text"), "0"),
        (String(localized: "Prov som andra har delat eller publicerat"), "0"),
    ] }

    /// The sheet's footnote, with the month's limit from the server.
    static func footnote(limit: Int, resetsDay: String?) -> String {
        String(localized: "En text på 764 tecken kostar 764 krediter. Du får \(exact(limit)) varje månad.")
            + (resetsDay.map { String(localized: " Nya krediter den \($0).") } ?? "") + String(localized: " Oanvända krediter sparas inte.")
    }
}
