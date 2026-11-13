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
}

enum DrillMakingError: Error, Equatable {
    case noMaterial
    /// No network (Ke50 §13: "Ingen internetanslutning …").
    case offline
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
    }

    func make(_ material: DrillMaterial, subject: String?, grade: String?, correction: String?,
              questions: Int, longWords: Int) async throws(DrillMakingError) -> DrillDraft {
        guard !material.isEmpty else { throw .noMaterial }
        // Step 1 only (Haiku: summary, notes, questions); the answers come with `answers(for:)` (K45 "answers": false).
        var body: [String: Any] = ["action": "drill", "questions": min(max(questions, 3), 60),
                                   "long_words": min(max(longWords, 40), 200), "answers": false]
        if !material.pages.isEmpty {
            body["pages"] = material.pages.prefix(20).map { ["media_type": "image/jpeg", "data": $0.base64EncodedString()] }
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
        return DrillDraft(summary: summary, items: items, notes: reply.notes ?? "")
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

    private func call(_ body: [String: Any], timeout: TimeInterval) async throws(DrillMakingError) -> Reply {
        let action = body["action"] as? String ?? ""
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
                Log.repetition.error("exam \(action, privacy: .public): HTTP \(response.statusCode, privacy: .public)")
                throw DrillMakingError.server("HTTP \(response.statusCode)")
            }
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch let error as DrillMakingError {
            throw error
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(error.code) {
            throw .offline
        } catch {
            throw .server(error.localizedDescription)
        }
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
        case .server: "Earmind kunde inte göra frågor just nu. Försök igen om en stund."
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

    func problem(for drill: Drill) -> String? { nil }

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
