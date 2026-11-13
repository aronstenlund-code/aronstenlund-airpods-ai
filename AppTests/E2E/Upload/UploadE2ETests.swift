import Foundation
import Testing
import UIKit
@testable import Lumen

/// T20 (Toby 1): K53 in the app, many photos to questions. `DrillClient.make` against the live `/exam` with 1, 4, 10
/// and 30 photographed pages (4 or fewer go as base64 in the drill, more are uploaded one by one with signed URLs),
/// with the time, the bytes and every request recorded; a flaky connection that must recover; and the error paths
/// with a stub, where the app must never say "Ingen internetanslutning" while the phone has a network (A85).
///
/// The pages are made-up study text (never a pupil's), drawn as a 4 032 × 3 024 camera photo and scaled by the app's
/// own `ExamMaterials.jpeg`, as `NewDrillView` does. Live and paid (Claude Haiku for the questions, no answers, no
/// ElevenLabs): only when `scripts/apptest/upload.sh` sets `LUMEN_E2E_UPLOAD`. Each live case signs in as its own
/// anonymous account, so the exam rate limit (12 per minute, a drill weighs 4) is never shared. Simulator only.
enum UploadEnvironment {
    static var enabled: Bool { ProcessInfo.processInfo.environment["LUMEN_E2E_UPLOAD"] != nil }
    static var out: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
    }
}

/// Every request through the client: what it was, how big, how it ended. A fault plan can drop chosen attempts.
final class RecordingHTTP: HTTPStreaming, @unchecked Sendable {
    struct Entry: Codable {
        var kind: String
        var bytes: Int
        var outcome: String
        var ms: Int
    }

    private let inner: any HTTPStreaming
    private let lock = NSLock()
    private var entries: [Entry] = []
    private var attempts: [String: Int] = [:]
    /// (kind, attempt number for that kind) → an error to throw instead of sending.
    private let fault: @Sendable (String, Int) -> URLError?

    init(inner: any HTTPStreaming = URLSessionHTTP(), fault: @escaping @Sendable (String, Int) -> URLError? = { _, _ in nil }) {
        self.inner = inner
        self.fault = fault
    }

    var log: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    static func kind(of request: URLRequest) -> String {
        if request.httpMethod == "PUT" { return "put \(request.url?.lastPathComponent ?? "")" }
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let action = json["action"] as? String {
            return action
        }
        return request.httpMethod ?? "?"
    }

    private func note(_ kind: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        attempts[kind, default: 0] += 1
        return attempts[kind] ?? 1
    }

    private func add(_ entry: Entry) {
        lock.lock()
        entries.append(entry)
        lock.unlock()
    }

    func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        let kind = Self.kind(of: request)
        let attempt = note(kind)
        let bytes = request.httpBody?.count ?? 0
        let started = Date()
        let ms = { Int(Date().timeIntervalSince(started) * 1000) }
        if let error = fault(kind, attempt) {
            add(Entry(kind: kind, bytes: bytes, outcome: "dropped URLError \(error.code.rawValue) (fault plan)", ms: 0))
            throw error
        }
        do {
            let result = try await inner.data(for: request)
            add(Entry(kind: kind, bytes: bytes, outcome: "HTTP \(result.0.statusCode)", ms: ms()))
            return result
        } catch let error as URLError {
            add(Entry(kind: kind, bytes: bytes, outcome: "URLError \(error.code.rawValue)", ms: ms()))
            throw error
        } catch {
            add(Entry(kind: kind, bytes: bytes, outcome: "\(error)", ms: ms()))
            throw error
        }
    }

    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        try await inner.lines(for: request)
    }

    func bytes(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, any Error>) {
        try await inner.bytes(for: request)
    }
}

/// Answers `/exam` without a server: `upload_urls` gives fake URLs, everything else follows `respond`.
struct StubExamHTTP: HTTPStreaming {
    let respond: @Sendable (_ kind: String, _ request: URLRequest) throws -> (Int, Data)

