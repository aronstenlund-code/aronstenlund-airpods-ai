import Foundation
import Observation

// MARK: - K46/K47: `POST /drill`

/// What `/drill` answers for "save", "get", "status" and "import" (K46, `backend/supabase/functions/drill/handler.ts`).
struct DrillCloudView: Decodable, Sendable, Equatable {
    struct Info: Decodable, Sendable, Equatable {
        var id: String
        var title: String?
        var subject: String?
        var grade: String?
        var covers: String?
        var long_words: Int?
        var shared_from: String?
        var voice_model: String? = nil
        /// K70 (D185): "questions" or "text" (Läsläget); nil from a server before K70.
        var kind: String? = nil
        /// K71 (D190, D191): false until `start`; nil from a server before K71 (always started then).
        var audio_started: Bool? = nil
    }

    struct File: Decodable, Sendable, Equatable {
        /// "pending", "working", "done", "failed" or "missing".
        var status: String
        /// Signed for one hour; only for done files.
        var url: String?
        var duration_ms: Int?
        /// D145: the long file up to here is the short answer.
        var short_end_ms: Int?
        /// K62: why a file failed (the voice service's credits ran out: `audio_unavailable`).
        var error: String? = nil
        /// K70 (D185): a text part's file: [start_ms, end_ms] per sentence, in the order of the item's `sentences`.
        var sentences: [[Int]]? = nil

        var isDone: Bool { status == "done" && url != nil }
        var isFailed: Bool { status == "failed" }
        /// The cache name: the last part of the storage path, `<hash>.mp3`.
        var fileName: String? {
            guard let url, let parsed = URL(string: url) else { return nil }
            let name = parsed.lastPathComponent
            return name.hasSuffix(".mp3") ? name : nil
        }
    }

    struct Item: Decodable, Sendable, Equatable {
        struct Audio: Decodable, Sendable, Equatable {
            var question: File
            var long: File
            /// K70 (D185): a text part has one file, `text`, and no question or long file.
            var text: File? = nil
        }

        var id: String
        var position: Int
        var question: String
        var short: String
        var long: String
        var audio: Audio
        /// K61 (D176): the question and the long answer, in characters to ElevenLabs, and its class.
        var voice_chars: Int?
        var length_class: String?
        /// K66 point 4 (A102): the shown text, as it was saved.
        var screen: DrillScreenText?
        /// K70 (D185): a text's part ("heading" or "para"), its text (also in `long`) and its displayed sentences.
        var part: String? = nil
        var sentences: [String]? = nil

        enum CodingKeys: String, CodingKey {
            case id, position, question, short, long, audio, voice_chars, length_class, screen, part, text, sentences
        }
    }

    struct Totals: Decodable, Sendable, Equatable {
        var done: Int
        var total: Int
        var failed: Int?
    }

    struct Cue: Decodable, Sendable, Equatable {
        var press_for_answer: File?
    }

    var drill: Info
    var items: [Item]
    var audio: Totals
    /// K51: fixed lines in the exam's voice, free and outside the progress.
    var cue: Cue? = nil
    /// K78 (D200): the voice service's credits are out. The questions and answers are here as text, nothing was queued
    /// or counted, and the sound is made the next time it is asked for with credits back. Not an error (HTTP 200).
    var audio_unavailable: Bool? = nil
    /// K78: questions that had been counted for sound that was never made, given back once.
    var refunded_questions: Int? = nil
}

extension DrillCloudView.Item {
    /// K70 (D185): a text part has `part`, `text` and `sentences` instead of a question and answers; its text is kept
    /// in `long`, where the server keeps it too.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        position = try c.decode(Int.self, forKey: .position)
        part = try c.decodeIfPresent(String.self, forKey: .part)
        let text = try c.decodeIfPresent(String.self, forKey: .text)
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        short = try c.decodeIfPresent(String.self, forKey: .short) ?? ""
        long = try c.decodeIfPresent(String.self, forKey: .long) ?? text ?? ""
        audio = try c.decode(Audio.self, forKey: .audio)
        voice_chars = try c.decodeIfPresent(Int.self, forKey: .voice_chars)
        length_class = try c.decodeIfPresent(String.self, forKey: .length_class)
        screen = try c.decodeIfPresent(DrillScreenText.self, forKey: .screen)
        sentences = try c.decodeIfPresent([String].self, forKey: .sentences)
    }

    var isTextPart: Bool { part != nil }
}

extension DrillCloudView.Item.Audio {
    enum CodingKeys: String, CodingKey { case question, long, text }

