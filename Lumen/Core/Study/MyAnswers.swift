import Foundation
import Observation

/// A53 (D126, K37): "Mina svar". The student decides what Lumen says to an exam question: they write the question,
/// Lumen suggests how to answer it (`/my-answers suggest`), they edit it, and when the question comes in Provläge the
/// backend says the saved answer word for word (`saved_answers` in `/answer`, matched semantically there). A recording
/// of a perfect answer (a teacher, a video) is written out on the phone and compressed into one answer only when the
/// student taps Klar (`/my-answers compress`). The answers live on the phone only, like Minne (D49), never on the server
/// and never in the repo. Every save is a version, so nothing is lost; "Säg mina svar" turns the feature off without
/// deleting anything.
struct MyAnswer: Identifiable, Codable, Equatable, Sendable {
    enum Author: String, Codable, Sendable {
        /// The student typed or edited it.
        case mine
        /// Lumen's suggestion, saved as it was.
        case lumen
        /// Compressed from a recording, saved as it was.
        case recording

        var title: String {
            switch self {
            case .mine: "Din"
            case .lumen: "Earminds förslag"
            case .recording: "Från inspelning"
            }
        }
    }

    struct Version: Codable, Equatable, Sendable, Identifiable {
        var id = UUID()
        var question: String
        var answer: String
        var author: Author
        var savedAt: Date
    }

    var id = UUID()
    /// The exam it belongs to (`ExamPlan.id`); nil = every exam.
    var examID: UUID?
    var question: String
    var answer: String
    /// Lumen's suggestion, kept above the student's text so they can go back to it.
    var suggestion: String?
    /// It came from a recording ("Inspelat" on the list).
    var recorded = false
    /// Oldest first, the newest is the current text. At most `MyAnswerStore.versionLimit`.
    var versions: [Version] = []
    var updatedAt = Date()
}

/// What `/answer` gets: `saved_answers: [{id, q, a}]` (Kevin's limits: 60 items, id 64, q 300, a 1 500).
struct SavedAnswerPayload: Codable, Equatable, Sendable {
    var id: String
    var q: String
    var a: String

    static let itemLimit = 60
    static let questionLimit = 300
    static let answerLimit = 1_500
}

/// `done.saved_answer`: the backend said this saved answer (via the code match or the small model's check).
struct SavedAnswerHit: Codable, Equatable, Sendable {
    var id: String
    var text: String?
    var via: String?
}

@MainActor
@Observable
final class MyAnswerStore {
    static let versionLimit = 10
    static let enabledKey = "myAnswers.enabled"

    private(set) var answers: [MyAnswer] = []
    /// "Säg mina svar" (Inställningar › Provläge). Off: Lumen answers as usual; nothing is deleted.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    private let file: LocalJSONFile
    private let defaults: UserDefaults

    init(directory: URL = NotesStore.defaultDirectory, defaults: UserDefaults = .standard) {
        file = LocalJSONFile(url: directory.appendingPathComponent("my-answers.json"))
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        answers = (try? file.load([MyAnswer].self)) ?? []
    }

