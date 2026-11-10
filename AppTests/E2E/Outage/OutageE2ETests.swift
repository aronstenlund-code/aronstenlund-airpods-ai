import Foundation
import Testing
@testable import Lumen

/// T10 part 2 (Toby): ElevenLabs down, without an app hook and without spending ElevenLabs credits. A `URLProtocol`
/// in the test process answers `503` to `/functions/v1/stt-token` and `/functions/v1/tts` (both go through
/// `URLSession.shared`), so Scribe never opens and the premium voice never plays. Everything else (sign-in, `/voices`,
/// `/answer`) is the real backend.
///
/// What the app should do (A45, N3): go on with the iPhone's own recogniser and voice, say "Lumen hör och pratar lite
/// sämre just nu" once, never go silent, and never show "Lyssnar" and "Jag hör inte just nu" together.
///
/// Frågor with two spoken questions (`say`, free), then one sentence through the speaker with an ElevenLabs voice
/// chosen, so the voice's fallback is exercised even if the Simulator's recogniser hears nothing.
/// Output: `<LUMEN_E2E_OUT>/outage.json`. Simulator only: never a verification on a device.
enum OutageEnvironment {
    static var audioDir: URL? {
        ProcessInfo.processInfo.environment["LUMEN_E2E_OUTAGE_DIR"].map { URL(fileURLWithPath: $0) }
    }
}

