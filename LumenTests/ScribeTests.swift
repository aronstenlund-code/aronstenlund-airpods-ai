import Foundation
import Testing
@testable import Lumen

/// Scripted socket: `incoming` is handed out by `receive()`; when it runs dry `receive()` waits, or throws after `fail()`.
final class FakeScribeSocket: ScribeSocket, @unchecked Sendable {
    // @unchecked: every access goes through the lock.
    private let lock = NSLock()
    private var incoming: [String] = []
    private var waiter: CheckedContinuation<String, any Error>?
    private var didFail = false
    private var sentMessages: [String] = []
    private var closed = false

    var sent: [String] { lock.withLock { sentMessages } }
    var isClosed: Bool { lock.withLock { closed } }

    func deliver(_ text: String) {
        lock.withLock {
            if let waiter {
                self.waiter = nil
                waiter.resume(returning: text)
            } else {
                incoming.append(text)
            }
        }
    }

    func fail() {
        lock.withLock {
            didFail = true
            waiter?.resume(throwing: URLError(.networkConnectionLost))
            waiter = nil
        }
    }

    func send(_ text: String) async throws {
        lock.withLock { sentMessages.append(text) }
    }

    func receive() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                if !incoming.isEmpty {
                    continuation.resume(returning: incoming.removeFirst())
                } else if didFail {
                    continuation.resume(throwing: URLError(.networkConnectionLost))
                } else {
                    waiter = continuation
                }
            }
        }
    }

    func close() {
        lock.withLock { closed = true }
        fail()
    }
}

@Suite struct ScribeMessageTests {
    @Test func readsTheSocketMessages() {
        #expect(ScribeMessage.parse("{\"message_type\":\"partial_transcript\",\"text\":\"vad är\"}") == .partial("vad är"))
        #expect(ScribeMessage.parse("{\"message_type\":\"committed_transcript\",\"text\":\"vad är pi\"}") == .committed("vad är pi"))
        #expect(ScribeMessage.parse("{\"message_type\":\"committed_transcript_with_timestamps\",\"text\":\"pi\"}") == .committed("pi"))
        #expect(ScribeMessage.parse("{\"message_type\":\"session_started\"}") == .other)
        #expect(ScribeMessage.parse("{\"message_type\":\"warning\",\"text\":\"Zero retention mode not applied\"}") == .other)
        #expect(ScribeMessage.parse("{\"message_type\":\"quota_exceeded\",\"error\":\"no credits\"}") == .failure("quota_exceeded: no credits"))
        #expect(ScribeMessage.parse("not json") == .other)
    }

    @Test func audioIsLittleEndianBase64() throws {
        let message = ScribeMessage.audio([1, -2], commit: true)
        let json = try #require(try JSONSerialization.jsonObject(with: Data(message.utf8)) as? [String: Any])
        #expect(json["message_type"] as? String == "input_audio_chunk")
        #expect(json["commit"] as? Bool == true)
        #expect(json["sample_rate"] as? Int == 16_000)
        let base64 = try #require(json["audio_base_64"] as? String)
        #expect(Data(base64Encoded: base64) == Data([0x01, 0x00, 0xFE, 0xFF]))
    }

    @Test func theSocketURLCarriesLanguageKeytermsAndThePrivacyParameters() throws {
        let token = ScribeToken(token: "t1", model_id: "scribe_v2_realtime", ws_url: "wss://api.elevenlabs.io/v1/speech-to-text/realtime",
                                language_code: "swe", extra_query: "enable_logging=false&filter_background_audio=true")
        let url = try #require(token.url(language: .swedish, keyterms: (0..<30).map { "term\($0)" }))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        #expect(value("token") == "t1")
        #expect(value("language_code") == "swe")
        #expect(value("audio_format") == "pcm_16000")
        #expect(value("commit_strategy") == "vad")
        #expect(value("enable_logging") == "false")
        #expect(value("filter_background_audio") == "true")
        #expect(items.filter { $0.name == "keyterms" }.count == ScribeProvider.keytermLimit)

        let english = try #require(token.url(language: .english, keyterms: []))
        #expect(english.absoluteString.contains("language_code=eng"))
    }
}