    func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        let kind = RecordingHTTP.kind(of: request)
        if kind == "upload_urls" {
            let json = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            let count = json?["count"] as? Int ?? 0
            let uploads = (0..<count).map { ["path": "stub/\($0).jpg", "url": "https://upload.invalid/stub/\($0).jpg"] }
            return Self.reply(200, try JSONSerialization.data(withJSONObject: ["uploads": uploads]), request)
        }
        let (status, body) = try respond(kind, request)
        return Self.reply(status, body, request)
    }

    static func reply(_ status: Int, _ body: Data, _ request: URLRequest) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url ?? URL(string: "https://stub.invalid")!, statusCode: status, httpVersion: nil,
                         headerFields: ["Content-Type": "application/json"])!, body)
    }

    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        throw URLError(.unsupportedURL)
    }

    func bytes(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, any Error>) {
        throw URLError(.unsupportedURL)
    }
}

@MainActor
@Suite(.serialized, .enabled(if: UploadEnvironment.enabled, "set LUMEN_E2E_UPLOAD (scripts/apptest/upload.sh)"))
struct UploadE2ETests {
    struct CaseResult: Codable {
        var name: String
        var photos: Int
        var photoBytes: Int
        var largestPhotoBytes: Int
        var largestPhotoPixels: Int
        var seconds: Double
        var ok: Bool
        var error: String?
        var userMessage: String?
        var questions: [String] = []
        var subject = ""
        var grade = ""
        var covers = ""
        var note: String?
        var requests: [RecordingHTTP.Entry] = []
    }

    // MARK: Live

    @Test func onePhoto() async throws { try await live(photos: 1) }
    @Test func fourPhotosGoInline() async throws { try await live(photos: 4) }
    @Test func tenPhotosAreUploaded() async throws { try await live(photos: 10) }
    @Test func thirtyPhotosWithin60Seconds() async throws {
        let result = try await live(photos: 30)
        #expect(result.seconds <= 60, "30 photos took \(result.seconds) s (mål ≤ 60 s)")
    }

    /// A 5G-like hiccup: the third photo's first PUT and the drill's first POST are dropped. Both are tried again,
    /// the questions come, and the user never sees an error.
    @Test func aDroppedPhotoAndADroppedDrillRecover() async throws {
        // The upload names come from the server, so the third PUT sent is the one dropped.
        let counter = PutCounter()
        let flaky = RecordingHTTP { kind, attempt in
            if kind == "drill", attempt == 1 { return URLError(.networkConnectionLost) }
            if kind.hasPrefix("put"), counter.next() == 3 { return URLError(.networkConnectionLost) }
            return nil
        }
        let result = try await live(photos: 10, http: flaky, name: "flaky-10")
        #expect(result.requests.contains { $0.outcome.contains("fault plan") && $0.kind == "drill" })
        #expect(result.requests.filter { $0.outcome.contains("fault plan") }.count == 2)
    }

