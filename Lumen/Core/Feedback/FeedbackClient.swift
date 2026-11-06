import Foundation
import Observation

/// "Dela historik för att förbättra appen" (D57): off until the user says yes, plus the random id of this install.
@MainActor
@Observable
final class ShareSettings {
    static let sharingKey = "share.enabled"
    static let askedKey = "share.asked"
    static let installKey = "share.installID"
    static let throughKey = "share.through"
    static let deleteKey = "share.deletePending"

    private(set) var isSharing: Bool
    /// The onboarding question has been answered.
    private(set) var hasAsked: Bool
    /// No name, no e-mail: only ties a report or shared row to this install.
    let installID: String
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isSharing = defaults.bool(forKey: Self.sharingKey)
        self.hasAsked = defaults.bool(forKey: Self.askedKey)
        if let stored = defaults.string(forKey: Self.installKey) {
            self.installID = stored
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: Self.installKey)
            self.installID = fresh
        }
    }

    /// Everything up to here has been uploaded.
    var sharedThrough: Date? {
        get { defaults.object(forKey: Self.throughKey) as? Date }
        set { defaults.set(newValue, forKey: Self.throughKey) }
    }

    /// The user opted out and the server has not confirmed the deletion yet.
    var deleteIsPending: Bool {
        get { defaults.bool(forKey: Self.deleteKey) }
        set { defaults.set(newValue, forKey: Self.deleteKey) }
    }

    func setSharing(_ sharing: Bool) {
        isSharing = sharing
        hasAsked = true
        defaults.set(sharing, forKey: Self.sharingKey)
        defaults.set(true, forKey: Self.askedKey)
        if sharing {
            sharedThrough = nil
            deleteIsPending = false
        } else {
            deleteIsPending = true
        }
    }
}

/// `POST /feedback` and `POST|DELETE /shared-history` (D57). Only the user's own words and the assistant's answers
/// ever go here; callers pass nil for a question that was someone else's speech.
@MainActor
final class FeedbackClient {
    static let batchLimit = 50

    private struct Feedback: Encodable {
        var install_id: String
        var type: String
        var fragment: String?
        var answer: String?
        var comment: String?
        var mode: String?
        var persona: String?
        var timings: [String: Double]?
        var app_version: String?
    }

    private struct SharedItem: Encodable {
        var fragment: String
        var answer: String
        var summary: String?
    }

    private struct SharedBatch: Encodable {
        var install_id: String
        var items: [SharedItem]
    }

    private struct Opt: Encodable {
        var install_id: String
    }

    let settings: ShareSettings
    private let config: BackendConfig
    private let auth: SupabaseAuth
    private let http: any HTTPStreaming
    private var isSyncing = false

    init(config: BackendConfig, auth: SupabaseAuth, http: any HTTPStreaming, settings: ShareSettings) {
        self.config = config
        self.auth = auth
        self.http = http
        self.settings = settings
    }

    /// `type`: `report` | `app` | `suggestion`.
    func send(type: String, fragment: String? = nil, answer: String? = nil, comment: String? = nil,
              mode: String? = nil, persona: String? = nil, timings: [String: Double]? = nil) async throws(AnswerError) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        try await post(config.feedbackURL, method: "POST",
                       body: Feedback(install_id: settings.installID, type: type, fragment: fragment?.nilIfEmpty, answer: answer?.nilIfEmpty,
                                      comment: comment?.nilIfEmpty, mode: mode, persona: persona, timings: timings, app_version: version))
    }

    /// Catches up: uploads what is new when sharing is on, and finishes an opt-out that failed earlier.
    func sync(_ entries: [HistoryEntry]) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            if settings.deleteIsPending {
                try await post(config.sharedHistoryURL, method: "DELETE", body: Opt(install_id: settings.installID))
                settings.deleteIsPending = false
            }
            guard settings.isSharing else { return }
            let through = settings.sharedThrough ?? .distantPast
            let fresh = entries.filter { $0.createdAt > through }.sorted { $0.createdAt < $1.createdAt }
            for start in stride(from: 0, to: fresh.count, by: Self.batchLimit) {
                let batch = fresh[start..<min(fresh.count, start + Self.batchLimit)]
                let items = batch.compactMap { entry -> SharedItem? in
                    guard let question = entry.question, !entry.answer.isEmpty else { return nil }
                    return SharedItem(fragment: question, answer: entry.answer, summary: entry.summary)
                }
                if !items.isEmpty {
                    try await post(config.sharedHistoryURL, method: "POST", body: SharedBatch(install_id: settings.installID, items: items))
                }
                settings.sharedThrough = batch.last?.createdAt
            }
        } catch {
            Log.answer.error("Shared history not synced: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func post(_ url: URL, method: String, body: some Encodable) async throws(AnswerError) {
        let token = try await auth.accessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try? JSONEncoder().encode(body)
        let response: HTTPURLResponse
        let data: Data
        do {
            (response, data) = try await http.data(for: request)
        } catch {
            throw AnswerError.from(error)
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 { auth.invalidate() }
            throw .backend(status: response.statusCode, failure: AnswerSSEDecoder.decodeErrorBody(data, status: response.statusCode))
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
