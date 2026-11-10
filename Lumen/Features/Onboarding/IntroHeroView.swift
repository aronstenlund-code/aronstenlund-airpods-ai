import SwiftUI
import UIKit

/// A13.6: the intro's hero. Elias (`docs/marketing/karaktar.md`) as a cut-out PNG with a transparent background
/// (head and shoulders) on the app's own squared paper, so it works in light and dark; the logo's rings are drawn
/// here and spread from his earbud three times. Reduce Motion: the rings stand still. A18: the approved picture is in
/// the app (`Resources/Images/IntroElias@2x/@3x.png`, 191 kB @3x after quantising), always in a light card (SYSTEM.md),
/// so the navy jumper never melts into a dark background. Without the file a placeholder stands in.
struct IntroHeroView: View {
    /// Where the earbud is in the picture (0…1 of the picture's own width and height): the rings start here.
    static let ringOrigin = UnitPoint(x: 0.32, y: 0.37)
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
                    // A18 (SYSTEM.md): Elias always in a light card, also in dark mode, like a photo.
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                        .padding(.horizontal, 24)
                        .padding(.top, 56) // clear of the status bar (the intro ignores the top safe area)
                    Image(uiImage: picture)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            GeometryReader { image in
                                rings.position(x: image.size.width * Self.ringOrigin.x, y: image.size.height * Self.ringOrigin.y)
                            }
                        }
                        .frame(maxWidth: size.width - 48, maxHeight: size.height - 64, alignment: .bottom)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 24)
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
