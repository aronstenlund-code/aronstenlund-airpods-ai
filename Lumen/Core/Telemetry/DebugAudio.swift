@preconcurrency import AVFoundation
import Foundation
import Observation

/// A76 (D140, owner): "Testläge: skicka ljud för felsökning". Off by default for everyone (CLAUDE.md: no audio stored
/// by default). When on, everything the microphone hears while Lumen listens is kept in 60 s pieces (AAC mono 16 kHz,
/// about 32 kbit/s) with what was heard, decided and answered in that minute, and the pieces go to us when there is
/// network (Kevin's K43, private bucket, deleted after 14 days). The listening indicator says it all the time. After
/// upload a piece is deleted from the phone; pieces that cannot be uploaded are kept at most `keepLimit` / `keepAge`.
@MainActor
@Observable
final class TestModeSettings {
    nonisolated static let enabledKey = "testMode.enabled"
    /// The user's own switch (testers turn it on themselves).
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    /// K43: the server says this account is a test account (Aron's OWNER_EMAIL or the `tester` flag): on by default.
    private(set) var serverSaysTester = false
    /// K43 refused this account (it only takes accounts signed in by email): nothing is kept, and Settings says why.
    var serverRefused = false
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    /// K43's flag arrived: a test account is switched on once (it can still be turned off).
    func applyServerFlag(_ isTester: Bool) {
        serverSaysTester = isTester
        serverRefused = !isTester && isEnabled
        let askedKey = "testMode.serverApplied"
        if isTester, !defaults.bool(forKey: askedKey) {
            defaults.set(true, forKey: askedKey)
            isEnabled = true
            needsServerNotice = true // Ke46 T2: a test account sees the sheet once, with "Okej"
        }
    }

    /// Ke46 T2: switched on by the server, not by the user: Start shows the sheet once.
    var needsServerNotice = false

    /// Ke45/Ke46 T4: D138's sentence is not true while the test mode is on; this replaces it then.
    nonisolated static let soundNote = "Testläget är på: ljudet skickas till oss och sparas i 14 dagar. Sömnläget sparar klippen bara på din telefon."
}

/// One finished minute, waiting for upload: the audio and what happened in it.
struct DebugPiece: Codable, Equatable, Sendable {
    struct Turn: Codable, Equatable, Sendable {
        var at: Date
        var heard: String
        var outcome: String
        var reason: String?
        var status: String?
    }
    struct Heard: Codable, Equatable, Sendable {
        var at: Date
        var text: String
    }
    var id: String
    var startedAt: Date
    var endedAt: Date
    var audioFile: String
    var mode: String
    var heard: [Heard] = []
    /// "question → answer" for each answer that began in the minute.
    var answers: [Heard] = []
    var turns: [Turn] = []
    var log: [String] = []
}

/// K43's `POST /debug-audio` body: one minute is one "turn" there (its audio, what was heard, the app's decisions).
struct DebugTurnBody: Encodable, Sendable {
    struct Meta: Encodable, Sendable {
        var started_at: String
        var ended_at: String
        var seconds: Int
        var turns: [DebugPiece.Turn]
        var log: [String]
    }
    var turn_id: String
    var mode: String
    var audio_b64: String?
    var audio_mime: String?
    var transcript: String?
    var decision: String
    var answer: String?
    var meta: Meta?

    /// K43 keeps `meta` only up to 4000 characters, the transcript and the answers up to 4000/6000: the oldest log
    /// lines go first, then the turns, so the rest always arrives.
    init(piece: DebugPiece, audio: Data?) {
        let offset = { (date: Date) in "[\(max(0, Int(date.timeIntervalSince(piece.startedAt)))) s]" }
        turn_id = piece.id
        mode = piece.mode
        audio_b64 = audio?.base64EncodedString()
        audio_mime = audio == nil ? nil : "audio/mp4"
        let heard = piece.heard.map { "\(offset($0.at)) \($0.text)" }.joined(separator: "\n")
        transcript = heard.isEmpty ? nil : String(heard.suffix(4000))
        let answered = piece.answers.map { "\(offset($0.at)) \($0.text)" }.joined(separator: "\n\n")
        answer = answered.isEmpty ? nil : String(answered.prefix(6000))
        decision = String(Self.decision(piece.turns).prefix(64))
        let iso = ISO8601DateFormatter()
        var meta = Meta(started_at: iso.string(from: piece.startedAt), ended_at: iso.string(from: piece.endedAt),
                        seconds: Int(piece.endedAt.timeIntervalSince(piece.startedAt).rounded()),
                        turns: piece.turns, log: piece.log)
        while Self.length(meta) > 3900, !meta.log.isEmpty { meta.log.removeFirst(max(1, meta.log.count / 5)) }
        while Self.length(meta) > 3900, !meta.turns.isEmpty { meta.turns.removeFirst() }
        self.meta = meta
    }

    /// "answered 2, silent 1" (no turn: "no turn").
    static func decision(_ turns: [DebugPiece.Turn]) -> String {
        var counts: [(String, Int)] = []
        for turn in turns {
            if let index = counts.firstIndex(where: { $0.0 == turn.outcome }) { counts[index].1 += 1 } else { counts.append((turn.outcome, 1)) }
        }
        return counts.isEmpty ? "no turn" : counts.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
    }

