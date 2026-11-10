import Foundation

/// A16 (K15): what a spoken utterance means during a practice exam run. A port of Kevin's `practiceNav`
/// (`backend/supabase/functions/exam/practice.ts`), decided on the phone so "nästa" moves at once and works offline.
/// Anything that is not navigation is an answer to grade. The indexes are 0-based and clamped to the list.
enum PracticeNav: Equatable, Sendable {
    case next(Int)
    case previous(Int)
    case go(Int)
    case skip(Int)
    case repeatQuestion(Int)
    case stop
    case results
    case answer

    static let numbers: [String: Int] = [
        "ett": 1, "en": 1, "etta": 1, "två": 2, "tvåan": 2, "tre": 3, "trean": 3, "fyra": 4, "fyran": 4, "fem": 5,
        "femman": 5, "sex": 6, "sexan": 6, "sju": 7, "sjuan": 7, "åtta": 8, "åttan": 8, "nio": 9, "nian": 9, "tio": 10,
        "tian": 10, "elva": 11, "elvan": 11, "tolv": 12, "tolvan": 12, "tretton": 13, "fjorton": 14, "femton": 15,
        "sexton": 16, "sjutton": 17, "arton": 18, "nitton": 19, "tjugo": 20, "tjugoett": 21, "tjugoen": 21,
        "tjugotvå": 22, "tjugotre": 23, "tjugofyra": 24, "tjugofem": 25,
    ]