    /// K70: a text part's audio is only `{"text": {…}}`; its question and long file read as missing.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let missing = DrillCloudView.File(status: "missing", url: nil, duration_ms: nil, short_end_ms: nil)
        text = try c.decodeIfPresent(DrillCloudView.File.self, forKey: .text)
        question = try c.decodeIfPresent(DrillCloudView.File.self, forKey: .question) ?? missing
        long = try c.decodeIfPresent(DrillCloudView.File.self, forKey: .long) ?? missing
    }

    /// The files the item has: the question and the long answer, or a text part's one file.
    var files: [DrillCloudView.File] { text.map { [$0] } ?? [question, long] }
}

/// D155: generated questions this calendar month (`list` → `quota`).
struct DrillQuota: Decodable, Sendable, Equatable {
    var used: Int
    var limit: Int
    var per: String?
    var resets: String?
    /// K61 (D175): what is left, and what Nytt prov should propose (min(left, 20)), from `/drill quota`.
    var serverLeft: Int?
    var suggest: Int?
    /// K82 (D205): what costs what, from the server's table (never hard-coded in the app).
    var prices: DrillPrices? = nil

    enum CodingKeys: String, CodingKey {
        case used, limit, per, resets, suggest, prices
        case serverLeft = "left"
    }

    init(used: Int, limit: Int, per: String? = nil, resets: String? = nil, serverLeft: Int? = nil, suggest: Int? = nil) {
        self.used = used
        self.limit = limit
        self.per = per
        self.resets = resets
        self.serverLeft = serverLeft
        self.suggest = suggest
    }

    var left: Int { max(0, serverLeft ?? (limit - used)) }

    /// D175: Nytt prov proposes at most what is left, never more than 20 (D146); at least 1 while any is left.
    var suggestedQuestions: Int {
        min(Drill.defaultQuestionCount, max(0, suggest ?? left))
    }

    /// D175: nothing left this month, said before the exam is made (not as a 402 afterwards).
    var isUsedUp: Bool { left == 0 }
    /// "x av 15 frågor kvar den här månaden".
    var line: String { "\(left) av \(limit) frågor kvar den här månaden" }
}

/// K82 (D205): the price table in `/drill quota`. Today every question with new sound counts as 1 (`questions`);
/// `tokens` is what D176 charges once payment is built.
struct DrillPrices: Decodable, Sendable, Equatable {
    struct Class: Decodable, Sendable, Equatable {
        var name: String
        var min_chars: Int?
        var max_chars: Int?
        var questions: Double
        var tokens: Int?

        enum CodingKeys: String, CodingKey {
            case name = "class"
            case min_chars, max_chars, questions, tokens
        }
    }

    struct Read: Decodable, Sendable, Equatable { var chars_per_question: Int }

    var classes: [Class]
    var read: Read?
    var free: [String]?
}

struct DrillCloudListEntry: Decodable, Sendable, Equatable {
    var id: String
    var title: String?
    var items: Int?
    var updated_at: String?
}

struct DrillShareLink: Decodable, Sendable, Equatable {
    var code: String
    /// `https://earmind.ai/p/<code>` (universal links are not set up yet).
    var url: String?
    /// `earmind://prov/<code>`.
    var app_url: String?
}

enum DrillCloudError: Error, Equatable {
    /// The server said no with a message for the user (rate limit, not found, too many exams, audio not ready).
    case refused(status: Int, code: String, message: String)
    case offline(String)

    /// The server's code ("rate_limited", "share_not_found" …), for the log.
    var errorCode: String {
        switch self {
        case .refused(_, let code, _): code
        case .offline: "offline"
        }
    }

    var userMessage: String {
        switch self {
        case .refused(_, _, let message): message
        case .offline:
            // A103: without a network, say so plainly (and that downloaded exams still play).
            NetworkStatus.shared.isOnline ? "Ingen kontakt med EarMind just nu. Försök igen om en stund."
                : NetworkStatus.noNetworkLine
        }
    }
}

@MainActor
protocol DrillCloudSyncing: AnyObject, Sendable {
    func save(_ drill: Drill) async throws(DrillCloudError) -> DrillCloudView
    func status(id: String) async throws(DrillCloudError) -> DrillCloudView
    func list() async throws(DrillCloudError) -> [DrillCloudListEntry]
    func delete(id: String) async throws(DrillCloudError)
    func share(id: String) async throws(DrillCloudError) -> DrillShareLink
    func importShared(code: String) async throws(DrillCloudError) -> DrillCloudView
    func download(_ url: URL) async throws(DrillCloudError) -> Data
    /// Toby 2 T24: the account the list belongs to (nil when unknown).
    func accountID() async -> String?
    /// K71 (D190): Starta prov: the server makes every missing file in play order and counts the month's quota now.
    func start(id: String) async throws(DrillCloudError) -> DrillCloudView
}