    /// One exam's answers (and the ones for every exam), newest change first.
    func answers(for examID: UUID?) -> [MyAnswer] {
        answers.filter { $0.examID == nil || $0.examID == examID }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func count(for examID: UUID?) -> Int { answers(for: examID).count }

    func answer(_ id: UUID) -> MyAnswer? { answers.first { $0.id == id } }

    /// A new answer or a new version of one. An unchanged text is not a new version.
    @discardableResult
    func save(id: UUID? = nil, examID: UUID?, question: String, answer: String, author: MyAnswer.Author,
              suggestion: String? = nil, recorded: Bool = false, now: Date = Date()) -> MyAnswer? {
        let question = Self.clean(question, limit: SavedAnswerPayload.questionLimit)
        let text = Self.clean(answer, limit: SavedAnswerPayload.answerLimit)
        guard !question.isEmpty, !text.isEmpty else { return nil }
        let version = MyAnswer.Version(question: question, answer: text, author: author, savedAt: now)
        if let id, let index = answers.firstIndex(where: { $0.id == id }) {
            var item = answers[index]
            guard item.question != question || item.answer != text else { return item }
            item.question = question
            item.answer = text
            if let suggestion { item.suggestion = suggestion }
            item.versions = Array((item.versions + [version]).suffix(Self.versionLimit))
            item.updatedAt = now
            answers[index] = item
            persist()
            return item
        }
        let item = MyAnswer(id: id ?? UUID(), examID: examID, question: question, answer: text, suggestion: suggestion,
                            recorded: recorded, versions: [version], updatedAt: now)
        answers.append(item)
        persist()
        return item
    }

    /// "Återställ": the old text becomes the newest version; nothing disappears.
    @discardableResult
    func restore(_ versionID: UUID, of id: UUID, now: Date = Date()) -> MyAnswer? {
        guard let item = answer(id), let old = item.versions.first(where: { $0.id == versionID }) else { return nil }
        return save(id: id, examID: item.examID, question: old.question, answer: old.answer, author: old.author, now: now)
    }

    func delete(_ id: UUID) {
        answers.removeAll { $0.id == id }
        persist()
    }

    /// What `/answer` gets in Provläge for the exam: nothing when "Säg mina svar" is off.
    func payload(for examID: UUID?) -> [SavedAnswerPayload] {
        guard isEnabled else { return [] }
        return answers(for: examID).prefix(SavedAnswerPayload.itemLimit).map {
            SavedAnswerPayload(id: $0.id.uuidString,
                               q: String($0.question.prefix(SavedAnswerPayload.questionLimit)),
                               a: String($0.answer.prefix(SavedAnswerPayload.answerLimit)))
        }
    }

    nonisolated static func clean(_ text: String, limit: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private func persist() {
        do { try file.save(answers) } catch {
            Log.session.error("Mina svar not saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// `/my-answers` (K37): Lumen's suggestion for a typed question, the spelling fix when saving, and a recording's
/// transcript compressed to one answer. Nothing is stored on the server.
@MainActor
final class MyAnswersClient {
    struct Suggestion: Decodable, Equatable, Sendable {
        var q: String
        var answer: String
    }

    struct Proofread: Decodable, Equatable, Sendable {
        struct Changed: Decodable, Equatable, Sendable {
            var q: Bool?
            var a: Bool?
        }
        var q: String
        var a: String
        var changed: Changed?
    }

    struct Context: Sendable, Equatable {
        var subject: String?
        var grade: String?
        var exam: String?
        var goals: String?
        var terms: [String] = []
    }

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func suggest(question: String, context: Context) async -> Suggestion? {
        await post(Self.suggestBody(question: question, context: context), timeout: 35)
    }

    func proofread(question: String, answer: String) async -> Proofread? {
        await post(["action": .string("proofread"), "q": .string(question), "a": .string(answer)], timeout: 20)
    }

    func compress(transcript: String, question: String?, subject: String?) async -> Suggestion? {
        var body: [String: JSONValue] = ["action": .string("compress"), "transcript": .string(String(transcript.prefix(60_000)))]
        if let question, !question.isEmpty { body["q"] = .string(question) }
        if let subject, !subject.isEmpty { body["subject"] = .string(subject) }
        return await post(body, timeout: 50)
    }

    nonisolated static func suggestBody(question: String, context: Context) -> [String: JSONValue] {
        var body: [String: JSONValue] = ["action": .string("suggest"), "q": .string(String(question.prefix(SavedAnswerPayload.questionLimit)))]
        if let subject = context.subject, !subject.isEmpty { body["subject"] = .string(subject) }
        if let grade = context.grade, !grade.isEmpty { body["grade"] = .string(grade) }
        if let exam = context.exam, !exam.isEmpty { body["exam"] = .string(exam) }
        if let goals = context.goals, !goals.isEmpty { body["goals"] = .string(String(goals.prefix(1_500))) }
        if !context.terms.isEmpty { body["terms"] = .array(context.terms.prefix(50).map { .string(String($0.prefix(60))) }) }
        return body
    }

    private func post<Reply: Decodable>(_ body: [String: JSONValue], timeout: TimeInterval) async -> Reply? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.myAnswersURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = timeout
            request.httpBody = try JSONEncoder().encode(JSONValue.object(body))
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.answer.error("my-answers: HTTP \(response.statusCode, privacy: .public)")
                return nil
            }
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            return nil
        }
    }
}

/// Pure helpers for the editor.
enum MyAnswerText {
    /// "Rättat: kraftverk": the words the spelling fix changed, for a line under the field (Ke30 step 3).
    static func changedWords(from before: String, to after: String) -> [String] {
        let old = words(before), new = words(after)
        guard old.count == new.count else {
            return new.filter { word in !old.contains { $0.caseInsensitiveCompare(word) == .orderedSame } }
        }
        return zip(old, new).compactMap { $0 == $1 ? nil : $1 }
    }

    private static func words(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// "02:14 av 10:00" under the recording.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// The first words of the transcript, for "FRÅN DIN INSPELNING · 2:14".
    static func excerpt(_ transcript: String, limit: Int = 160) -> String {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let end = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<end]) + " …"
    }
}
