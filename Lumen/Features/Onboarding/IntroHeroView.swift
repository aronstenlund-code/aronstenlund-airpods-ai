import SwiftUI
import UIKit

/// A13.6: the intro's hero. Elias (`docs/marketing/karaktar.md`) as a cut-out PNG with a transparent background
/// (head and shoulders) on the app's own squared paper, so it works in light and dark; the logo's rings are drawn
/// here and spread from his earbud three times. Reduce Motion: the rings stand still. Until Aron has approved the
/// picture (`Assets.xcassets/IntroElias`, at most 300 kB @3x, a dark variant if the edge shows on dark paper) a
/// placeholder stands in.
struct IntroHeroView: View {
    /// Where the earbud is in the picture (0…1 of the hero's width and height): the rings start here. Adjust when
    /// the final picture lands.
    static let ringOrigin = UnitPoint(x: 0.62, y: 0.46)
    static let imageName = "IntroElias"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spread = false

    private var hasPicture: Bool { UIImage(named: Self.imageName) != nil }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let origin = CGPoint(x: size.width * Self.ringOrigin.x, y: size.height * Self.ringOrigin.y)
            ZStack {
                GridPaper(cornerRadius: 0)
                if hasPicture {
                    Image(Self.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: size.width, maxHeight: size.height, alignment: .bottom)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                } else {
                    // Placeholder: the earbud where Elias' will be.
                    Image(systemName: "airpods")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(LumenColor.muted)
                        .position(x: origin.x, y: origin.y + 34)
                }
                rings
                    .position(origin)
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .onAppear { spread = true }
    }

    /// Three rings in the logo's colour and rhythm, one after the other, three times; then still.
    private var rings: some View {
        ZStack {
            Circle().fill(LumenColor.blue).frame(width: 14, height: 14)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(LumenColor.blue.opacity(0.6), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(reduceMotion ? 1 + CGFloat(index + 1) * 0.9 : (spread ? 4.5 : 1))
                    .opacity(reduceMotion ? 0.8 - Double(index) * 0.2 : (spread ? 0 : 0.9))
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.6).repeatCount(3, autoreverses: false).delay(Double(index) * 0.45),
                               value: spread)
            }
        }
    }
}
