import Foundation

/// D84: one task of a practice exam as Kevin's `POST /exam` "parse" returns it, kept on the phone and sent back with
/// every hint and grading call (nothing is stored on the server).
struct ExamTask: Codable, Equatable, Sendable, Identifiable {
    struct Points: Codable, Equatable, Sendable {
        var E: Double
        var C: Double
        var A: Double

        static let zero = Points(E: 0, C: 0, A: 0)
        var total: Double { E + C + A }
    }

    var no: String
    var text: String
    var points: Points
    var answer: String
    var assessment: String

    var id: String { no }

    /// The exam and its marking instructions are read separately; the same task number from both becomes one task.
    func merged(with other: ExamTask) -> ExamTask {
        func pick(_ a: String, _ b: String) -> String { a.count >= b.count ? a : b }
        return ExamTask(no: no, text: pick(text, other.text),
                        points: points.total >= other.points.total ? points : other.points,
                        answer: pick(answer, other.answer), assessment: pick(assessment, other.assessment))
    }
}

struct ExamBoundary: Codable, Equatable, Sendable {
    var grade: String
    var total: Double
    var minCa: Double?
    var minA: Double?

    enum CodingKeys: String, CodingKey {
        case grade, total
        case minCa = "min_ca"
        case minA = "min_a"
    }
}

/// The parsed exam on this phone.
struct ExamPaper: Codable, Equatable, Sendable {
    var tasks: [ExamTask] = []
    var boundaries: [ExamBoundary] = []
    var name = ""

    /// Merges one parse batch by task number, keeping the order tasks were first seen in.
    mutating func merge(tasks new: [ExamTask], boundaries newBoundaries: [ExamBoundary]) {
        for task in new {
            if let index = tasks.firstIndex(where: { $0.no.lowercased() == task.no.lowercased() }) {
                tasks[index] = tasks[index].merged(with: task)
            } else {
                tasks.append(task)
            }
        }
        if !newBoundaries.isEmpty, newBoundaries.count >= boundaries.count { boundaries = newBoundaries }
    }
}

/// D84: the practice exam inside Provläge. Only "Lumen, …" commands count (in the wearer's own voice when there is a
/// voice profile); nothing is answered on its own. Pure; the clock is passed in.
struct ExamSession: Equatable, Sendable {
    enum Command: Equatable, Sendable {
        case task(String)
        case hint
        case grade(String)
        case next
        case startTimer(minutes: Int)
        case howDidItGo
        case end
    }

    let paper: ExamPaper
    private(set) var current: String?
    private(set) var startedAt: Date?
    private(set) var minutes: Int?
    private(set) var warned: Set<Int> = []
    /// Per task: the points given at the last grading.
    private(set) var results: [String: ExamTask.Points] = [:]
    private(set) var hints: [String: Int] = [:]

    static let warnings = [30, 10, 5, 1]

    init(paper: ExamPaper) { self.paper = paper }

    var currentTask: ExamTask? { current.flatMap { no in paper.tasks.first { $0.no == no } } }

    /// "uppgift 7" finds "7", else "7a".
    func task(named spoken: String) -> ExamTask? {
        let key = spoken.lowercased().replacingOccurrences(of: " ", with: "")
        return paper.tasks.first { $0.no.lowercased() == key } ?? paper.tasks.first { $0.no.lowercased().hasPrefix(key) }
    }

