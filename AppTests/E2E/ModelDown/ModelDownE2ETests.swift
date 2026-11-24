import Foundation
import Testing
@testable import Lumen

/// T57 (Toby, D258): the app while the server's model is down. A `URLProtocol` in the test process answers `/answer`
/// with `503 provider_quota` (what the real server says when the model's credits are out), so nothing reaches Claude;
/// `/stt-token` and `/tts` answer 503 too (D180: never ElevenLabs, also by mistake). The phone's model is Angela's
/// pretend one (A159, `OnDeviceMock` in the test builds), since the Simulator has no Foundation Models.
///
/// Part 1 (A159): a question in the listening gets the phone model's answer, in the language that was spoken
/// ("Jag svarar med telefonens egen modell." / "Answering with the phone's own model." and the pretend sentence), or
/// "Jag kan inte svara just nu" when the phone has no model or not that language. The server is asked once per
/// question when the phone answers (twice when it cannot: the ask ahead and the final one), and the month's credits are
/// the same before and after (the real `/drill quota`).
/// Part 2 (A160: practise a saved exam while the model is down) comes when A160 is on main.
///
/// Recorded questions go into `ListeningModel` the way Scribe's text does (T17c), Scribe is off, the capture plays
/// silence. Output: `<LUMEN_E2E_OUT>/modeldown.json`. Simulator only: never a verification on a device.
enum ModelDownEnvironment {
    static var silence: URL? { ProcessInfo.processInfo.environment["LUMEN_E2E_MODELDOWN_SILENCE"].map { URL(fileURLWithPath: $0) } }
    static var out: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory()) }
}