extension DrillCloudSyncing {
    func accountID() async -> String? { nil }
    /// Mocks written before K71: a started exam is what `status` says.
    func start(id: String) async throws(DrillCloudError) -> DrillCloudView { try await status(id: id) }
}

@MainActor
final class DrillCloudClient: DrillCloudSyncing {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    func accountID() async -> String? { auth.userID }

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    /// The body "save" sends: order = play order, server ids kept so rows stay (K46).
    static func saveBody(_ drill: Drill) -> [String: Any] {
        var info: [String: Any] = ["title": drill.title, "subject": drill.summary.subject, "grade": drill.summary.grade,
                                   "covers": String(drill.summary.covers.prefix(400)), "long_words": drill.longWords]
        if let id = drill.serverID { info["id"] = id }
        if drill.serverID == nil, let voice = drill.voiceModel { info["voice_model"] = voice } // K50: locked after
        // A107 (D190, K71): saving never makes sound; Starta prov does. After the start the server makes only the
        // changed files (D144), with or without the flag.
        if drill.isText {
            // K70 (D185): a text is saved as its parts in order; the kind is locked at the first save.
            info["kind"] = DrillKind.text.rawValue
            let parts: [[String: Any]] = drill.items.map { item in
                var row: [String: Any] = ["kind": (item.part ?? .para).rawValue, "text": item.long]
                if let id = item.serverID { row["id"] = id }
                return row
            }
            return ["action": "save", "drill": info, "items": parts, "defer_audio": true]
        }
        let items: [[String: Any]] = drill.items.map { item in
            var row: [String: Any] = ["question": item.question, "short": item.short, "long": item.long]
            if let id = item.serverID { row["id"] = id }
            // A102 (K66 point 4): only the fields that differ; a field the user changed has none (`DrillItem.edited`).
            if let screen = item.screen, !screen.isEmpty {
                var shown: [String: String] = [:]
                if let q = screen.question { shown["question"] = q }
                if let s = screen.short { shown["short"] = s }
                if let l = screen.long { shown["long"] = l }
                row["screen"] = shown
            }
            return row
        }
        return ["action": "save", "drill": info, "items": items, "defer_audio": true]
    }

    func save(_ drill: Drill) async throws(DrillCloudError) -> DrillCloudView {
        try await call(Self.saveBody(drill), timeout: 30)
    }

    func status(id: String) async throws(DrillCloudError) -> DrillCloudView {
        try await call(["action": "status", "id": id], timeout: 20)
    }

    /// K71: `{"action":"start","id"}` → the drill as `get` gives it (402 `quota_exceeded` as for save).
    func start(id: String) async throws(DrillCloudError) -> DrillCloudView {
        try await call(["action": "start", "id": id], timeout: 30)
    }

    func list() async throws(DrillCloudError) -> [DrillCloudListEntry] {
        struct Reply: Decodable { var drills: [DrillCloudListEntry]; var quota: DrillQuota? }
        let reply: Reply = try await call(["action": "list"], timeout: 20)
        lastQuota = reply.quota
        return reply.drills
    }

    /// K61 (D175): `/drill quota` → used, limit, left, suggest.
    @discardableResult
    func quota() async throws(DrillCloudError) -> DrillQuota {
        let quota: DrillQuota = try await call(["action": "quota"], timeout: 15)
        lastQuota = quota
        return quota
    }

    /// A84 (D155): the month's limit from the last `list`.
    private(set) var lastQuota: DrillQuota?

    func delete(id: String) async throws(DrillCloudError) {
        struct Reply: Decodable { var deleted: Bool? }
        let _: Reply = try await call(["action": "delete", "id": id], timeout: 20)
    }

    func share(id: String) async throws(DrillCloudError) -> DrillShareLink {
        try await call(["action": "share", "id": id], timeout: 20)
    }

    func importShared(code: String) async throws(DrillCloudError) -> DrillCloudView {
        try await call(["action": "import", "code": code], timeout: 30)
    }

