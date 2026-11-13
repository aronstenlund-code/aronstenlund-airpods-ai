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
    /// Kelly N1, K51: "Tryck en gång för svaret." in the exam's own voice (`<hash>.mp3` in the cache).
    var cueAudio: String?
    /// A83 (K49): this exam is published at a school (kept on the phone; the server does not say it in `get`).
    var publication: DrillPublication?
    /// A83: the publication this copy was added from ("played" is counted on it).
    var fromPublication: String?
    /// A84 (D151): "A", "B" or "C", chosen before the sound is made; locked after the first save (K50).
    var voiceModel: String?

    static let defaultQuestionCount = 20
    static let defaultLongWords = 90

    /// "Ljud: 36 av 40 klara" (Kelly Ke49 §4.7): with D145 two files per question, the question and the long answer.
    var audioFileCount: Int { items.count * 2 }
}

/// What Earmind made of the material (K45 `summary`). The user may correct it with a line of text.
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
    /// K46: the downloaded files in the phone's cache (`<hash>.mp3`), and where the short answer ends in the long file
    /// (D145, from ElevenLabs' character timestamps). Nil until downloaded; a changed text gets new ones.
    var questionAudio: String?
    var longAudio: String?
    var shortEndMs: Int?

    init(id: UUID = UUID(), question: String, short: String, long: String, serverID: String? = nil) {
        self.id = id
        self.question = question
        self.short = short
        self.long = long
        self.serverID = serverID
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

/// One item's sound: where the question and the long answer are, and where the short answer ends in the long file
/// (word timestamps from K46). Without a timestamp the short answer has a file of its own (the free iPhone voice
/// used until K46 is live).
struct RepetitionTrack: Equatable, Sendable {
    let question: URL
    let long: URL
    let short: Short

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
