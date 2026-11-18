import Foundation
import Testing
@testable import Lumen

/// Serves an SSE body shaped like the live `/answer` through a real `URLSession`: `FakeHTTP` cannot catch
/// what `URLSession` does to the bytes.
final class SSEStubProtocol: URLProtocol, @unchecked Sendable {
    static let body = Data("""
    event: meta
    data: {"reconstructed_question":"roten ur hundra","confidence":1,"is_question":true,"needs_confirmation":false}

    event: delta
    data: {"text":"Roten ur hundra är tio."}

    event: done
    data: {"answered":true,"timing":{"meta_ms":3466},"breakdown":{"direct":true,"cold":true},"usage":{"input_tokens":510,"output_tokens":14}}


    """.utf8)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "text/event-stream; charset=utf-8"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite struct URLSessionSSETests {
    private let url = URL(string: "https://example.supabase.co/functions/v1/answer")!

    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SSEStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Why `URLSessionHTTP.lines` splits the bytes itself.
    @Test func asyncBytesLinesDropsTheBlankLinesSSENeeds() async throws {
        let (bytes, _) = try await stubbedSession().bytes(for: URLRequest(url: url))
        var lines: [String] = []
        for try await line in bytes.lines { lines.append(line) }
        #expect(!lines.contains(""))
    }

    @Test func everyEventOfALiveShapedStreamIsDecoded() async throws {
        let http = URLSessionHTTP(session: stubbedSession())
        let (_, lines) = try await http.lines(for: URLRequest(url: url))
        var parser = SSELineParser()
        var events: [AnswerEvent] = []
        for try await line in lines {
            if let event = parser.feed(line), let decoded = try AnswerSSEDecoder.decode(event) {
                events.append(decoded)
            }
        }
        #expect(events.count == 3)
        #expect(events.dropFirst().first == AnswerEvent.delta("Roten ur hundra är tio."))
        guard case .done(let done) = events.last else { Issue.record("expected done"); return }
        #expect(done.usage?.outputTokens == 14)
    }
}

@MainActor
@Suite struct BackendWarmerTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")

    @Test func pingsAnswerAndTTSWithoutAUserToken() async {
        let http = FakeHTTP([.init(status: 204, body: ""), .init(status: 204, body: "")])
        await BackendWarmer(config: config, http: http).warm()

        #expect(http.requests.map(\.url) == [config.answerURL, config.ttsURL])
        for request in http.requests {
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "x-warm") == "1")
            #expect(request.value(forHTTPHeaderField: "apikey") == "pk")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    @Test func isThrottledAndSurvivesFailures() async {
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.notConnectedToInternet)),
                             .init(status: 204, body: ""),
                             .init(status: 204, body: ""),
                             .init(status: 204, body: "")])
        let warmer = BackendWarmer(config: config, http: http)
        let start = Date(timeIntervalSince1970: 1_000)

        await warmer.warm(now: start)
        await warmer.warm(now: start.addingTimeInterval(BackendWarmer.minimumInterval - 1))
        #expect(http.requests.count == 2)
        await warmer.warm(now: start.addingTimeInterval(BackendWarmer.minimumInterval))
        #expect(http.requests.count == 4)
    }
}

