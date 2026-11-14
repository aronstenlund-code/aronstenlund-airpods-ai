import SwiftUI
import UIKit

/// Ke53 point 5 (SYSTEM §0.3, A87): the system's semantic colours. The accent blue (#2346C8 / #7F9BFF, also
/// AccentColor in Assets) is the app's only colour of its own. Colours follow the iPhone's light/dark unless locked
/// in Settings.
enum LumenColor {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) })
    }

    // A18: the tokens of `docs/design/SYSTEM.md` (Ke12). `paper` and `grid` remain as names for the grouped
    // background and the hairlines; there is no squared paper any more.
    // Ke53 point 5: `background`, `surface`, `raised` → the system's backgrounds; `ink`, `muted` → label colours;
    // `line` → the separator.
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let raised = Color(uiColor: .secondarySystemGroupedBackground)
    static let paper = surface
    static let grid = Color(uiColor: .separator)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let blue = dynamic(0x2346C8, 0x7F9BFF)
    static let red = Color(uiColor: .systemRed)
    static let onBlue = dynamic(0xFFFFFF, 0x0E1630)
    static let onRed = dynamic(0xFFFFFF, 0x2A0B07)
    static let chip = surface
    static let line = Color(uiColor: .separator)
    static let soft = dynamic(0xEAF0FF, 0x1E2A4F)

    // The modes (the sketches' dark variants keep the contrast on the dark background).
    static let graphite = dynamic(0x4B5563, 0xB4BCCB)
    static let green = dynamic(0x1E7A4C, 0x4FC28A)
    static let orange = dynamic(0xE0731B, 0xF59A4A)
    static let magenta = dynamic(0xC2307A, 0xF26BAE)

    // A76 (Kelly Ke45/Ke46): the test mode only, orange so it is seen at once without looking like an error.
    static let test = dynamic(0xB45309, 0xFBBF6A)
    static let testSoft = dynamic(0xFEF3E2, 0x3A2A12)
    static let onTest = dynamic(0xFFFFFF, 0x2A1A05)

    // A80 (Kelly Ke49 §4.5): green only for a finished check mark (the AirPods check, "Läser materialet").
    static let ok = dynamic(0x1F7A4D, 0x5FD39A)
    static let okSoft = dynamic(0xE5F4EC, 0x15301F)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Ke53 point 3 (SYSTEM §0.2, A87): SF Pro with the system's text styles, so Dynamic Type, tracking and leading
/// follow by themselves. The old point sizes pick the nearest text style ("17" is `.body`, "15" `.subheadline`);
/// Familjen Grotesk and Kalam are no longer in the app.
enum LumenFont {
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.system(textStyle(for: size), weight: weight)
    }

    /// The text style nearest a point size at the default text size.
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 33...: .largeTitle   // 34
        case 26..<33: .title      // 28
        case 21..<26: .title2     // 22
        case 19..<21: .title3     // 20
        case 17..<19: .body       // 17
        case 16..<17: .callout    // 16
        case 14..<16: .subheadline // 15
        case 13..<14: .footnote   // 13
        case 12..<13: .caption    // 12
        default: .caption2        // 11
        }
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
