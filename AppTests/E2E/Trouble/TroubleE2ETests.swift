import Foundation
import Testing
@testable import Lumen

/// T60 (Toby, Deangelo 2026-11-27 04:07): D273 (Lyssnar when something goes wrong) and D271 (Historik: find it again
/// and play it again), from the app's own wiring (`AppContainer`). Fake sources where the Simulator has no real one:
/// the network, the battery and the low power mode (`DeviceConditions`), AirPods going away (the audio session's own
/// route event, as iOS sends it). The route itself is real: the Simulator has no AirPods, so the answers go to the
/// speaker. A `URLProtocol` plays the server: `/answer` answers with a short stream, `/tts` says `tts_quota` or has no
/// connection, `/stt-token` is closed. Nothing reaches Claude or ElevenLabs (D180), and no live `/answer`.
/// `LUMEN_E2E_MIC=denied` (the script's second pass, with the microphone refused by `simctl privacy`) runs only the
/// refused-microphone case. Output: `<LUMEN_E2E_OUT>/trouble.jsonl`. Simulator only: never a device test.
enum TroubleEnvironment {
    static var silence: URL? { ProcessInfo.processInfo.environment["LUMEN_E2E_TROUBLE_SILENCE"].map { URL(fileURLWithPath: $0) } }
    static var micDenied: Bool { ProcessInfo.processInfo.environment["LUMEN_E2E_MIC"] == "denied" }
    static var out: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory()) }
}

final class TroubleStub: URLProtocol, @unchecked Sendable {
    enum Voice: Sendable { case quota, offline }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var voice: Voice = .quota
    nonisolated(unsafe) private static var answer = "Fotosyntesen gör socker av ljus."
    nonisolated(unsafe) private static var hits: [String] = []
    static let answerPath = "/functions/v1/answer"
    static let ttsPath = "/functions/v1/tts"
    static let closed = [answerPath, ttsPath, "/functions/v1/stt-token"]

    static func set(voice: Voice? = nil, answer: String? = nil) {
        lock.lock()
        if let voice { self.voice = voice }
        if let answer { self.answer = answer }
        lock.unlock()
    }
    static func snapshot() -> [String] { lock.lock(); defer { lock.unlock() }; return hits }
    static func count(_ path: String) -> Int { snapshot().filter { $0 == path }.count }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.host?.hasSuffix("supabase.co") == true else { return false }
        return closed.contains(url.path)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.lock()
        Self.hits.append(url.path)
        let voice = Self.voice
        let answer = Self.answer
        Self.lock.unlock()
        func reply(_ status: Int, _ type: String, _ body: String) {
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                                 headerFields: ["Content-Type": type]) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        switch url.path {
        case Self.answerPath:
            let delta = String(data: try! JSONEncoder().encode(["text": answer]), encoding: .utf8)!
            reply(200, "text/event-stream", "event: delta\ndata: \(delta)\n\nevent: done\ndata: {\"answered\":true}\n\n")
        case Self.ttsPath where voice == .offline:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case Self.ttsPath:
            reply(503, "application/json", #"{"error":{"code":"tts_quota","message":"T60: the voice quota is out (test)","fallback":true}}"#)
        default:
            reply(503, "application/json", #"{"error":{"code":"upstream_unavailable","message":"T60: closed in the test (D180)","fallback":true}}"#)
        }
    }

    override func stopLoading() {}
}

/// The network, the battery and the low power mode, as the test says.
@MainActor
final class PretendConditions: DeviceConditions {
    var isOnline = true
    var batteryPercent: Int? = 80
    var isCharging = false
    var isLowPowerMode = false
    var onChange: (@MainActor () -> Void)?
    private(set) var watching = false
    func startWatching() { watching = true }
    func stopWatching() { watching = false }
    func change(_ apply: (PretendConditions) -> Void) {
        apply(self)
        onChange?()
    }
}

@MainActor
@Suite(.serialized, .enabled(if: TroubleEnvironment.silence != nil, "set LUMEN_E2E_TROUBLE_SILENCE (scripts/apptest/t60.sh)"))
struct TroubleE2ETests {
    struct Outcome: Codable {
        var id: String
        var verdict = ""
        var notes: [String] = []
    }

    // MARK: D273: the line under the badge

