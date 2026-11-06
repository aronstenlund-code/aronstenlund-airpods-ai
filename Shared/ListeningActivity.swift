import ActivityKit
import AppIntents

/// The Lock Screen / Dynamic Island presence of a listening session (D33). Compiled into the app and `LumenControls`.
struct ListeningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
        /// Rizzläge: all options, best first (D43).
        var suggestions: [String] = []
        var currentSuggestion = 0
    }
}

/// How the intent reaches the running session. Set by `AppContainer`; stays nil in the widget extension.
@MainActor
enum ListeningRemote {
    static var toggle: (@MainActor () async -> Void)?
    static var nextSuggestion: (@MainActor () -> Void)?
    static var start: (@MainActor () async -> Void)?
    static var ask: (@MainActor () async -> Void)?
    static var startStudy: (@MainActor () async -> Void)?
    static var pause: (@MainActor () async -> Void)?
}

/// "Starta Lumen" from Siri or a Control (D58). Runs with the app open: the microphone only starts from the app,
/// after consent, and the listening state is on screen from the first second.
struct StartListeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Lumen"
    static let supportedModes: IntentModes = .foreground

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ListeningRemote.start?()
        return .result()
    }
}

/// "Nästa" on the Live Activity: speak the next Rizzläge suggestion.
struct NextSuggestionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next suggestion"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ListeningRemote.nextSuggestion?()
        return .result()
    }
}

/// Pause/Resume from the Live Activity or a Control (D33). `LiveActivityIntent` runs in the app's process;
/// `AudioRecordingIntent` is what lets a resume reach the microphone without opening the app.
struct ToggleListeningIntent: LiveActivityIntent, AudioRecordingIntent {
    static let title: LocalizedStringResource = "Pause or resume Lumen"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ListeningRemote.toggle?()
        return .result()
    }
}