    func download(_ url: URL) async throws(DrillCloudError) -> Data {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 60
            let (response, data) = try await http.data(for: request)
            guard response.statusCode == 200, !data.isEmpty else {
                throw DrillCloudError.refused(status: response.statusCode, code: "download", message: "Ljudet gick inte att hämta.")
            }
            return data
        } catch let error as DrillCloudError {
            throw error
        } catch {
            throw .offline(error.localizedDescription)
        }
    }

    func call<Reply: Decodable>(_ body: [String: Any], timeout: TimeInterval) async throws(DrillCloudError) -> Reply {
        let action = body["action"] as? String ?? ""
        let response: HTTPURLResponse
        let data: Data
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: config.projectURL.appending(path: "functions/v1/drill"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = timeout
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            (response, data) = try await http.data(for: request)
        } catch {
            Log.repetition.error("drill \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw .offline(error.localizedDescription)
        }
        guard response.statusCode == 200 else {
            let refusal = Self.refusal(status: response.statusCode, data: data)
            Log.repetition.error("drill \(action, privacy: .public): HTTP \(response.statusCode, privacy: .public) \(refusal.errorCode, privacy: .public)")
            throw refusal
        }
        do {
            return try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            Log.repetition.error("drill \(action, privacy: .public): bad reply \(error.localizedDescription, privacy: .public)")
            throw .offline("bad reply")
        }
    }

    /// `{"error": {"code", "message"}}` (backend `errorBody`); the message is Swedish and meant for the user.
    static func refusal(status: Int, data: Data) -> DrillCloudError {
        struct Body: Decodable {
            struct Inner: Decodable { var code: String?; var message: String? }
            var error: Inner?
        }
        let inner = (try? JSONDecoder().decode(Body.self, from: data))?.error
        let fallback = status == 404 ? "Provet finns inte." : "EarMind kunde inte spara just nu. Försök igen om en stund."
        return .refused(status: status, code: inner?.code ?? "http_\(status)", message: inner?.message ?? fallback)
    }
}

// MARK: - The view → the phone's exam

extension Drill {
    /// An exam from the server (another phone, a shared link), or the server's answer merged into the phone's copy.
    /// Items whose texts are unchanged keep their downloaded sound.
    static func from(_ view: DrillCloudView, merging local: Drill? = nil) -> Drill {
        let items = view.items.sorted { $0.position < $1.position }.enumerated().map { offset, remote in
            var item = DrillItem(question: remote.question, short: remote.short, long: remote.long, serverID: remote.id)
            item.part = remote.part.flatMap(DrillPart.init(rawValue:)) ?? (remote.isTextPart ? .para : nil) // K70
            item.sentences = remote.sentences
            item.lengthClass = remote.length_class.flatMap(DrillLengthClass.init(rawValue:)) // K61 (D176)
            item.screen = remote.screen.flatMap { $0.isEmpty ? nil : $0 } // A102
            if let local, local.items.indices.contains(offset) {
                let mine = local.items[offset]
                item.id = mine.id
                if mine.sameText(as: item) {
                    item.questionAudio = mine.questionAudio
                    item.longAudio = mine.longAudio
                    item.shortEndMs = mine.shortEndMs
                    item.sentenceTimesMs = mine.sentenceTimesMs
                }
            }
            return item
        }
        var drill = local ?? Drill(title: "", summary: DrillSummary(subject: "", grade: "", covers: ""), items: [])
        drill.serverID = view.drill.id
        if let title = view.drill.title, !title.isEmpty { drill.title = title }
        if drill.title.isEmpty { drill.title = "Prov" }
        drill.summary = DrillSummary(subject: view.drill.subject ?? drill.summary.subject,
                                     grade: view.drill.grade ?? drill.summary.grade,
                                     covers: view.drill.covers ?? drill.summary.covers)
        if let words = view.drill.long_words { drill.longWords = words }
        if let voice = view.drill.voice_model { drill.voiceModel = voice }
        if let started = view.drill.audio_started { drill.audioStarted = started ? nil : false } // A107 (K71)
        if let kind = view.drill.kind.flatMap(DrillKind.init(rawValue:)) {
            drill.kind = kind == .text ? .text : nil // K70; nil stays "questions" for old copies
        } else if items.contains(where: { $0.part != nil }) {
            drill.kind = .text
        }
        drill.items = items
        drill.questionCount = items.count
        return drill
    }
}

// MARK: - K46: the sound from the server

