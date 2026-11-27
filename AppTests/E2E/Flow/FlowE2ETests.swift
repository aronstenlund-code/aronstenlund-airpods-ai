import Foundation
import Testing
@testable import Lumen

/// T59 (Toby, Deangelo 2026-11-27 01:17): what came on main with D269 (the common flow), Ke91/D268 (English command
/// words) and K124/D267 (the phone's voice when ElevenLabs' quota is out), from the app's own wiring (`AppContainer`).
/// A `URLProtocol` in the test process plays the server: `/answer` fails (504 `timeout`, or no connection) or answers
/// with a short server-sent-events stream; `/tts` answers 503 `tts_quota` (`fallback: true`), as the real one does
/// when the quota is out; `/stt-token` is closed. Nothing reaches Claude or ElevenLabs (D180), and no live `/answer`.
/// Questions come in through `submitText` (the text field) and `receiveFinalTranscript` (as Scribe's text, T17c);
/// Scribe is off. Output: `<LUMEN_E2E_OUT>/flow.jsonl`. Simulator only: never a verification on a device.
enum FlowEnvironment {
    static var silence: URL? { ProcessInfo.processInfo.environment["LUMEN_E2E_FLOW_SILENCE"].map { URL(fileURLWithPath: $0) } }
    static var out: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMEN_E2E_OUT"] ?? NSTemporaryDirectory()) }
}

final class FlowStub: URLProtocol, @unchecked Sendable {
    enum Answer: Sendable { case timeout, offline, text(String) }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var answer: Answer = .timeout
    nonisolated(unsafe) private static var hits: [(path: String, body: String)] = []
    static let answerPath = "/functions/v1/answer"
    static let ttsPath = "/functions/v1/tts"
    static let closed = [answerPath, ttsPath, "/functions/v1/stt-token"]

