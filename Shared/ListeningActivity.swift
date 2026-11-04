import ActivityKit
import AppIntents

/// The Lock Screen / Dynamic Island presence of a listening session (D33). Compiled into the app and `LumenControls`.
struct ListeningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
    }
}

/// How the intent reaches the running session. Set by `AppContainer`; stays nil in the widget extension.
@MainActor
enum ListeningRemote {
    static var toggle: (@MainActor () async -> Void)?
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
