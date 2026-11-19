import SwiftUI
import UIKit

// A153 (D238, Toby T53 2026-11-19): at the largest text the card is taller than the room above the keyboard, and
// Spela ended up behind the keys with no way to put the keyboard down. Two things follow, both the system's own
// pattern (the row above the keyboard):
// - "Klar" in that row puts the keyboard down from the big field.
// - When the card's own Spela cannot be pressed, the same Spela stands in that row. When the card's Spela can be
//   seen, the row has only "Klar": one filled Spela at a time (Kelly Ke72).

enum SayKeyboard {
    /// A button that only just clears the keyboard's row is not one to aim at.
    static let margin: CGFloat = 4

    /// The card must be this wide for the style's four suggestions and Spela to stand side by side above the
    /// keyboard (the widest phones); on the others the last suggestion gives way to Spela.
    static let widthForAllSuggestions: CGFloat = 398

    /// On the narrowest phones (iPhone SE) the row above the keyboard has room for "Spela" and the cost, not for
    /// "Spela i 10 min" and the cost. The card is narrower than this there.
    static let narrowCard: CGFloat = 320

    /// Kelly (2026-11-19): the cost stands in the row above the keyboard, since the card's own is behind the keys
    /// at the largest text. The card's words; on a narrow screen their first part ("120 krediter" of
    /// "120 krediter · du har 88").
    static func costWords(_ line: String, narrow: Bool) -> String {
        narrow ? (line.components(separatedBy: " · ").first ?? line) : line
    }

    /// The button's words in that row: the card's ("Spela i 10 min"); on a narrow screen beside a cost, "Spela".
    static func playWords(_ title: String, narrow: Bool, withCost: Bool) -> String {
        narrow && withCost ? (title.components(separatedBy: " ").first ?? title) : title
    }

    /// The strip of plain ground under the keyboard's row: from where the keyboard with its row begins
    /// (`keyboardTop`) down to where the screen's own content ends above the keys (`bottom`, the strip's own lower
    /// edge). Measured on an iPhone 17 Pro with iOS 26: the row begins at 491 and the content ends at 525, so 34
    /// points; that is also the guess before both are known. Never more than a row and a half.
    static func stripHeight(bottom: CGFloat?, keyboardTop: CGFloat?) -> CGFloat {
        guard let bottom, let keyboardTop, bottom > 0 else { return 34 }
        return min(max(bottom - keyboardTop, 0), 72)
    }

    /// The card's own Spela cannot be pressed while the keyboard is up: the keyboard (with its row) covers it, wholly
    /// or in part, or it has been scrolled away above the screen.
    /// - `button`: the button's top and bottom on the screen; nil = not measured, and then the answer is the safe
    ///   one (Spela is offered above the keyboard rather than nowhere).
    /// - `keyboardTop`: where the keyboard begins on the screen; nil = no keyboard, and nothing is hidden.
    static func hidesPlay(button: ClosedRange<CGFloat>?, keyboardTop: CGFloat?, top: CGFloat = 0) -> Bool {
        guard let keyboardTop else { return false }
        guard let button else { return true }
        return button.upperBound > keyboardTop - margin || button.lowerBound < top
    }

    /// Where the keyboard will begin on the screen, from the system's own notice. Nil when it is going down. A
    /// keyboard that has left the screen begins at the screen's bottom edge, which is below every button.
    static func top(from note: Notification) -> CGFloat? {
        if note.name == UIResponder.keyboardWillHideNotification { return nil }
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect, frame.height > 0 else { return nil }
        return frame.minY
    }

    /// What the view knows about the two, kept outside its state: the button moves with every scrolled point, and
    /// only the answer (hidden or not) is worth drawing the card again for.
    @MainActor final class Geometry {
        var button: ClosedRange<CGFloat>?
        var keyboardTop: CGFloat?
        var hidesPlay: Bool { SayKeyboard.hidesPlay(button: button, keyboardTop: keyboardTop) }
    }
}