    @Test(arguments: ["sv-SE", "en-US"], [false, true])
    func theLineSaysWhatIsWrongAndTheWayOn(_ language: String, _ phoneModel: Bool) async throws {
        guard !TroubleEnvironment.micDenied else { return }
        var out = Outcome(id: "line-\(language)-\(phoneModel ? "model" : "nomodel")")
        let (container, model, conditions) = try await start(language: language, mock: phoneModel ? "sv,en" : "none")
        var wrong: [String] = []
        let outputs = container.sessionController.session.snapshot?.outputs.map(\.portType) ?? []
        let first = await waitFor { model.listeningCondition != nil }
        out.notes.append("listening \(model.isListening), watching \(conditions.watching), route \(outputs), line: \(model.listeningCondition.map { "\($0) — \($0.line)" } ?? "none")")
        if !conditions.watching { wrong.append("the conditions are not watched while listening") }
        if !first || model.listeningCondition != .noAirPods { wrong.append("no AirPods line in the Simulator (\(String(describing: model.listeningCondition)))") }

        conditions.change { $0.isOnline = false }
        let offline = await waitFor { if case .offline = model.listeningCondition { true } else { false } }
        out.notes.append("network off: \(model.listeningCondition.map { "\($0) — \($0.line)" } ?? "none")")
        if !offline || model.listeningCondition != .offline(phoneModel: phoneModel) {
            wrong.append("network off gave \(String(describing: model.listeningCondition)), not offline(phoneModel: \(phoneModel))")
        }
        conditions.change { $0.isOnline = true; $0.batteryPercent = 8; $0.isCharging = false; $0.isLowPowerMode = true }
        _ = await waitFor { model.listeningCondition == .noAirPods }
        out.notes.append("network back, battery 8 %, low power on: \(model.listeningCondition.map { "\($0) — \($0.line)" } ?? "none") (AirPods first in the order)")
        if model.listeningCondition != .noAirPods { wrong.append("after the network came back: \(String(describing: model.listeningCondition))") }
        // The battery and the low power mode stand behind "no AirPods" in the order; their lines as the app writes them:
        out.notes.append("battery line: \(ListeningCondition.lowBattery(percent: 8).line) | low power line: \(ListeningCondition.lowPowerMode.line)")
        for line in [ListeningCondition.noAirPods.line, ListeningCondition.offline(phoneModel: phoneModel).line] where line.count > 140 {
            wrong.append("a long line (\(line.count) characters): \(line)")
        }
        let english = language.hasPrefix("en")
        if english, model.listeningCondition?.line.contains("AirPods") == true, model.listeningCondition?.line.contains("Inga") == true {
            out.notes.append("note: the line is Swedish while EarMind listens in English (the app's language decides the words)")
        }
        await model.endSession()
        out.notes.append("after Avsluta: watching \(conditions.watching), line \(model.listeningCondition.map { "\($0)" } ?? "none")")
        if conditions.watching { wrong.append("the conditions are still watched after the session") }
        if model.listeningCondition != nil { wrong.append("a line after the session") }
        try finish(&out, wrong, container)
    }

    // MARK: D273: AirPods go away mid-session