    private static func length(_ meta: Meta) -> Int {
        (try? JSONEncoder().encode(meta).count) ?? 0
    }
}

/// The pieces on the phone (`Application Support/Lumen/debug-audio`), oldest first. Pure file handling, testable.
struct DebugPieceStore: Sendable {
    static let keepLimit = 120 // two hours of pieces at most
    static let keepAge: TimeInterval = 48 * 3600

    let folder: URL

    init(folder: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.folder = folder ?? base.appending(path: "Lumen", directoryHint: .isDirectory).appending(path: "debug-audio", directoryHint: .isDirectory)
    }

    func newAudioURL(at date: Date) -> URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("piece-\(Int(date.timeIntervalSince1970 * 1000)).m4a")
    }

    func save(_ piece: DebugPiece) {
        let url = folder.appendingPathComponent(piece.id + ".json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(piece) { try? data.write(to: url, options: .atomic) }
        prune()
    }

    func pending() -> [DebugPiece] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(DebugPiece.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// After upload: the piece and its audio leave the phone.
    func delete(_ piece: DebugPiece) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(piece.id + ".json"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(piece.audioFile))
    }

    /// Never more than `keepLimit` pieces or older than `keepAge` (no network for days must not fill the phone).
    func prune(now: Date = Date()) {
        let all = pending()
        let tooOld = all.filter { now.timeIntervalSince($0.endedAt) > Self.keepAge }
        let tooMany = all.count > Self.keepLimit ? Array(all.prefix(all.count - Self.keepLimit)) : []
        for piece in Set((tooOld + tooMany).map(\.id)).compactMap({ id in all.first { $0.id == id } }) { delete(piece) }
    }

    func audio(of piece: DebugPiece) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent(piece.audioFile))
    }
}

/// `/debug-audio` (K43): the flag, the tester's own switch and the upload.
@MainActor
final class DebugAudioClient {
    enum Upload: Equatable, Sendable { case sent, refused, failed }
    private struct Flag: Decodable { var debug_audio: Bool }

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    /// `GET`: is the test mode on for this account. Nil when it could not be asked.
    func flag() async -> Bool? {
        guard let reply = await send(method: "GET", query: nil, body: nil), reply.status == 200 else { return nil }
        return (try? JSONDecoder().decode(Flag.self, from: reply.data))?.debug_audio
    }

    /// `POST ?action=opt_in|opt_out`. False when the server refuses (anonymous accounts never get the test mode).
    func setOptIn(_ on: Bool) async -> Bool? {
        guard let reply = await send(method: "POST", query: on ? "opt_in" : "opt_out", body: nil) else { return nil }
        if reply.status == 403 { return false }
        guard reply.status == 200 else { return nil }
        return (try? JSONDecoder().decode(Flag.self, from: reply.data))?.debug_audio
    }

    func upload(_ body: DebugTurnBody) async -> Upload {
        guard let data = try? JSONEncoder().encode(body),
              let reply = await send(method: "POST", query: nil, body: data, timeout: 60) else { return .failed }
        let status = reply.status
        switch status {
        case 200: return .sent
        case 403: return .refused
        default:
            Log.answer.error("debug-audio: HTTP \(status, privacy: .public)")
            return .failed
        }
    }

    private func send(method: String, query: String?, body: Data?, timeout: TimeInterval = 15) async -> (status: Int, data: Data)? {
        do {
            let token = try await auth.accessToken()
            var url = config.debugAudioURL
            if let query { url = url.appending(queryItems: [URLQueryItem(name: "action", value: query)]) }
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            }
            request.timeoutInterval = timeout
            let (response, data) = try await http.data(for: request)
            return (status: response.statusCode, data: data)
        } catch {
            return nil
        }
    }
}

/// Writes the microphone's chunks into 60 s AAC files, off the main actor.
actor DebugAudioWriter {
    static let pieceSeconds = 60
    private let store: DebugPieceStore
    private var file: AVAudioFile?
    private var fileURL: URL?
    private var samplesInFile = 0
    private var startedAt = Date()
    /// Called with a finished file (its URL and start/end), on the writer.
    private let onPiece: @Sendable (URL, Date, Date) -> Void

    init(store: DebugPieceStore, onPiece: @escaping @Sendable (URL, Date, Date) -> Void) {
        self.store = store
        self.onPiece = onPiece
    }

    func append(_ samples: [Int16]) {
        if file == nil { open() }
        guard let file, !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.int16ChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        try? file.write(from: buffer)
        samplesInFile += samples.count
        if samplesInFile >= Self.pieceSeconds * Int(LumenAudioFormat.sampleRate) { close() }
    }

    /// The end of listening (or the test mode turned off): the last, shorter piece is finished too.
    func close() {
        guard let url = fileURL else { return }
        file = nil // closes and finishes the AAC file
        fileURL = nil
        let had = samplesInFile
        samplesInFile = 0
        if had > 0 { onPiece(url, startedAt, Date()) } else { try? FileManager.default.removeItem(at: url) }
    }

    private func open() {
        let url = store.newAudioURL(at: Date())
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: LumenAudioFormat.sampleRate,
                                       AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32_000]
        file = try? AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatInt16, interleaved: true)
        fileURL = file == nil ? nil : url
        startedAt = Date()
    }
}
