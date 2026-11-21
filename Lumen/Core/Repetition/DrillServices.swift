import AVFAudio
import CryptoKit
import Foundation
import Observation

// MARK: - K45: material → questions and answers

/// What the user gave: photos and pages, free text and a document's text (B4: never stored, only sent).
struct DrillMaterial: Sendable {
    var pages: [Data] = []
    var text: String = ""

    var isEmpty: Bool { pages.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct DrillDraft: Sendable, Equatable {
    var summary: DrillSummary
    var items: [DrillItem]
    /// The material as compact text (K45 `notes`), sent again for edited questions; kept only in memory.
    var notes: String
    /// K51 (D159): "Materialet räckte till 4 frågor." when the material carried fewer than asked.
    var note: String? = nil
}

/// A105 (D185, K70 `/exam read`): the material cleaned for reading aloud, in parts. Nothing is stored until the user
/// saves it (`Drill.text`, `RepetitionModel.save`), and only saving counts against the month (`countsAs`).
struct DrillTextDraft: Sendable, Equatable {
    var title: String
    var summary: DrillSummary
    /// Headings and paragraphs in reading order (`DrillItem.textPart`).
    var parts: [DrillItem]
    var chars: Int
    /// What saving will count: every started 800 characters is one question (D185).
    var countsAs: Int
    /// The material was longer than the server reads (40 000 characters, 150 parts).
    var truncated: Bool = false
    var warning: String? = nil
    /// A131 (D213, K90): what saving and starting the text costs in credits, from `/exam read`; nil from a server
    /// that counts questions.
    var cost: Int? = nil

    /// A105: the exam to save. Toby's T51 (2026-11-18): it is marked as not said. A text without a name, subject and
    /// grade is named by the server after its first heading, which is what the Säg field would have called it too, so
    /// `Drill.isSaid`'s rule for texts from before the mark took it for a said text: no exam on Start, only a capsule
    /// under Senaste.
    var drill: Drill {
        var made = Drill.text(title: title, summary: summary, parts: parts)
        made.said = false
        return made
    }

    /// D185: every started 800 characters is one question (the server's `counts_as` wins when it sends one).
    static func countsAs(chars: Int, perQuestion: Int = 800) -> Int {
        chars <= 0 ? 0 : (chars + perQuestion - 1) / perQuestion
    }
}

enum DrillMakingError: Error, Equatable {
    case noMaterial
    /// No network (Ke50 §13: "Ingen internetanslutning …"), only when the phone has none (A85).
    case offline
    /// The server said no with a message for the user (a page too big, the rate limit …).
    case refused(String)
    /// The server did not answer as K45 says (not deployed yet, offline, an error).
    case server(String)
    /// A154 (K109/K110, D239, D241): the credits do not cover the exam that was asked for. Said by the server before
    /// it makes anything, with how many questions fit.
    case tooFewCredits(ExamRefusal)
}

/// K109/K110: the server's no to an exam the credits do not cover (402 `quota_exceeded` with `fits`). Nothing was
/// made and nothing was counted.
struct ExamRefusal: Equatable, Sendable {
    /// The server's words ("Ett prov med 12 frågor kostar cirka 7 704 krediter. Du har 1 500 kvar, …").
    var message: String
    /// How many questions the credits cover. An upper bound (K110): an exam with this many can always be saved.
    var fits: Int
    /// The fewest questions an exam has (`min_questions`, 3).
    var minQuestions: Int
    /// Credits per question at the asked length of the long answers.
    var perQuestion: Int?
    /// What the asked exam would cost, about.
    var cost: Int?
    /// The credits that are left.
    var left: Int?

    var canMakeAnExam: Bool { fits >= minQuestions }
}

/// Toby's T55 44712185537 (2026-11-20): the app's `cost` call said about 2 500 credits for three questions of a text
/// of 39 words, and the server's own path for the same case cost 1 091–1 474. What the app sends is written to the
/// log, in lengths only (never the texts), so the next run shows what is longer.
enum ExamLog {
    static func words(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    /// The rows of a `cost` (or `save`) call: how many, and how long each question and answer is. The server counts
    /// the question's and the long answer's characters.
    static func costLines(_ drill: Drill, limit: Int = 12) -> [String] {
        let rows = drill.items
        let questions = rows.reduce(0) { $0 + $1.question.count }
        let longs = rows.reduce(0) { $0 + $1.long.count }
        let longWords = rows.reduce(0) { $0 + words($1.long) }
        var lines = ["Exam cost: asks about \(rows.count) rows, long_words \(drill.longWords): questions \(questions) chars, "
                     + "long answers \(longs) chars (\(longWords) words), \(questions + longs) in all"]
        for (i, item) in rows.prefix(limit).enumerated() {
            lines.append("Exam cost: row \(i + 1): question \(item.question.count) chars, short \(item.short.count) chars "
                         + "(\(words(item.short)) words), long \(item.long.count) chars (\(words(item.long)) words), "
                         + "long starts with short \(item.long.hasPrefix(item.short) ? "yes" : "no")")
        }
        if rows.count > limit { lines.append("Exam cost: and \(rows.count - limit) more rows") }
        return lines
    }

    /// One answer as the server gave it (`drill_answers`), and how long the app's kept long answer became (the short
    /// answer is put first when the server's long answer does not start with it, D145).
    static func answerLine(row: Int, short: String, long: String, kept: String) -> String {
        "Exam answers: row \(row): the server's short \(short.count) chars (\(words(short)) words), long \(long.count) chars "
            + "(\(words(long)) words), starts with short \(long.hasPrefix(short) ? "yes" : "no"); kept \(kept.count) chars"
    }
}

/// A154 (D239, D241): what a question of a new exam costs, as the server counts it, so that Nytt prov can say how
/// many questions the credits cover before anything is made.
struct ExamRoom: Equatable, Sendable {
    /// Credits per question (an upper bound, K110: 75 + 6,3 per word of the long answer; 642 at 90 words).
    var perQuestion: Int
    /// The fewest questions an exam has.
    var minQuestions: Int = 3
    /// The length of the long answers the price is for (another length is another price).
    var longWords: Int

    init(perQuestion: Int, minQuestions: Int = 3, longWords: Int) {
        self.perQuestion = perQuestion
        self.minQuestions = minQuestions
        self.longWords = longWords
    }

    /// From the server's no: its own price per question, or counted from how many it said fit.
    init?(_ no: ExamRefusal, longWords: Int) {
        if let per = no.perQuestion, per > 0 {
            self.init(perQuestion: per, minQuestions: no.minQuestions, longWords: longWords)
        } else if let left = no.left {
            // `fits` questions fit and one more does not: a price between the two (none fit: more than is left).
            self.init(perQuestion: no.fits > 0 ? max(1, left / no.fits) : left + 1, minQuestions: no.minQuestions, longWords: longWords)
        } else {
            return nil
        }
    }

    func fits(left: Int) -> Int { perQuestion > 0 ? max(0, left) / perQuestion : DrillSettings.questionRange.upperBound }
    func canMakeAnExam(left: Int) -> Bool { fits(left: left) >= minQuestions }

    /// "Annars kostnaden före sparandet": the server's exact cost of the finished exam against what is left. No
    /// answer (no network, an older server) is not a no: the server then decides at the save, as before.
    static func covers(cost: DrillCost?, left: Int) -> Bool {
        guard let cost else { return true }
        if let enough = cost.enough { return enough }
        return cost.cost <= (cost.remaining ?? left)
    }
}

/// K45 (`POST /exam` `drill`, `drill_answers`, `drill_one`, `doc_text`). `MockDrillMaker` stands in until it is live
/// and in the Simulator tests.
@MainActor
protocol DrillMaking: AnyObject, Sendable {
    func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
              questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft
    /// K45 `drill_answers`: the short and long answers of questions that have none yet (step 2, while the user reads
    /// the summary). Returns the same items in the same order with their answers.
    func answers(for items: [DrillItem], summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> [DrillItem]
    /// A new or edited question: its short and long answer.
    func answer(_ question: String, summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> DrillItem
    /// .docx: iOS cannot read Word (only macOS can), so the server does (K45 `doc_text`).
    func documentText(docx: Data) async throws(DrillMakingError) -> String
    /// A105 (D185, K70): Läs upp texten: the material cleaned for reading aloud, in parts.
    func readText(_ material: DrillMaterial, subject: String?, grade: String?, title: String?) async throws(DrillMakingError) -> DrillTextDraft
    /// A116 (D204, K81): a web page's readable text, fetched by the server.
    func fetchPage(_ address: String) async throws(DrillMakingError) -> FetchedPage
}

/// A116 (D204, Kevin's K81 `fetch-url`): a web page read by the server (only http/https, never an internal address,
/// at most 2 MB and 40 000 characters of readable text). The text then goes to `/exam` like a document's text.
struct FetchedPage: Decodable, Sendable, Equatable {
    var url: String?
    var title: String?
    var text: String
    var chars: Int?
    var truncated: Bool?

    /// What the user pasted, as an address the server takes: "example.com/sida" gets https in front.
    static func address(_ pasted: String) -> String? {
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let lower = trimmed.lowercased()
        let full = lower.hasPrefix("http://") || lower.hasPrefix("https://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: full), let host = url.host, host.contains(".") else { return nil }
        return full
    }

    /// Ke69: said when the page could not be read and the server gave no words of its own.
    static let unreadableLine = String(localized: "Sidan gick inte att läsa. Kopiera texten och klistra in den i stället.")
}

extension DrillMaking {
    /// A116: only the real client reads pages; the mocks say no.
    func fetchPage(_ address: String) async throws(DrillMakingError) -> FetchedPage { throw .server("fetch-url not available") }
}

@MainActor
final class DrillClient: DrillMaking {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming
    /// K67 (O64): the questions `drill` just made, by item id. Only those, unchanged, may be fixed by the answers step.
    private var generated: [UUID: String] = [:]

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    private struct Reply: Decodable {
        struct Summary: Decodable { var subject: String?; var grade: String?; var covers: String? }
        struct Item: Decodable {
            var id: String?
            var question: String
            var short: String?
            var long: String?
            /// K66 point 4 (A102): the shown text, only the fields that differ.
            struct Screen: Decodable { var question: String?; var short: String?; var long: String? }
            var screen: Screen?

            func screenText(spokenShort: String, spokenLong: String) -> DrillScreenText? {
                guard let screen else { return nil }
                return DrillScreenText.made(question: screen.question, short: screen.short, long: screen.long,
                                            spokenShort: spokenShort, spokenLong: spokenLong)
            }
        }
        var summary: Summary?
        var notes: String?
        var items: [Item]?
        var item: Item?
        var text: String?
        var note: String?
        struct Upload: Decodable { var path: String; var url: String }
        var uploads: [Upload]?
        /// K70 `/exam read`.
        struct Part: Decodable { var kind: String?; var text: String }
        var parts: [Part]?
        var title: String?
        var subject: String?
        var grade: String?
        var chars: Int?
        var counts_as: Int?
        /// K90 (D213): the text's cost in credits.
        var cost: Int?
        var truncated: Bool?
        var warning: String?
    }

    /// K53: up to 4 photos go as base64 in the drill itself; more are uploaded first (at most 40).
    static let inlinePages = 4
    static let maxPages = 40
    static let parallelUploads = 4

    /// K53: pre-signed URLs from `/exam upload_urls`, a PUT per photo (4 at a time, no auth headers), each tried twice.
    /// Returns the paths in the photos' order.
    private func upload(_ pages: [Data]) async throws(DrillMakingError) -> [String] {
        let reply = try await call(["action": "upload_urls", "count": pages.count], timeout: 30)
        let uploads = reply.uploads ?? []
        guard uploads.count >= pages.count else { throw .server("upload_urls gave \(uploads.count) of \(pages.count)") }
        let http = self.http
        let started = Date()
        var failed = 0
        var next = 0
        await withTaskGroup(of: Bool.self) { group in
            func add(_ i: Int) {
                let url = URL(string: uploads[i].url)
                let page = pages[i]
                group.addTask {
                    guard let url else { return false }
                    for _ in 0..<2 {
                        var request = URLRequest(url: url)
                        request.httpMethod = "PUT"
                        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                        request.timeoutInterval = 60
                        request.httpBody = page
                        if let result = try? await http.data(for: request), (200..<300).contains(result.0.statusCode) {
                            return true
                        }
                    }
                    return false
                }
            }
            while next < min(Self.parallelUploads, pages.count) { add(next); next += 1 }
            for await ok in group {
                if !ok { failed += 1 }
                if next < pages.count { add(next); next += 1 }
            }
        }
        let bytes = pages.reduce(0) { $0 + $1.count }
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        let missing = failed
        let count = pages.count
        Log.repetition.info("exam upload: \(count, privacy: .public) photos, \(bytes, privacy: .public) bytes, \(missing, privacy: .public) failed, \(ms, privacy: .public) ms")
        guard missing == 0 else {
            if !NetworkStatus.shared.isOnline { throw .offline }
            throw .refused(String(localized: "\(missing) av \(count) bilder kom inte fram. Försök igen."))
        }
        return uploads.prefix(pages.count).map(\.path)
    }

    func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
              questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft {
        guard !material.isEmpty else { throw .noMaterial }
        // Step 1 only (Haiku: summary, notes, questions); the answers come with `answers(for:)` (K45 "answers": false).
        var body: [String: Any] = ["action": "drill", "questions": min(max(questions, 3), 60),
                                   "long_words": min(max(longWords, 40), 200), "answers": false]
        if material.pages.count > Self.inlinePages {
            // K53: many photos go one by one to Storage first, and the drill names their paths.
            body["page_paths"] = try await upload(Array(material.pages.prefix(Self.maxPages)))
        } else if !material.pages.isEmpty {
            body["pages"] = material.pages.map { ["media_type": "image/jpeg", "data": $0.base64EncodedString()] }
        }
        let text = material.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { body["text"] = String(text.prefix(40_000)) }
        if let subject, !subject.isEmpty { body["subject"] = subject }
        if let grade, !grade.isEmpty { body["grade"] = grade }
        if let correction, !correction.isEmpty { body["correction"] = correction }
        let reply = try await call(body, timeout: 150)
        let summary = DrillSummary(subject: reply.summary?.subject ?? "", grade: reply.summary?.grade ?? "",
                                   covers: reply.summary?.covers ?? "")
        let items = (reply.items ?? []).map { item in
            let short = item.short ?? ""
            var made = DrillItem(question: item.question, short: short, long: DrillItem.long(item.long ?? "", startingWith: short))
            made.screen = item.screenText(spokenShort: short, spokenLong: item.long ?? "") // A102
            return made
        }
        guard !items.isEmpty else { throw .server("no questions") }
        generated = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.question) })
        let note = reply.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DrillDraft(summary: summary, items: items, notes: reply.notes ?? "", note: note?.isEmpty == false ? note : nil)
    }

    func answers(for items: [DrillItem], summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> [DrillItem] {
        let missing = items.filter { $0.short.isEmpty }
        guard !missing.isEmpty else { return items }
        var body: [String: Any] = ["action": "drill_answers", "subject": summary.subject, "grade": summary.grade,
                                   "notes": String(notes.prefix(12_000)), "long_words": min(max(longWords, 40), 200),
                                   "items": missing.map { ["id": $0.id.uuidString, "question": $0.question] }]
        // K67 (O64): the answers step may swap a bad question ("varför" the material does not explain, a premise
        // against it), but only questions `drill` made that nobody changed; never the student's own.
        let mayFix = Self.mayFix(missing, generated: generated)
        if mayFix { body["may_fix"] = true }
        let reply = try await call(body, timeout: 150)
        var byID: [String: Reply.Item] = [:]
        for item in reply.items ?? [] { if let id = item.id { byID[id] = item } }
        var answerLines: [String] = [] // lengths only, for the log (Toby's T55: what makes the cost)
        let filled = items.map { item -> DrillItem in
            guard item.short.isEmpty, let made = byID[item.id.uuidString], let short = made.short, !short.isEmpty else { return item }
            var item = item
            let fixed = made.question.trimmingCharacters(in: .whitespacesAndNewlines)
            if mayFix, !fixed.isEmpty, fixed != item.question {
                item.question = fixed // K67: the same id, a better question
                item.screen?.question = nil // step 1's shown question was for the old one
            }
            item.short = short
            item.long = DrillItem.long(made.long ?? "", startingWith: short)
            answerLines.append(ExamLog.answerLine(row: answerLines.count + 1, short: short, long: made.long ?? "", kept: item.long))
            // A102: the question's shown text from step 1 stays; the answers' come now.
            let answers = made.screenText(spokenShort: short, spokenLong: made.long ?? "")
            var screen = item.screen ?? DrillScreenText()
            screen.short = answers?.short
            screen.long = answers?.long
            if screen.question == nil { screen.question = answers?.question }
            item.screen = screen.isEmpty ? nil : screen
            return item
        }
        Log.repetition.info("Exam answers: asked for \(missing.count, privacy: .public) with long_words \(longWords, privacy: .public), got \(answerLines.count, privacy: .public)")
        for line in answerLines.prefix(12) { Log.repetition.info("\(line, privacy: .public)") }
        guard filled.contains(where: { !$0.short.isEmpty }) else { throw .server("no answers") }
        return filled
    }

    func answer(_ question: String, summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> DrillItem {
        let body: [String: Any] = ["action": "drill_one", "question": question, "subject": summary.subject,
                                   "grade": summary.grade, "notes": String(notes.prefix(12_000)), "long_words": min(max(longWords, 40), 200)]
        let reply = try await call(body, timeout: 60)
        guard let item = reply.item else { throw .server("no item") }
        let short = item.short ?? ""
        var made = DrillItem(question: item.question.isEmpty ? question : item.question, short: short,
                             long: DrillItem.long(item.long ?? "", startingWith: short))
        made.screen = item.screenText(spokenShort: short, spokenLong: item.long ?? "") // A102
        return made
    }

    func readText(_ material: DrillMaterial, subject: String?, grade: String?, title: String?) async throws(DrillMakingError) -> DrillTextDraft {
        guard !material.isEmpty else { throw .noMaterial }
        // K70: the same inputs as `drill`.
        var body: [String: Any] = ["action": "read"]
        if material.pages.count > Self.inlinePages {
            body["page_paths"] = try await upload(Array(material.pages.prefix(Self.maxPages)))
        } else if !material.pages.isEmpty {
            body["pages"] = material.pages.map { ["media_type": "image/jpeg", "data": $0.base64EncodedString()] }
        }
        let text = material.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { body["text"] = String(text.prefix(40_000)) }
        if let subject, !subject.isEmpty { body["subject"] = subject }
        if let grade, !grade.isEmpty { body["grade"] = grade }
        if let title, !title.isEmpty { body["title"] = title }
        let reply = try await call(body, timeout: 150)
        var draft = try Self.textDraft(reply.parts ?? [], title: reply.title, subject: reply.subject, grade: reply.grade,
                                       chars: reply.chars, countsAs: reply.counts_as, truncated: reply.truncated,
                                       warning: reply.warning)
        draft.cost = reply.cost // A131 (K90)
        return draft
    }

    /// K70's reply as the draft to save; a reply without a readable part is the server's "too little".
    private static func textDraft(_ parts: [Reply.Part], title: String?, subject: String?, grade: String?, chars: Int?,
                                  countsAs: Int?, truncated: Bool?, warning: String?) throws(DrillMakingError) -> DrillTextDraft {
        let items = parts.compactMap { part -> DrillItem? in
            let text = part.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return DrillItem.textPart(text, part: part.kind == "heading" ? .heading : .para)
        }
        guard !items.isEmpty else { throw .server("no text") }
        let total = chars ?? items.reduce(0) { $0 + $1.long.count }
        let subjectText = subject ?? ""
        let name = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DrillTextDraft(title: name?.isEmpty == false ? name! : (subjectText.isEmpty ? String(localized: "Text") : subjectText),
                              summary: DrillSummary(subject: subjectText, grade: grade ?? "", covers: ""),
                              parts: items, chars: total, countsAs: countsAs ?? DrillTextDraft.countsAs(chars: total),
                              truncated: truncated ?? false, warning: warning?.isEmpty == false ? warning : nil)
    }

    func documentText(docx: Data) async throws(DrillMakingError) -> String {
        // K45 drill.ts: {"action":"doc_text", "data": "<base64 .docx>"}
        let reply = try await call(["action": "doc_text", "data": docx.base64EncodedString()], timeout: 60)
        guard let text = reply.text, !text.isEmpty else { throw .server("no text") }
        return text
    }

    /// A116 (D204, K81): `POST /functions/v1/fetch-url {"url"}`. The server's refusals carry Swedish words for the user
    /// (`url_blocked`, `url_unreachable`, `url_too_large`, `url_not_text`, `url_empty`, `rate_limited`).
    func fetchPage(_ address: String) async throws(DrillMakingError) -> FetchedPage {
        let payload: Data
        do {
            payload = try JSONSerialization.data(withJSONObject: ["url": address])
        } catch {
            throw .server("could not encode")
        }
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.examURL.deletingLastPathComponent().appending(path: "fetch-url"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = payload
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.repetition.error("fetch-url: HTTP \(response.statusCode, privacy: .public)")
                throw Self.refusal(status: response.statusCode, data: data)
            }
            let page = try JSONDecoder().decode(FetchedPage.self, from: data)
            Log.repetition.info("fetch-url: 200, \(page.text.count, privacy: .public) characters")
            return page
        } catch let error as DrillMakingError {
            throw error
        } catch let error as URLError {
            if !NetworkStatus.shared.isOnline || error.code == .notConnectedToInternet { throw .offline }
            throw .server("URLError \(error.code.rawValue)")
        } catch {
            throw .server(error.localizedDescription)
        }
    }

    /// K67: true only when every question still is the one `drill` made for that id.
    static func mayFix(_ items: [DrillItem], generated: [UUID: String]) -> Bool {
        !items.isEmpty && items.allSatisfy { generated[$0.id] == $0.question }
    }

    /// A85: the real cause is logged (status or URLError code, bytes sent, time, network), a dropped connection is tried
    /// once more, and "offline" is said only when the phone has no network at all.
    private func call(_ body: [String: Any], timeout: TimeInterval) async throws(DrillMakingError) -> Reply {
        let action = body["action"] as? String ?? ""
        let payload: Data
        do {
            payload = try JSONSerialization.data(withJSONObject: AppLanguage.stamped(body)) // A157 (K114): lang
        } catch {
            throw .server("could not encode")
        }
        var attempt = 0
        while true {
            attempt += 1
            let started = Date()
            let elapsed = { Int(Date().timeIntervalSince(started) * 1000) }
            do {
                let token = try await auth.accessToken()
                var request = URLRequest(url: config.examURL)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
                request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = timeout
                request.httpBody = payload
                let (response, data) = try await http.data(for: request)
                let ms = elapsed()
                guard response.statusCode == 200 else {
                    Log.repetition.error("exam \(action, privacy: .public): HTTP \(response.statusCode, privacy: .public), \(payload.count, privacy: .public) bytes sent, \(ms, privacy: .public) ms")
                    throw Self.refusal(status: response.statusCode, data: data)
                }
                Log.repetition.info("exam \(action, privacy: .public): 200, \(payload.count, privacy: .public) bytes sent, \(ms, privacy: .public) ms")
                return try JSONDecoder().decode(Reply.self, from: data)
            } catch let error as DrillMakingError {
                throw error
            } catch let error as URLError {
                let ms = elapsed()
                let online = NetworkStatus.shared.isOnline
                let network = NetworkStatus.shared.interface
                Log.repetition.error("exam \(action, privacy: .public): URLError \(error.code.rawValue, privacy: .public), \(payload.count, privacy: .public) bytes, \(ms, privacy: .public) ms, try \(attempt, privacy: .public), network \(online ? network : "none", privacy: .public)")
                if !online || error.code == .notConnectedToInternet || error.code == .dataNotAllowed { throw .offline }
                if attempt < 2, Self.isTransient(error.code) {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }
                throw .server("URLError \(error.code.rawValue)")
            } catch {
                Log.repetition.error("exam \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
                throw .server(error.localizedDescription)
            }
        }
    }

    /// A connection that broke on the way (5G, a server that closed it) is worth one more try.
    static func isTransient(_ code: URLError.Code) -> Bool {
        [.networkConnectionLost, .timedOut, .cannotConnectToHost, .secureConnectionFailed].contains(code)
    }

    /// K45's refusals carry a Swedish message for the user (`{"error": {"code", "message"}}`, 413, 429 …).
    static func refusal(status: Int, data: Data) -> DrillMakingError {
        struct Body: Decodable {
            struct Inner: Decodable { var code: String?; var message: String? }
            var error: Inner?
            // K109/K110: with a 402 before the exam is made
            var fits: Int?
            var min_questions: Int?
            var per_question: Int?
            var cost: Int?
            var remaining: Int?
            var left: Int?
        }
        let body = try? JSONDecoder().decode(Body.self, from: data)
        if (400..<500).contains(status), status != 401, let message = body?.error?.message, !message.isEmpty {
            // A154 (D239, D241): the credits do not cover the exam; how many questions fit comes with the no.
            if status == 402, let fits = body?.fits {
                return .tooFewCredits(ExamRefusal(message: message, fits: max(0, fits), minQuestions: body?.min_questions ?? 3,
                                                  perQuestion: body?.per_question, cost: body?.cost,
                                                  left: body?.remaining ?? body?.left))
            }
            return .refused(message)
        }
        return .server("HTTP \(status)")
    }
}

extension DrillMakingError {
    /// Kelly Ke50 §2, §13.
    var userMessage: String {
        switch self {
        case .noMaterial: String(localized: "Lägg till material först.")
        case .offline: NetworkStatus.noNetworkLine // A103: nothing is queued, so "försök igen"
        case .server(let why) where why == "no questions":
            String(localized: "EarMind hittade för lite att göra frågor av. Lägg till fler sidor eller mer text.")
        case .server(let why) where why == "no text":
            String(localized: "EarMind hittade ingen text att läsa upp. Lägg till fler sidor eller mer text.") // A105
        case .refused(let message): message
        case .tooFewCredits(let no): no.message // A154: the server's own words
        case .server: String(localized: "Det gick inte att skapa frågorna. Försök igen.") // A85
        }
    }
}

/// Stands in for K45 in tests, the Simulator (`-RepetitionMock YES`) and while K45 is not deployed: fixed questions
/// about the material's first words, clearly marked as a sample. No model call, no cost.
@MainActor
final class MockDrillMaker: DrillMaking {
    var delay: Duration = .zero

    func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
              questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft {
        guard !material.isEmpty else { throw .noMaterial }
        if delay > .zero { try? await Task.sleep(for: delay) }
        let topic = material.text.split(whereSeparator: { $0 == "." || $0 == "\n" }).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? String(localized: "Materialet")
        let bank: [(String, String, String)] = [
            (String(localized: "Varför behövs klorofyll?"), String(localized: "Klorofyll fångar solljuset som växten behöver för fotosyntesen."),
             String(localized: "Utan ljusenergin kan växten inte bygga socker av koldioxid och vatten, så klorofyllet är startpunkten för hela näringskedjan.")),
            (String(localized: "Vad bildas vid fotosyntesen?"), String(localized: "Socker och syre bildas av koldioxid och vatten med hjälp av ljus."),
             String(localized: "Sockret ger växten energi och byggmaterial, och syret släpps ut och används av djur och människor i cellandningen.")),
            (String(localized: "Hur hänger fotosyntes och cellandning ihop?"), String(localized: "Fotosyntesen bygger socker och cellandningen bryter ner det igen."),
             String(localized: "Det ena processens produkter är den andras råvaror, så kol och syre går i ett kretslopp mellan växter och djur.")),
        ]
        let count = max(1, min(questions, 60))
        let items = (0..<count).map { i in
            let (q, s, rest) = bank[i % bank.count]
            return DrillItem(question: count > bank.count ? "\(q) (\(i + 1))" : q, short: s, long: s + " " + rest)
        }
        return DrillDraft(summary: DrillSummary(subject: subject ?? String(localized: "Biologi"), grade: grade ?? String(localized: "åk 8"),
                                                covers: String(localized: "Exempel (testläge): \(topic).")),
                          items: items, notes: material.text)
    }

    func answers(for items: [DrillItem], summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> [DrillItem] {
        if delay > .zero { try? await Task.sleep(for: delay) }
        var out: [DrillItem] = []
        for item in items {
            if !item.short.isEmpty { out.append(item); continue }
            let made = try await answer(item.question, summary: summary, notes: notes, longWords: longWords)
            var filled = item
            filled.short = made.short
            filled.long = made.long
            out.append(filled)
        }
        return out
    }

    func answer(_ question: String, summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> DrillItem {
        let short = String(localized: "Ett kort svar på \(question.lowercased())")
        return DrillItem(question: question, short: short + ".", long: short + String(localized: ". Och ett längre svar med förklaring och exempel."))
    }

    func documentText(docx: Data) async throws(DrillMakingError) -> String {
        throw .server("Word-filer läses av servern (K45 doc_text)")
    }

    /// A105: the material's own lines as parts (a short line without a full stop is a heading), clearly a sample.
    func readText(_ material: DrillMaterial, subject: String?, grade: String?, title: String?) async throws(DrillMakingError) -> DrillTextDraft {
        guard !material.isEmpty else { throw .noMaterial }
        if delay > .zero { try? await Task.sleep(for: delay) }
        var source = material.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty {
            source = String(localized: "Fotosyntes\nVäxter gör socker av koldioxid och vatten. De behöver ljus för det. Syre blir över.")
        }
        let parts = source.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .map { line in
                var part = DrillItem.textPart(line, part: line.count < 60 && !line.hasSuffix(".") ? .heading : .para)
                part.sentences = MockDrillMaker.sentences(line)
                return part
            }
        let chars = parts.reduce(0) { $0 + $1.long.count }
        return DrillTextDraft(title: title ?? String(localized: "Exempeltext (testläge)"),
                              summary: DrillSummary(subject: subject ?? String(localized: "Biologi"), grade: grade ?? String(localized: "åk 8"), covers: ""),
                              parts: parts, chars: chars, countsAs: DrillTextDraft.countsAs(chars: chars))
    }

    /// The mock's sentence split: after ".", "!" or "?" and a space.
    nonisolated static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        var previous: Character?
        for char in text {
            if char == " ", let p = previous, ".!?".contains(p) {
                out.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            previous = char
        }
        let last = current.trimmingCharacters(in: .whitespaces)
        if !last.isEmpty { out.append(last) }
        return out.isEmpty ? [text] : out
    }
}

// MARK: - K46: the exams per account

/// K46 stores the exams per account on the server. Until then (and as the phone's cache after) they live in one
/// JSON file in Application Support. The material (photos, documents) is never stored (B4).
@MainActor
@Observable
final class DrillStore {
    private(set) var drills: [Drill] = []
    private let url: URL

    init(url: URL? = nil) {
        let base = url ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true))?
            .appendingPathComponent("drills.json") ?? FileManager.default.temporaryDirectory.appendingPathComponent("drills.json")
        self.url = base
        if let data = try? Data(contentsOf: base), let saved = try? JSONDecoder().decode([Drill].self, from: data) {
            drills = saved
        }
    }

    func drill(_ id: UUID) -> Drill? { drills.first { $0.id == id } }

    func save(_ drill: Drill) {
        if let i = drills.firstIndex(where: { $0.id == drill.id }) { drills[i] = drill } else { drills.insert(drill, at: 0) }
        write()
    }

    func delete(_ id: UUID) {
        drills.removeAll { $0.id == id }
        write()
    }

    /// T24-M1 (D189): told after every change, so Provläge's exams follow the repetition exams.
    @ObservationIgnored var onChange: (@MainActor ([Drill]) -> Void)?

    private func write() {
        onChange?(drills)
        do {
            try JSONEncoder().encode(drills).write(to: url, options: .atomic)
        } catch {
            Log.repetition.error("DrillStore: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - K46: the sound

/// The files for one item, made from its texts.
struct DrillAudioKey: Hashable, Sendable {
    enum Kind: String, Sendable { case question, short, long }

    /// D144 action 1: the name is a hash of the normalised text and the voice, so the same text is made once.
    static func name(text: String, voice: String) -> String {
        let normalised = text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let digest = SHA256.hash(data: Data((voice + "|" + normalised).utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}

/// Makes and finds the sound for an exam. Until K46 (ElevenLabs on the server, word timestamps) the iPhone's own
/// voice writes the files on the phone: free, offline, 0 ElevenLabs characters. The short answer then has a file
/// of its own (no word timestamps from Apple's voice).
@MainActor
protocol DrillAudioProviding: AnyObject, Sendable {
    /// Ready and total files for the exam ("Ljud: 54 av 90 klara").
    func progress(for drill: Drill) -> (ready: Int, total: Int)
    /// Makes what is missing, in playing order. Safe to call again: made files are kept.
    func prepare(_ drill: Drill) async
    /// All tracks, or nil while a file is missing.
    func tracks(for drill: Drill) -> [RepetitionTrack]?
    /// One question's track, or nil while its sound is not made yet (the player then waits, Kelly Ke49 "Gör ljud …").
    func track(for drill: Drill, at index: Int) -> RepetitionTrack?
    /// What went wrong making the sound, said on the exam's screen.
    func problem(for drill: Drill) -> String?
    /// Kelly N1: "Tryck en gång för svaret." in the exam's voice, if there is one.
    func cue(for drill: Drill) -> URL?
    /// A105 (D185): a text's part `index`: its file and sentence times, or nil while its sound is not here.
    func reading(for drill: Drill, part index: Int) -> ReadingAudio?
    /// A107 (D190, K71): Starta prov asks the server for the sound. False = it could not start (said in `problem`).
    func startAudio(_ drill: Drill) async -> Bool
    /// A107: Starta prov is asking for the sound right now.
    func isStarting(_ drill: Drill) -> Bool
}

extension DrillAudioProviding {
    /// A107 (D190): the on-phone voice (mock mode) has nothing to start.
    func startAudio(_ drill: Drill) async -> Bool { true }
    func isStarting(_ drill: Drill) -> Bool { false }

    /// A105: all of an exam's sound is on the phone (a text has no tracks, so it is counted by its files).
    func hasAllSound(_ drill: Drill) -> Bool {
        if drill.isText {
            let p = progress(for: drill)
            return p.total > 0 && p.ready == p.total
        }
        return tracks(for: drill) != nil
    }
}

@MainActor
@Observable
final class DeviceVoiceDrillAudio: DrillAudioProviding {
    /// Bumped as files are made, so views that show the progress follow it.
    private(set) var made = 0
    private(set) var preparing: Set<UUID> = []
    private let folder: URL
    private let voice: String
    @ObservationIgnored private var synthesizer: AVSpeechSynthesizer?

    /// Tests set `makesSound: false`: they write their own silent files and must not keep the main actor busy with
    /// speech synthesis while other suites measure time.
    @ObservationIgnored private let makesSound: Bool

    init(folder: URL? = nil, language: String = "sv-SE", makesSound: Bool = true) {
        self.makesSound = makesSound
        let base = folder ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                          appropriateFor: nil, create: true))?
            .appendingPathComponent("drill_audio", isDirectory: true) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.folder = base
        self.voice = language
    }

    func url(text: String) -> URL {
        folder.appendingPathComponent("\(DrillAudioKey.name(text: text, voice: voice)).wav")
    }

    private func texts(_ drill: Drill) -> [String] {
        // A105: a text's part is one file of its text.
        drill.isText ? drill.items.map(\.long) : drill.items.flatMap { [$0.question, $0.short, $0.long] }
    }

    func progress(for drill: Drill) -> (ready: Int, total: Int) {
        _ = made
        let all = texts(drill)
        return (all.filter { FileManager.default.fileExists(atPath: url(text: $0).path) }.count, all.count)
    }

    func tracks(for drill: Drill) -> [RepetitionTrack]? {
        let all = drill.items.indices.compactMap { track(for: drill, at: $0) }
        return all.count == drill.items.count && !all.isEmpty ? all : nil
    }

    func track(for drill: Drill, at index: Int) -> RepetitionTrack? {
        _ = made
        guard drill.items.indices.contains(index) else { return nil }
        let item = drill.items[index]
        let track = RepetitionTrack(question: url(text: item.question), long: url(text: item.long),
                                    short: .file(url(text: item.short)))
        let files = [track.question, track.long, url(text: item.short)]
        return files.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) ? track : nil
    }

    func problem(for drill: Drill) -> String? { stagedProblems[drill.id] }

    /// A100 scenes: "Ljudet kan inte göras just nu" without a server.
    var stagedProblems: [UUID: String] = [:]

    func cue(for drill: Drill) -> URL? { nil } // the mock has no fixed line

    /// A105: the iPhone voice reads each sentence into its own file part by part; the times are spread over the part
    /// by the sentences' lengths (Apple's voice gives no timestamps). Only for the mock mode and the Simulator.
    func reading(for drill: Drill, part index: Int) -> ReadingAudio? {
        _ = made
        guard drill.items.indices.contains(index) else { return nil }
        let item = drill.items[index]
        let file = self.url(text: item.long)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let duration = (try? AVAudioPlayer(contentsOf: file))?.duration ?? 0
        return ReadingAudio(url: file, times: Self.spread(item.readingSentences, over: duration))
    }

    /// Sentence times over `duration` in proportion to each sentence's characters.
    nonisolated static func spread(_ sentences: [String], over duration: TimeInterval) -> [ClosedRange<TimeInterval>] {
        let total = Double(max(sentences.reduce(0) { $0 + $1.count }, 1))
        var start = 0.0
        return sentences.map { sentence in
            let end = start + duration * Double(sentence.count) / total
            defer { start = end }
            return start...max(start, end)
        }
    }

    func prepare(_ drill: Drill) async {
        guard makesSound, !preparing.contains(drill.id) else { return }
        preparing.insert(drill.id)
        defer { preparing.remove(drill.id) }
        for text in texts(drill) where !text.isEmpty {
            let target = url(text: text)
            if FileManager.default.fileExists(atPath: target.path) { continue }
            do {
                try await write(text, to: target)
                made += 1
            } catch {
                Log.repetition.error("Device voice: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func write(_ text: String, to target: URL) async throws {
        let synthesizer = self.synthesizer ?? AVSpeechSynthesizer()
        self.synthesizer = synthesizer
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        let (stream, continuation) = AsyncStream<TTSChunk>.makeStream(bufferingPolicy: .unbounded)
        synthesizer.write(utterance, toBufferCallback: PlaybackService.ttsBufferCallback(continuation))
        var samples: [Int16] = []
        var rate = 22_050.0
        for await chunk in stream {
            rate = chunk.sampleRate
            samples.append(contentsOf: chunk.samples.map { Int16(max(-1, min(1, $0)) * 32_767) })
        }
        guard !samples.isEmpty else { throw DrillMakingError.server("no speech for \(text.prefix(20))") }
        try WAVWriter.write(samples: samples, sampleRate: Int(rate), to: target)
    }
}
