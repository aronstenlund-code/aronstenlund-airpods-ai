import SwiftUI
import UIKit

/// A13.6: the intro's hero. Elias (`docs/marketing/karaktar.md`) as a PNG; the logo's rings are drawn here and spread
/// from his earbud three times. Reduce Motion: the rings stand still. A18: the approved picture is in
/// the app (`Resources/Images/IntroElias@2x/@3x.png`, 191 kB @3x after quantising), always in a light card (SYSTEM.md),
/// so the navy jumper never melts into a dark background. Without the file a placeholder stands in.
struct IntroHeroView: View {
    /// Where the earbud is in the picture (0…1 of the picture's own width and height): the rings start here.
    nonisolated static let ringOrigin = UnitPoint(x: 0.32, y: 0.37)
    /// The placeholder's earbud, in the hero's own frame.
    static let placeholderOrigin = UnitPoint(x: 0.62, y: 0.46)
    static let imageName = "IntroElias"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var spread = false
    /// After the three spreads the rings rest where the logo has them (they faded to nothing before).
    @State private var settled = false

    private var picture: UIImage? { UIImage(named: Self.imageName) }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let origin = CGPoint(x: size.width * Self.placeholderOrigin.x, y: size.height * Self.placeholderOrigin.y)
            ZStack {
                LumenColor.background
                if let picture {
                    // A26 R1 (Kelly, `bilder/system/intro.png`): Elias fills the light card (always light, also in dark
                    // mode, like a photo), and the rings start at his earbud in the visible picture.
                    GeometryReader { card in
                        let fill = Self.fill(card: card.size, picture: picture.size, focus: Self.ringOrigin)
                        ZStack(alignment: .topLeading) {
                            Color.white
                            Image(uiImage: picture)
                                .resizable()
                                .frame(width: fill.size.width, height: fill.size.height)
                                .offset(x: fill.origin.x, y: fill.origin.y)
                            rings.position(fill.focus)
                        }
                        .frame(width: card.size.width, height: card.size.height, alignment: .topLeading)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 14) // room for the shadow
                } else {
                    // Placeholder: the earbud where Elias' will be.
                    Image(systemName: "airpods")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(LumenColor.muted)
                        .position(x: origin.x, y: origin.y + 34)
                    rings
                        .position(origin)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .onAppear { spread = true }
        .task {
            try? await Task.sleep(for: .seconds(1.6 * 3 + 0.9 + 0.2))
            withAnimation(.easeIn(duration: 0.4)) { settled = true }
        }
    }

    /// A26 R1: the picture scaled to fill a card of `card` size, never smaller than the card in either direction.
    /// The top stays in view unless the focus (the earbud) would then sit low in the card: the picture moves up until
    /// the focus is at 60 % of the card's height (the SE's short card), never so far that white shows below it.
    /// Returns the picture's size and top-left corner in the card, and where the focus is in the card.
    nonisolated static func fill(card: CGSize, picture: CGSize, focus: UnitPoint) -> (size: CGSize, origin: CGPoint, focus: CGPoint) {
        guard card.width > 0, card.height > 0, picture.width > 0, picture.height > 0 else { return (card, .zero, .zero) }
        let scale = max(card.width / picture.width, card.height / picture.height)
        let size = CGSize(width: picture.width * scale, height: picture.height * scale)
        let focusX = size.width * focus.x
        let focusY = size.height * focus.y
        let x = min(0, max(card.width - size.width, card.width / 2 - focusX))
        let y = min(0, max(card.height - size.height, card.height * 0.6 - focusY))
        return (size, CGPoint(x: x, y: y), CGPoint(x: x + focusX, y: y + focusY))
    }

    /// Three rings in the logo's colour and rhythm, one after the other, three times; then still.
    private var rings: some View {
        ZStack {
            Circle().fill(LumenColor.blue).frame(width: 14, height: 14)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(LumenColor.blue.opacity(0.6), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(reduceMotion || settled ? 1 + CGFloat(index + 1) * 0.9 : (spread ? 4.5 : 1))
                    .opacity(reduceMotion || settled ? 0.8 - Double(index) * 0.2 : (spread ? 0 : 0.9))
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.6).repeatCount(3, autoreverses: false).delay(Double(index) * 0.45),
                               value: spread)
            }
        }
    }
}