/// Answers 503 for the two ElevenLabs paths of Kevin's backend; lets every other request through.
final class OutageStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var hits: [String] = []
    static let blocked = ["/functions/v1/stt-token", "/functions/v1/tts"]

    static func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return hits
    }

    private static func record(_ path: String) {
        lock.lock(); hits.append(path); lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.host?.hasSuffix("supabase.co") == true else { return false }
        return blocked.contains(url.path)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        Self.record(url.path)
        let body = Data(#"{"error":"upstream_unavailable","message":"T10 test outage (503)"}"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized, .enabled(if: OutageEnvironment.audioDir != nil, "set LUMEN_E2E_OUTAGE_DIR (scripts/apptest/outage.sh)"))
struct OutageE2ETests {
    struct Sample: Codable {
        let t: Double
        let active: Bool
        let listening: Bool
        let hearing: Bool
        let problem: String
        let notices: [String]
        let speaking: Bool
    }

    struct Event: Codable {
        let t: Double
        let kind: String
        let text: String
    }

    struct Report: Codable {
        var stubHits: [String] = []
        var samples: [Sample] = []
        var events: [Event] = []
        var log: [String] = []
        var standInLines = 0
        var noticeSeconds = 0
        var noticeFirstAt: Double?
        var lyssnarWithCannotHear = 0
        var sessionEndedEarly: Double?
        var voiceFallbacks = 0
        var spoken = 0
        var voiceAtStart = ""
        var seconds = 0.0
    }

    static let lyssnarSentence = "Det här är ett test av reservrösten."

    @Test func frågorGoesOnWhenElevenLabsIsDown() async throws {
        let dir = try #require(OutageEnvironment.audioDir)
        let files = ["lead.wav", "q1.wav", "q2.wav"].map { dir.appendingPathComponent($0) }
        for file in files { #expect(FileManager.default.fileExists(atPath: file.path), "missing \(file.path)") }
        setenv("LUMEN_AUDIO_FILES", files.map(\.path).joined(separator: ":"), 1)
        setenv("LUMEN_AUDIO_GAP", "15", 1)
        unsetenv("LUMEN_AUDIO_LOOP")

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: VoiceSettings.speakKey)
        // An ElevenLabs voice, as for a new user (D32): `reconcile` may swap the id for the server's default, still
        // ElevenLabs, so the answer goes to /tts, which the stub fails.
        let premium = VoiceChoice(kind: .elevenLabs, voiceID: "t10-outage", name: "T10")
        defaults.set(try JSONEncoder().encode(premium), forKey: VoiceSettings.voiceKey)

        URLProtocol.registerClass(OutageStub.self)
        defer { URLProtocol.unregisterClass(OutageStub.self) }

        let container = AppContainer()
        let model = container.listening
        container.consent.grant()

        let start = Date()
        var report = Report()
        var log: [Event] = []
        model.sessionObserver = { event, date in
            let t = date.timeIntervalSince(start)
            switch event {
            case .heard(let text): report.events.append(Event(t: t, kind: "heard", text: text))
            case .asked(let query, _): report.events.append(Event(t: t, kind: "asked", text: query))
            case .answered(let question, _, _, _): report.events.append(Event(t: t, kind: "answered", text: question))
            case .spoke(let text): report.events.append(Event(t: t, kind: "spoke", text: text))
            }
        }
        container.sessionController.logObserver = { entry in
            log.append(Event(t: entry.time.timeIntervalSince(start), kind: "log", text: entry.text))
        }

        await model.startMode(.standard)
        report.voiceAtStart = defaults.data(forKey: VoiceSettings.voiceKey)
            .flatMap { try? JSONDecoder().decode(VoiceChoice.self, from: $0) }.map { "\($0.kind.rawValue):\($0.voiceID)" } ?? "none"

        var said = false
        while Date().timeIntervalSince(start) < 80 {
            try await Task.sleep(for: .seconds(1))
            let t = Date().timeIntervalSince(start)
            let notices = model.visibleNotices
            let problem = model.problem.map { String(describing: $0) } ?? ""
            report.samples.append(Sample(t: t, active: model.isActiveSession, listening: model.isListening,
                                         hearing: model.isHearing, problem: problem, notices: notices,
                                         speaking: model.speaker.isSpeaking))
            if notices.contains(ListeningModel.fallbackLine) {
                report.noticeSeconds += 1
                report.noticeFirstAt = report.noticeFirstAt ?? t
            }
            if model.isListening, model.isHearing, model.problem == .cannotHear { report.lyssnarWithCannotHear += 1 }
            if !model.isActiveSession {
                report.sessionEndedEarly = t
                break
            }
            // After both questions: one sentence in the chosen (ElevenLabs) voice, whatever the recogniser heard.
            if !said, t > 50 {
                said = true
                model.speaker.enqueue(Self.lyssnarSentence, language: .swedish)
            }
        }
        // Let the sentence finish.
        let speakDeadline = Date().addingTimeInterval(15)
        while model.speaker.isSpeaking, Date() < speakDeadline { try await Task.sleep(for: .milliseconds(200)) }

        report.seconds = Date().timeIntervalSince(start)
        report.stubHits = OutageStub.snapshot()
        report.voiceFallbacks = model.speaker.fallbackCount
        report.spoken = model.speaker.spokenCount
        report.log = log.map { String(format: "%7.2f ", $0.t) + $0.text }
        report.standInLines = log.filter { $0.text.contains("Stand-in engine") }.count
        if model.isActiveSession { await model.endSession() }
        if model.isActiveSession { await model.endSession() } // A19.2: a second tap ends at once
        model.sessionObserver = nil
        container.sessionController.logObserver = nil
        try write(report)

        #expect(report.stubHits.contains("/functions/v1/stt-token"), "Scribe was never tried (no /stt-token)")
        #expect(report.sessionEndedEarly == nil, "the session ended by itself at \(report.sessionEndedEarly ?? 0) s")
        #expect(report.standInLines == 1, "A45 line logged \(report.standInLines) times, expected once")
        #expect(report.noticeSeconds > 0, "'\(ListeningModel.fallbackLine)' never visible")
        #expect(report.stubHits.contains("/functions/v1/tts"), "the ElevenLabs voice was never tried (no /tts)")
        #expect(report.voiceFallbacks >= 1 && report.spoken >= 1,
                "not silent: \(report.voiceFallbacks) voice fallbacks, \(report.spoken) spoken")
        #expect(report.lyssnarWithCannotHear == 0,
                "'Lyssnar' and 'Jag hör inte just nu' at the same time for \(report.lyssnarWithCannotHear) s")
    }

    private func write(_ report: Report) throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let url = out.appendingPathComponent("outage.json")
        try encoder.encode(report).write(to: url)
        print("T10 result: \(url.path) stub hits \(report.stubHits.count), stand-in lines \(report.standInLines), "
              + "spoken \(report.spoken), voice fallbacks \(report.voiceFallbacks)")
    }
}