@MainActor
@Suite struct ScribeProviderTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
    private let tokenJSON = "{\"token\":\"t1\",\"expires_in\":900,\"model_id\":\"scribe_v2_realtime\",\"ws_url\":\"wss://example.com/rt\",\"language_code\":\"swe\"}"

    private func makeProvider(_ http: FakeHTTP, socket: FakeScribeSocket) -> ScribeProvider {
        let session = SupabaseSession(accessToken: "jwt", refreshToken: "r", expiresAt: Date().addingTimeInterval(3_600))
        return ScribeProvider(locale: Locale(identifier: "sv-SE"), language: .swedish, config: config,
                              auth: SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http), http: http,
                              makeSocket: { _ in socket })
    }

    @Test func aRefusedTokenFailsPrepare() async {
        let provider = makeProvider(FakeHTTP([.init(status: 401, body: "{\"error\":{\"code\":\"missing_permissions\"}}")]), socket: FakeScribeSocket())
        do {
            try await provider.prepare()
            Issue.record("expected failure")
        } catch {
            #expect(error.localizedDescription.contains("missing_permissions"))
        }
    }

    @Test func streamsAudioDeliversResultsAndReportsTheSeconds() async throws {
        let http = FakeHTTP([.init(status: 200, body: tokenJSON), .init(status: 200, body: "{}")])
        let socket = FakeScribeSocket()
        let provider = makeProvider(http, socket: socket)
        try await provider.prepare()
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer jwt")

        let (audio, feed) = AsyncStream<AudioChunk>.makeStream()
        try await provider.start(audio: audio)
        feed.yield(AudioChunk(samples: [Int16](repeating: 1, count: 16_000), hostTime: 0, firstSampleIndex: 0))
        #expect(await waitUntil { socket.sent.count == 1 })

        socket.deliver("{\"message_type\":\"partial_transcript\",\"text\":\"vad\"}")
        socket.deliver("{\"message_type\":\"committed_transcript\",\"text\":\"vad är pi\"}")
        var received: [STTResult] = []
        for await result in provider.results {
            received.append(result)
            if received.count == 2 { break }
        }
        #expect(received == [STTResult(text: "vad", isFinal: false), STTResult(text: "vad är pi", isFinal: true)])

        provider.commit()
        #expect(await waitUntil { socket.sent.count == 2 })
        #expect(socket.sent[1].contains("\"commit\":true"))

        await provider.stop()
        #expect(socket.isClosed)
        #expect(http.requests.count == 2)
        #expect(http.requests[1].httpMethod == "POST")
        #expect(http.requests[1].httpBody == Data("{\"seconds\":1}".utf8))
    }
}

@MainActor
@Suite struct ScribeFallbackTests {
    private func makeCoordinator(_ h: ControllerHarness, useCloud: Bool = true,
                                 available: SpeechEngineAvailability = SpeechEngineAvailability(speechTranscriberLocales: ["sv-se"])) -> (TranscriptionCoordinator, Recorder) {
        let suite = "lumen.tests.stt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = STTSettings(defaults: defaults)
        settings.useCloud = useCloud
        let recorder = Recorder()
        let coordinator = TranscriptionCoordinator(controller: h.controller,
                                                   language: LanguageSettings(defaults: defaults, systemLocale: Locale(identifier: "sv_SE")),
                                                   settings: settings,
                                                   probe: { _ in available },
                                                   makeProvider: { locale, engine in
            let provider = FakeSTTProvider(locale: locale, engine: engine)
            if engine == .scribe { provider.prepareError = recorder.scribeError }
            recorder.created.append(provider)
            return provider
        })
        return (coordinator, recorder)
    }

    @MainActor final class Recorder {
        var created: [FakeSTTProvider] = []
        var scribeError: STTError?
    }

    @Test func scribeIsTheDefaultAndSaysSo() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h)
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.scribe) })
        #expect(recorder.created.map(\.engine) == [.scribe])
    }

    @Test func aRefusedTokenFallsBackToThePhone() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h)
        recorder.scribeError = .startFailed(detail: "missing_permissions")
        await h.controller.start()

        #expect(await waitUntil { coordinator.status == .running(.speechTranscriber) })
        #expect(coordinator.cloudFailure?.contains("missing_permissions") == true)
    }

    @Test func aLostConnectionFallsBackDuringTheSession() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h)
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.scribe) })

        recorder.created[0].emit.finish()

        #expect(await waitUntil { coordinator.status == .running(.speechTranscriber) })
        #expect(coordinator.cloudFailure != nil)
    }

    @Test func aNewSessionTriesScribeAgain() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h)
        recorder.scribeError = .startFailed(detail: "offline")
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.speechTranscriber) })
        await h.controller.stop()

        recorder.scribeError = nil
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.scribe) })
        #expect(coordinator.cloudFailure == nil)
    }

    @Test func stoppingNormallyIsNotAFailure() async {
        let h = ControllerHarness()
        let (coordinator, _) = makeCoordinator(h)
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.scribe) })

        await h.controller.stop()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.cloudFailure == nil)
        #expect(coordinator.status == .idle)
    }

    @Test func theSwitchStaysOnThePhone() async {
        let h = ControllerHarness()
        let (coordinator, recorder) = makeCoordinator(h, useCloud: false)
        await h.controller.start()
        #expect(await waitUntil { coordinator.status == .running(.speechTranscriber) })
        #expect(recorder.created.map(\.engine) == [.speechTranscriber], "no audio leaves the phone")

        await coordinator.setUseCloud(true)
        #expect(await waitUntil { coordinator.status == .running(.scribe) })
    }
}
