import Foundation

/// O97 (Kevin, deploy 370): when the model behind EarMind is out of credits, busy or down, /answer, /exam and /drill
/// answer 503 (or 502) with a `provider_*` code and `fallback: true`. The app then says one short line of its own in
/// the chosen language. The server's `message` is not shown for these codes: it has been technical before ("LLM
/// credits exhausted"), and nothing guarantees that the next one is not. The spoken answers already go by the code
/// (`ListeningModel.problem`: "Jag kan inte svara just nu"); this is the same for the exams.
enum ServerTrouble {
    static func isProvider(_ code: String?) -> Bool {
        code?.hasPrefix("provider_") == true
    }

    static var line: String { String(localized: "EarMind kan inte svara just nu. Försök igen om en stund.") }
}

extension URLRequest {
    /// The language chosen in Inställningar (A157, D253) as `x-earmind-lang`, so the server's own words to the user
    /// (limits, refusals) come in that language and not in the phone's. Called next to `markTestTraffic()` where the
    /// server's message can reach the screen.
    mutating func markLanguage() {
        setValue(AppLanguage.current.code, forHTTPHeaderField: "x-earmind-lang")
    }
}
