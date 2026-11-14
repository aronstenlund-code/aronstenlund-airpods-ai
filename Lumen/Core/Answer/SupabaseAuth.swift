import Foundation
import Security

/// An anonymous Supabase session (`POST /auth/v1/signup` with `{}`); refreshed with the refresh token.
struct SupabaseSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    func isValid(at date: Date, margin: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(date) > margin
    }
}

protocol SessionStore: AnyObject, Sendable {
    func load() -> SupabaseSession?
    func save(_ session: SupabaseSession)
    func clear()
}

/// Keychain-backed store (the session token is a credential for our backend; never UserDefaults).
final class KeychainSessionStore: SessionStore {
    private let service: String
    private let account = "anonymous-session"

    init(service: String = "com.rsolutions.lumen.supabase") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> SupabaseSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    func save(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            _ = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    func clear() {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }
}

final class InMemorySessionStore: SessionStore, @unchecked Sendable {
    // @unchecked: only touched from the main actor in the app and in tests.
    private var session: SupabaseSession?
    init(_ session: SupabaseSession? = nil) { self.session = session }
    func load() -> SupabaseSession? { session }
    func save(_ session: SupabaseSession) { self.session = session }
    func clear() { session = nil }
}

/// Signs in anonymously and keeps the token fresh (`backend/README.md` "Connect the app").
@MainActor
final class SupabaseAuth {
    let config: BackendConfig
    private let store: any SessionStore
    private let http: any HTTPStreaming
    private let now: @Sendable () -> Date
    private var session: SupabaseSession?
    /// The running sign-in or refresh, shared by everyone who needs a token meanwhile.
    private var renewal: Task<String, any Error>?

    init(config: BackendConfig, store: any SessionStore, http: any HTTPStreaming, now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.store = store
        self.http = http
        self.now = now
        self.session = store.load()
    }

    var hasSession: Bool { session != nil }

    /// A valid access token: cached, refreshed, or from a fresh anonymous sign-up.
    func accessToken() async throws(AnswerError) -> String {
        if let session, session.isValid(at: now()) {
            return session.accessToken
        }
        // The voices and the warm-up run together at launch: one sign-in, not one anonymous user per caller.
        let task: Task<String, any Error>
        if let renewal {
            task = renewal
        } else {
            task = Task { [self] in
                defer { renewal = nil }
                return try await renewToken()
            }
            renewal = task
        }
        do {
            return try await task.value
        } catch {
            throw AnswerError.from(error)
        }
    }

    private func renewToken() async throws(AnswerError) -> String {
        if let session, !session.refreshToken.isEmpty {
            do {
                return try await refresh(session).accessToken
            } catch {
                // Refresh token rejected → start over with a new anonymous user. Offline keeps the session.
                guard case .unauthorized = AnswerError.from(error) else { throw AnswerError.from(error) }
                invalidate()
            }
        }
        return try await signUp().accessToken
    }

    /// Forget the session (after a 401) so the next call signs in again.
    func invalidate() {
        session = nil
        store.clear()
    }

    private func signUp() async throws(AnswerError) -> SupabaseSession {
        var request = URLRequest(url: config.signUpURL)
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return try await perform(request)
    }

    private func refresh(_ old: SupabaseSession) async throws(AnswerError) -> SupabaseSession {
        var request = URLRequest(url: config.refreshURL)
        request.httpMethod = "POST"
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.markTestTraffic() // T24: x-earmind-test in Debug UI tests
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["refresh_token": old.refreshToken])
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws(AnswerError) -> SupabaseSession {
        let response: HTTPURLResponse
        let data: Data
        do {
            (response, data) = try await http.data(for: request)
        } catch {
            throw AnswerError.from(error)
        }
        guard (200..<300).contains(response.statusCode) else {
            let failure = AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode)
            throw AnswerError.unauthorized(detail: "\(failure.code)\(failure.message.map { " — \($0)" } ?? "") (HTTP \(response.statusCode))")
        }
        struct TokenResponse: Decodable {
            var access_token: String
            var refresh_token: String?
            var expires_in: Double?
            var expires_at: Double?
        }
        let token: TokenResponse
        do {
            token = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AnswerError.decoding(detail: "auth: \(error.localizedDescription)")
        }
        let expiresAt: Date = if let at = token.expires_at {
            Date(timeIntervalSince1970: at)
        } else {
            now().addingTimeInterval(token.expires_in ?? 3600)
        }
        let newSession = SupabaseSession(accessToken: token.access_token, refreshToken: token.refresh_token ?? "", expiresAt: expiresAt)
        session = newSession
        store.save(newSession)
        return newSession
    }
}
