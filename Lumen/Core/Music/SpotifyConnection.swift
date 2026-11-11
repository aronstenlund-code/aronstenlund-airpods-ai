import Foundation
import Observation

/// A59 (K36, docs/AGENT.md "Spotify, protokollet"): Spotify control through the server (Web API, OAuth). A pilot for
/// testers: playback needs Premium, and a Spotify app in Development Mode takes at most 5 accounts that Aron adds.
/// The phone keeps only whether it is connected (to send `connections: ["spotify"]` with `/answer`); the tokens are
/// encrypted on the server and never reach the phone.
@MainActor
@Observable
final class SpotifyConnection {
    static let connectedKey = "connections.spotify"
    static let premiumKey = "connections.spotify.premium"

    /// The server has Spotify's keys: only then is "Koppla Spotify" shown.
    private(set) var isAvailable = false
    private(set) var isConnected: Bool {
        didSet { defaults.set(isConnected, forKey: Self.connectedKey) }
    }
    /// False: connected, but playback needs Premium.
    private(set) var hasPremium: Bool? {
        didSet { defaults.set(hasPremium, forKey: Self.premiumKey) }
    }
    private(set) var notice: String?

    @ObservationIgnored private let client: ConnectClient?
    @ObservationIgnored private let defaults: UserDefaults

    init(client: ConnectClient?, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        isConnected = defaults.bool(forKey: Self.connectedKey)
        hasPremium = defaults.object(forKey: Self.premiumKey) as? Bool
    }

    /// What `/answer` gets: the connected services.
    var connections: [String] { isConnected ? ["spotify"] : [] }

    func refresh() async {
        guard let client, let status = await client.status() else { return }
        isAvailable = status.available?["spotify"] == true
        let spotify = status.connections.first { $0.provider == "spotify" }
        isConnected = spotify != nil
        hasPremium = spotify?.premium
    }

    /// The address to open in the web authentication session.
    func connectURL() async -> URL? {
        guard let client else { return nil }
        notice = nil
        guard let url = await client.start() else {
            notice = "Det gick inte att koppla Spotify just nu."
            return nil
        }
        return url
    }

    /// `lumen://connect?provider=spotify&status=…` back from the server.
    func finish(_ callback: URL) async {
        notice = Self.notice(for: callback)
        await refresh()
    }

    func disconnect() async {
        guard let client else { return }
        if await client.disconnect() {
            isConnected = false
            hasPremium = nil
            notice = nil
        }
    }

    nonisolated static func notice(for callback: URL) -> String? {
        let status = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "status" }?.value
        switch status {
        case "ok": return nil
        case "premium_required": return "Kopplat, men Spotify spelar bara upp med Premium."
        case "denied": return "Du sa nej i Spotify. Inget kopplades."
        default: return "Det gick inte att koppla Spotify just nu."
        }
    }
}

/// `/connect` (K36).
@MainActor
final class ConnectClient {
    struct Status: Decodable, Equatable, Sendable {
        struct Connection: Decodable, Equatable, Sendable {
            var provider: String
            var premium: Bool?
        }
        var connections: [Connection]
        var available: [String: Bool]?
    }

    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func status() async -> Status? {
        guard let reply = await send("GET", url: config.connectURL), reply.code == 200 else { return nil }
        return try? JSONDecoder().decode(Status.self, from: reply.data)
    }

    func start() async -> URL? {
        struct Reply: Decodable { var url: String }
        guard let body = try? JSONEncoder().encode(["provider": "spotify"]),
              let sent = await send("POST", url: config.connectURL, body: body), sent.code == 200,
              let reply = try? JSONDecoder().decode(Reply.self, from: sent.data) else { return nil }
        return URL(string: reply.url)
    }

    func disconnect() async -> Bool {
        let url = config.connectURL.appending(queryItems: [URLQueryItem(name: "provider", value: "spotify")])
        return await send("DELETE", url: url)?.code == 200
    }

    private func send(_ method: String, url: URL, body: Data? = nil) async -> (code: Int, data: Data)? {
        do {
            let token = try await auth.accessToken()
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            }
            request.timeoutInterval = 15
            let (response, data) = try await http.data(for: request)
            if response.statusCode != 200 { Log.answer.error("connect: HTTP \(response.statusCode, privacy: .public)") }
            return (response.statusCode, data)
        } catch {
            return nil
        }
    }
}

/// `done.server_tool` (K36): a tool the server ran (Spotify), for the log.
struct ServerToolResult: Codable, Equatable, Sendable {
    var name: String
    var status: String
    var playing: String?
}
