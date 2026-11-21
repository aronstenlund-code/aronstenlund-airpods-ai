import Foundation
import Testing
@testable import Lumen

/// A157 (D251, D253): English is the base language and Swedish a translation. The app starts in English on every
/// phone and Svenska is chosen in Inställningar. The unit tests run in Swedish (the scheme names the language, as a
/// test run may), so the English is read from its own table here.
@MainActor
@Suite struct A157LanguageTests {
    private func table(_ language: String) -> Bundle? {
        Bundle.main.path(forResource: language, ofType: "lproj").flatMap { Bundle(path: $0) }
    }

    private func text(_ key: String, in language: String) -> String? {
        table(language)?.localizedString(forKey: key, value: "(missing)", table: nil)
    }

    /// D253 (Aron): "den måste vara på engelska och man ska kunna byta till svenska".
    @Test func theAppStartsInEnglishAlsoOnASwedishPhone() {
        #expect(LanguageChoice.resolve(arguments: [], stored: nil, localizations: ["sv"]) == .en)
        #expect(LanguageChoice.resolve(arguments: [], stored: nil, localizations: ["en"]) == .en)
        #expect(LanguageChoice.resolve(arguments: [], stored: "sv", localizations: ["en"]) == .sv) // chosen in Inställningar
        #expect(LanguageChoice.resolve(arguments: [], stored: "tlh", localizations: ["sv"]) == .en)
    }

    /// A run that names its language (the tests' scheme, the app tests, the pictures) gets it, as before D253.
    @Test func aRunThatNamesItsLanguageGetsIt() {
        let swedishRun = ["Lumen", "-AppleLanguages", "(sv)"]
        #expect(LanguageChoice.resolve(arguments: swedishRun, stored: "en", localizations: ["sv"]) == .sv)
        #expect(LanguageChoice.resolve(arguments: ["Lumen", "-AppleLanguages", "(en)"], stored: "sv", localizations: ["en"]) == .en)
        #expect(LanguageChoice.resolve(arguments: swedishRun + ["-app.language", "en"], stored: nil, localizations: ["sv"]) == .en)
        #expect(AppLanguage.from(["sv-SE"]) == .sv && AppLanguage.from(["de"]) == .en && AppLanguage.from([]) == .en)
    }

    /// The choice is kept (also where the widget reads it), shows at once, and asks the system for the same language
    /// from the next start.
    @Test func theChoiceIsKeptAndShowsAtOnce() throws {
        let app = try #require(UserDefaults(suiteName: "a157-app-\(UUID().uuidString)"))
        let group = try #require(UserDefaults(suiteName: "a157-group-\(UUID().uuidString)"))
        let systemName = "a157-system-\(UUID().uuidString)"
        let system = try #require(UserDefaults(suiteName: systemName))
        // What the app has written for the system. Read from the store's own values: a plain read of AppleLanguages
        // would give the test run's own "-AppleLanguages (sv)", which stands before every store.
        func pinned() -> [String]? { UserDefaults.standard.persistentDomain(forName: systemName)?["AppleLanguages"] as? [String] }
        let choice = LanguageChoice(arguments: ["Lumen"], stores: [app, group], localizations: ["sv"], rereads: false, systemStore: system)
        #expect(choice.language == .en && !choice.isSetFromOutside)
        let settings = AppLanguageSettings(choice: choice, reloadsWidgets: false, defaults: app)
        #expect(settings.language == .en)
        // What is listened for keeps the phone's language (the tests' phone is Swedish), whatever the texts are in.
        #expect(app.string(forKey: LanguageSettings.defaultsKey) == TranscriptionLanguage.swedish.rawValue)
        #expect(pinned() == ["en"]) // English system buttons from the next start
        settings.choose(.sv)
        #expect(settings.language == .sv && choice.language == .sv)
        #expect(app.string(forKey: LanguageChoice.key) == "sv" && group.string(forKey: LanguageChoice.key) == "sv")
        #expect(pinned() == ["sv"])
        #expect(AppLanguage.stamped(["action": "quota"], language: choice.language)["lang"] as? String == "sv")
        // The next start, and the widget (which reads the shared store every time).
        #expect(LanguageChoice(arguments: ["Lumen"], stores: [app, group], localizations: ["en"], rereads: false, systemStore: nil).language == .sv)
        let widget = LanguageChoice(arguments: ["LumenControls"], stores: [UserDefaults(suiteName: "a157-empty-\(UUID().uuidString)") ?? .standard, group],
                                    localizations: ["en"], rereads: true, systemStore: nil)
        #expect(widget.language == .sv)
        settings.choose(.en)
        #expect(widget.language == .en && AppLanguage.sv.nativeName == "Svenska" && AppLanguage.en.nativeName == "English")
        // A run that named its language leaves the phone's settings alone.
        let named = LanguageChoice(arguments: ["Lumen", "-AppleLanguages", "(sv)"], stores: [app], localizations: ["sv"], rereads: false, systemStore: system)
        named.pinSystemLanguage()
        #expect(named.isSetFromOutside && pinned() == ["en"])
    }