    static func set(_ value: Answer) { lock.lock(); answer = value; lock.unlock() }
    static func snapshot() -> [(path: String, body: String)] { lock.lock(); defer { lock.unlock() }; return hits }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.host?.hasSuffix("supabase.co") == true else { return false }
        return closed.contains(url.path)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private static func body(of request: URLRequest) -> String {
        if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return String(decoding: data, as: UTF8.self)
    }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.lock()
        Self.hits.append((url.path, Self.body(of: request)))
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
        case Self.ttsPath:
            // K124 (D267): the quota is out; the app reads with the phone's own voice.
            reply(503, "application/json", #"{"error":{"code":"tts_quota","message":"T59: the voice quota is out (test)","fallback":true}}"#)
        case Self.answerPath:
            switch answer {
            case .timeout:
                reply(504, "application/json", #"{"error":{"code":"timeout","message":"T59: too slow (test)"}}"#)
            case .offline:
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            case .text(let text):
                let delta = String(data: try! JSONEncoder().encode(["text": text]), encoding: .utf8)!
                reply(200, "text/event-stream", "event: delta\ndata: \(delta)\n\nevent: done\ndata: {\"answered\":true}\n\n")
            }
        default:
            reply(503, "application/json", #"{"error":{"code":"upstream_unavailable","message":"T59: closed in the test (D180)","fallback":true}}"#)
        }
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized, .enabled(if: FlowEnvironment.silence != nil, "set LUMEN_E2E_FLOW_SILENCE (scripts/apptest/t59.sh)"))
struct FlowE2ETests {
    struct Outcome: Codable {
        var id: String
        var verdict = ""
        var notes: [String] = []
        var answerBodies: [String] = []
        var log: [String] = []
    }

    // MARK: D269 (1): Försök igen asks the question that failed

    @Test(arguments: ["timeout", "offline"])
    func tryAgainAsksTheQuestionThatFailed(_ failure: String) async throws {
        var out = Outcome(id: "try-again-\(failure)")
        let (container, model, logs) = try await start(language: "sv-SE", speak: false)
        FlowStub.set(.text("Pi är ungefär 3,14."))
        model.submitText("vad är pi")
        _ = await waitUntil(20) { model.conversation.answers.count >= 1 && !model.isAnswering }
        let first = model.conversation.answers.last?.answer ?? "-"
        out.notes.append("first question answered: \(first)")

        FlowStub.set(failure == "offline" ? .offline : .timeout)
        let before = answers().count
        model.submitText("vad är fotosyntes")
        let expected: LumenProblem = failure == "offline" ? .offline : .overloaded
        let carded = await waitUntil(25) { model.problem == expected && !model.isAnswering }
        out.notes.append("after the failure: problem \(model.problem.map { "\($0)" } ?? "none")")

        FlowStub.set(.text("Växter gör socker och syre av ljus, vatten och koldioxid."))
        let beforeRetry = answers().count
        model.act(on: expected) // the card's "Försök igen"
        let answered = await waitUntil(25) { model.conversation.answers.last?.answer.contains("Växter gör socker") == true && !model.isAnswering }
        let retried = Array(answers().dropFirst(beforeRetry))
        out.answerBodies = Array(answers().dropFirst(before)).map { String($0.prefix(400)) }
        out.notes.append("after Försök igen: \(retried.count) /answer, last answer \(model.conversation.answers.last.map { String($0.answer.prefix(80)) } ?? "-"), problem \(model.problem.map { "\($0)" } ?? "none")")

        var wrong: [String] = []
        if !carded { wrong.append("no \(expected) card after the failure") }
        if retried.isEmpty { wrong.append("Försök igen asked nothing") }
        if let body = retried.first, !body.contains("fotosyntes") { wrong.append("Försök igen did not ask the failed question") }
        if retried.contains(where: { $0.contains("vad är pi") && !$0.contains("fotosyntes") }) { wrong.append("Försök igen asked the answered question") }
        if !answered { wrong.append("no answer after Försök igen") }
        if model.problem != nil { wrong.append("the card stayed") }
        try await finish(&out, wrong, container, model, logs)
    }

    // MARK: D269 (2): Pausa pauses in the "Mer?" window

    @Test func pauseOnTheScreenPausesInTheMoreWindow() async throws {
        var out = Outcome(id: "pause-in-more-window")
        let (container, model, logs) = try await start(language: "sv-SE", speak: false)
        FlowStub.set(.text("Kort svar."))
        model.submitText("vad är en atom")
        _ = await waitUntil(20) { model.conversation.answers.count >= 1 && !model.isAnswering }
        let offering = await waitUntil(5) { model.isOfferingMore }
        out.notes.append("Mer? window open after the answer: \(offering)")
        await model.togglePause(fromScreen: true)
        let paused: Bool = { if case .paused = model.state { true } else { false } }()
        out.notes.append("after Pausa on the screen: \(model.state.label)")
        var wrong: [String] = []
        if !paused { wrong.append("Pausa did not pause (state \(model.state.label), Mer? \(offering))") }
        if !offering { out.notes.append("note: no Mer? window this time, so the pause was the ordinary one") }
        try await finish(&out, wrong, container, model, logs)
    }

    // MARK: Ke91 / D268: English command words

    @Test func lumenContinueResumesInEnglish() async throws {
        var out = Outcome(id: "en-lumen-continue")
        let (container, model, logs) = try await start(language: "en-US", speak: false)
        await model.togglePause(fromScreen: true)
        let paused: Bool = { if case .paused = model.state { true } else { false } }()
        out.notes.append("paused: \(model.state.label)")
        model.receivePartialTranscript("Lumen, continue", at: Date())
        try await Task.sleep(for: .milliseconds(300))
        model.receiveFinalTranscript("Lumen, continue", at: Date())
        let resumed = await waitUntil(10) { model.state == .listening }
        out.notes.append("after \"Lumen, continue\": \(model.state.label)")
        var wrong: [String] = []
        if !paused { wrong.append("could not pause first") }
        if !resumed { wrong.append("\"Lumen, continue\" did not resume (\(model.state.label))") }
        if answers().contains(where: { $0.lowercased().contains("continue") }) { wrong.append("\"Lumen, continue\" went to /answer as a question") }
        try await finish(&out, wrong, container, model, logs)
    }

    @Test func quizMeIsOneCheckQuestionInEnglish() async throws {
        var out = Outcome(id: "en-quiz-me")
        let (container, model, logs) = try await start(language: "en-US", speak: false)
        FlowStub.set(.text("What does chlorophyll do?"))
        let before = answers().count
        model.receivePartialTranscript("Lumen, quiz me", at: Date())
        try await Task.sleep(for: .milliseconds(300))
        model.receiveFinalTranscript("Lumen, quiz me", at: Date())
        _ = await waitUntil(20) { answers().count > before && !model.isAnswering }
        try await Task.sleep(for: .seconds(1))
        let asked = Array(answers().dropFirst(before))
        out.answerBodies = asked.map { String($0.prefix(500)) }
        out.notes.append("mode \(model.mode), /answer \(asked.count), mini test running: \(logs.lines.contains { $0.localizedCaseInsensitiveContains("minitest") || $0.localizedCaseInsensitiveContains("mini test") })")
        var wrong: [String] = []
        if asked.isEmpty { wrong.append("\"quiz me\" asked nothing") }
        // D268 (2): one check question (`MiniTest.checkQuestionQuery`), not the mini test.
        if !asked.isEmpty, !asked.contains(where: { $0.contains("ask one check question") || $0.localizedCaseInsensitiveContains("quiz me") }) {
            wrong.append("the request was not the check question")
        }
        try await finish(&out, wrong, container, model, logs)
    }

    // MARK: K124 / D267: the phone's voice when /tts says tts_quota

    @Test func thePhonesVoiceReadsWhenTheVoiceQuotaIsOut() async throws {
        var out = Outcome(id: "tts-quota-phone-voice")
        let (container, model, logs) = try await start(language: "sv-SE", speak: true)
        let speaker = container.speaker
        FlowStub.set(.text("Fotosyntesen gör socker av ljus."))
        let fallbacksBefore = speaker.fallbackCount
        let spokenBefore = speaker.spokenCount
        let ttsBefore = FlowStub.snapshot().filter { $0.path == FlowStub.ttsPath }.count
        model.submitText("vad gör fotosyntesen")
        _ = await waitUntil(25) { model.conversation.answers.count >= 1 && !model.isAnswering }
        _ = await waitUntil(20) { speaker.spokenCount > spokenBefore }
        try await Task.sleep(for: .seconds(2))
        let firstTts = FlowStub.snapshot().filter { $0.path == FlowStub.ttsPath }.count - ttsBefore
        out.notes.append("answer 1: /tts \(firstTts) (all stopped in the test), fallbacks \(speaker.fallbackCount - fallbacksBefore), spoken \(speaker.spokenCount - spokenBefore), notice \(speaker.notice ?? "-")")
        out.notes.append("lines on Lyssnar: \(model.visibleNotices)")

        // A second answer within K124's ten minutes: is /tts asked again?
        FlowStub.set(.text("Klorofyll fångar ljuset."))
        let ttsMid = FlowStub.snapshot().filter { $0.path == FlowStub.ttsPath }.count
        let spokenMid = speaker.spokenCount
        model.submitText("vad gör klorofyll")
        _ = await waitUntil(25) { model.conversation.answers.count >= 2 && !model.isAnswering }
        _ = await waitUntil(20) { speaker.spokenCount > spokenMid }
        try await Task.sleep(for: .seconds(2))
        let secondTts = FlowStub.snapshot().filter { $0.path == FlowStub.ttsPath }.count - ttsMid
        out.notes.append("answer 2: /tts \(secondTts), spoken \(speaker.spokenCount - spokenMid)")

        var wrong: [String] = []
        if firstTts < 1 { wrong.append("the ElevenLabs voice was not asked for (test set-up)") }
        if speaker.fallbackCount <= fallbacksBefore { wrong.append("no fallback to the phone's voice") }
        if speaker.spokenCount <= spokenBefore { wrong.append("nothing was spoken") }
        if !model.visibleNotices.contains(ListeningModel.fallbackLine) && !model.visibleNotices.contains(where: { $0.localizedCaseInsensitiveContains("telefonens röst") }) {
            wrong.append("no short line on Lyssnar that the phone's voice reads (\(model.visibleNotices))")
        }
        try await finish(&out, wrong, container, model, logs)
    }

    // MARK: Helpers

    final class Logs { var lines: [String] = [] }

    private func start(language: String, speak: Bool) async throws -> (AppContainer, ListeningModel, Logs) {
        URLProtocol.registerClass(FlowStub.self)
        let silence = try #require(FlowEnvironment.silence)
        setenv("LUMEN_AUDIO_FILES", silence.path, 1)
        setenv("LUMEN_AUDIO_LOOP", "1", 1)
        setenv("LUMEN_AUDIO_GAP", "0", 1)
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: STTSettings.cloudKey) // D180: never Scribe, never /stt-token
        defaults.set(speak, forKey: VoiceSettings.speakKey)
        let voice = speak ? VoiceChoice(kind: .elevenLabs, voiceID: "t59-test-voice", name: "T59") : VoiceChoice.appleDefault
        defaults.set(try JSONEncoder().encode(voice), forKey: VoiceSettings.voiceKey) // /tts only to the stub
        defaults.set(language, forKey: LanguageSettings.defaultsKey)
        defaults.set("none", forKey: "OnDeviceMock") // no phone model: a failure is a failure (A159)
        let container = AppContainer()
        let model = container.listening
        container.consent.grant()
        let logs = Logs()
        let t0 = Date()
        container.sessionController.logObserver = { entry in
            logs.lines.append(String(format: "%7.2f ", entry.time.timeIntervalSince(t0)) + entry.text)
        }
        await model.startMode(.standard)
        try await Task.sleep(for: .seconds(10)) // as T57: the anonymous sign-in of a new session
        return (container, model, logs)
    }

    private func answers() -> [String] {
        FlowStub.snapshot().filter { $0.path == FlowStub.answerPath }.map(\.body)
    }

    private func waitUntil(_ seconds: Double, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return condition()
    }

    private func finish(_ out: inout Outcome, _ wrong: [String], _ container: AppContainer, _ model: ListeningModel, _ logs: Logs) async throws {
        if model.isActiveSession { await model.endSession() }
        container.sessionController.logObserver = nil
        UserDefaults.standard.removeObject(forKey: "OnDeviceMock")
        unsetenv("LUMEN_AUDIO_LOOP")
        out.verdict = wrong.isEmpty ? "ok" : wrong.joined(separator: "; ")
        out.log = logs.lines.filter { $0.contains("Fel") || $0.contains("Command") || $0.contains("voice") || $0.contains("Answer") || $0.contains("retry") || $0.contains("paus") || $0.contains("Paus") || $0.contains("Mer") }.suffix(40).map { String($0.prefix(240)) }
        let url = FlowEnvironment.out.appending(path: "flow.jsonl")
        var data = try JSONEncoder().encode(out)
        data.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
        print("T59 \(out.id): \(out.verdict); \(out.notes.joined(separator: " | "))")
        #expect(out.verdict == "ok", "\(out.id): \(out.verdict)")
    }
}
