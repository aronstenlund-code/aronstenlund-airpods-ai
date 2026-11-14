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

    enum CodingKeys: String, CodingKey {
        case used, limit, per, resets, suggest
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
        case .offline: "Ingen kontakt med Earmind just nu. Försök igen om en stund."
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
}

@MainActor
final class DrillCloudClient: DrillCloudSyncing {
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

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
        let items: [[String: Any]] = drill.items.map { item in
            var row: [String: Any] = ["question": item.question, "short": item.short, "long": item.long]
            if let id = item.serverID { row["id"] = id }
            return row
        }
        return ["action": "save", "drill": info, "items": items]
    }

    func save(_ drill: Drill) async throws(DrillCloudError) -> DrillCloudView {
        try await call(Self.saveBody(drill), timeout: 30)
    }

    func status(id: String) async throws(DrillCloudError) -> DrillCloudView {
        try await call(["action": "status", "id": id], timeout: 20)
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
        let fallback = status == 404 ? "Provet finns inte." : "Earmind kunde inte spara just nu. Försök igen om en stund."
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
            item.lengthClass = remote.length_class.flatMap(DrillLengthClass.init(rawValue:)) // K61 (D176)
            if let local, local.items.indices.contains(offset) {
                let mine = local.items[offset]
                item.id = mine.id
                if mine.sameText(as: item) {
                    item.questionAudio = mine.questionAudio
                    item.longAudio = mine.longAudio
                    item.shortEndMs = mine.shortEndMs
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
        self.folder = base
        self.pollInterval = pollInterval
        self.maxPolls = maxPolls
    }

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
    static let unavailableLine = "Ljudet kan inte göras just nu. Försök igen om en stund."
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
                    // Gone on the server (deleted on another phone): keep the phone's copy, save it as new next time.
                    var copy = current
                    copy.serverID = nil
                    copy.needsUpload = true
                    store.save(copy)
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
            failedFiles[drill.id] = view.audio.failed ?? 0
            let p = progress(for: latest)
            if p.total > 0, p.ready == p.total { return }
            if view.audio.done + (view.audio.failed ?? 0) >= view.audio.total, view.audio.done == p.ready {
                // Nothing more will come: some files failed on the server; the next open asks again.
                let failed = max(1, (p.total - p.ready + 1) / 2)
                let files = view.items.flatMap { [$0.audio.question, $0.audio.long] }
                problems[drill.id] = files.contains { $0.isFailed && Self.isUnavailable($0.error) }
                    ? Self.unavailableLine // K62: the voice service is out, not this exam
                    : "Ljudet för \(DrillText.questions(failed)) kunde inte göras. Earmind försöker igen av sig själv."
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
            for kind in [0, 1] {
                let file = kind == 0 ? item.audio.question : item.audio.long
                guard file.isDone, let name = file.fileName, let link = file.url, let url = URL(string: link) else { continue }
                if !exists(name) {
                    do throws(DrillCloudError) {
                        let data = try await cloud.download(url)
                        try? data.write(to: fileURL(name), options: .atomic)
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
                    try? data.write(to: fileURL(name), options: .atomic)
                } catch {
                    Log.repetition.error("Drill cue download: \(error.userMessage, privacy: .public)")
                }
            }
            if exists(name) { drill.cueAudio = name }
        }
        return drill
    }

    func cue(for drill: Drill) -> URL? {
        guard let name = drill.cueAudio, exists(name) else { return nil }
        return fileURL(name)
    }
}