    /// What `String(localized:)` does in the app: the chosen language's table, with the values in place.
    @Test func aTextIsLookedUpInTheChosenLanguage() {
        let english = AppLanguage.en, swedish = AppLanguage.sv
        #expect(String(localized: "Fyll på", table: nil, bundle: english.bundle, locale: english.locale, comment: nil) == "Top up")
        #expect(String(localized: "Fyll på", table: nil, bundle: swedish.bundle, locale: swedish.locale, comment: nil) == "Fyll på")
        let questions = "5 questions"
        #expect(String(localized: "Krediterna räcker till \(questions).", table: nil, bundle: english.bundle, locale: english.locale, comment: nil)
                == "Your credits cover 5 questions.")
        #expect(String(localized: "Du var på fråga \(3) av \(12).", table: nil, bundle: english.bundle, locale: english.locale, comment: nil)
                == "You were on question 3 of 12.")
        #expect(String(localized: "Du var på fråga \(3) av \(12).") == "Du var på fråga 3 av 12.") // the tests' language
    }

    @Test func englishIsTheBaseAndBothLanguagesAreInTheApp() {
        #expect(Bundle.main.developmentLocalization == "en")
        #expect(Set(Bundle.main.localizations).isSuperset(of: ["en", "sv"]))
        #expect(table("en") != nil && table("sv") != nil)
    }

    /// The other tests compare Swedish texts; this one says why they may.
    @Test func theUnitTestsRunInSwedish() {
        #expect(AppLanguage.current == .sv)
        #expect(String(localized: "Fyll på") == "Fyll på")
    }

    /// Kelly's words (docs/design/engelska.md §1): the Swedish text is the key, and each table has its own words.
    @Test func kellysWordsAreInBothTables() {
        let words = [("Fyll på", "Top up"), ("Nytt prov", "New quiz"), ("Starta prov", "Start quiz"),
                     ("Säg i AirPods", "Say in AirPods"), ("Hur ska det låta?", "How should it sound?"),
                     ("Klar", "Done"), ("Avbryt", "Cancel"), ("Veckokort", "Weekly pass"), ("Senaste", "Recent"),
                     ("Blanda röster", "Mix voices"), ("Krediter", "Credits"), ("Försök igen", "Try again"),
                     ("Öppna länk", "Open link"), ("Fler lägen", "More modes"), ("Andra prov", "Other quizzes")]
        for (swedish, english) in words {
            #expect(text(swedish, in: "en") == english, "\(swedish)")
            #expect(text(swedish, in: "sv") == swedish, "\(swedish)")
        }
    }

    /// A text with values in it keeps them in English, also when the order changes.
    @Test func valuesStandInTheEnglishTextToo() throws {
        let fits = try #require(text("Krediterna räcker till %@.", in: "en"))
        #expect(String(format: fits, "5 questions") == "Your credits cover 5 questions.")
        let refill = try #require(text("Fylls på den %lld %@.", in: "en"))
        #expect(String(format: refill, 1, "December") == "Refills on December 1.")
        #expect(CreditText.examFits(5) == "Krediterna räcker till 5 frågor.") // Swedish as before
        #expect(RepetitionModel.refillLine("2026-12-01") == "Fylls på den 1 december.")
    }

    @Test func numbersAndDaysFollowTheLanguage() throws {
        #expect(AppLanguage.sv.grouping == "\u{00A0}" && AppLanguage.sv.decimalSign == ",")
        #expect(AppLanguage.decimal("1.5", separator: ",") == "1,5" && AppLanguage.decimal("1.5", separator: ".") == "1.5")
        // The phone's own region when its language is the texts' language, otherwise the language's usual one.
        #expect(AppLanguage.en.locale(phone: Locale(identifier: "sv_SE")).identifier == "en_US")
        #expect(AppLanguage.en.locale(phone: Locale(identifier: "en_GB")).identifier == "en_GB")
        #expect(AppLanguage.sv.locale(phone: Locale(identifier: "en_US")).identifier == "sv_SE")
        #expect(AppLanguage.sv.dayAndMonth(month: 12, day: 1) == "1 december")
        #expect(AppLanguage.en.dayAndMonth(month: 12, day: 1) == "December 1") // the tests' phone is Swedish → en_US
        #expect(CreditText.number(1236) == "1\u{00A0}236" && CreditText.short(5392, .up) == "5,4k")
        // The server's Swedish day is not shown in English: the day is written from `resets` there.
        let json = #"{"unit":"chars","limit":1500,"used":264,"remaining":1236,"resets":"2026-12-01","resets_day":"1 december"}"#
        let quota = try JSONDecoder().decode(DrillQuota.self, from: Data(json.utf8))
        #expect(quota.resetsDay(in: .sv) == "1 december" && quota.resetsDay == "1 december")
        #expect(quota.resetsDay(in: .en) == "December 1")
        #expect(ChatGPTImportView.nextMonth(after: Date(timeIntervalSince1970: 1_795_000_000), language: .en) == "December")
    }

    /// K114: `lang` (en/sv) goes with every request to answer, drill, exam and help.
    @Test func theServerIsToldTheLanguage() throws {
        #expect(AppLanguage.stamped(["action": "quota"], language: .en)["lang"] as? String == "en")
        #expect(AppLanguage.stamped(["action": "quota"], language: .sv)["lang"] as? String == "sv")
        #expect(AppLanguage.stamped(["action": "quota", "lang": "sv"], language: .en)["lang"] as? String == "sv")
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "x", mode: "text", language: "en"))
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["lang"] as? String == "sv")     // the app's texts (the tests run in Swedish)
        #expect(body["language"] as? String == "en") // the language listened for is another matter
    }

    /// The server answers in the app's language, so its words are looked for in both.
    @Test func theServersWordsAreReadInBothLanguages() {
        #expect(SayText.isAboutCredits("Krediterna räcker inte.") && SayText.isAboutCredits("Not enough credits."))
        #expect(!SayText.isAboutCredits("Försök igen om en stund."))
        #expect(HelpPlace.guess(question: "How do the presses work?", answer: "") == .controls)
        #expect(HelpPlace.guess(question: "Hur fungerar trycken?", answer: "") == .controls)
        #expect(HelpPlace.guess(question: "How do I share a quiz?", answer: "") == .share)
        let said = "Not enough credits. New credits on December 1."
        #expect(SaidText.refusalLine(problem: said, quotaExceeded: true, refill: "Fylls på den 1 december.") == said)
    }
}
