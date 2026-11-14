import Observation
import SwiftUI
import UIKit

extension ConversationMode {
    /// Frågor graphite, Intervju green, Socialt orange, Rizz magenta, Prov blue (D86).
    /// A18 (SYSTEM.md): one accent; the modes no longer have colours of their own in the interface.
    var color: Color { LumenColor.blue }

    /// The short name on the mode buttons.
    var shortName: String {
        switch self {
        case .standard: "Standardläge" // A37 (D115)
        case .interview: "Intervju"
        case .social: "Socialt"
        case .rizz: "Rizz" // D112: no 18+
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
        case .prov: "För dina prov" // D126 (owner)
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

    /// The font for a question the user asked. A18 (SYSTEM.md): one family, no handwriting; the question is the
    /// smaller, quieter line above its answer. The old setting is kept but no longer changes the look.
    func questionFont(_ size: CGFloat) -> Font {
        LumenFont.text(max(15, size - 4), .semibold, relativeTo: .subheadline)
    }
}

// MARK: - Paper and buttons

/// A18 (SYSTEM.md, Ke12): the squared paper is gone. What used to be paper is now the system's card: `raised`,
/// corners 20, a soft shadow in light mode, a hairline instead of the shadow in dark mode. Corner 0 (a screen's
/// header) is just the screen's background.
struct GridPaper: View {
    var cornerRadius: CGFloat = 20
    var dashed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if cornerRadius == 0 {
            LumenColor.background.accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: LumenCard.radius)
                .fill(LumenColor.raised)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: LumenCard.radius).strokeBorder(LumenColor.line, lineWidth: 1)
                    }
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 1, y: 1)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.07), radius: 10, y: 6)
                .accessibilityHidden(true)
        }
    }
}

enum LumenCard {
    static let radius: CGFloat = 20
}

extension View {
    /// The system's card (A18: was squared paper; the name stays so every caller follows).
    func gridPaper(cornerRadius: CGFloat = 20, dashed: Bool = false) -> some View {
        background { GridPaper(cornerRadius: cornerRadius, dashed: dashed) }
    }

    /// List screens (Settings, Diagnostik, Notes …): the system's inset grouped list with its own grouped background
    /// (Ke53 point 5: no hidden scroll background, so they look like Settings in light and dark), the accent.
    func lumenForm() -> some View {
        listStyle(.insetGrouped)
            .font(.body)
            .tint(LumenColor.blue)
    }

    /// The system's background and label colour.
    func lumenScreen() -> some View {
        background(LumenColor.background.ignoresSafeArea())
            .foregroundStyle(.primary)
            .font(.body)
            .tint(LumenColor.blue)
    }
}

/// Ke53 point 4 (A87): the system's buttons, full width. `.primary` is the screen's filled button
/// (`.borderedProminent`, with Angela Fable's dark label on the light accent in dark mode), `.secondary` is
/// `.bordered`, `.danger` the filled red one. All `.controlSize(.large)`; the system draws the pressed and disabled
/// states. Replaces the app's own button style (Ke53).
struct SystemButton: PrimitiveButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let role = configuration.role ?? (kind == .danger ? .destructive : nil)
        switch kind {
        case .primary:
            Button(role: role, action: configuration.trigger) { FilledButtonLabel { label(configuration) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .secondary:
            Button(role: role, action: configuration.trigger) { label(configuration) }
                .buttonStyle(.bordered)
                .controlSize(.large)
        case .danger:
            Button(role: role, action: configuration.trigger) { label(configuration) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(LumenColor.red)
        }
    }

    private func label(_ configuration: Configuration) -> some View {
        configuration.label
            // A12: one line that shrinks; two lines broke words in the middle ("Paus/a") at the largest size.
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
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
                .background(background, in: RoundedRectangle(cornerRadius: 12))
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

/// A18 (SYSTEM.md): the red pen became a calm badge, `soft` with blue text, fully round ("5 dagar kvar").
struct RedPenRing: View {
    let text: String

    var body: some View {
        Text(text)
            .font(LumenFont.text(14, .semibold, relativeTo: .footnote))
            .foregroundStyle(LumenColor.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(LumenColor.soft, in: Capsule())
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
