import Foundation

/// A157 (D251, D253): the language the app shows its texts in. English is the base and Swedish a translation. The app
/// always starts in English, also on a Swedish phone (Aron, D253); Svenska is chosen in Inställningar and the choice
/// is kept. The texts, the numbers and the server (`lang`) all follow this one value. In Shared, so the widget and the
/// Live Activity show the same language as the app.
enum AppLanguage: String, Sendable, CaseIterable, Identifiable {
    case en
    case sv

    var id: String { rawValue }

    /// The language's own name, the same whatever the app is showing, so anyone finds their own.
    var nativeName: String { self == .sv ? "Svenska" : "English" }

    /// The language chosen (English until Svenska is picked).
    static var current: AppLanguage { LanguageChoice.shared.language }

    /// This language's table of texts (its folder in the bundle). `String(localized:)` and the tests read it.
    var bundle: Bundle { LanguageChoice.shared.table(self) }

    /// The first of the bundle's chosen localizations ("sv", "sv-SE" → Swedish; anything else → English).
    static func from(_ localizations: [String]) -> AppLanguage {
        guard let first = localizations.first?.lowercased() else { return .en }
        return first == "sv" || first.hasPrefix("sv-") || first.hasPrefix("sv_") ? .sv : .en
    }

    /// `lang` to the server (K114): "en" or "sv".
    var code: String { rawValue }

    /// How numbers, dates and months are written next to the texts: the phone's own region when its language is the
    /// texts' language (a British phone writes 24 Nov), otherwise the language's usual one (1,236 · 1 236).
    var locale: Locale { locale(phone: .current) }

    func locale(phone: Locale) -> Locale {
        if phone.language.languageCode?.identifier == rawValue { return phone }
        return Locale(identifier: self == .sv ? "sv_SE" : "en_US")
    }

    /// Between the thousands: a space that does not break the line in Swedish ("1 236"), the region's own sign in
    /// English ("1,236").
    var grouping: String { self == .sv ? "\u{00A0}" : (locale.groupingSeparator ?? ",") }

    /// The decimal sign: "," in Swedish, the region's own in English (".").
    var decimalSign: String { self == .sv ? "," : (locale.decimalSeparator ?? ".") }

    /// "1 december" in Swedish, "December 1" in English (the region's own order).
    func dayAndMonth(month: Int, day: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        guard (1...12).contains(month) else { return "\(day)" }
        let name = calendar.monthSymbols[month - 1]
        if self == .sv { return "\(day) \(name)" }
        var parts = DateComponents()
        parts.year = 2001 // any year: only the day and the month are written
        parts.month = month
        parts.day = day
        guard let date = calendar.date(from: parts) else { return "\(name) \(day)" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: date)
    }

    /// "1,5" in Swedish and "1.5" in English, from a number written with a point ("%.1f").
    static func decimal(_ text: String, language: AppLanguage = .current) -> String {
        decimal(text, separator: language.decimalSign)
    }

    static func decimal(_ text: String, separator: String) -> String {
        separator == "." ? text : text.replacingOccurrences(of: ".", with: separator)
    }

    /// K114: `lang` on a request to answer, drill, exam or help, unless the caller has set it.
    static func stamped(_ body: [String: Any], language: AppLanguage = .current) -> [String: Any] {
        var body = body
        if body["lang"] == nil { body["lang"] = language.code }
        return body
    }
}

/// D253: where the choice is kept and read. English unless the user has picked Svenska.
///
/// Two exceptions, for what runs the app rather than uses it: `-app.language sv` on the command line picks a language
/// outright, and a run that was started with `-AppleLanguages` (the unit tests' scheme, the app tests, the picture
/// workflows) gets the language it asked for there, as before D253.
final class LanguageChoice: @unchecked Sendable {
    static let shared = LanguageChoice()
    static let key = "app.language"

    private let lock = NSLock()
    private var value: AppLanguage
    private let stores: [UserDefaults]
    private let arguments: [String]
    private let localizations: [String]
    /// The widget is its own process: it reads the choice again every time, so a change in the app shows there.
    private let rereads: Bool
    /// Where the system reads the app's own language list from (`AppleLanguages`); nil in tests.
    private let systemStore: UserDefaults?
    private let english: Bundle
    private let swedish: Bundle

    init(arguments: [String] = ProcessInfo.processInfo.arguments,
         stores: [UserDefaults] = [UserDefaults.standard] + [UserDefaults(suiteName: "group.com.rsolutions.lumen")].compactMap { $0 },
         localizations: [String] = Bundle.main.preferredLocalizations,
         rereads: Bool = Bundle.main.bundlePath.hasSuffix(".appex"),
         systemStore: UserDefaults? = .standard) {
        self.systemStore = systemStore
        self.arguments = arguments
        self.stores = stores
        self.localizations = localizations
        self.rereads = rereads
        english = Self.folder("en")
        swedish = Self.folder("sv")
        value = Self.resolve(arguments: arguments, stored: Self.stored(in: stores), localizations: localizations)
    }

    var language: AppLanguage {
        if rereads { return Self.resolve(arguments: arguments, stored: Self.stored(in: stores.reversed()), localizations: localizations) }
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func table(_ language: AppLanguage) -> Bundle { language == .sv ? swedish : english }

    private static func folder(_ code: String) -> Bundle {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap { Bundle(path: $0) } ?? .main
    }

    /// A run that named its language itself (tests, pictures): the phone's settings are left alone then.
    var isSetFromOutside: Bool { Self.asked(arguments) != nil || arguments.contains("-AppleLanguages") }

    func set(_ language: AppLanguage) {
        lock.lock()
        value = language
        lock.unlock()
        for store in stores { store.set(language.rawValue, forKey: Self.key) }
        pinSystemLanguage()
    }

    /// The system's own words (Back, Done, Paste, the permission questions) are chosen when the app starts, from the
    /// phone's language. This asks for the app's language instead, from the next start: without it a Swedish phone
    /// would show English texts with Swedish system buttons.
    func pinSystemLanguage() {
        guard !isSetFromOutside, !rereads else { return }
        systemStore?.set([language.rawValue], forKey: "AppleLanguages")
    }

    static func resolve(arguments: [String], stored: String?, localizations: [String]) -> AppLanguage {
        if let asked = asked(arguments) { return asked }
        if arguments.contains("-AppleLanguages") { return AppLanguage.from(localizations) }
        return stored.flatMap { AppLanguage(rawValue: $0) } ?? .en
    }

    private static func asked(_ arguments: [String]) -> AppLanguage? {
        guard let index = arguments.firstIndex(of: "-" + key), index + 1 < arguments.count else { return nil }
        return AppLanguage(rawValue: arguments[index + 1])
    }

    private static func stored(in stores: [UserDefaults]) -> String? {
        stores.lazy.compactMap { $0.string(forKey: key) }.first
    }
}

extension String {
    /// D253: every `String(localized: "…")` in the app and the widget comes here, and gets the text in the language
    /// chosen in the app (not the phone's), with its numbers written that language's way. The call sites stay as
    /// Swift's own, so Xcode and tools/l10n still see every text.
    init(localized value: String.LocalizationValue) {
        let language = AppLanguage.current
        self.init(localized: value, table: nil, bundle: language.bundle, locale: language.locale, comment: nil)
    }
}
