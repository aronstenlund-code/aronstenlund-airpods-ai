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

    static let defaultQuestionCount = 20
    static let defaultLongWords = 90
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
