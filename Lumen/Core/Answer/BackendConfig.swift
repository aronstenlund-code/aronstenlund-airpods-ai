import Foundation

/// Kevin's Supabase backend (`backend/README.md`, "Connect the app"). The publishable key is public by design:
/// it grants nothing without a user JWT and may be embedded (D2 still holds — no provider keys in the app).
struct BackendConfig: Sendable, Equatable {
    var projectURL: URL
    var publishableKey: String

    var answerURL: URL { projectURL.appending(path: "functions/v1/answer") }
    var ttsURL: URL { projectURL.appending(path: "functions/v1/tts") }
    var voicesURL: URL { projectURL.appending(path: "functions/v1/voices") }
    var sttTokenURL: URL { projectURL.appending(path: "functions/v1/stt-token") }
    var feedbackURL: URL { projectURL.appending(path: "functions/v1/feedback") }
    /// D80: memory extraction after a turn (Kevin builds it).
    var memoryURL: URL { projectURL.appending(path: "functions/v1/memory") }
    /// D81 (Kevin): study cards and a five-question test from a Provläge session.
    var studyCardsURL: URL { projectURL.appending(path: "functions/v1/study-cards") }
    var sharedHistoryURL: URL { projectURL.appending(path: "functions/v1/shared-history") }
    var signUpURL: URL { projectURL.appending(path: "auth/v1/signup") }
    var refreshURL: URL {
        projectURL.appending(path: "auth/v1/token").appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])
    }

    static let lumen = BackendConfig(projectURL: URL(string: "https://xjczbzfkmbjdebwlccki.supabase.co")!,
                                     publishableKey: "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8")
}
