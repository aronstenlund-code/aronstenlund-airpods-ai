import AVFoundation
import Foundation
import Testing
@testable import Lumen

/// T58 part 2 (Toby, D263): "Spela in själv – helt gratis" from the app's own wiring (`AppContainer`), A164's core.
/// A collection is made, questions and answers are typed, one card gets a pretend recording (the Simulator in CI has
/// no microphone, so a recorder in the test writes a silent m4a where the microphone's file would go), and the
/// collection is practised through the real exam player, which plays the files. While that happens every request the
/// app makes is stopped and written down by a `URLProtocol` in the test process: there must be none. The month's
/// credits are read from the real `/drill quota` before and after (the gate is open only for that) and must be the
/// same. `/answer`, `/stt-token` and `/tts` are always closed (no live /answer, D180: 0 ElevenLabs).
/// Part 2b (A165): the sheet that points here when `/exam` says 402 for credits or 503 `provider_quota`.
/// Output: `<LUMEN_E2E_OUT>/owndeck.jsonl`. Simulator only: never a verification on a device.
enum OwnDeckEnvironment {
    static var enabled: Bool { ProcessInfo.processInfo.environment["LUMEN_E2E_OWNDECK"] == "1" }
    static var out: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory()) }
}

/// Open: only `/answer`, `/stt-token` and `/tts` are stopped (as T57). Shut: every http(s) request is stopped and
/// written down.
final class OwnDeckGate: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var shut = false
    nonisolated(unsafe) private static var hits: [String] = []
    static let alwaysClosed = ["/functions/v1/answer", "/functions/v1/stt-token", "/functions/v1/tts"]
    static let exam = "/functions/v1/exam"
    /// Part 2b: what `/exam` says while set (402 for credits, or 503 `provider_quota`); nil = the gate's usual rule.
    enum ExamNo: Sendable { case credits, modelDown }
    nonisolated(unsafe) private static var examNo: ExamNo?

    static func setShut(_ value: Bool) { lock.lock(); shut = value; lock.unlock() }
    static func setExamNo(_ value: ExamNo?) { lock.lock(); examNo = value; lock.unlock() }

    static func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return hits
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, let scheme = url.scheme, scheme == "http" || scheme == "https" else { return false }
        lock.lock(); defer { lock.unlock() }
        return shut || alwaysClosed.contains(url.path) || (examNo != nil && url.path == exam)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.lock()
        Self.hits.append("\(request.httpMethod ?? "GET") \(url.host ?? "") \(url.path)")
        let no = url.path == Self.exam ? Self.examNo : nil
        Self.lock.unlock()
        let (status, body): (Int, String) = switch no {
        // K109/K110: the credits do not cover an exam; 1 question fits, 3 is the least.
        case .credits: (402, #"{"error":{"code":"quota_exceeded","message":"T58: Du har inte krediter nog för ett prov (test)."},"fits":1,"min_questions":3,"per_question":700,"remaining":1500}"#)
        case .modelDown: (503, #"{"error":{"code":"provider_quota","message":"T58: the model is out of credits (test)","fallback":true}}"#)
        case nil: (503, #"{"error":{"code":"upstream_unavailable","message":"T58: closed in the test","fallback":true}}"#)
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// The microphone's place: writes `seconds` of silence as AAC in the m4a file the app asked for.
@MainActor
final class PretendMicrophone: OwnRecording {
    var elapsed: TimeInterval = 0
    var levelDBFS: Double?
    var onLimit: (@MainActor () -> Void)?
    let seconds: TimeInterval
    private(set) var starts = 0
    private var target: URL?

    init(seconds: TimeInterval = 1.5) { self.seconds = seconds }

    func start(to url: URL) async throws(OwnRecordingError) {
        let frames = AVAudioFrameCount(44_100 * seconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw .failed("T58 pretend microphone: no buffer")
        }
        buffer.frameLength = frames // zero-filled: silence
        do {
            let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                                                  AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1])
            try file.write(from: buffer)
        } catch {
            throw .failed("T58 pretend microphone: \(error)")
        }
        starts += 1
        target = url
        elapsed = seconds
    }

    func stop() -> TimeInterval? {
        guard target != nil else { return nil }
        target = nil
        return seconds
    }

    func cancel() {
        if let target { try? FileManager.default.removeItem(at: target) }
        target = nil
    }
}

@MainActor
@Suite(.serialized, .enabled(if: OwnDeckEnvironment.enabled, "set LUMEN_E2E_OWNDECK=1 (scripts/apptest/t58.sh)"))
struct OwnDeckE2ETests {
    struct Outcome: Codable {
        var id: String
        var verdict = ""
        var phases: [String] = []
        var requestsWhilePractising: [String] = []
        var creditsBefore: Int?
        var creditsAfter: Int?
        var notes: [String] = []
    }

    /// Part 2a (A164): make a collection, type, record one card with the pretend microphone, practise. The second card
    /// has no recording: the phone's own voice (AVSpeechSynthesizer) reads it, never ElevenLabs.
    @Test func makeRecordAndPractiseWithoutNetworkOrCredits() async throws {
        var out = Outcome(id: "make-record-practise")
        let (container, repetition) = try await start(seed: false)
        out.creditsBefore = await credits(repetition)
        let original = try #require(repetition.ownDecks)
        let microphone = PretendMicrophone()
        let own = OwnDeckModel(store: original.store, audio: original.audio, recorder: microphone)
        own.onWillRecord = { [weak repetition] in repetition?.end() }
        repetition.ownDecks = own
        let drillsBefore = repetition.store.drills.map(\.id)

        OwnDeckGate.setShut(true)
        let baseline = OwnDeckGate.snapshot().count
        let deck = own.addDeck(title: "T58 Biologi")
        let first = try #require(own.addCard(to: deck.id, question: "Vad är en cell?", answer: "Livets minsta del."))
        let second = try #require(own.addCard(to: deck.id))
        own.setText("Vad gör mitokondrien?", for: .question, card: second.id, in: deck.id)
        own.setText("Den gör energi åt cellen.", for: .answer, card: second.id, in: deck.id)
        for part in OwnPart.allCases {
            await own.record(part, card: first.id, in: deck.id)
            own.stopRecording()
        }
        let saved = try #require(own.deck(deck.id))
        let recorded = try #require(saved.cards.first { $0.id == first.id })
        out.notes.append("cards \(saved.cards.count), playable \(saved.playableCards.count), recorded q \(recorded.questionRecording != nil) a \(recorded.answerRecording != nil), problem \(own.problem ?? "-")")
        let recordingURL = recorded.questionRecording.map { own.store.url(for: $0) }
        if let recordingURL { out.notes.append("question recording \(recordingURL.lastPathComponent) exists \(FileManager.default.fileExists(atPath: recordingURL.path))") }
        let backup = try? own.store.audioFolder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        out.notes.append("recording in \(recordingURL?.deletingLastPathComponent().pathComponents.suffix(3).joined(separator: "/") ?? "?"), out of backup \(backup.map(String.init) ?? "?")")

        await repetition.start(own: saved)
        out.phases = try await watch(repetition, pressLongOnFirst: true, until: { $0.lap >= 1 }, seconds: 90)
        let player = repetition.session.player
        out.notes.append("lap \(player?.lap ?? -1), showsPlayer \(repetition.showsPlayer), drill \(repetition.session.drill?.title ?? "-") items \(repetition.session.drill?.items.count ?? -1)")
        repetition.end()
        let inStore = repetition.store.drills.contains { $0.id == deck.id }
        out.requestsWhilePractising = Array(OwnDeckGate.snapshot().dropFirst(baseline))
        OwnDeckGate.setShut(false)
        out.creditsAfter = await credits(repetition)
        own.delete(deck.id)

        var wrong: [String] = []
        if recorded.questionRecording == nil || recorded.answerRecording == nil { wrong.append("the pretend recording was not kept") }
        if microphone.starts != 2 { wrong.append("the microphone started \(microphone.starts) times, not 2") }
        if backup != true { wrong.append("the recordings' folder is in the backup") }
        if !out.phases.contains("question 0") || !out.phases.contains("answer 0 long") { wrong.append("card 1 (recorded) not played with its answer") }
        if !out.phases.contains("question 1") { wrong.append("card 2 (the phone's voice) never played") }
        if (player?.lap ?? 0) < 1 { wrong.append("the collection was not played through") }
        if inStore || repetition.store.drills.map(\.id) != drillsBefore { wrong.append("the exam store changed") }
        if !out.requestsWhilePractising.isEmpty { wrong.append("\(out.requestsWhilePractising.count) requests") }
        if out.creditsBefore == nil || out.creditsBefore != out.creditsAfter { wrong.append("credits \(text(out.creditsBefore)) → \(text(out.creditsAfter))") }
        out.verdict = wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
        _ = container
        try write(out)
        #expect(out.verdict == "ok", "\(out.verdict)")
    }

    /// Part 2a (A164's hook): `-SeedOwnDeck 1` gives three cards and a silent phone voice; Öva plays them all with no
    /// request and the same credits.
    @Test func theSeededCollectionIsPractisedWithoutNetworkOrCredits() async throws {
        var out = Outcome(id: "seeded-practise")
        let (container, repetition) = try await start(seed: true)
        defer { UserDefaults.standard.removeObject(forKey: OwnDeckSeed.argument) }
        out.creditsBefore = await credits(repetition)
        let own = try #require(repetition.ownDecks)
        OwnDeckGate.setShut(true)
        let baseline = OwnDeckGate.snapshot().count
        let deck = try #require(own.decks.first)
        out.notes.append("seeded \"\(deck.title)\" (\(deck.language)), cards \(deck.cards.count), can start \(own.canStart(deck))")
        await repetition.start(own: deck)
        out.phases = try await watch(repetition, pressLongOnFirst: false, until: { $0.lap >= 1 }, seconds: 90)
        let lap = repetition.session.player?.lap ?? 0
        repetition.end()
        out.requestsWhilePractising = Array(OwnDeckGate.snapshot().dropFirst(baseline))
        OwnDeckGate.setShut(false)
        out.creditsAfter = await credits(repetition)
        own.delete(deck.id)

        var wrong: [String] = []
        if deck.cards.count != 3 { wrong.append("\(deck.cards.count) seeded cards") }
        for i in 0..<3 where !out.phases.contains("question \(i)") { wrong.append("question \(i) never played") }
        if lap < 1 { wrong.append("not played through") }
        if !out.requestsWhilePractising.isEmpty { wrong.append("\(out.requestsWhilePractising.count) requests") }
        if out.creditsBefore == nil || out.creditsBefore != out.creditsAfter { wrong.append("credits \(text(out.creditsBefore)) → \(text(out.creditsAfter))") }
        out.verdict = wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
        _ = container
        try write(out)
        #expect(out.verdict == "ok", "\(out.verdict)")
    }

    /// Part 2b (A165): Nytt prov when `/exam` says 402 for credits or 503 `provider_quota`. The sheet "Slut på
    /// krediter? …" (credits) or its model-down title comes up once for the occasion, not at the next no; its button
    /// asks Start to open "Spela in själv". Nothing is made and the credits are the same.
    @Test(arguments: ["credits", "modelDown"])
    func theSheetComesOnceWhenTheServerSaysNo(_ reason: String) async throws {
        var out = Outcome(id: "sheet-\(reason)")
        let (container, repetition) = try await start(seed: false)
        out.creditsBefore = await credits(repetition)
        let drills = repetition.drills.count
        let expected: OwnDeckOffer.Reason = reason == "credits" ? .credits : .modelDown
        OwnDeckGate.setExamNo(reason == "credits" ? .credits : .modelDown)
        let baseline = OwnDeckGate.snapshot().count
        let material = DrillMaterial(text: "Fotosyntesen gör socker och syre av koldioxid, vatten och ljus. Den sker i kloroplasterna.")

        let first = await makeError(repetition, material)
        let shownFirst = repetition.ownOffer.showing
        let title = shownFirst.map { OwnDeckText.offerTitle($0) } ?? "-"
        out.notes.append("first no: \(first); sheet \(shownFirst.map(\.rawValue) ?? "none"): \"\(title)\" / \"\(OwnDeckText.offerLine)\"")
        var wrong: [String] = []
        if shownFirst != expected { wrong.append("the sheet was \(shownFirst.map(\.rawValue) ?? "not shown"), not \(expected.rawValue)") }
        if reason == "credits" {
            repetition.ownOffer.close() // Inte nu
            if repetition.ownOffer.showing != nil { wrong.append("Inte nu did not close the sheet") }
        } else {
            repetition.ownOffer.open() // the sheet's button
            if repetition.ownOffer.showing != nil || !repetition.ownOffer.opensDecks { wrong.append("the button did not ask Start to open Spela in själv") }
            repetition.ownOffer.opensDecks = false
        }
        let second = await makeError(repetition, material)
        let shownSecond = repetition.ownOffer.showing
        out.notes.append("second no: \(second); sheet \(shownSecond.map(\.rawValue) ?? "none")")
        if shownSecond != nil { wrong.append("the sheet came again for the same occasion") }
        let examCalls = OwnDeckGate.snapshot().dropFirst(baseline).filter { $0.hasSuffix(OwnDeckGate.exam) }.count
        out.requestsWhilePractising = Array(OwnDeckGate.snapshot().dropFirst(baseline))
        OwnDeckGate.setExamNo(nil)
        out.creditsAfter = await credits(repetition)
        if examCalls < 2 { wrong.append("/exam asked \(examCalls) times, not twice") }
        if repetition.drills.count != drills { wrong.append("an exam was made") }
        if out.creditsBefore == nil || out.creditsBefore != out.creditsAfter { wrong.append("credits \(text(out.creditsBefore)) → \(text(out.creditsAfter))") }
        out.verdict = wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
        _ = container
        try write(out)
        #expect(out.verdict == "ok", "\(out.verdict)")
    }

    private func makeError(_ repetition: RepetitionModel, _ material: DrillMaterial) async -> String {
        do throws(DrillMakingError) {
            _ = try await repetition.make(material, settings: DrillSettings())
            return "made (no error)"
        } catch {
            return "\(error)".prefix(120).description
        }
    }

    // MARK: Helpers

    private func start(seed: Bool) async throws -> (AppContainer, RepetitionModel) {
        URLProtocol.registerClass(OwnDeckGate.self)
        OwnDeckGate.setShut(false)
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: STTSettings.cloudKey) // D180: never Scribe
        defaults.set(try JSONEncoder().encode(VoiceChoice.appleDefault), forKey: VoiceSettings.voiceKey) // never /tts
        defaults.set(seed, forKey: OwnDeckSeed.argument) // read when the container is made
        let container = AppContainer()
        let repetition = try #require(container.listening.repetition)
        // Empty the own store of an earlier run's decks (the seed only fills an empty store).
        if !seed, let own = repetition.ownDecks { for deck in own.decks { own.delete(deck.id) } }
        // As T57: the anonymous sign-in takes a few seconds.
        try await Task.sleep(for: .seconds(8))
        return (container, repetition)
    }

    private func credits(_ repetition: RepetitionModel) async -> Int? {
        await repetition.refreshQuota()
        return repetition.quota.map { $0.serverLeft ?? ($0.limit - $0.used) }
    }

    /// The player's phases as they change; one long press during the first question when asked.
    private func watch(_ repetition: RepetitionModel, pressLongOnFirst: Bool, until done: (RepetitionPlayer) -> Bool,
                       seconds: Double) async throws -> [String] {
        var phases: [String] = []
        var pressed = false
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            guard let player = repetition.session.player else { phases.append("no player"); break }
            let now = Self.name(player.phase)
            if phases.last != now { phases.append(now) }
            if pressLongOnFirst, !pressed, case .thinking(0) = player.phase {
                player.handle(.long)
                pressed = true
            }
            if done(player) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        return phases
    }

    private static func name(_ phase: RepetitionPlayer.Phase) -> String {
        switch phase {
        case .idle: "idle"
        case .question(let i): "question \(i)"
        case .thinking(let i): "thinking \(i)"
        case .answer(let i, let kind): "answer \(i) \(kind.rawValue)"
        case .waitingForAudio(let i): "waiting \(i)"
        }
    }

    private func text(_ value: Int?) -> String { value.map(String.init) ?? "?" }

    private func write(_ outcome: Outcome) throws {
        let url = OwnDeckEnvironment.out.appending(path: "owndeck.jsonl")
        var data = try JSONEncoder().encode(outcome)
        data.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
        print("T58 \(outcome.id): \(outcome.verdict); phases \(outcome.phases.joined(separator: " → ")); requests \(outcome.requestsWhilePractising); credits \(text(outcome.creditsBefore)) → \(text(outcome.creditsAfter)); \(outcome.notes.joined(separator: " | "))")
    }
}
