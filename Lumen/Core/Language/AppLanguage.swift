import Foundation

/// A157 (D251): the language the app shows its texts in. English is the base and Swedish a translation: a phone set
/// to Swedish gets Swedish, every other phone English. The choice is the system's (the phone's language list against
/// the two languages in the bundle); this type only reads it, so the texts, the numbers and the server agree.
enum AppLanguage: String, Sendable, CaseIterable {
    case en
    case sv

    /// The language of this launch.
    static var current: AppLanguage { from(Bundle.main.preferredLocalizations) }

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
