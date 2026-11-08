import Foundation
import Observation

/// D81: a study card from a Provläge question and its answer, kept on the phone until the exam is over.
struct StudyCard: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var question: String
    var answer: String
    var subject: String?
    var examDate: Date?
    var createdAt: Date
    var right = 0
    var wrong = 0

    init(id: UUID = UUID(), question: String, answer: String, subject: String?, examDate: Date?, createdAt: Date = Date()) {
        self.id = id
        self.question = question
        self.answer = answer
        self.subject = subject
        self.examDate = examDate
        self.createdAt = createdAt
    }

    /// Cards for an exam that is more than a day past are no longer shown.
    func isCurrent(now: Date = Date()) -> Bool {
        guard let examDate else { return now.timeIntervalSince(createdAt) < 30 * 86_400 }
        return now.timeIntervalSince(examDate) < 86_400
    }

    /// The first two sentences of the answer: what is worth remembering, read aloud in a few seconds.
    static func shortAnswer(_ answer: String, limit: Int = 240) -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        var sentences: [String] = []
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { sentence, _, _, stop in
            if let sentence { sentences.append(sentence.trimmingCharacters(in: .whitespaces)) }
            if sentences.count == 2 { stop = true }
        }
        let joined = sentences.isEmpty ? trimmed : sentences.joined(separator: " ")
        return joined.count > limit ? String(joined.prefix(limit)) + "…" : joined
    }

    /// A question worth a card: a real question of a few words, not "ja", "nej" or a command.
    static func isWorthACard(question: String, answer: String) -> Bool {
        let words = question.split(whereSeparator: \.isWhitespace)
        guard words.count >= 3, answer.count >= 20 else { return false }
        return !FillerFilter.isOnlyFiller(question)
    }
}

@MainActor
@Observable
final class StudyCardStore {
    private(set) var cards: [StudyCard] = []
    private let file: LocalJSONFile
    static let maxCards = 300

    init(directory: URL = NotesStore.defaultDirectory) {
        file = LocalJSONFile(url: directory.appendingPathComponent("study-cards.json"))
        cards = (try? file.load([StudyCard].self)) ?? []
    }

    /// The cards still worth practising (exam not passed), newest first.
    func current(now: Date = Date()) -> [StudyCard] {
        cards.filter { $0.isCurrent(now: now) }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(question: String, answer: String, profile: StudyProfile, now: Date = Date()) -> StudyCard? {
        guard StudyCard.isWorthACard(question: question, answer: answer) else { return nil }
        let key = AheadAnswer.key(question)
        guard !cards.contains(where: { AheadAnswer.key($0.question) == key }) else { return nil }
        let card = StudyCard(question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                             answer: StudyCard.shortAnswer(answer), subject: profile.subject.isEmpty ? nil : profile.subject,
                             examDate: profile.examDate, createdAt: now)
        cards.append(card)
        if cards.count > Self.maxCards { cards.removeFirst(cards.count - Self.maxCards) }
        save()
        return card
    }

    /// D81: the five test questions the backend made for the last session; used by the next mini test, once.
    private(set) var pendingTest: [StudyCard] = []

    /// The backend's cards join the local ones (one per question); its test waits for the mini test.
    func addRemote(_ reply: StudyCardsReply, profile: StudyProfile, now: Date = Date()) {
        let subject = profile.subject.isEmpty ? nil : profile.subject
        for item in reply.cards {
            let key = AheadAnswer.key(item.q)
            guard !item.q.isEmpty, !item.a.isEmpty, !cards.contains(where: { AheadAnswer.key($0.question) == key }) else { continue }
            cards.append(StudyCard(question: item.q, answer: item.a, subject: subject, examDate: profile.examDate, createdAt: now))
        }
        if cards.count > Self.maxCards { cards.removeFirst(cards.count - Self.maxCards) }
        pendingTest = reply.test.prefix(5).map {
            StudyCard(question: $0.q, answer: $0.a, subject: subject, examDate: profile.examDate, createdAt: now)
        }
        save()
    }

    /// The pending test if there is one (then it is used up), else five of the cards.
    func takeTest(sessionStart: Date?, now: Date = Date()) -> [StudyCard] {
        if !pendingTest.isEmpty {
            defer { pendingTest = [] }
            return pendingTest
        }
        return miniTest(sessionStart: sessionStart, now: now)
    }

    func mark(_ id: UUID, right: Bool) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        if right { cards[index].right += 1 } else { cards[index].wrong += 1 }
        save()
    }

    func delete(_ id: UUID) {
        cards.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        cards = []
        save()
    }

    /// Five questions: this session's first, then the ones most often wrong, then the oldest.
    func miniTest(sessionStart: Date?, count: Int = 5, now: Date = Date()) -> [StudyCard] {
        let current = current(now: now)
        let fromSession = current.filter { sessionStart.map { start in $0.createdAt >= start } ?? false }
            .sorted { $0.createdAt < $1.createdAt }
        let rest = current.filter { card in !fromSession.contains { $0.id == card.id } }
            .sorted { ($0.wrong - $0.right, $1.createdAt) > ($1.wrong - $1.right, $0.createdAt) }
        return Array((fromSession + rest).prefix(count))
    }