@MainActor
@Suite struct SupabaseAuthRenewalTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")

    @Test func concurrentCallersShareOneSignIn() async throws {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http)

        async let first = auth.accessToken()
        async let second = auth.accessToken()
        let tokens = try await [first, second]

        #expect(tokens == ["jwt", "jwt"])
        #expect(http.requests.count == 1)
    }

    @Test func goingOfflineDuringRefreshKeepsTheSession() async {
        let expired = SupabaseSession(accessToken: "old", refreshToken: "r1", expiresAt: Date(timeIntervalSince1970: 0))
        let store = InMemorySessionStore(expired)
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.notConnectedToInternet))])
        let auth = SupabaseAuth(config: config, store: store, http: http)

        do {
            _ = try await auth.accessToken()
            Issue.record("expected offline")
        } catch {
            #expect(AnswerError.from(error) == .offline)
        }
        #expect(store.load() == expired, "a new anonymous user would orphan the old one")
        #expect(http.requests.count == 1, "no sign-up attempt")
    }

    // MARK: A143 (D225 point 4): the sign-in never holds the user back, and the account is kept

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func expiredSession() -> SupabaseSession {
        SupabaseSession(accessToken: "old", refreshToken: "r1", expiresAt: t0.addingTimeInterval(-10))
    }

    /// Lets the background sign-in run until `done` (the fake network answers at once).
    private func settle(until done: () -> Bool) async {
        for _ in 0..<200 where !done() { await Task.yield() }
    }

    @Test func theSignInStartsWhenTheAppOpens() async throws {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { t0 })

        auth.prepare()
        await settle { auth.hasSession }

        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/signup"], "signed in before anyone asked for a token")
        #expect(try await auth.accessToken() == "jwt")
        #expect(http.requests.count == 1, "the first call finds the token there")
    }

    @Test func aCallDuringTheSignInAtAppOpenSharesIt() async throws {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { t0 })

        auth.prepare()
        #expect(try await auth.accessToken() == "jwt")
        #expect(http.requests.count == 1, "one anonymous user, not one for the app start and one for the call")
    }

    @Test func aTokenWithLittleLeftIsRenewedAheadAndNobodyWaits() async throws {
        let soon = SupabaseSession(accessToken: "old", refreshToken: "r1", expiresAt: t0.addingTimeInterval(120))
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt2", refresh: "r2"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(soon), http: http, now: { t0 })

        #expect(try await auth.accessToken() == "old", "still valid: no call waits")
        #expect(http.requests.isEmpty)
        auth.prepare()
        await settle { !http.requests.isEmpty }
        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/token"], "renewed in the background")

        // The renewal's answer is stored on the main actor's next turns; meanwhile the old token still answers.
        var token = "old"
        for _ in 0..<200 where token == "old" {
            await Task.yield()
            token = (try? await auth.accessToken()) ?? "old"
        }
        #expect(token == "jwt2")
        #expect(http.requests.count == 1)
    }

    @Test func aFreshTokenIsLeftAloneWhenTheAppOpens() async {
        let fresh = SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600))
        let http = FakeHTTP()
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(fresh), http: http, now: { t0 })

        auth.prepare()
        for _ in 0..<50 { await Task.yield() }

        #expect(http.requests.isEmpty)
    }

    @Test func aSignUpThatGetsNoAnswerIsTriedOnceMore() async throws {
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.timedOut)),
                             .init(status: 200, body: Fixtures.tokenJSON(access: "jwt"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { t0 })

        #expect(try await auth.accessToken() == "jwt")
        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/signup", "/auth/v1/signup"])
        #expect(http.requests[0].timeoutInterval == SupabaseAuth.requestTimeout, "8 s, not the system's 60 s")
    }

    @Test func aRefreshThatGetsNoAnswerIsTriedOnceMoreWithTheSameToken() async throws {
        let store = InMemorySessionStore(expiredSession())
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.timedOut)),
                             .init(status: 200, body: Fixtures.tokenJSON(access: "jwt2", refresh: "r2"))])
        let auth = SupabaseAuth(config: config, store: store, http: http, now: { t0 })

        #expect(try await auth.accessToken() == "jwt2")
        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/token", "/auth/v1/token"], "never a new sign-up")
        #expect(http.json(1)["refresh_token"] as? String == "r1")
        #expect(store.load()?.refreshToken == "r2")
    }

    @Test func twoTimeoutsInARowGiveUpAndKeepTheAccount() async {
        let expired = expiredSession()
        let store = InMemorySessionStore(expired)
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.timedOut)),
                             .init(status: 0, body: "", error: URLError(.timedOut))])
        let auth = SupabaseAuth(config: config, store: store, http: http, now: { t0 })

        do {
            _ = try await auth.accessToken()
            Issue.record("expected an error")
        } catch {
            #expect(AnswerError.from(error) == .transport(detail: "timed out"))
        }
        #expect(http.requests.count == 2, "one more try, not more")
        #expect(store.load() == expired)
    }

    /// Before A143 every answer that was not a success made a new anonymous user, also the server's own trouble.
    @Test(arguments: [429, 500, 502, 503])
    func theServersTroubleDuringRefreshKeepsTheAccount(status: Int) async {
        let expired = expiredSession()
        let store = InMemorySessionStore(expired)
        let http = FakeHTTP([.init(status: status, body: "{\"code\":\(status),\"error_code\":\"over_request_rate_limit\",\"msg\":\"busy\"}")])
        let auth = SupabaseAuth(config: config, store: store, http: http, now: { t0 })

        do {
            _ = try await auth.accessToken()
            Issue.record("expected an error")
        } catch {
            guard case .backend(let got, _) = AnswerError.from(error) else { Issue.record("wrong error \(error)"); return }
            #expect(got == status)
        }
        #expect(store.load() == expired, "the account and its refresh token are kept")
        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/token"], "no new anonymous user")
    }

    @Test func onlyARefusedRefreshTokenStartsANewAccount() {
        #expect([400, 401, 403, 404].allSatisfy(SupabaseAuth.refusesTheRefreshToken))
        #expect(![408, 429, 500, 502, 503, 504].contains(where: SupabaseAuth.refusesTheRefreshToken))
    }

    /// A 401 from one of our functions: the token is renewed with the refresh token. Before A143 the session was
    /// thrown away, and the next call made a new anonymous user.
    @Test func a401FromOurFunctionsRenewsTheTokenAndKeepsTheAccount() async throws {
        let valid = SupabaseSession(accessToken: "jwt", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600))
        let store = InMemorySessionStore(valid)
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt2", refresh: "r2"))])
        let auth = SupabaseAuth(config: config, store: store, http: http, now: { t0 })

        auth.invalidate()

        #expect(auth.hasSession)
        #expect(store.load()?.refreshToken == "r1", "the refresh token is still on the phone")
        #expect(try await auth.accessToken() == "jwt2")
        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/token"])
        #expect(http.json(0)["refresh_token"] as? String == "r1")
    }
}