/// K46 (D143, D145): the server makes every file with ElevenLabs when the exam is saved, in play order; the phone
/// downloads them as they are done and keeps them (`Application Support/drill_audio/<hash>.mp3`). A repetition and a
/// shared copy cost 0 characters. The short answer is the long file up to `short_end_ms`.
@MainActor
@Observable
final class CloudDrillAudio: DrillAudioProviding {
    /// Bumped as files arrive, so the views that show the progress follow it.
    private(set) var made = 0
    private(set) var preparing: Set<UUID> = []
    /// The last thing that went wrong per exam, for the exam's screen ("Du har gjort mycket ljud i dag …").
    private(set) var problems: [UUID: String] = [:]
    private(set) var failedFiles: [UUID: Int] = [:]
    /// A84 (D155): exams whose save hit the month's limit (402 `quota_exceeded`).
    private(set) var quotaExceeded: Set<UUID> = []

    @ObservationIgnored private let cloud: any DrillCloudSyncing
    @ObservationIgnored private let store: DrillStore
    @ObservationIgnored private let folder: URL
    @ObservationIgnored private let pollInterval: Duration
    @ObservationIgnored private let maxPolls: Int

    init(cloud: any DrillCloudSyncing, store: DrillStore, folder: URL? = nil,
         pollInterval: Duration = .seconds(3), maxPolls: Int = 400) {
        self.cloud = cloud
        self.store = store
        let base = folder ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                          appropriateFor: nil, create: true))?
            .appendingPathComponent("drill_audio", isDirectory: true) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // A103 (D186): Application Support, never Caches, so iOS does not empty it and an exam plays on the underground
        // after a restart. Kept out of the iCloud backup: the server can always send the files again.
        var folderURL = base
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folderURL.setResourceValues(values)
        self.folder = base
        self.pollInterval = pollInterval
        self.maxPolls = maxPolls
        removeUnused()
    }

    /// A103 (D186): the limit is the exams themselves. Files no saved exam uses (a deleted exam, a changed text) are
    /// removed at launch; every file an exam here uses stays, however long since it was played.
    @discardableResult
    func removeUnused() -> Int {
        // Only sound files, and never in the temporary folder (the fallback when Application Support is missing).
        guard folder.standardizedFileURL != FileManager.default.temporaryDirectory.standardizedFileURL,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return 0 }
        let used = Self.usedFiles(store.drills)
        let sound: Set<String> = ["mp3", "m4a", "aac", "wav", "caf"]
        var removed = 0
        for name in names where !used.contains(name) && sound.contains((name as NSString).pathExtension.lowercased()) {
            if (try? FileManager.default.removeItem(at: fileURL(name))) != nil { removed += 1 }
        }
        if removed > 0 { Log.repetition.info("Drill audio: \(removed, privacy: .public) unused files removed") }
        return removed
    }

    nonisolated static func usedFiles(_ drills: [Drill]) -> Set<String> {
        var used = Set<String>()
        for drill in drills {
            if let cue = drill.cueAudio { used.insert(cue) }
            for item in drill.items {
                if let q = item.questionAudio { used.insert(q) }
                if let l = item.longAudio { used.insert(l) }
            }
        }
        return used
    }

    /// A103: a file could not be written (the phone is full).
    static let noSpaceLine = "Telefonen har inte plats för ljudet. Frigör lite lagring, så laddas resten ner."
    /// Toby 2 T24 L6: the server has made nothing for a while (`slowAfter`) and the first question has no sound yet.
    static let slowLine = "Ljudet dröjer. Provet kan starta när första frågan är klar."
    /// T24 L6: how long without a new file before `slowLine` is said (shorter in the tests).
    @ObservationIgnored var slowAfter: Duration = .seconds(20)
    /// A103: no network while the sound is fetched; it goes on by itself when the phone is online again.
    static let waitingForNetworkLine = "Ingen internetanslutning. Resten av ljudet laddas ner när du är uppkopplad igen."
    /// How long `prepare` waits for the network to come back (A103), checked every `networkCheck`.
    private let networkWait: Duration = .seconds(30 * 60)
    private let networkCheck: Duration = .seconds(10)
    @ObservationIgnored private var noSpace: Set<UUID> = []

    func fileURL(_ name: String) -> URL { folder.appendingPathComponent(name) }

    private func exists(_ name: String?) -> Bool {
        guard let name else { return false }
        return FileManager.default.fileExists(atPath: fileURL(name).path)
    }

    func progress(for drill: Drill) -> (ready: Int, total: Int) {
        _ = made
        let ready = drill.items.reduce(0) { $0 + (exists($1.questionAudio) ? 1 : 0) + (exists($1.longAudio) ? 1 : 0) }
        return (ready, drill.audioFileCount)
    }

    func track(for drill: Drill, at index: Int) -> RepetitionTrack? {
        _ = made
        guard drill.items.indices.contains(index) else { return nil }
        let item = drill.items[index]
        guard let q = item.questionAudio, let l = item.longAudio, exists(q), exists(l) else { return nil }
        let short: RepetitionTrack.Short = item.shortEndMs.map { .prefix(ofLongUntil: Double($0) / 1000) }
            ?? .prefix(ofLongUntil: .infinity)
        return RepetitionTrack(question: fileURL(q), long: fileURL(l), short: short)
    }

    func tracks(for drill: Drill) -> [RepetitionTrack]? {
        let all = drill.items.indices.compactMap { track(for: drill, at: $0) }
        return all.count == drill.items.count && !all.isEmpty ? all : nil
    }

    func problem(for drill: Drill) -> String? { problems[drill.id] }

    /// K62 (Kelly): the voice service cannot make sound now (its credits ran out), said instead of a counter that
    /// never moves.
    /// A112 (D200): the calm line. The text works as usual, nothing is counted, and nothing is an error.
    static let unavailableLine = "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt."

    /// A112 (K78): how many times the server gave questions back; the model reads the month's quota again then.
    private(set) var refunds = 0

    /// A112 (D200): reading aloud is off for this exam for now (the views show the text and the calm line).
    func isReadingAloudOff(_ drill: Drill) -> Bool { problems[drill.id] == Self.unavailableLine }
    /// The codes that mean the sound cannot be made now (K62; the app accepts these until Kevin's code is final).
    static let unavailableCodes: Set<String> = ["audio_unavailable", "tts_unavailable", "voice_unavailable",
                                                "tts_quota_exceeded", "voice_quota_exceeded"]

    static func isUnavailable(_ code: String?) -> Bool {
        guard let code else { return false }
        return unavailableCodes.contains(code)
    }

    /// Sends what changed, then follows the server's queue and downloads every done file. Safe to call again.
    func prepare(_ drill: Drill) async {
        guard !preparing.contains(drill.id) else { return }
        preparing.insert(drill.id)
        defer { preparing.remove(drill.id) }
        problems[drill.id] = nil
        var polls = 0
        // T24 L6: polls in a row that brought no new file.
        var stillPolls = 0
        var lastReady = -1
        let slowPolls = max(1, Int((slowAfter / pollInterval).rounded(.up)))
        while polls < maxPolls, !Task.isCancelled {
            guard let current = store.drill(drill.id) else { return } // deleted meanwhile
            let view: DrillCloudView
            do throws(DrillCloudError) {
                if current.serverID == nil || current.needsUpload == true {
                    view = try await cloud.save(current)
                    Log.repetition.info("Drill saved: \(view.items.count, privacy: .public) items, audio \(view.audio.done, privacy: .public)/\(view.audio.total, privacy: .public)")
                } else if let id = current.serverID {
                    view = try await cloud.status(id: id)
                } else {
                    return
                }
            } catch {
                if case .offline = error, !NetworkStatus.shared.isOnline {
                    // A103: on the underground. Say it, then go on by itself when the network is back.
                    problems[drill.id] = Self.waitingForNetworkLine
                    var waited: Duration = .zero
                    while !NetworkStatus.shared.isOnline, waited < networkWait, !Task.isCancelled {
                        try? await Task.sleep(for: networkCheck)
                        waited += networkCheck
                    }
                    guard NetworkStatus.shared.isOnline, !Task.isCancelled else { return }
                    problems[drill.id] = nil
                    polls += 1
                    continue
                }
                if case .refused(_, let code, _) = error, code == "quota_exceeded" {
                    quotaExceeded.insert(drill.id) // A84: the way to others' exams is shown
                }
                if case .refused(let status, let code, _) = error, Self.isUnavailable(code) || status == 503 {
                    problems[drill.id] = Self.unavailableLine // K62
                } else if case .refused(_, let code, _) = error, code == "rate_limited" {
                    // Ke50 §13: K46's daily limit for new sound.
                    problems[drill.id] = "Dagens gräns för nytt ljud är nådd. Resten görs i morgon. Frågorna som har ljud kan du plugga på redan nu."
                } else {
                    problems[drill.id] = error.userMessage
                }
                if case .refused(let status, _, _) = error, status == 404, current.serverID != nil {
                    // Not this account's on the server (a relaunch as a new anonymous account, D183, or deleted on
                    // another phone): keep the phone's copy and save it as new at once (Toby T24 L5). Until then the
                    // card on Start said "Provet finns inte" though the exam is here; now it says the sound's state.
                    var copy = current
                    copy.serverID = nil
                    copy.needsUpload = true
                    store.save(copy)
                    problems[drill.id] = nil
                    polls += 1
                    continue
                }
                return
            }
            // The phone may have changed while we waited: merge only into the latest copy, and only when the texts match.
            guard var latest = store.drill(drill.id) else { return }
            let edited = latest.items.map(\.question) != current.items.map(\.question)
                || zip(latest.items, current.items).contains { !$0.sameText(as: $1) }
            if edited {
                latest.needsUpload = true
                store.save(latest)
                polls += 1
                continue
            }
            latest = Drill.from(view, merging: latest)
            latest.needsUpload = nil
            latest = await download(view, into: latest)
            store.save(latest)
            if (view.refunded_questions ?? 0) > 0 { refunds += 1 } // A112 (K78): the quota went back up
            if latest.awaitsAudioStart {
                // A107 (D190): saved, and no sound is asked for until Starta prov. Nothing to wait for.
                // A112 (K78): unless the server says the voice service is out: then the calm line, already now.
                problems[drill.id] = view.audio_unavailable == true ? Self.unavailableLine : nil
                return
            }
            if noSpace.remove(drill.id) != nil {
                problems[drill.id] = Self.noSpaceLine // A103: said, not a counter that never moves
                return
            }
            failedFiles[drill.id] = view.audio.failed ?? 0
            let p = progress(for: latest)
            if p.total > 0, p.ready == p.total { problems[drill.id] = nil; return }
            if view.audio_unavailable == true {
                // A112 (K78, D200): the credits are out. The text is here; no counter that never moves, no error.
                problems[drill.id] = Self.unavailableLine
                return
            }
            if view.items.flatMap(\.audio.files).contains(where: { $0.isFailed && Self.isUnavailable($0.error) }) {
                // T24 L5 (K62): the voice service cannot make sound now; said at the first such file, not after
                // every file has failed. The files that are done stay; the next open asks again.
                problems[drill.id] = Self.unavailableLine
                return
            }
            if p.ready == lastReady { stillPolls += 1 } else { stillPolls = 0; lastReady = p.ready }
            let firstMissing = latest.isText ? reading(for: latest, part: 0) == nil : track(for: latest, at: 0) == nil
            // T24 L6: "Ljud: 0 av 6 klara" that never moves says why.
            problems[drill.id] = stillPolls >= slowPolls && firstMissing ? Self.slowLine : nil
            if view.audio.done + (view.audio.failed ?? 0) >= view.audio.total, view.audio.done == p.ready {
                // Nothing more will come: some files failed on the server; the next open asks again.
                let failed = max(1, (p.total - p.ready + 1) / 2)
                let files = view.items.flatMap(\.audio.files)
                problems[drill.id] = files.contains { $0.isFailed && Self.isUnavailable($0.error) }
                    ? Self.unavailableLine // K62: the voice service is out, not this exam
                    : "Ljudet för \(DrillText.questions(failed)) kunde inte göras. EarMind försöker igen av sig själv."
                return
            }
            polls += 1
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// Downloads the done files the phone does not have yet (names = the server's hashes, so a file shared by two
    /// exams is downloaded once).
    private func download(_ view: DrillCloudView, into drill: Drill) async -> Drill {
        var drill = drill
        let remote = view.items.sorted { $0.position < $1.position }
        for (i, item) in remote.enumerated() where drill.items.indices.contains(i) {
            if let file = item.audio.text {
                // K70 (D185): a text part's one file, kept as the long file, and its sentence times.
                guard file.isDone, let name = file.fileName, let link = file.url, let url = URL(string: link) else { continue }
                if !exists(name) {
                    do throws(DrillCloudError) {
                        let data = try await cloud.download(url)
                        guard write(data, to: name, for: drill.id) else { continue }
                        made += 1
                    } catch {
                        Log.repetition.error("Drill text audio download: \(error.userMessage, privacy: .public)")
                        continue
                    }
                }
                drill.items[i].longAudio = name
                drill.items[i].sentenceTimesMs = file.sentences
                continue
            }
            for kind in [0, 1] {
                let file = kind == 0 ? item.audio.question : item.audio.long
                guard file.isDone, let name = file.fileName, let link = file.url, let url = URL(string: link) else { continue }
                if !exists(name) {
                    do throws(DrillCloudError) {
                        let data = try await cloud.download(url)
                        guard write(data, to: name, for: drill.id) else { continue }
                        made += 1
                    } catch {
                        Log.repetition.error("Drill audio download: \(error.userMessage, privacy: .public)")
                        continue
                    }
                }
                if kind == 0 {
                    drill.items[i].questionAudio = name
                } else {
                    drill.items[i].longAudio = name
                    drill.items[i].shortEndMs = file.short_end_ms
                }
            }
        }
        // Kelly N1: the cue "Tryck en gång för svaret." in the same voice.
        if let file = view.cue?.press_for_answer, file.isDone, let name = file.fileName, let link = file.url,
           let url = URL(string: link) {
            if !exists(name) {
                do throws(DrillCloudError) {
                    let data = try await cloud.download(url)
                    write(data, to: name, for: drill.id)
                } catch {
                    Log.repetition.error("Drill cue download: \(error.userMessage, privacy: .public)")
                }
            }
            if exists(name) { drill.cueAudio = name }
        }
        return drill
    }

    /// A103: a failed write (a full phone) is logged and said, never taken for a downloaded file.
    @discardableResult
    private func write(_ data: Data, to name: String, for drillID: UUID) -> Bool {
        do {
            try data.write(to: fileURL(name), options: .atomic)
            return true
        } catch {
            Log.repetition.error("Drill audio write: \(error.localizedDescription, privacy: .public)")
            noSpace.insert(drillID)
            return false
        }
    }

    func cue(for drill: Drill) -> URL? {
        guard let name = drill.cueAudio, exists(name) else { return nil }
        return fileURL(name)
    }

    /// A107: exams whose Starta prov is asking the server for the sound right now ("Gör ljudet …").
    private(set) var starting: Set<UUID> = []

    func isStarting(_ drill: Drill) -> Bool { starting.contains(drill.id) }

    /// A107 (D190, K71): Starta prov. Saves what the server has not seen, asks it to make every missing file (the
    /// month's quota is counted now), then follows and downloads the sound as `prepare` does. True when the sound is
    /// on its way (or already here); false when it could not start (no network, the month used up), said in
    /// `problem(for:)`. Calling it again costs nothing.
    @discardableResult
    func startAudio(_ drill: Drill) async -> Bool {
        guard store.drill(drill.id)?.awaitsAudioStart == true else { return true }
        guard !starting.contains(drill.id) else { return true }
        starting.insert(drill.id)
        defer { starting.remove(drill.id) }
        problems[drill.id] = nil
        // A save that is still on its way first (it brings the server id).
        for _ in 0..<100 where preparing.contains(drill.id) { try? await Task.sleep(for: .milliseconds(100)) }
        guard var current = store.drill(drill.id) else { return false }
        do throws(DrillCloudError) {
            if current.serverID == nil || current.needsUpload == true {
                current = Drill.from(try await cloud.save(current), merging: current)
                current.needsUpload = nil
                store.save(current)
            }
            guard let id = current.serverID else { return false }
            let view = try await cloud.start(id: id)
            guard var latest = store.drill(drill.id) else { return false }
            if view.audio_unavailable == true, view.drill.audio_started == false {
                // A112 (K78, D200): the voice service's credits are out. Nothing was queued or counted; the exam stays
                // text, and the next Starta prov makes the sound when the credits are back.
                latest = Drill.from(view, merging: latest)
                latest.audioStarted = false
                store.save(latest)
                problems[drill.id] = Self.unavailableLine
                Log.repetition.info("Drill audio not started: the voice service is out (audio_unavailable)")
                return false
            }
            latest = Drill.from(view, merging: latest)
            latest.audioStarted = nil // started, whatever an older server says
            store.save(latest)
            Log.repetition.info("Drill audio started: \(view.audio.done, privacy: .public)/\(view.audio.total, privacy: .public)")
        } catch {
            if case .refused(_, let code, _) = error, code == "quota_exceeded" { quotaExceeded.insert(drill.id) }
            problems[drill.id] = error.userMessage
            return false
        }
        let started = store.drill(drill.id) ?? drill
        Task { await self.prepare(started) } // follows "Gör ljudet …" and downloads
        return true
    }

    /// A105 (D185, K70): a text part's downloaded file and its sentence times. Without times (an older download, a
    /// test account's sound) every sentence starts at 0, so pause and the presses replay the part, never skip.
    func reading(for drill: Drill, part index: Int) -> ReadingAudio? {
        _ = made
        guard drill.items.indices.contains(index) else { return nil }
        let item = drill.items[index]
        guard let name = item.longAudio, exists(name) else { return nil }
        return ReadingAudio(url: fileURL(name), times: item.sentenceTimes ?? [])
    }
}