    static func decide(_ utterance: String, current: Int, nos: [String]) -> PracticeNav {
        let t = normalized(utterance)
        let clamp = { (i: Int) in max(0, min(nos.count - 1, i)) }
        if matches(t, #"nästa(?: fråga| uppgift)?|nästa tack|vidare|gå vidare|fortsätt|nästa då"#) { return .next(clamp(current + 1)) }
        if matches(t, #"förra(?: fråga| uppgift(?:en)?)?|föregående(?: fråga)?|tillbaka|gå tillbaka|backa|den förra"#) {
            return .previous(clamp(current - 1))
        }
        if matches(t, #"hoppa över(?: den(?: här)?| den här frågan| frågan)?|skippa(?: den)?|jag hoppar över den|vet inte hoppa över|pass"#) {
            return .skip(clamp(current + 1))
        }
        if matches(t, #"upprepa(?: frågan)?|säg (?:den |frågan )?igen|en gång till|vad var frågan|läs (?:upp )?(?:den |frågan )?igen|repetera"#) {
            return .repeatQuestion(clamp(current))
        }
        if matches(t, #"sluta|avsluta(?: provet| övningsprovet)?|stopp|jag är klar|vi slutar|det räcker"#) { return .stop }
        if matches(t, #"hur (?:gick|går) det|resultat(?:et)?|hur många (?:rätt|poäng)|vad fick jag"#) { return .results }
        if let no = spokenNumber(t) {
            if let i = nos.firstIndex(where: { $0.lowercased() == no }) { return .go(i) }
            // "fråga 3" is the first of 3a, 3b
            if let i = nos.firstIndex(where: { $0.lowercased().replacingOccurrences(of: #"[a-f]$"#, with: "", options: .regularExpression) == no }) {
                return .go(i)
            }
        }
        return .answer
    }

    static func normalized(_ text: String) -> String {
        var t = text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        t = t.replacingOccurrences(of: #"^(?:(?:okej|ok|hej|nej|men) )?(?:lumen )?(?:(?:kan|kunde) (?:du|vi) |snälla |vi tar |ta |gå till |jag vill (?:ha|ta|göra) )*"#,
                                   with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #" (?:tack|nu|snälla|då)$"#, with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// The task number said: "7", "sju", "3b", "tre b", "fråga sjuan".
    static func spokenNumber(_ t: String) -> String? {
        let pattern = #"^(?:fråga|uppgift|uppgiften|nummer|nr|frågan|del) (?:nummer )?([\p{L}\p{N}]+)(?: ([a-f]))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let wordRange = Range(match.range(at: 1), in: t) else { return nil }
        let word = String(t[wordRange])
        let letter = Range(match.range(at: 2), in: t).map { String(t[$0]) } ?? ""
        let base: String
        if word.range(of: #"^\d{1,2}[a-f]?$"#, options: .regularExpression) != nil {
            base = word
        } else if let number = numbers[word] {
            base = String(number)
        } else {
            return nil
        }
        return (base + letter).lowercased()
    }

    private static func matches(_ text: String, _ alternatives: String) -> Bool {
        text.range(of: "^(?:" + alternatives + ")$", options: .regularExpression) != nil
    }
}

/// A16: a practice exam read aloud one question at a time. Lumen reads the question, the student answers aloud and
/// Lumen grades and explains (`/exam` grade with `practice: true`), then the next open question. Pure.
struct PracticeRun: Equatable, Sendable {
    struct Outcome: Equatable, Sendable {
        var points: Double
        var max: Double

        /// Full marks; a question without points is right or wrong (Kevin: 1 E point).
        var isRight: Bool { max > 0 ? points >= max : points > 0 }
        var isPartly: Bool { !isRight && points > 0 }
    }

    let paper: ExamPaper
    private(set) var index = 0
    private(set) var outcomes: [String: Outcome] = [:]
    private(set) var skipped: Set<String> = []
    /// A grading call is under way; what the student says meanwhile waits.
    var isGrading = false
    /// The last feedback and its question, shown under the next question.
    var lastFeedback: String?
    var lastFeedbackNo: String?

    init?(paper: ExamPaper) {
        guard !paper.tasks.isEmpty else { return nil }
        self.paper = paper
    }

    var count: Int { paper.tasks.count }
    var task: ExamTask { paper.tasks[index] }
    var nos: [String] { paper.tasks.map(\.no) }
    /// "Fråga 3 av 12".
    var progress: String { "Fråga \(index + 1) av \(count)" }

    /// How Lumen reads the question: Kevin's `spoken` (numbers in words, the points last), else the D84 form.
    static func spoken(_ task: ExamTask) -> String {
        if let spoken = task.spoken, !spoken.isEmpty { return spoken }
        return ExamSession.spoken(task)
    }

    var spokenQuestion: String { Self.spoken(task) }

    mutating func move(to newIndex: Int) {
        index = max(0, min(count - 1, newIndex))
    }

    mutating func graded(points: Double, max: Double) {
        outcomes[task.no] = Outcome(points: points, max: max)
        skipped.remove(task.no)
    }

    mutating func skip() {
        if outcomes[task.no] == nil { skipped.insert(task.no) }
    }

    /// The next question after this one that has no grade yet; nil when the rest are done.
    var nextOpenIndex: Int? {
        guard index + 1 < count else { return nil }
        return (index + 1..<count).first { outcomes[paper.tasks[$0].no] == nil && !skipped.contains(paper.tasks[$0].no) }
            ?? (index + 1..<count).first { outcomes[paper.tasks[$0].no] == nil }
    }

    struct Summary: Equatable, Sendable {
        var right: Int
        var partly: Int
        var wrong: Int
        var skipped: Int
        var answered: Int
        /// What to practise: the topics (or the question's first words) of what was not right, in the exam's order.
        var practise: [String]
    }

    var summary: Summary {
        var right = 0, partly = 0, wrong = 0
        var practise: [String] = []
        for task in paper.tasks {
            let missed: Bool
            if let outcome = outcomes[task.no] {
                if outcome.isRight { right += 1 } else if outcome.isPartly { partly += 1 } else { wrong += 1 }
                missed = !outcome.isRight
            } else {
                missed = skipped.contains(task.no)
            }
            if missed {
                let name = Self.topic(of: task)
                if !practise.contains(name) { practise.append(name) }
            }
        }
        return Summary(right: right, partly: partly, wrong: wrong, skipped: skipped.count,
                       answered: outcomes.count, practise: practise)
    }

    /// "Du hade 7 rätt av 10. 2 delvis rätt och 1 fel. Öva på procent och ekvationer."
    var spokenSummary: String {
        let s = summary
        guard s.answered > 0 else { return "Inga frågor rättade än." }
        var text = "Du hade \(s.right) rätt av \(s.answered)."
        var rest: [String] = []
        if s.partly > 0 { rest.append("\(s.partly) delvis rätt") }
        if s.wrong > 0 { rest.append("\(s.wrong) fel") }
        if s.skipped > 0 { rest.append("\(s.skipped) överhoppade") }
        if !rest.isEmpty { text += " " + Self.list(rest).capitalizedFirst + "." }
        if !s.practise.isEmpty { text += " Öva på " + Self.list(Array(s.practise.prefix(3))) + "." }
        return text
    }

    /// Right and wrong per topic, for `concept_stats` ("testa mina svagaste").
    var conceptResults: [(concept: String, right: Bool)] {
        paper.tasks.compactMap { task in
            guard let outcome = outcomes[task.no], let topic = task.topic, !topic.isEmpty else { return nil }
            return (topic, outcome.isRight)
        }
    }

    /// "kör övningsprovet", "starta övningsprovet", "övningsprovet".
    static func isStartCommand(_ text: String) -> Bool {
        let t = PracticeNav.normalized(text)
        return t.range(of: #"^(?:(?:kör|starta|börja|gör|öva på) )?(?:mitt |det )?övningsprov(?:et)?$"#, options: .regularExpression) != nil
    }

    static func topic(of task: ExamTask) -> String {
        if let topic = task.topic, !topic.isEmpty { return topic }
        return "fråga \(task.no)"
    }

    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " och " + items.last!
    }
}

/// A16: right and wrong per concept across practice runs, kept on this phone and sent as `concept_stats` in
/// Provläge so "testa mina svagaste" and the session summary know what went wrong (K9, K17).
struct ConceptStats: Codable, Equatable, Sendable {
    struct Count: Codable, Equatable, Sendable {
        var right = 0
        var wrong = 0
        var at: Date
    }

    static let limit = 30 // the backend's `concept_stats` limit
    static let conceptLength = 80
    private(set) var counts: [String: Count] = [:]

    mutating func record(_ concept: String, right: Bool, at now: Date = Date()) {
        let key = String(concept.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.conceptLength))
        guard !key.isEmpty else { return }
        var count = counts[key] ?? Count(at: now)
        if right { count.right += 1 } else { count.wrong += 1 }
        count.at = now
        counts[key] = count
        if counts.count > Self.limit * 2, let oldest = counts.min(by: { $0.value.at < $1.value.at })?.key {
            counts[oldest] = nil
        }
    }

    /// At most 30, the most recent first.
    var backendItems: [AnswerContext.ConceptStat] {
        counts.sorted { $0.value.at > $1.value.at }.prefix(Self.limit)
            .map { AnswerContext.ConceptStat(concept: $0.key, right: $0.value.right, wrong: $0.value.wrong) }
    }

    static let key = "practice.conceptStats"

    static func load(_ defaults: UserDefaults = .standard) -> ConceptStats {
        guard let data = defaults.data(forKey: key), let stats = try? JSONDecoder().decode(ConceptStats.self, from: data) else {
            return ConceptStats()
        }
        return stats
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