    @Test(arguments: [true, false])
    func airPodsGoneMidSession(_ pauseSetting: Bool) async throws {
        guard !TroubleEnvironment.micDenied else { return }
        var out = Outcome(id: "airpods-gone-\(pauseSetting ? "pause" : "keep")")
        UserDefaults.standard.set(pauseSetting, forKey: MicrophoneSettings.pauseOnLossKey)
        defer { UserDefaults.standard.removeObject(forKey: MicrophoneSettings.pauseOnLossKey) }
        let (container, model, _) = try await start(language: "sv-SE", mock: "none")
        var wrong: [String] = []
        let session = container.sessionController.session
        guard var snapshot = session.snapshot else {
            try finish(&out, ["no audio session snapshot in the Simulator (cannot send the route event)"], container)
            return
        }
        snapshot.outputs = [PortInfo(portType: "Speaker", portName: "Speaker", uid: "t60", channelCount: 1, dataSource: nil)]
        session.eventHandler?(.routeChanged(reason: "oldDeviceUnavailable", outputLost: true, snapshot: snapshot))
        if pauseSetting {
            let paused = await waitFor { model.state == .paused(.outputDeviceLost) }
            out.notes.append("state \(model.state.label), card \(model.problem.map { "\($0): \($0.text) [\($0.actionTitle ?? "-")]" } ?? "none")")
            if !paused { wrong.append("did not pause (\(model.state.label))") }
            if model.problem != .airPodsLostPaused { wrong.append("card \(String(describing: model.problem)), not airPodsLostPaused") }
            if model.problem?.actionTitle != "Lyssna vidare" { wrong.append("the card's button is \(model.problem?.actionTitle ?? "-"), not Lyssna vidare") }
            model.act(on: .airPodsLostPaused)
            let on = await waitFor { model.isListening }
            out.notes.append("after Lyssna vidare: \(model.state.label), card \(model.problem.map { "\($0)" } ?? "none"), line \(model.listeningCondition.map { $0.line } ?? "none")")
            if !on { wrong.append("Lyssna vidare did not listen again") }
            if model.problem != nil { wrong.append("the card stayed after Lyssna vidare") }
            if model.listeningCondition != .noAirPods { wrong.append("no speaker line after Lyssna vidare") }
        } else {
            _ = await waitFor { model.problem != nil }
            out.notes.append("state \(model.state.label), card \(model.problem.map { "\($0): \($0.text) [\($0.actionTitle ?? "-")]" } ?? "none")")
            if !model.isListening { wrong.append("stopped listening with the setting off (\(model.state.label))") }
            if model.problem != .airPodsDisconnected { wrong.append("card \(String(describing: model.problem)), not airPodsDisconnected") }
        }
        await model.endSession()
        try finish(&out, wrong, container)
    }

    // MARK: D273: the microphone refused (second pass)

    @Test func aRefusedMicrophoneSaysWhereToTurnItOn() async throws {
        guard TroubleEnvironment.micDenied else { return }
        var out = Outcome(id: "microphone-denied")
        let (container, model, _) = try await start(language: "sv-SE", mock: "none", waitForListening: false)
        _ = await waitFor(15) { model.problem != nil }
        out.notes.append("state \(model.state.label), card \(model.problem.map { "\($0): \($0.text) [\($0.actionTitle ?? "-")]" } ?? "none")")
        var wrong: [String] = []
        if model.problem != .microphoneDenied { wrong.append("card \(String(describing: model.problem)), not microphoneDenied") }
        if model.problem?.actionTitle == nil { wrong.append("the card has no button") }
        if model.isListening { wrong.append("listening with the microphone refused") }
        if model.isActiveSession { await model.endSession() }
        try finish(&out, wrong, container)
    }

    // MARK: D271: Historik, found again and played again

