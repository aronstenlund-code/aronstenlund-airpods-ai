import Foundation
import Testing
@testable import Lumen

@MainActor
@Suite struct SupabaseAuthTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func signsUpAnonymouslyAndStoresTheSession() async throws {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt1", refresh: "r1", expiresIn: 3600))])
        let store = InMemorySessionStore()
        let auth = SupabaseAuth(config: config, store: store, http: http, now: { t0 })

        let token = try await auth.accessToken()

        #expect(token == "jwt1")
        #expect(http.requests.count == 1)
        #expect(http.requests[0].url == config.signUpURL)
        #expect(http.requests[0].httpMethod == "POST")
        #expect(http.requests[0].value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == nil, "never the publishable key as bearer")
        #expect(String(decoding: http.requests[0].httpBody ?? Data(), as: UTF8.self) == "{}")
        #expect(store.load() == SupabaseSession(accessToken: "jwt1", refreshToken: "r1", expiresAt: t0.addingTimeInterval(3600)))

        _ = try await auth.accessToken()
        #expect(http.requests.count == 1, "a valid cached token is reused")
    }

    @Test func refreshesAnExpiredSession() async throws {
        let expired = SupabaseSession(accessToken: "old", refreshToken: "r-old", expiresAt: t0.addingTimeInterval(30))
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt2", refresh: "r2"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(expired), http: http, now: { t0 })

        let token = try await auth.accessToken()

        #expect(token == "jwt2")
        #expect(http.requests[0].url?.absoluteString == "https://example.supabase.co/auth/v1/token?grant_type=refresh_token")
        #expect(http.json(0)["refresh_token"] as? String == "r-old")
    }

    @Test func refreshFailureFallsBackToANewAnonymousUser() async throws {
        let expired = SupabaseSession(accessToken: "old", refreshToken: "r-old", expiresAt: t0)
        let http = FakeHTTP([.init(status: 400, body: "{\"error\":\"invalid_grant\"}"),
                             .init(status: 200, body: Fixtures.tokenJSON(access: "jwt3"))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(expired), http: http, now: { t0 })

        #expect(try await auth.accessToken() == "jwt3")
        #expect(http.requests.map { $0.url?.path } == ["/auth/v1/token", "/auth/v1/signup"])
    }

    @Test func anonymousSignInDisabledIsAClearError() async {
        let http = FakeHTTP([.init(status: 422, body: "{\"code\":422,\"error_code\":\"anonymous_provider_disabled\",\"msg\":\"Anonymous sign-ins are disabled\"}")])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { t0 })
        do {
            _ = try await auth.accessToken()
            Issue.record("expected an error")
        } catch {
            guard case .unauthorized(let detail) = AnswerError.from(error) else { Issue.record("wrong error \(error)"); return }
            #expect(detail.contains("anonymous_provider_disabled"))
            #expect(detail.contains("422"))
        }
    }

    @Test func offlineIsReported() async {
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.notConnectedToInternet))])
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(), http: http, now: { t0 })
        do {
            _ = try await auth.accessToken()
            Issue.record("expected an error")
        } catch {
            #expect(AnswerError.from(error) == .offline)
        }
    }
}

@MainActor
@Suite struct CloudAnswerProviderTests {
    private let config = BackendConfig(projectURL: URL(string: "https://example.supabase.co")!, publishableKey: "sb_publishable_test")
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeProvider(_ http: FakeHTTP, session: SupabaseSession? = nil) -> CloudAnswerProvider {
        let auth = SupabaseAuth(config: config, store: InMemorySessionStore(session), http: http, now: { t0 })
        return CloudAnswerProvider(config: config, auth: auth, http: http)
    }

    private var validSession: SupabaseSession {
        SupabaseSession(accessToken: "jwt-valid", refreshToken: "r", expiresAt: t0.addingTimeInterval(3600))
    }

    private func collect(_ stream: AsyncThrowingStream<AnswerEvent, any Error>) async throws -> [AnswerEvent] {
        var out: [AnswerEvent] = []
        for try await event in stream { out.append(event) }
        return out
    }

