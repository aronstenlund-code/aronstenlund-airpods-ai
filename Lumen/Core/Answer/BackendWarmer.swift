import Foundation

/// Wakes `/answer` and `/tts` ahead of the first question (D31): `GET` + `x-warm: 1`, answered 204 without a user
/// token (verified live 2026-11-04). Free, so failures are only logged; the real request reports its own errors.
@MainActor
final class BackendWarmer {
    static let minimumInterval: TimeInterval = 60

    private let config: BackendConfig
    private let http: any HTTPStreaming
    private var lastWarmAt: Date?

    init(config: BackendConfig, http: any HTTPStreaming) {
        self.config = config
        self.http = http
    }

    func warm(now: Date = Date()) async {
        if let lastWarmAt, now.timeIntervalSince(lastWarmAt) < Self.minimumInterval { return }
        lastWarmAt = now
        for url in [config.answerURL, config.ttsURL] {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("1", forHTTPHeaderField: "x-warm")
            request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
            request.timeoutInterval = 10
            do {
                let (response, _) = try await http.data(for: request)
                Log.answer.info("warm \(url.lastPathComponent, privacy: .public): HTTP \(response.statusCode, privacy: .public)")
            } catch {
                Log.answer.error("warm \(url.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
