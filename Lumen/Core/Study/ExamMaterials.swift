import Foundation
import Observation
import PDFKit
import UIKit

/// D84: the uploaded exam and its marking instructions. The pages are turned into JPEG images on the phone (about
/// 1 600 px, Kevin's advice), sent to `POST /exam` "parse" in batches of at most 10, and only the parsed tasks are
/// kept, on this phone. The images are not kept.
@MainActor
@Observable
final class ExamMaterials {
    private(set) var paper = ExamPaper()
    private(set) var status: String?
    private(set) var isReading = false
    private let file: LocalJSONFile

    init(directory: URL = NotesStore.defaultDirectory) {
        file = LocalJSONFile(url: directory.appendingPathComponent("exam-paper.json"))
        paper = (try? file.load(ExamPaper.self)) ?? ExamPaper()
    }

    var isReady: Bool { !paper.tasks.isEmpty }

    func clear() {
        paper = ExamPaper()
        status = nil
        save()
    }

    /// A16: a practice exam pasted as text (K15 `parse` with `text`).
    func read(text: String, name: String, with client: ExamClient, subject: String?, grade: String?) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isReading = true
        defer { isReading = false }
        status = "Läser frågorna …"
        guard let parsed = await client.parse(text: text, subject: subject, grade: grade) else {
            status = "Kunde inte läsa texten. Försök igen med internet."
            return
        }
        paper = ExamPaper()
        paper.name = name
        paper.merge(tasks: parsed.tasks, boundaries: parsed.boundaries)
        save()
        status = "\(paper.tasks.count) frågor."
    }

    /// A PDF with a text layer is read as text (K15), which is cheaper and exact; one without goes as page images.
    nonisolated static let textLayerMinimum = 200

    /// Reads the files (the exam, the instructions, or both at once) and merges what comes back.
    func read(_ urls: [URL], with client: ExamClient, subject: String?, grade: String?) async {
        isReading = true
        defer { isReading = false }
        if urls.count == 1, let url = urls.first, url.pathExtension.lowercased() == "pdf",
           let text = try? DocumentText.read(url), text.count >= Self.textLayerMinimum {
            status = "Läser \(url.lastPathComponent) …"
            if let parsed = await client.parse(text: text, subject: subject, grade: grade) {
                if paper.name.isEmpty { paper.name = url.deletingPathExtension().lastPathComponent }
                paper.merge(tasks: parsed.tasks, boundaries: parsed.boundaries)
                save()
                status = "\(paper.tasks.count) uppgifter" + (paper.boundaries.isEmpty ? "." : ", betygsgränser hittade.")
                return
            }
            // the text call failed: the pages as images below
        }
        var pages: [Data] = []
        for url in urls {
            status = "Förbereder \(url.lastPathComponent) …"
            pages += await Self.pages(from: url)
        }
        guard !pages.isEmpty else {
            status = "Inga sidor kunde läsas ur filerna."
            return
        }
        if paper.name.isEmpty { paper.name = urls.first?.deletingPathExtension().lastPathComponent ?? "" }
        var batch = 0
        for start in stride(from: 0, to: pages.count, by: ExamClient.pagesPerCall) {
            batch += 1
            let slice = Array(pages[start..<min(start + ExamClient.pagesPerCall, pages.count)])
            status = "Läser sida \(start + 1)–\(start + slice.count) av \(pages.count) …"
            guard let parsed = await client.parse(pages: slice, subject: subject, grade: grade) else {
                status = "Kunde inte läsa sidorna (\(batch). omgången). Försök igen med internet."
                save()
                return
            }
            paper.merge(tasks: parsed.tasks, boundaries: parsed.boundaries)
        }
        save()
        status = "\(paper.tasks.count) uppgifter" + (paper.boundaries.isEmpty ? "." : ", betygsgränser hittade.")
    }

    private func save() {
        try? file.save(paper)
    }

    // MARK: Pages

    nonisolated static let longestSide: CGFloat = 1_600
    nonisolated static let maxPages = 40

    /// JPEG pages from a PDF or one photo.
    nonisolated static func pages(from url: URL) async -> [Data] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { return [] }
            var out: [Data] = []
            for index in 0..<min(document.pageCount, maxPages) {
                guard let page = document.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let scale = longestSide / max(bounds.width, bounds.height, 1)
                let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                if let data = image.jpegData(compressionQuality: 0.7) { out.append(data) }
            }
            return out
        }
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return [] }
        return jpeg(image).map { [$0] } ?? []
    }

    nonisolated static func jpeg(_ image: UIImage) -> Data? {
        let scale = min(1, longestSide / max(image.size.width, image.size.height, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

/// D84: Kevin's `POST /functions/v1/exam`: parse (page images), hint (level 1–3), grade (points checked in code),
/// summary (code only).
@MainActor
final class ExamClient {
    static let pagesPerCall = 10

    struct Parsed: Decodable, Sendable {
        var tasks: [ExamTask]
        var boundaries: [ExamBoundary]
    }

    struct Graded: Decodable, Sendable {
        var points: ExamTask.Points
        var max: ExamTask.Points?
        var feedback: String
    }

    struct Summary: Decodable, Sendable {
        var spoken: String
        var grade: String?
    }

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func parse(pages: [Data], subject: String?, grade: String?) async -> Parsed? {
        var body: [String: Any] = ["action": "parse",
                                   "pages": pages.map { ["media_type": "image/jpeg", "data": $0.base64EncodedString()] }]
        if let subject { body["subject"] = subject }
        if let grade { body["grade"] = grade }
        return await call(body, timeout: 120)
    }

    func hint(task: ExamTask, level: Int) async -> String? {
        struct Reply: Decodable { var hint: String }
        let reply: Reply? = await call(["action": "hint", "task": Self.json(task), "level": level], timeout: 20)
        return reply?.hint
    }

    func grade(task: ExamTask, answer: String, practice: Bool = false) async -> Graded? {
        var body: [String: Any] = ["action": "grade", "task": Self.json(task), "answer": String(answer.prefix(2_000))]
        if practice { body["practice"] = true } // K15: the feedback also says the right answer and why
        return await call(body, timeout: 30)
    }

    /// K15: an exam given as text (pasted, or a PDF's text layer); at most 40 000 characters.
    func parse(text: String, subject: String?, grade: String?) async -> Parsed? {
        var body: [String: Any] = ["action": "parse", "text": String(text.prefix(40_000))]
        if let subject { body["subject"] = subject }
        if let grade { body["grade"] = grade }
        return await call(body, timeout: 120)
    }

    func summary(results: [(no: String, points: ExamTask.Points)], boundaries: [ExamBoundary]) async -> Summary? {
        let list = results.map { ["no": $0.no, "points": ["E": $0.points.E, "C": $0.points.C, "A": $0.points.A]] as [String: Any] }
        let limits = boundaries.map { b -> [String: Any] in
            var item: [String: Any] = ["grade": b.grade, "total": b.total]
            if let minCa = b.minCa { item["min_ca"] = minCa }
            if let minA = b.minA { item["min_a"] = minA }
            return item
        }
        return await call(["action": "summary", "results": list, "boundaries": limits], timeout: 15)
    }

    private static func json(_ task: ExamTask) -> [String: Any] {
        ["no": task.no, "text": task.text, "answer": task.answer, "assessment": task.assessment,
         "points": ["E": task.points.E, "C": task.points.C, "A": task.points.A]]
    }

    private func call<Reply: Decodable>(_ body: [String: Any], timeout: TimeInterval) async -> Reply? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.examURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = timeout
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200 else {
                Log.answer.error("exam: HTTP \(response.statusCode, privacy: .public)")
                return nil
            }
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            return nil
        }
    }
}
