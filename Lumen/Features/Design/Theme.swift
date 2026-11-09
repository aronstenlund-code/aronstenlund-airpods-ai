import Observation
import SwiftUI
import UIKit

extension ConversationMode {
    /// Frågor graphite, Intervju green, Socialt orange, Rizz magenta, Prov blue (D86).
    var color: Color {
        switch self {
        case .standard: LumenColor.graphite
        case .interview: LumenColor.green
        case .social: LumenColor.orange
        case .rizz: LumenColor.magenta
        case .prov: LumenColor.blue
        }
    }

    /// The short name on the mode buttons.
    var shortName: String {
        switch self {
        case .standard: "Frågor"
        case .interview: "Intervju"
        case .social: "Socialt"
        case .rizz: "Rizz 18+"
        case .prov: "Provläge"
        }
    }

    /// One line under the name in "Byt läge".
    var tagline: String {
        switch self {
        case .standard: "Svarar när någon frågar"
        case .interview: "Färdiga svar på intervjufrågor"
        case .social: "Ett förslag i pausen"
        case .rizz: "Flörtig wingman"
        case .prov: "Pluggar till provet"
        }
    }

    var symbol: String {
        switch self {
        case .standard: "questionmark.circle"
        case .interview: "briefcase"
        case .social: "bubble.left.and.bubble.right"
        case .rizz: "heart"
        case .prov: "graduationcap"
        }
    }
}

/// Light, dark or follow the iPhone (default); handwriting for questions on or off.
@MainActor
@Observable
final class AppearanceSettings {
    enum Appearance: String, CaseIterable, Sendable {
        case system, light, dark

        var title: String {
            switch self {
            case .system: "Som iPhonen"
            case .light: "Ljust"
            case .dark: "Mörkt"
            }
        }
    }

    static let appearanceKey = "design.appearance"
    static let handwritingKey = "design.handwriting"
    private let defaults: UserDefaults

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    var handwriting: Bool {
        didSet { defaults.set(handwriting, forKey: Self.handwritingKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Self.appearanceKey).flatMap(Appearance.init(rawValue:)) ?? .system
        handwriting = defaults.object(forKey: Self.handwritingKey) as? Bool ?? true
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// The font for a question the user asked.
    func questionFont(_ size: CGFloat) -> Font {
        handwriting ? LumenFont.handwriting(size) : LumenFont.text(size - 2, .medium)
    }
}

// MARK: - Paper and buttons

/// The squared exercise-book paper: lines every 18 pt.
struct GridPaper: View {
    var cornerRadius: CGFloat = 6
    var dashed = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LumenColor.paper)
            .overlay {
                Canvas { context, size in
                    var path = Path()
                    var x: CGFloat = 18
                    while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += 18 }
                    var y: CGFloat = 18
                    while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 18 }
                    context.stroke(path, with: .color(LumenColor.grid), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(LumenColor.grid, style: StrokeStyle(lineWidth: dashed ? 1.5 : 1, dash: dashed ? [6, 4] : []))
            }
            .accessibilityHidden(true)
    }
}

extension View {
    /// Content on squared paper (the exam card, the listening header).
    func gridPaper(cornerRadius: CGFloat = 6, dashed: Bool = false) -> some View {
        background { GridPaper(cornerRadius: cornerRadius, dashed: dashed) }
    }

    /// D86 (A2): list screens (Settings, Diagnostik, Notes …) in the new look: squared-paper ground, the app's font,
    /// no capitals over headings, the blue accent. The rows keep the system's grouped cells (readable in both modes).
    func lumenForm() -> some View {
        scrollContentBackground(.hidden)
            .background(LumenColor.paper.ignoresSafeArea())
            .font(LumenFont.text(17))
            .textCase(nil)
            .tint(LumenColor.blue)
    }

    /// The app's background and ink.
    func lumenScreen() -> some View {
        background(LumenColor.background.ignoresSafeArea())
            .foregroundStyle(LumenColor.ink)
            .font(LumenFont.text(17))
            .tint(LumenColor.blue)
    }
}

struct LumenButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LumenFont.text(18, .semibold, relativeTo: .headline))
            // A12: one line that shrinks; two lines broke words in the middle ("Paus/a") at the largest size.
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 12)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private var foreground: Color {
        switch kind {
        case .primary: LumenColor.onBlue
        case .secondary: LumenColor.ink
        case .danger: LumenColor.onRed
        }
    }

    private var background: Color {
        switch kind {
        case .primary: LumenColor.blue
        case .secondary: LumenColor.chip
        case .danger: LumenColor.red
        }
    }
}

/// A square 44 pt icon button (settings, close, back).
struct IconButton: View {
    let systemName: String
    let label: String
    var background: Color = LumenColor.chip
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(background, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(LumenColor.ink)
        .accessibilityLabel(label)
    }
}

/// The round mode button in its colour.
struct ModeCircle: View {
    let mode: ConversationMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(LumenColor.background)
                    .frame(width: 66, height: 66)
                    .background(mode.color, in: Circle())
                Text(mode.shortName)
                    .font(LumenFont.text(14, .medium, relativeTo: .caption))
                    .foregroundStyle(LumenColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.shortName)
        .accessibilityHint(mode.tagline)
    }
}

/// The teacher's red pen: a loose hand-drawn ring around a few handwritten words ("5 dagar kvar").
struct RedPenRing: View {
    let text: String

    var body: some View {
        Text(text)
            .font(LumenFont.handwriting(20, bold: true, relativeTo: .headline))
            .foregroundStyle(LumenColor.red)
            .rotationEffect(.degrees(-4))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background {
                RingShape().stroke(LumenColor.red, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
            .fixedSize()
    }

    struct RingShape: Shape {
        func path(in r: CGRect) -> Path {
            // The sketch's path, scaled from its 156 × 60 box.
            let sx = r.width / 156, sy = r.height / 60
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
            var path = Path()
            path.move(to: p(14, 32))
            path.addCurve(to: p(86, 8), control1: p(10, 17), control2: p(50, 6))
            path.addCurve(to: p(141, 31), control1: p(122, 10), control2: p(144, 19))
            path.addCurve(to: p(61, 52), control1: p(138, 45), control2: p(97, 54))
            path.addCurve(to: p(11, 25), control1: p(24, 50), control2: p(7, 41))
            return path
        }
    }
}

/// "Lyssnar": the pulsing rings (a still image when Reduce Motion is on).
struct ListeningRings: View {
    var size: CGFloat = 64
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().stroke(LumenColor.blue.opacity(0.3), lineWidth: 2).frame(width: size * 0.84, height: size * 0.84)
                .scaleEffect(pulse ? 1.06 : 1)
            Circle().stroke(LumenColor.blue.opacity(0.6), lineWidth: 2.5).frame(width: size * 0.53, height: size * 0.53)
            Circle().fill(active ? LumenColor.blue : LumenColor.muted).frame(width: size * 0.25, height: size * 0.25)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard active, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}
