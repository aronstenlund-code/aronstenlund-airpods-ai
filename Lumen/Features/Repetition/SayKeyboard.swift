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
