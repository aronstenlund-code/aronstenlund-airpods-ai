import Foundation

/// A161 (D259): the words of the launch week: the percent, how long is left, and the sheet that says it when the
/// app is opened. Short, and nothing that is not true: the percent and the end come from the server (K119).
enum LaunchOfferText {
    static var title: String { String(localized: "Lanseringsrabatt") }
    static var seePacks: String { String(localized: "Se paketen") }
    static var notNow: String { String(localized: "Inte nu") }

    /// "-65 %".
    static func badge(_ percent: Int) -> String { String(localized: "-\(percent) %") }

    static func line(_ percent: Int) -> String { String(localized: "\(percent) % rabatt på alla kreditpaket den här veckan.") }

    /// "Slutar om 2 dagar 4 tim", "Slutar om 4 tim 12 min", "Slutar om 12 min", "Slutar om under en minut".
    static func left(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let hoursText = String(localized: "\(hours) tim")
        let minutesText = String(localized: "\(minutes) min")
        let text: String
        if days > 0 {
            text = (days == 1 ? String(localized: "1 dag") : String(localized: "\(days) dagar")) + " " + hoursText
        } else if hours > 0 {
            text = hoursText + " " + minutesText
        } else if minutes > 0 {
            text = minutesText
        } else {
            text = String(localized: "under en minut")
        }
        return String(localized: "Slutar om \(text)")
    }

    static func left(_ offer: LaunchOffer, now: Date) -> String {
        left(seconds: offer.endsAt.timeIntervalSince(now))
    }

    /// VoiceOver on a pack's price during the week: what it costs now and what it costs otherwise.
    static func spoken(title: String, price: String, regular: String) -> String {
        String(localized: "Köp \(title) för \(price), ordinarie pris \(regular)")
    }
}