@MainActor
@Suite struct VoiceReconcileTests {
    private let adam = VoiceChoice(kind: .elevenLabs, voiceID: "a1", name: "Adam")
    private let elin = VoiceChoice(kind: .elevenLabs, voiceID: "e1", name: "Elin")

    @Test func adoptsTheServerDefaultUntilTheUserPicks() {
        let settings = freshVoiceSettings()
        settings.reconcile(with: [adam, elin], defaultID: "e1")
        #expect(settings.voice == elin)

        settings.voice = .appleDefault
        settings.reconcile(with: [adam, elin], defaultID: "e1")
        #expect(settings.voice == .appleDefault, "an explicit Apple choice stays")
    }

    @Test func aVoiceTheBackendDroppedIsReplaced() {
        let settings = freshVoiceSettings()
        settings.voice = VoiceChoice(kind: .elevenLabs, voiceID: "gone", name: "Old")
        settings.reconcile(with: [adam], defaultID: nil)
        #expect(settings.voice == adam)

        settings.reconcile(with: [], defaultID: nil)
        #expect(settings.voice == .appleDefault)
    }

    @Test func modelAppliesTheCatalogToTheSettings() async {
        let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "pk")
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt")),
                             .init(status: 200, body: "{\"voices\":[{\"name\":\"Adam\",\"id\":\"a1\"}],\"default_id\":\"a1\"}")])
        let catalog = VoiceCatalog(config: config, auth: SupabaseAuth(config: config, store: InMemorySessionStore(), http: http), http: http)
        let h = ControllerHarness()
        let speaker = makeTestSpeaker(h.playback)
        let model = ListeningModel(controller: h.controller, consent: FakeConsentStore(granted: true), transcription: makeTestCoordinator(h.controller), activation: makeTestActivation(), answers: makeTestAnswerEngine(), speaker: speaker, voices: catalog, notes: makeTestNotes(), prep: makeTestPrep())

        await model.prepareBackend()

        #expect(speaker.settings.voice == adam)
        #expect(catalog.defaultID == "a1")
    }
}

@MainActor
@Suite struct FirstSpeechTests {
    @MainActor final class Started {
        var providers: [String] = []
    }

    @Test func isMarkedWhenAudioIsScheduledNotWhenTheRequestStarts() async {
        let playback = FakePlaybackService()
        let premium = FakeTTSProvider(name: "elevenlabs")
        premium.delay = .milliseconds(500)
        let speaker = Speaker(settings: freshVoiceSettings(), apple: FakeTTSProvider(name: "apple"), premium: premium, playback: playback)
        speaker.settings.voice = VoiceChoice(kind: .elevenLabs, voiceID: "v1", name: "Adam")
        let started = Started()
        speaker.onSentenceStarted = { started.providers.append($0) }

        speaker.enqueue("Hej.", language: .swedish)
        for _ in 0..<100 where premium.calls.isEmpty {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(premium.calls.count == 1)
        #expect(started.providers.isEmpty, "the /tts request is running, nothing is audible yet")

        playback.onAudioScheduled?()
        playback.onAudioScheduled?()
        #expect(started.providers == ["elevenlabs"])
        speaker.interrupt()
    }
}