    @Test func signsUpThenStreamsTheAnswer() async throws {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.tokenJSON(access: "jwt1")),
                             .init(status: 200, body: Fixtures.answerSSE)])
        let provider = makeProvider(http)
        let activation = ActivationRequest(query: "roten ur hundra", trigger: .answerLast, language: .swedish)
        let context = AnswerContext(transcript: "läraren pratade om tal", recentQA: [AnswerContext.QA(q: "q", a: "a")], prepTerms: ["kvadratrot"])

        let events = try await collect(provider.answer(AnswerRequest(activation: activation, context: context)))

        #expect(events.count == 4)
        #expect(events[1] == .delta("Roten ur hundra "))
        #expect(http.requests.count == 2)
        let answer = http.requests[1]
        #expect(answer.url == config.answerURL)
        #expect(answer.value(forHTTPHeaderField: "Authorization") == "Bearer jwt1")
        #expect(answer.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(answer.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = http.json(1)
        #expect(body["fragment"] as? String == "roten ur hundra")
        #expect(body["mode"] as? String == "push_to_talk")
        #expect(body["language"] as? String == "sv")
        let ctx = body["context"] as? [String: Any]
        #expect(ctx?["transcript"] as? String == "läraren pratade om tal")
        #expect((ctx?["recent_qa"] as? [[String: String]])?.first == ["q": "q", "a": "a"])
        #expect(ctx?["prep_terms"] as? [String] == ["kvadratrot"])
    }

    @Test func emptyContextMembersAreOmitted() {
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "x", mode: "text", language: "en"))
        let json = String(decoding: data, as: UTF8.self)
        #expect(json == "{\"context\":{},\"fragment\":\"x\",\"language\":\"en\",\"length\":\"adaptive\",\"mode\":\"text\"}")
    }

    @Test func retriesOnceAfter401WithAFreshSession() async throws {
        let http = FakeHTTP([.init(status: 401, body: "{\"error\":{\"code\":\"unauthorized\",\"message\":\"expired\"}}"),
                             .init(status: 200, body: Fixtures.tokenJSON(access: "jwt-new")),
                             .init(status: 200, body: Fixtures.answerSSE)])
        let provider = makeProvider(http, session: validSession)

        let events = try await collect(provider.answer(AnswerRequest(fragment: "x", mode: "text", language: "sv")))

        #expect(events.count == 4)
        #expect(http.requests.map { $0.url?.path } == ["/functions/v1/answer", "/auth/v1/signup", "/functions/v1/answer"])
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer jwt-valid")
        #expect(http.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer jwt-new")
    }

    @Test func secondConsecutive401IsUnauthorized() async {
        let http = FakeHTTP([.init(status: 401, body: "{}"),
                             .init(status: 200, body: Fixtures.tokenJSON(access: "jwt-new")),
                             .init(status: 401, body: "{\"error\":{\"code\":\"unauthorized\"}}")])
        let provider = makeProvider(http, session: validSession)
        do {
            _ = try await collect(provider.answer(AnswerRequest(fragment: "x", mode: "text", language: "sv")))
            Issue.record("expected an error")
        } catch {
            guard case .unauthorized = AnswerError.from(error) else { Issue.record("wrong error \(error)"); return }
        }
    }

    @Test func backendErrorBodyBecomesABackendErrorWithFallback() async {
        let http = FakeHTTP([.init(status: 503, body: "{\"error\":{\"code\":\"provider_quota\",\"message\":\"credits exhausted\",\"fallback\":true}}")])
        let provider = makeProvider(http, session: validSession)
        do {
            _ = try await collect(provider.answer(AnswerRequest(fragment: "x", mode: "text", language: "sv")))
            Issue.record("expected an error")
        } catch {
            let answerError = AnswerError.from(error)
            #expect(answerError == .backend(status: 503, failure: AnswerFailure(code: "provider_quota", message: "credits exhausted", fallback: true)))
            #expect(answerError.wantsFallback)
        }
    }

    @Test func errorEventMidStreamIsYieldedThenThrown() async {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.streamErrorSSE)])
        let provider = makeProvider(http, session: validSession)
        var events: [AnswerEvent] = []
        do {
            for try await event in provider.answer(AnswerRequest(fragment: "x", mode: "text", language: "sv")) {
                events.append(event)
            }
            Issue.record("expected an error")
        } catch {
            #expect(events.count == 3)
            #expect(events.last == .error(AnswerFailure(code: "provider_error", message: "upstream closed", fallback: true)))
            #expect(AnswerError.from(error) == .backend(status: 200, failure: AnswerFailure(code: "provider_error", message: "upstream closed", fallback: true)))
        }
    }

    @Test func autoModeNotAQuestionStreamsMetaAndDone() async throws {
        let http = FakeHTTP([.init(status: 200, body: Fixtures.notAQuestionSSE)])
        let provider = makeProvider(http, session: validSession)
        let events = try await collect(provider.answer(AnswerRequest(fragment: "idag pratar vi om celler", mode: "auto", language: "sv")))
        #expect(events.count == 2)
        guard case .meta(let meta) = events[0] else { Issue.record("expected meta"); return }
        #expect(!meta.isQuestion)
    }

    @Test func offlineIsReportedAsOffline() async {
        let http = FakeHTTP([.init(status: 0, body: "", error: URLError(.networkConnectionLost))])
        let provider = makeProvider(http, session: validSession)
        do {
            _ = try await collect(provider.answer(AnswerRequest(fragment: "x", mode: "text", language: "sv")))
            Issue.record("expected an error")
        } catch {
            #expect(AnswerError.from(error) == .offline)
            #expect(AnswerError.offline.wantsFallback)
        }
    }
}
