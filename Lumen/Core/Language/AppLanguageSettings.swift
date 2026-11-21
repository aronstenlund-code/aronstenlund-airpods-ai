import Foundation
import Observation
import WidgetKit

/// D253: the language choice as the screens see it. The app starts in English; Inställningar has English and Svenska,
/// and a change shows at once: the root view is built again in the new language (see `AppRoot`), the server gets the
/// new `lang` with the next request, and the widget is drawn again.
@MainActor
@Observable
final class AppLanguageSettings {
    private(set) var language: AppLanguage
    @ObservationIgnored private let choice: LanguageChoice
    @ObservationIgnored private let reloadsWidgets: Bool

    init(choice: LanguageChoice = .shared, reloadsWidgets: Bool = true, defaults: UserDefaults = .standard) {
        self.choice = choice
        self.reloadsWidgets = reloadsWidgets
        language = choice.language
        // The language that is listened for follows the phone's language until the user picks one (LanguageSettings).
        // Asking the system for the app's language below changes what the phone seems to be set to from the next
        // start, so the phone's own answer is written down first: a Swedish phone keeps listening for Swedish.
        if !choice.isSetFromOutside, defaults.string(forKey: LanguageSettings.defaultsKey) == nil {
            defaults.set(TranscriptionLanguage.systemDefault().rawValue, forKey: LanguageSettings.defaultsKey)
        }
        choice.pinSystemLanguage()
    }

    func choose(_ new: AppLanguage) {
        guard new != language else { return }
        choice.set(new)
        language = new
        if reloadsWidgets { WidgetCenter.shared.reloadAllTimelines() }
        Log.repetition.info("Language: \(new.rawValue, privacy: .public) chosen in Inställningar")
    }
}