    private func save() {
        do { try file.save(cards) } catch {
            Log.session.error("Study cards not saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// D81: the five-question test after Provläge, by voice. Lumen asks, the wearer answers, the tutor says whether it
/// was right (the stored answer goes along so it can judge), then the next question.
struct MiniTest: Equatable, Sendable {
    private(set) var cards: [StudyCard]
    private(set) var index = 0
    private(set) var results: [UUID: Bool] = [:]

    init(cards: [StudyCard]) { self.cards = cards }

    var current: StudyCard? { index < cards.count ? cards[index] : nil }
    var isFinished: Bool { index >= cards.count }
    var rightCount: Int { results.values.filter { $0 }.count }

    func question(swedish: Bool) -> String? {
        guard let card = current else { return nil }
        let number = swedish ? "Fråga \(index + 1) av \(cards.count)" : "Question \(index + 1) of \(cards.count)"
        return "\(number): \(card.question)"
    }

    /// What the tutor gets for the wearer's answer.
    func gradingQuery(for answer: String, swedish: Bool) -> String? {
        guard let card = current else { return nil }
        return swedish
            ? "Minitest. Frågan var: \(card.question)\nSvaret från tidigare: \(card.answer)\nMitt svar: \(answer)\nSäg först \"Rätt\" eller \"Inte riktigt\", sedan högst en mening om varför."
            : "Mini test. The question was: \(card.question)\nThe earlier answer: \(card.answer)\nMy answer: \(answer)\nSay \"Right\" or \"Not quite\" first, then at most one sentence why."
    }

    /// The tutor's reply decides right or wrong; the test moves on.
    mutating func graded(_ reply: String) {
        guard let card = current else { return }
        let start = reply.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        results[card.id] = start.hasPrefix("rätt") || start.hasPrefix("right") || start.hasPrefix("correct") || start.hasPrefix("helt rätt")
        index += 1
    }

    mutating func skip() {
        guard let card = current else { return }
        results[card.id] = false
        index += 1
    }

    /// "Lumen, minitest", "Lumen, förhör mig", "Lumen, quiz me".
    static func isStartCommand(_ text: String) -> Bool {
        let key = AheadAnswer.key(text)
        return ["minitest", "mini test", "förhör mig", "forhor mig", "testa mig", "quiz me", "test me"].contains { key.hasPrefix($0) || key == $0 }
    }

    /// "vet inte", "hoppa över", "nästa", "pass".
    static func isSkip(_ text: String) -> Bool {
        let key = AheadAnswer.key(text)
        return ["vet inte", "jag vet inte", "hoppa över", "hoppa over", "nästa", "nasta", "pass", "skip", "i don t know", "i dont know"].contains(key)
    }

    func summary(swedish: Bool) -> String {
        swedish ? "Klart. \(rightCount) av \(cards.count) rätt." : "Done. \(rightCount) of \(cards.count) right."
    }
}

/// D81: `POST /functions/v1/study-cards` (Kevin). The session's questions and answers go up as a summary; cards and
/// a five-question test come back. Nothing is stored on the server. Quiet when offline: the local cards remain.
struct StudyCardsReply: Decodable, Equatable, Sendable {
    struct Item: Decodable, Equatable, Sendable {
        var q: String
        var a: String
    }
    var cards: [Item]
    var test: [Item]
}

enum StudyCardsRequest {
    static let summaryLimit = 6_000
    static let profileLimit = 2_000

    struct Body: Encodable, Equatable, Sendable {
        var summary: String
        var profile: String?
        var cards: Int
        var language: String
    }

    /// "Fråga: …\nSvar: …" per turn, newest kept when it is too long.
    static func summary(_ turns: [(question: String, answer: String)]) -> String {
        var parts: [String] = []
        var length = 0
        for turn in turns.reversed() {
            let part = "Fråga: \(turn.question)\nSvar: \(turn.answer)"
            if length + part.count + 2 > summaryLimit { break }
            parts.insert(part, at: 0)
            length += part.count + 2
        }
        return parts.joined(separator: "\n\n")
    }

    static func body(turns: [(question: String, answer: String)], profile: String?, swedish: Bool) -> Body? {
        let text = summary(turns)
        guard !text.isEmpty else { return nil }
        return Body(summary: text, profile: profile.map { String($0.prefix(profileLimit)) },
                    cards: min(12, max(3, turns.count * 2)), language: swedish ? "sv" : "en")
    }
}

@MainActor
final class StudyCardsClient {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func cards(_ body: StudyCardsRequest.Body) async -> StudyCardsReply? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.studyCardsURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 20
            request.httpBody = try JSONEncoder().encode(body)
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.answer.error("study cards: HTTP \(response.statusCode, privacy: .public)")
                return nil
            }
            return try JSONDecoder().decode(StudyCardsReply.self, from: data)
        } catch {
            return nil
        }
    }
}