    /// The words after "Lumen,". Nil: not an exam command (and in an exam session, not answered).
    static func command(_ text: String) -> Command? {
        let words = VoiceChannel.normalized(text)
        let numbers = ["ett": "1", "en": "1", "två": "2", "tre": "3", "fyra": "4", "fem": "5", "sex": "6", "sju": "7",
                       "åtta": "8", "nio": "9", "tio": "10", "elva": "11", "tolv": "12", "tretton": "13", "fjorton": "14",
                       "femton": "15", "sexton": "16", "sjutton": "17", "arton": "18", "nitton": "19", "tjugo": "20"]
        for prefix in ["uppgift ", "fråga ", "task "] where words.hasPrefix(prefix) {
            let rest = words.dropFirst(prefix.count).split(separator: " ").map(String.init)
            guard let first = rest.first else { return nil }
            var no = numbers[first] ?? first
            if rest.count > 1, rest[1].count == 1, rest[1].first?.isLetter == true { no += rest[1] } // "sju a"
            return .task(no)
        }
        if words.hasPrefix("ledtråd") || words.hasPrefix("ge mig en ledtråd") || words == "tips" || words == "en ledtråd" { return .hint }
        for prefix in ["rätta jag fick ", "rätta mitt svar är ", "rätta mitt svar ", "rätta svaret är ", "rätta ", "jag fick "]
        where words.hasPrefix(prefix) {
            let answer = String(words.dropFirst(prefix.count))
            return answer.isEmpty ? nil : .grade(answer)
        }
        if words == "nästa" || words == "nästa uppgift" { return .next }
        if words.hasPrefix("starta provtid") || words.hasPrefix("starta provtiden") || words.hasPrefix("provtid") {
            let digits = words.split(separator: " ").compactMap { Int($0) }.first
            return .startTimer(minutes: digits ?? 60)
        }
        if words.hasPrefix("hur gick det") || words == "sammanfatta provet" { return .howDidItGo }
        if words == "avsluta provet" || words == "sluta provet" || words == "provet är klart" { return .end }
        return nil
    }

    mutating func go(to no: String) -> ExamTask? {
        guard let task = task(named: no) else { return nil }
        current = task.no
        return task
    }

    mutating func next() -> ExamTask? {
        guard let current, let index = paper.tasks.firstIndex(where: { $0.no == current }) else {
            return paper.tasks.first.flatMap { go(to: $0.no) }
        }
        guard index + 1 < paper.tasks.count else { return nil }
        return go(to: paper.tasks[index + 1].no)
    }

    /// 1, 2, 3, then 3 again: Kevin's levels.
    mutating func nextHintLevel() -> Int? {
        guard let current else { return nil }
        let level = min(3, (hints[current] ?? 0) + 1)
        hints[current] = level
        return level
    }

    mutating func graded(_ points: ExamTask.Points) {
        guard let current else { return }
        results[current] = points
    }

    mutating func startTimer(minutes: Int, at now: Date) {
        self.minutes = max(1, minutes)
        startedAt = now
        warned = []
    }

    var hasTimer: Bool { startedAt != nil }

    /// Minutes left, rounded up. Nil without a timer.
    func minutesLeft(at now: Date) -> Int? {
        guard let startedAt, let minutes else { return nil }
        let left = Double(minutes) * 60 - now.timeIntervalSince(startedAt)
        return max(0, Int((left / 60).rounded(.up)))
    }

    /// "30 minuter kvar", … "Tiden är slut." Each once, the nearest one when some were missed.
    mutating func warning(at now: Date) -> String? {
        guard let left = minutesLeft(at: now), let minutes else { return nil }
        if left == 0 {
            guard !warned.contains(0) else { return nil }
            warned.insert(0)
            return "Tiden är slut."
        }
        for mark in Self.warnings.sorted() where left <= mark && mark < minutes && !warned.contains(mark) {
            warned.formUnion(Self.warnings.filter { $0 >= mark })
            return mark == 1 ? "En minut kvar." : "\(mark) minuter kvar."
        }
        return nil
    }

    /// For the summary call, in the exam's order.
    var resultList: [(no: String, points: ExamTask.Points)] {
        paper.tasks.compactMap { task in results[task.no].map { (no: task.no, points: $0) } }
    }

    /// For Minne afterwards: the tasks that did not get full marks, by their first words (the kind of task).
    func weakTaskTypes() -> [String] {
        paper.tasks.compactMap { task -> String? in
            guard let got = results[task.no], got.total < task.points.total else { return nil }
            let start = task.text.split(separator: " ").prefix(8).joined(separator: " ")
            return "Provträning: öva på uppgifter som \"\(start)…\""
        }
    }

    /// "Uppgift 3b, 1 E, 1 C poäng. …" read aloud.
    static func spoken(_ task: ExamTask) -> String {
        var points: [String] = []
        if task.points.E > 0 { points.append("\(number(task.points.E)) E") }
        if task.points.C > 0 { points.append("\(number(task.points.C)) C") }
        if task.points.A > 0 { points.append("\(number(task.points.A)) A") }
        let head = points.isEmpty ? "Uppgift \(task.no)." : "Uppgift \(task.no), \(points.joined(separator: ", ")) poäng."
        return head + " " + task.text
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value).replacingOccurrences(of: ".", with: ",")
    }
}
