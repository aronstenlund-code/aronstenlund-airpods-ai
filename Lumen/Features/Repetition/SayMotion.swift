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

    /// Two faces of the same surface change places (the card that is written in, and the card that plays): the old
    /// one is gone before the new one comes, so two texts are never read on top of each other. (Seen in the
    /// recording of 2026-11-18: a plain cross-fade showed both for two frames.)
    static func swap(_ reduceMotion: Bool) -> AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeIn(duration: reduceMotion ? 0.1 : 0.18).delay(reduceMotion ? 0.05 : 0.12)),
                    removal: .opacity.animation(.easeOut(duration: reduceMotion ? 0.05 : 0.1)))
    }

    /// Kelly Ke83: the player of a said text is pulled down with a finger. It follows the finger one to one
    /// downwards; upwards there is nowhere to go, so it gives a little and resists more the further it is pulled.
    static func pulled(_ translation: CGFloat) -> CGFloat {
        translation >= 0 ? translation : -pow(-translation, 0.7)
    }

    /// Where a pull is going decides, not where it is: a quick flick folds the player down from near the top, a slow
    /// pull that stops short lets it go back (the gesture's own projection of where it would come to rest).
    static func folds(projected: CGFloat, height: CGFloat) -> Bool {
        height > 0 && projected > height * 0.3
    }

    /// After a pull that was let go: back to its place with the little bounce a thing that was moved has; with
    /// Reduce Motion a short ease.
    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.8)
    }

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

/// A169 (Deangelo 2026-11-27): a row that is coming, as the system draws it while it loads: grey bars in the shape of
/// a title and a line under it, still (no shimmer), so the screen is never empty and nothing spins.
struct PlaceholderRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Xxxxxxxxxxxxxxxxx").fontWeight(.semibold)
            Text(verbatim: "Xxxxxxx · xx xxxxxxx").font(.subheadline)
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

/// A169: a light touch only at the moments that matter, in the same frame as what is seen: a recording starts or
/// stops, a quiz is done. Nothing for ordinary taps (the system's own controls have their own).
enum Feel {
    /// A recording of one's own voice: `.start` when one begins, `.stop` when it ends.
    static func recording<T: Equatable>(from old: T?, to new: T?) -> SensoryFeedback? {
        if old == nil, new != nil { return .start }
        if old != nil, new == nil { return .stop }
        return nil
    }

    /// A quiz is done (its summary is shown).
    static let quizDone: SensoryFeedback = .success
}