/// `/answer` says the model is out of credits; the two ElevenLabs paths are closed. Everything else is the real backend.
final class ModelDownStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var hits: [String] = []
    static let answer = "/functions/v1/answer"
    static let closed = [answer, "/functions/v1/stt-token", "/functions/v1/tts"]

    static func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return hits
    }

    private static func record(_ path: String) {
        lock.lock(); hits.append(path); lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.host?.hasSuffix("supabase.co") == true else { return false }
        return closed.contains(url.path)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        Self.record(url.path)
        let body = url.path == Self.answer
            ? Data(#"{"error":{"code":"provider_quota","message":"T57: the model is out of credits (test)","fallback":true}}"#.utf8)
            : Data(#"{"error":{"code":"upstream_unavailable","message":"T57: closed in the test (D180)","fallback":true}}"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized, .enabled(if: ModelDownEnvironment.silence != nil, "set LUMEN_E2E_MODELDOWN_SILENCE (scripts/apptest/t57.sh)"))
struct ModelDownE2ETests {
    struct Case: Codable {
        let id: String
        /// `OnDeviceMock`: "sv,en", "en" or "none".
        let mock: String
        let language: String
        let question: String
        /// "phone": the phone model answers with its lead line; "cannot": "Jag kan inte svara just nu".
        let expect: String
    }

    struct CaseResult: Codable {
        let id: String
        let mock: String
        let language: String
        let question: String
        let expect: String
        var answered: [String] = []
        var problem: String = ""
        var answerCalls = 0
        var elevenLabsCalls = 0
        var creditsBefore: Int?
        var creditsAfter: Int?
        var verdict = ""
        var log: [String] = []
    }

    static let cases: [Case] = [
        Case(id: "sv-phone", mock: "sv,en", language: "sv-SE", question: "Vad gör fotosyntesen?", expect: "phone"),
        Case(id: "en-phone", mock: "sv,en", language: "en-US", question: "What does photosynthesis do?", expect: "phone"),
        Case(id: "sv-no-model", mock: "none", language: "sv-SE", question: "Vad gör fotosyntesen?", expect: "cannot"),
        Case(id: "sv-model-only-en", mock: "en", language: "sv-SE", question: "Vad gör fotosyntesen?", expect: "cannot"),
    ]

    @Test func aQuestionWhileTheModelIsDown() async throws {
        URLProtocol.registerClass(ModelDownStub.self)
        defer { URLProtocol.unregisterClass(ModelDownStub.self) }
        var results: [CaseResult] = []
        for item in Self.cases {
            results.append(try await run(item))
        }
        try write(results)
        for one in results {
            #expect(one.verdict == "ok", "\(one.id): \(one.verdict)")
        }
    }

    private func run(_ item: Case) async throws -> CaseResult {
        let silence = try #require(ModelDownEnvironment.silence)
        setenv("LUMEN_AUDIO_FILES", silence.path, 1)
        setenv("LUMEN_AUDIO_LOOP", "1", 1)
        setenv("LUMEN_AUDIO_GAP", "0", 1)
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: STTSettings.cloudKey) // D180: never Scribe, never /stt-token
        defaults.set(false, forKey: VoiceSettings.speakKey) // nothing spoken: the answer is read from the event
        defaults.set(try JSONEncoder().encode(VoiceChoice.appleDefault), forKey: VoiceSettings.voiceKey) // never /tts
        defaults.set(item.language, forKey: LanguageSettings.defaultsKey) // the spoken language (D257)
        defaults.set(item.mock, forKey: "OnDeviceMock") // A159: read when the container is made

        let container = AppContainer()
        let model = container.listening
        container.consent.grant()
        let start = Date()
        var events: [(t: Double, kind: String, text: String)] = []
        model.sessionObserver = { event, date in
            let t = date.timeIntervalSince(start)
            switch event {
            case .heard(let text): events.append((t, "heard", text))
            case .asked(let query, _): events.append((t, "asked", query))
            case .answered(_, let answer, _, let source): events.append((t, "answered", "\(source): \(answer)"))
            case .spoke(let text): events.append((t, "spoke", text))
            }
        }
        container.sessionController.logObserver = { entry in
            events.append((entry.time.timeIntervalSince(start), "log", entry.text))
        }
        var one = CaseResult(id: item.id, mock: item.mock, language: item.language, question: item.question, expect: item.expect)
        await model.repetition?.refreshQuota()
        one.creditsBefore = model.repetition?.quota.map { $0.serverLeft ?? ($0.limit - $0.used) }

        await model.startMode(.standard)
        // As T17c: the anonymous sign-in of a new session takes about 10 s.
        try await Task.sleep(for: .seconds(10))
        let callsBefore = ModelDownStub.snapshot()
        let from = Date().timeIntervalSince(start)
        model.receivePartialTranscript(item.question, at: Date())
        try await Task.sleep(for: .milliseconds(400))
        model.receiveFinalTranscript(item.question, at: Date())
        // Wait for the turn: the phone's answer, or the problem card, at most 20 s.
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
            let answered = events.contains { $0.t >= from && $0.kind == "answered" }
            if (answered || model.problem == .overloaded) && !model.isAnswering { break }
        }
        try await Task.sleep(for: .seconds(1))
        let calls = Array(ModelDownStub.snapshot().dropFirst(callsBefore.count))
        one.answerCalls = calls.filter { $0 == ModelDownStub.answer }.count
        one.elevenLabsCalls = calls.filter { $0 != ModelDownStub.answer }.count
        one.answered = events.filter { $0.t >= from && $0.kind == "answered" }.map(\.text)
        one.problem = model.problem.map { "\($0)" } ?? ""
        if model.isActiveSession { await model.endSession() }

        await model.repetition?.refreshQuota()
        one.creditsAfter = model.repetition?.quota.map { $0.serverLeft ?? ($0.limit - $0.used) }
        model.sessionObserver = nil
        container.sessionController.logObserver = nil
        unsetenv("LUMEN_AUDIO_LOOP")
        defaults.removeObject(forKey: "OnDeviceMock")
        one.log = events.sorted { $0.t < $1.t }.map { String(format: "%7.2f ", $0.t) + "\($0.kind) " + $0.text }
        one.verdict = Self.judge(one)
        print("T57 \(one.id): \(one.verdict); answered \(one.answered); problem \(one.problem); /answer \(one.answerCalls); credits \(one.creditsBefore.map(String.init) ?? "?") → \(one.creditsAfter.map(String.init) ?? "?")")
        return one
    }

    static func judge(_ one: CaseResult) -> String {
        var wrong: [String] = []
        // Run 45250753732: with a phone model the answer asked ahead (on the partial text) is the one used, so the
        // server is asked once. Without one the ahead ask fails, and the final text asks again: twice, both 503, no
        // credits (a finding to Angela Schrute, not a T57 requirement). More than that is wrong.
        let most = one.expect == "phone" ? 1 : 2
        if one.answerCalls < 1 || one.answerCalls > most { wrong.append("/answer asked \(one.answerCalls) times (at most \(most))") }
        if one.elevenLabsCalls != 0 { wrong.append("\(one.elevenLabsCalls) calls to /stt-token or /tts (D180)") }
        if one.creditsBefore == nil || one.creditsBefore != one.creditsAfter {
            wrong.append("credits \(one.creditsBefore.map(String.init) ?? "?") → \(one.creditsAfter.map(String.init) ?? "?")")
        }
        let swedish = one.language.hasPrefix("sv")
        switch one.expect {
        case "phone":
            let lead = swedish ? "Jag svarar med telefonens egen modell." : "Answering with the phone's own model."
            let pretend = swedish ? PretendOnDeviceModel.swedish : PretendOnDeviceModel.english
            let text = one.answered.first ?? ""
            if !text.contains(lead) { wrong.append("no lead line \"\(lead)\" in \"\(text.prefix(160))\"") }
            if !text.contains(pretend) { wrong.append("not the pretend model's sentence") }
            if one.answered.count != 1 { wrong.append("\(one.answered.count) answers") }
        default:
            if !one.answered.isEmpty { wrong.append("answered \"\(one.answered.first?.prefix(120) ?? "")\" without a model for the language") }
            if one.problem != "overloaded" { wrong.append("problem \"\(one.problem)\", not overloaded (Jag kan inte svara just nu)") }
        }
        return wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
    }

    private func write(_ results: [CaseResult]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: ModelDownEnvironment.out, withIntermediateDirectories: true)
        try encoder.encode(results).write(to: ModelDownEnvironment.out.appendingPathComponent("modeldown.json"))
    }
}