    @Test func historyFindsTheAnswerAndPlaysItAgain() async throws {
        guard !TroubleEnvironment.micDenied else { return }
        var out = Outcome(id: "history-play-again")
        let (container, model, _) = try await start(language: "sv-SE", mock: "none", speak: false)
        var wrong: [String] = []
        TroubleStub.set(answer: "Fotosyntesen gör socker av ljus, vatten och koldioxid.")
        model.submitText("vad gör fotosyntesen t60")
        let recorded = await waitFor(20) { model.history.entries.contains { $0.answer.contains("Fotosyntesen gör socker") } }
        TroubleStub.set(answer: "Photosynthesis makes sugar from light, water and carbon dioxide.")
        model.submitText("what does photosynthesis do t60")
        _ = await waitFor(20) { model.history.entries.contains { $0.answer.contains("Photosynthesis makes sugar") } }
        await model.endSession()
        let entries = model.history.entries
        let found = HistoryStore.matching(entries, "fotosyntes")
        let days = HistoryStore.days(entries)
        out.notes.append("recorded \(recorded), \(entries.count) rows, search 'fotosyntes' → \(found.count), first day '\(days.first?.title ?? "-")'")
        if !recorded { wrong.append("the answer is not in Historik") }
        if found.isEmpty { wrong.append("the search did not find it") }
        if days.first?.title != "I dag" { wrong.append("the newest rows are not under I dag (\(days.first?.title ?? "-"))") }
        guard let swedish = entries.first(where: { $0.answer.contains("Fotosyntesen gör socker") }) else {
            try finish(&out, wrong, container)
            return
        }
        let speaker = container.speaker

        // (a) Talade svar av, Apple's voice: ▶ reads it anyway (its own press).
        let spoken = speaker.spokenCount
        model.readAgain(swedish)
        let readA = await waitFor(15) { speaker.spokenCount > spoken }
        let doneA = await waitFor(20) { model.readingAgain == nil }
        out.notes.append("(a) voice off, Apple: spoken \(readA), back to ▶ \(doneA), /tts \(TroubleStub.count(TroubleStub.ttsPath))")
        if !readA { wrong.append("▶ read nothing with spoken answers off") }
        if !doneA { wrong.append("the row stayed on ■ after the reading") }

        // (b) and (c): an ElevenLabs voice chosen; tts_quota, then no connection: the phone's own voice reads.
        speaker.settings.voice = VoiceChoice(kind: .elevenLabs, voiceID: "t60-test-voice", name: "T60")
        for (voice, name) in [(TroubleStub.Voice.quota, "tts_quota"), (.offline, "no connection")] {
            TroubleStub.set(voice: voice)
            let tts = TroubleStub.count(TroubleStub.ttsPath)
            let fallbacks = speaker.fallbackCount
            let spokenBefore = speaker.spokenCount
            model.readAgain(swedish)
            let read = await waitFor(20) { speaker.spokenCount > spokenBefore }
            _ = await waitFor(20) { model.readingAgain == nil }
            out.notes.append("(\(name)) /tts \(TroubleStub.count(TroubleStub.ttsPath) - tts), fallbacks \(speaker.fallbackCount - fallbacks), spoken \(read)")
            if !read { wrong.append("\(name): nothing read") }
            if speaker.fallbackCount <= fallbacks && TroubleStub.count(TroubleStub.ttsPath) > tts { wrong.append("\(name): no fallback to the phone's voice") }
        }

        // (d) An English answer is read in English (the answer's language, D271).
        if let english = entries.first(where: { $0.answer.contains("Photosynthesis makes sugar") }) {
            let language = ListeningModel.spokenLanguage(of: english.answer, otherwise: .swedish)
            out.notes.append("(d) the English row is read as \(language)")
            if language != .english { wrong.append("the English answer would be read as \(language)") }
        }
        speaker.settings.voice = .appleDefault
        try finish(&out, wrong, container)
    }

    // MARK: Helpers

    private func start(language: String, mock: String, speak: Bool = false, waitForListening: Bool = true) async throws
        -> (AppContainer, ListeningModel, PretendConditions) {
        URLProtocol.registerClass(TroubleStub.self)
        TroubleStub.set(voice: .quota, answer: "Fotosyntesen gör socker av ljus.")
        let silence = try #require(TroubleEnvironment.silence)
        setenv("LUMEN_AUDIO_FILES", silence.path, 1)
        setenv("LUMEN_AUDIO_LOOP", "1", 1)
        setenv("LUMEN_AUDIO_GAP", "0", 1)
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: STTSettings.cloudKey) // D180: never Scribe, never /stt-token
        defaults.set(speak, forKey: VoiceSettings.speakKey)
        defaults.set(try JSONEncoder().encode(VoiceChoice.appleDefault), forKey: VoiceSettings.voiceKey)
        defaults.set(language, forKey: LanguageSettings.defaultsKey)
        defaults.set(mock, forKey: "OnDeviceMock") // A159: read when the container is made
        let container = AppContainer()
        let model = container.listening
        let conditions = PretendConditions()
        model.deviceConditions = conditions
        container.consent.grant()
        await model.startMode(.standard)
        if waitForListening {
            _ = await waitFor(15) { model.isListening }
            try await Task.sleep(for: .seconds(3))
        }
        return (container, model, conditions)
    }

    private func waitFor(_ seconds: Double = 8, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return condition()
    }

    private func finish(_ out: inout Outcome, _ wrong: [String], _ container: AppContainer) throws {
        UserDefaults.standard.removeObject(forKey: "OnDeviceMock")
        unsetenv("LUMEN_AUDIO_LOOP")
        _ = container
        out.verdict = wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
        let url = TroubleEnvironment.out.appending(path: "trouble.jsonl")
        var data = try JSONEncoder().encode(out)
        data.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
        print("T60 \(out.id): \(out.verdict); \(out.notes.joined(separator: " | "))")
        #expect(out.verdict == "ok", "\(out.id): \(out.verdict)")
    }
}
