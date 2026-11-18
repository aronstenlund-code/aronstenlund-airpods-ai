import SwiftUI

// A150 (D231): how the repetition flow's own views move and answer a touch. The rules, from Apple's "Designing
// Fluid Interfaces" as the project follows it:
// - A touch is answered at once, on the way down, not when the finger lifts.
// - What changes on the screen moves with a spring that does not overshoot: nothing here is thrown, so nothing
//   bounces. A spring starts from where things are, so a change that comes in the middle of another is smooth.
// - Things come and go by fading where they stand; the system's sheets and menus keep their own paths.
// - A number that changes rolls in place and never changes the width of its neighbours.
// - With Reduce Motion nothing moves: a short cross-fade says the same thing.

enum SayMotion {
    /// Reduce Motion: the system's setting. (The Simulator recordings can force it, since `simctl` cannot set it.)
    @MainActor static func reduces(_ system: Bool) -> Bool {
        #if DEBUG
        if forcedReduceMotion { return true }
        #endif
        return system
    }

    #if DEBUG
    @MainActor static var forcedReduceMotion = false
    #endif

    /// A change of what is on the screen. No overshoot (critically damped); with Reduce Motion a short cross-fade.
    static func change(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.3)
    }

    /// A number that changes in place; with Reduce Motion it fades to the new number.
    static func number(_ reduceMotion: Bool) -> ContentTransition {
        reduceMotion ? .opacity : .numericText()
    }

    /// Something that appears or leaves where it stands. Never a slide: nothing here comes from somewhere.
    static var appear: AnyTransition { .opacity }

    /// The check mark of the chosen row: it grows a little as it appears, and only fades with Reduce Motion.
    static func mark(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.6))
    }
}

/// A button without the system's own look (a row of text, a round symbol) still answers the touch: it dims, and a
/// round one shrinks a little, the moment the finger is down. The way back is eased, the way down is not.
struct PressFeedbackStyle: ButtonStyle {
    /// 1 = the label keeps its size (a row of text); under 1 it shrinks a little (a round button).
    var scale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        Pressed(configuration: configuration, scale: scale)
    }

    private struct Pressed: View {
        let configuration: ButtonStyleConfiguration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
        private var reduceMotion: Bool { SayMotion.reduces(systemReduceMotion) }
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.55 : isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                // Down at once; back with a short ease.
                .animation(configuration.isPressed ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressFeedbackStyle {
    /// A row of text or a link: dims while pressed.
    static var pressFeedback: PressFeedbackStyle { PressFeedbackStyle() }
    /// A round symbol button: dims and shrinks a little while pressed.
    static var pressFeedbackRound: PressFeedbackStyle { PressFeedbackStyle(scale: 0.94) }
}
