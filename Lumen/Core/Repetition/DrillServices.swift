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

enum DrillMakingError: Error, Equatable {
    case noMaterial
    /// No network (Ke50 §13: "Ingen internetanslutning …"), only when the phone has none (A85).
    case offline
    /// The server said no with a message for the user (a page too big, the rate limit …).
    case refused(String)
    /// The server did not answer as K45 says (not deployed yet, offline, an error).
    case server(String)
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
}

@MainActor
final class DrillClient: DrillMaking {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    private struct Reply: Decodable {
        struct Summary: Decodable { var subject: String?; var grade: String?; var covers: String? }
        struct Item: Decodable { var id: String?; var question: String; var short: String?; var long: String? }
        var summary: Summary?
        var notes: String?
        var items: [Item]?
        var item: Item?
        var text: String?
        var note: String?
        struct Upload: Decodable { var path: String; var url: String }
        var uploads: [Upload]?
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
            throw .refused("\(missing) av \(count) bilder kom inte fram. Försök igen.")
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
            return DrillItem(question: item.question, short: short, long: DrillItem.long(item.long ?? "", startingWith: short))
        }
        guard !items.isEmpty else { throw .server("no questions") }
        let note = reply.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DrillDraft(summary: summary, items: items, notes: reply.notes ?? "", note: note?.isEmpty == false ? note : nil)
    }

    func answers(for items: [DrillItem], summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> [DrillItem] {
        let missing = items.filter { $0.short.isEmpty }
        guard !missing.isEmpty else { return items }
        let body: [String: Any] = ["action": "drill_answers", "subject": summary.subject, "grade": summary.grade,
                                   "notes": String(notes.prefix(12_000)), "long_words": min(max(longWords, 40), 200),
                                   "items": missing.map { ["id": $0.id.uuidString, "question": $0.question] }]
        let reply = try await call(body, timeout: 150)
        var byID: [String: Reply.Item] = [:]
        for item in reply.items ?? [] { if let id = item.id { byID[id] = item } }
        let filled = items.map { item -> DrillItem in
            guard item.short.isEmpty, let made = byID[item.id.uuidString], let short = made.short, !short.isEmpty else { return item }
            var item = item
            item.short = short
            item.long = DrillItem.long(made.long ?? "", startingWith: short)
            return item
        }
        guard filled.contains(where: { !$0.short.isEmpty }) else { throw .server("no answers") }
        return filled
    }

    func answer(_ question: String, summary: DrillSummary, notes: String, longWords: Int) async throws(DrillMakingError) -> DrillItem {
        let body: [String: Any] = ["action": "drill_one", "question": question, "subject": summary.subject,
                                   "grade": summary.grade, "notes": String(notes.prefix(12_000)), "long_words": min(max(longWords, 40), 200)]
        let reply = try await call(body, timeout: 60)
        guard let item = reply.item else { throw .server("no item") }
        let short = item.short ?? ""
        return DrillItem(question: item.question.isEmpty ? question : item.question, short: short,
                         long: DrillItem.long(item.long ?? "", startingWith: short))
    }

    func documentText(docx: Data) async throws(DrillMakingError) -> String {
        // K45 drill.ts: {"action":"doc_text", "data": "<base64 .docx>"}
        let reply = try await call(["action": "doc_text", "data": docx.base64EncodedString()], timeout: 60)
        guard let text = reply.text, !text.isEmpty else { throw .server("no text") }
        return text
    }

    /// A85: the real cause is logged (status or URLError code, bytes sent, time, network), a dropped connection is tried
    /// once more, and "offline" is said only when the phone has no network at all.
    private func call(_ body: [String: Any], timeout: TimeInterval) async throws(DrillMakingError) -> Reply {
        let action = body["action"] as? String ?? ""
        let payload: Data
        do {
            payload = try JSONSerialization.data(withJSONObject: body)
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
        }
        if (400..<500).contains(status), status != 401,
           let message = (try? JSONDecoder().decode(Body.self, from: data))?.error?.message, !message.isEmpty {
            return .refused(message)
        }
        return .server("HTTP \(status)")
    }
}

extension DrillMakingError {
    /// Kelly Ke50 §2, §13.
    var userMessage: String {
        switch self {
        case .noMaterial: "Lägg till material först."
        case .offline: "Ingen internetanslutning. Frågorna görs när du är uppkopplad igen."
        case .server(let why) where why == "no questions":
            "Earmind hittade för lite att göra frågor av. Lägg till fler sidor eller mer text."
        case .refused(let message): message
        case .server: "Det gick inte att skapa frågorna. Försök igen." // A85
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
            .trimmingCharacters(in: .whitespaces) ?? "Materialet"
        let bank: [(String, String, String)] = [
            ("Varför behövs klorofyll?", "Klorofyll fångar solljuset som växten behöver för fotosyntesen.",
             "Utan ljusenergin kan växten inte bygga socker av koldioxid och vatten, så klorofyllet är startpunkten för hela näringskedjan."),
            ("Vad bildas vid fotosyntesen?", "Socker och syre bildas av koldioxid och vatten med hjälp av ljus.",
             "Sockret ger växten energi och byggmaterial, och syret släpps ut och används av djur och människor i cellandningen."),
            ("Hur hänger fotosyntes och cellandning ihop?", "Fotosyntesen bygger socker och cellandningen bryter ner det igen.",
             "Det ena processens produkter är den andras råvaror, så kol och syre går i ett kretslopp mellan växter och djur."),
        ]
        let count = max(1, min(questions, 60))
        let items = (0..<count).map { i in
            let (q, s, rest) = bank[i % bank.count]
            return DrillItem(question: count > bank.count ? "\(q) (\(i + 1))" : q, short: s, long: s + " " + rest)
        }
        return DrillDraft(summary: DrillSummary(subject: subject ?? "Biologi", grade: grade ?? "åk 8",
                                                covers: "Exempel (testläge): \(topic)."),
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
        let short = "Ett kort svar på \(question.lowercased())"
        return DrillItem(question: question, short: short + ".", long: short + ". Och ett längre svar med förklaring och exempel.")
    }

    func documentText(docx: Data) async throws(DrillMakingError) -> String {
        throw .server("Word-filer läses av servern (K45 doc_text)")
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

    private func write() {
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
        drill.items.flatMap { [$0.question, $0.short, $0.long] }
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
