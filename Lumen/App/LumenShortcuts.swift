import AppIntents

/// "Fråga Lumen": one hands-free question, then the microphone goes off again.
struct AskLumenIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Lumen"
    static let supportedModes: IntentModes = .foreground

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ListeningRemote.ask?()
        return .result()
    }
}

struct StartProvlageIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Provläge"
    static let supportedModes: IntentModes = .foreground

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ListeningRemote.startStudy?()
        return .result()
    }
}

/// Lets go of the audio like the Pause button (D33). Needs no screen.
struct PauseLumenIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Lumen"
    static let supportedModes: IntentModes = .background

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ListeningRemote.pause?()
        return .result()
    }
}

/// Siri phrases (D58). The app opens for everything that switches the microphone on, so consent and the rule that
/// capture starts in the foreground still hold.
struct LumenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartListeningIntent(),
                    phrases: ["Starta \(.applicationName)", "Start \(.applicationName)"],
                    shortTitle: "Start Lumen", systemImageName: "mic.fill")
        AppShortcut(intent: AskLumenIntent(),
                    phrases: ["Fråga \(.applicationName)", "Ask \(.applicationName)"],
                    shortTitle: "Ask Lumen", systemImageName: "questionmark.bubble")
        AppShortcut(intent: StartProvlageIntent(),
                    phrases: ["Starta provläge med \(.applicationName)"],
                    shortTitle: "Start Provläge", systemImageName: "graduationcap")
        AppShortcut(intent: PauseLumenIntent(),
                    phrases: ["Pausa \(.applicationName)", "Pause \(.applicationName)"],
                    shortTitle: "Pause Lumen", systemImageName: "pause.circle")
    }
}
