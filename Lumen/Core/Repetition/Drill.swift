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

    /// A131 (D213, K90): what Starta prov costs in credits, as the server last said it. Never counted in the app.
    var startCost: Int?

    /// A107: the sound is not asked for yet; Starta prov asks for it.
    var awaitsAudioStart: Bool { audioStarted == false }

    /// A105: the items are the text's parts (headings and paragraphs), read in order.
    var isText: Bool { kind == .text }

    static let defaultQuestionCount = 20
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
        case .longer: "Lite längre än vanligt"
        case .tooLong: "Mycket lång"
        }
    }

    /// Kelly (A99): the editor's footer under the answer; nil for a normal one.
    var editorNote: String? {
        switch self {
        case .normal: nil
        case .longer: "Frågan och svaret är lite längre än vanligt."
        case .tooLong: "Frågan och svaret är mycket långa. Korta svaret om du vill."
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
    var sentenceTimes: [ClosedRange<TimeInterval>]? {
        guard let ms = sentenceTimesMs, !ms.isEmpty else { return nil }
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
    static func questions(_ n: Int) -> String { n == 1 ? "1 fråga" : "\(n) frågor" }
    static func things(_ n: Int) -> String { n == 1 ? "1 sak" : "\(n) saker" }

    /// "cirka {m} min per varv": the question (about 3 s) and the thinking time, without answers.
    static func minutesPerLap(_ drill: Drill) -> Int {
        let seconds = Double(drill.items.count) * (3 + ThinkingTime.seconds(questionCount: drill.items.count))
        return max(1, Int((seconds / 60).rounded(.up)))
    }
}

/// A115 (D203): the free text of "Säg i AirPods" as a text read aloud: exactly what was written, one part per
/// paragraph, named after its first words.
enum SaidText {
    /// The server reads at most this much (K70).
    static let maxChars = 40_000

    static func parts(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The characters that are read (what the month's questions are counted on).
    static func chars(_ text: String) -> Int { parts(text).reduce(0) { $0 + $1.count } }

    /// D185: one question per started 800 characters.
    static func countsAs(_ text: String) -> Int { DrillTextDraft.countsAs(chars: chars(text)) }
    /// A130 (D212): counted with the server's own number of characters per question (`/drill quota`, K82) when it is
    /// known, so the line under the field says what the server will say.
    static func countsAs(_ text: String, perQuestion: Int?) -> Int {
        DrillTextDraft.countsAs(chars: chars(text), perQuestion: max(1, perQuestion ?? 800))
    }

    /// A130 (D212): what stands under the field when Spela did not start anything.
    static func refusalLine(problem: String?, quotaExceeded: Bool, refill: String?) -> String {
        let said = (problem ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let base = said.isEmpty ? (quotaExceeded ? "Du har inga frågor kvar den här månaden." : "Det gick inte att spela just nu. Försök igen om en stund.") : said
        // A131 (K90): in credits the server's own line already says when ("Nya krediter 1 december.").
        guard quotaExceeded, let refill, !base.contains(refill), !base.contains("Nya krediter") else { return base }
        return "\(base) \(refill)"
    }

    static func title(_ text: String) -> String {
        guard let first = parts(text).first else { return "Text" }
        let words = first.split(separator: " ").prefix(5).joined(separator: " ")
        let cut = words.count > 32 ? String(words.prefix(31)) + "…" : words
        return cut.count < first.count && !cut.hasSuffix("…") ? cut + " …" : cut
    }
}


/// A131 (D213, Aron 2026-11-17; Kelly Ke71): the month in credits. 1 credit = 1 character of new sound, repeating and
/// sound that already exists cost nothing. Every number comes from the server; these are only the words.
enum CreditText {
    /// "1 236": thousands with a space that does not break the line.
    static func number(_ n: Int) -> String {
        let digits = String(abs(n))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append("\u{00A0}") }
            out.append(ch)
        }
        return n < 0 ? "-" + out : out
    }

    static func credits(_ n: Int) -> String { n == 1 ? "1 kredit" : "\(number(n)) krediter" }

    /// The capsule: "1 236 krediter kvar".
    static func capsule(_ left: Int) -> String { "\(credits(left)) kvar" }

    /// Under the field in Säg i AirPods, before Spela.
    static func sayLine(cost: Int) -> String {
        cost == 0 ? "Kostar inget. Ljudet finns redan." : "Kostar \(credits(cost)). Upprepningar kostar inget."
    }

    /// On the exam's card and screen: "Kostar 2 340 krediter".
    static func cardLine(cost: Int) -> String { cost == 0 ? "Kostar inget" : "Kostar \(credits(cost))" }

    /// The credits do not cover it (said before anything is saved or started).
    static func notEnough(cost: Int, left: Int, resetsDay: String?) -> String {
        "Det här kostar \(credits(cost)). Du har \(number(left)) kvar." + (resetsDay.map { " Nya krediter den \($0)." } ?? "")
    }

    /// The sheet's rows ("Så räknas det").
    static let rows: [(title: String, value: String)] = [
        ("1 tecken nytt ljud", "1 kredit"), ("Ljud som redan finns", "0"), ("Upprepa samma text", "0"),
        ("Prov som andra har delat eller publicerat", "0"),
    ]

    /// The sheet's footnote, with the month's limit from the server.
    static func footnote(limit: Int, resetsDay: String?) -> String {
        "En text på 764 tecken kostar 764 krediter. Du får \(credits(limit)) varje månad."
            + (resetsDay.map { " Nya krediter den \($0)." } ?? "") + " Oanvända krediter sparas inte."
    }
}