    @discardableResult
    private func live(photos: Int, http: RecordingHTTP = RecordingHTTP(), name: String? = nil) async throws -> CaseResult {
        let pages = Self.pages(photos)
        let auth = SupabaseAuth(config: .lumen, store: InMemorySessionStore(), http: URLSessionHTTP())
        let client = DrillClient(config: .lumen, auth: auth, http: http)
        var result = CaseResult(name: name ?? "live-\(photos)", photos: photos, photoBytes: pages.reduce(0) { $0 + $1.count },
                                largestPhotoBytes: pages.map(\.count).max() ?? 0,
                                largestPhotoPixels: pages.compactMap { UIImage(data: $0) }.map { Int(max($0.size.width * $0.scale, $0.size.height * $0.scale)) }.max() ?? 0,
                                seconds: 0, ok: false)
        let started = Date()
        let outcome = await Self.attempt {
            try await client.make(DrillMaterial(pages: pages), subject: nil, grade: nil, correction: nil, questions: 20, longWords: 90)
        }
        result.seconds = (Date().timeIntervalSince(started) * 10).rounded() / 10
        result.requests = http.log
        switch outcome {
        case .success(let draft):
            result.ok = true
            result.questions = draft.items.map(\.question)
            result.subject = draft.summary.subject
            result.grade = draft.summary.grade
            result.covers = draft.summary.covers
            result.note = draft.note
        case .failure(let error):
            result.error = "\(error)"
            result.userMessage = error.userMessage
        }
        try Self.write(result)
        print("T20 \(result.name): \(result.ok ? "ok" : "failed") \(result.seconds) s, \(result.questions.count) questions, \(result.error ?? "")")

        #expect(result.ok, "\(result.name): \(result.error ?? "") – \(result.userMessage ?? "")")
        #expect(result.userMessage?.hasPrefix("Ingen internetanslutning") != true, "false offline with a network")
        #expect(result.questions.count >= 3, "\(result.questions.count) questions")
        #expect(result.largestPhotoPixels <= 1_600)
        let puts = result.requests.filter { $0.kind.hasPrefix("put") && $0.outcome == "HTTP 200" }.count
        if photos > DrillClient.inlinePages {
            #expect(puts == photos, "\(puts) of \(photos) photos uploaded")
            #expect(result.requests.contains { $0.kind == "upload_urls" })
        } else {
            #expect(puts == 0, "\(photos) photos should go inline")
        }
        return result
    }

    // MARK: Error paths with a stub (no model, no cost)

    /// Every PUT drops (twice each): "x av 10 bilder kom inte fram", never "Ingen internetanslutning".
    @Test func photosThatNeverArriveAreNotOffline() async throws {
        let http = RecordingHTTP(inner: StubExamHTTP { _, _ in (500, Data()) }) { kind, _ in
            kind.hasPrefix("put") ? URLError(.networkConnectionLost) : nil
        }
        let result = try await stubbed("puts-dropped", photos: 10, http: http)
        #expect(result.error == "\(DrillMakingError.refused("10 av 10 bilder kom inte fram. Försök igen."))")
        #expect(result.requests.filter { $0.kind.hasPrefix("put") }.count == 20, "each photo tried twice")
        #expect(!result.requests.contains { $0.kind == "drill" }, "no drill without the photos")
    }

    /// The drill keeps dropping (5G that gives up): one more try, then "Det gick inte att skapa frågorna. Försök igen."
    @Test func aDrillThatKeepsDroppingIsNotOffline() async throws {
        let http = RecordingHTTP(inner: StubExamHTTP { _, _ in throw URLError(.networkConnectionLost) })
        let result = try await stubbed("drill-dropped", photos: 2, http: http)
        #expect(result.userMessage == "Det gick inte att skapa frågorna. Försök igen.")
        #expect(result.requests.filter { $0.kind == "drill" }.count == 2, "one more try")
    }

    @Test func aDrillThatTimesOutIsNotOffline() async throws {
        let http = RecordingHTTP(inner: StubExamHTTP { _, _ in throw URLError(.timedOut) })
        let result = try await stubbed("drill-timeout", photos: 2, http: http)
        #expect(result.userMessage == "Det gick inte att skapa frågorna. Försök igen.")
    }

