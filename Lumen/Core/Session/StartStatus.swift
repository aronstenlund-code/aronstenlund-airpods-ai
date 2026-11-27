import Foundation

/// Deangelo 2026-11-27 05:52: Start says how things stand before one starts listening – the AirPods, the credits, and
/// whether the phone's own model is ready (it answers when the server cannot, A159). One short line, nothing to press.
struct StartStatus: Equatable, Sendable {
    /// AirPods (or other headphones) are where the sound goes now.
    var airPods: Bool
    /// The credits as Start's capsule says them ("1 200 kr"); nil when not known yet.
    var credits: String?
    /// The phone's own model answers in the language spoken.
    var phoneModel: Bool

    var parts: [String] {
        var parts = [airPods ? String(localized: "AirPods anslutna") : String(localized: "Inga AirPods – svaren hörs i högtalaren")]
        if let credits { parts.append(credits) }
        if phoneModel { parts.append(String(localized: "Telefonens modell redo")) }
        return parts
    }

    /// "AirPods anslutna · 1 200 krediter · Telefonens modell redo".
    var line: String { parts.joined(separator: " · ") }
}
