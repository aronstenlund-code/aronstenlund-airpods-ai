import SwiftUI
import UIKit

/// D86: the Swedish-school look. Familjen Grotesk for everything, Kalam (handwriting) only for the user's questions
/// and the teacher's red pen. Colours follow the iPhone's light/dark unless locked in Settings.
enum LumenColor {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) })
    }

    static let background = dynamic(0xFFFFFF, 0x11151F)
    static let paper = dynamic(0xF5F8FC, 0x161C2A)
    static let grid = dynamic(0xD9E3F0, 0x232B3D)
    static let ink = dynamic(0x18213A, 0xEEF1F7)
    static let muted = dynamic(0x5A6478, 0x9AA3B5)
    static let blue = dynamic(0x2346C8, 0x7F9BFF)
    static let red = dynamic(0xD9342B, 0xFF6F61)
    static let onBlue = dynamic(0xFFFFFF, 0x0E1630)
    static let onRed = dynamic(0xFFFFFF, 0x2A0B07)
    static let chip = dynamic(0xF1F4F9, 0x1B2131)
    static let line = dynamic(0xE2E7EF, 0x2A3247)
    static let soft = dynamic(0xEAF0FF, 0x1E2A4F)

    // The modes (the sketches' dark variants keep the contrast on the dark background).
    static let graphite = dynamic(0x4B5563, 0xB4BCCB)
    static let green = dynamic(0x1E7A4C, 0x4FC28A)
    static let orange = dynamic(0xE0731B, 0xF59A4A)
    static let magenta = dynamic(0xC2307A, 0xF26BAE)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Fonts that grow with the user's text size (Dynamic Type), falling back to the system font if not registered.
enum LumenFont {
    static let family = "Familjen Grotesk"
    static let hand = "Kalam"

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(family, size: size, relativeTo: style).weight(weight)
    }

    /// Handwriting: the user's questions (a setting, on by default) and the red pen.
    static func handwriting(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(bold ? "Kalam-Bold" : "Kalam-Regular", size: size, relativeTo: style)
    }
}

/// Lumen's mark: a dot and two arcs, like sound reaching an ear.
struct LumenLogo: View {
    var size: CGFloat = 26

    var color: Color = LumenColor.blue

    var body: some View {
        // Shapes, not a Canvas, so the same mark draws in the Live Activity too.
        let s = size / 26
        ZStack {
            Arc(radius: 10.5 * s).stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            Arc(radius: 6.5 * s).stroke(color, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            Circle().fill(color).frame(width: 7 * s, height: 7 * s)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The upper half of a circle around the centre.
    struct Arc: Shape {
        let radius: CGFloat
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            return path
        }
    }
}