    /// K53's 422 `material_missing` reaches the user as the server wrote it.
    @Test func aMissingPhotoIsSaidAsTheServerSaysIt() async throws {
        let body = Data(#"{"error":{"code":"material_missing","message":"2 av 10 bilder kom inte fram. Ladda upp dem igen."}}"#.utf8)
        let http = RecordingHTTP(inner: StubExamHTTP { kind, _ in kind == "drill" ? (422, body) : (500, Data()) },
                                 fault: { _, _ in nil })
        let stub = PutsSucceed(inner: http)
        let result = try await stubbed("material-missing", photos: 10, http: http, transport: stub)
        #expect(result.userMessage == "2 av 10 bilder kom inte fram. Ladda upp dem igen.")
    }

    /// The only true "offline": iOS says there is no internet.
    @Test func noInternetIsOffline() async throws {
        let http = RecordingHTTP(inner: StubExamHTTP { _, _ in throw URLError(.notConnectedToInternet) })
        let result = try await stubbed("no-internet", photos: 2, http: http)
        #expect(result.userMessage?.hasPrefix("Ingen internetanslutning") == true)
    }

    private func stubbed(_ name: String, photos: Int, http: RecordingHTTP, transport: (any HTTPStreaming)? = nil) async throws -> CaseResult {
        let pages = Self.pages(photos)
        let auth = SupabaseAuth(config: .lumen, store: InMemorySessionStore(), http: URLSessionHTTP())
        let client = DrillClient(config: .lumen, auth: auth, http: transport ?? http)
        var result = CaseResult(name: name, photos: photos, photoBytes: pages.reduce(0) { $0 + $1.count },
                                largestPhotoBytes: pages.map(\.count).max() ?? 0, largestPhotoPixels: 0, seconds: 0, ok: false)
        let started = Date()
        let outcome = await Self.attempt {
            try await client.make(DrillMaterial(pages: pages), subject: nil, grade: nil, correction: nil, questions: 20, longWords: 90)
        }
        result.seconds = (Date().timeIntervalSince(started) * 10).rounded() / 10
        result.requests = http.log
        switch outcome {
        case .success(let draft): result.ok = true; result.questions = draft.items.map(\.question)
        case .failure(let error): result.error = "\(error)"; result.userMessage = error.userMessage
        }
        try Self.write(result)
        print("T20 \(name): \(result.error ?? "ok") → \(result.userMessage ?? "")")
        #expect(!result.ok, "\(name) should fail")
        return result
    }

    // MARK: Helpers

    static func attempt(_ body: () async throws(DrillMakingError) -> DrillDraft) async -> Result<DrillDraft, DrillMakingError> {
        do {
            return .success(try await body())
        } catch {
            return .failure(error)
        }
    }

    static func write(_ result: CaseResult) throws {
        let out = UploadEnvironment.out
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(result).write(to: out.appendingPathComponent("upload-\(result.name).json"))
    }

    /// The first `count` pages, each a camera photo (4 032 × 3 024 px, drawn at 3×) scaled by the app.
    static func pages(_ count: Int) -> [Data] {
        (0..<count).compactMap { index in
            ExamMaterials.jpeg(photo(page: index + 1, of: count, text: UploadPages.text[index % UploadPages.text.count]))
        }
    }

    static func photo(page: Int, of total: Int, text: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let size = CGSize(width: 1_008, height: 1_344)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // A slight shadow across the page, as in a photo taken under a lamp.
            UIColor(white: 0, alpha: 0.05).setFill()
            context.fill(CGRect(x: size.width * 0.6, y: 0, width: size.width * 0.4, height: size.height))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 10
            let title: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 40), .foregroundColor: UIColor.black]
            let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34),
                                                       .foregroundColor: UIColor(white: 0.12, alpha: 1), .paragraphStyle: style]
            ("Biologi åk 8 · Kroppen och ekologin · sida \(page) av \(total)" as NSString)
                .draw(in: CGRect(x: 70, y: 70, width: size.width - 140, height: 120), withAttributes: title)
            (text as NSString).draw(in: CGRect(x: 70, y: 220, width: size.width - 140, height: size.height - 290), withAttributes: body)
        }
    }
}

/// Counts PUTs across the parallel uploads.
final class PutCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}

/// Every PUT succeeds without a network (the stub's fake URLs), everything else goes to `inner`.
struct PutsSucceed: HTTPStreaming {
    let inner: RecordingHTTP

    func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        if request.httpMethod == "PUT" { return StubExamHTTP.reply(200, Data(), request) }
        return try await inner.data(for: request)
    }

    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, any Error>) {
        try await inner.lines(for: request)
    }

    func bytes(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<Data, any Error>) {
        try await inner.bytes(for: request)
    }
}
