import SwiftUI

/// A43 (N1, K33): how ready the student is, as a ring. On the exam card it is small ("68 %" inside); a tap opens
/// "Så redo är du": the big ring, K33's one-line explanation, what to practise (the three weakest, with the reason),
/// what is already known, today's pass, and "Förhör mig". One accent (blue) on a `soft` track, SYSTEM.md.
struct ReadinessRing: View {
    let percent: Int
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(LumenColor.soft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(LumenColor.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent) %")
                .font(LumenFont.text(size * 0.27, .bold, relativeTo: .footnote))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(lineWidth + 2)
        }
        .frame(width: size, height: size)
        .onAppear { fill() }
        .onChange(of: percent) { _, _ in fill() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent) procent redo")
    }

    /// Fills once when it appears (a rare screen, so a short ease-out is allowed); at once without motion.
    private func fill() {
        let target = Double(min(max(percent, 0), 100)) / 100
        if reduceMotion { shown = target } else { withAnimation(.easeOut(duration: 0.6)) { shown = target } }
    }
}

struct ReadinessView: View {
    let plan: ExamPlan
    let readiness: StudyPlanAPI.Readiness
    let known: [String]
    let today: String?
    let onQuiz: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let weakest = readiness.weakest, !weakest.isEmpty {
                        group("Öva på") {
                            ForEach(Array(weakest.enumerated()), id: \.offset) { index, weak in
                                row(title: weak.concept, detail: weak.why.map(Self.reason), divider: index > 0)
                            }
                        }
                    }
                    if !known.isEmpty {
                        group("Det här kan du") {
                            ForEach(Array(known.enumerated()), id: \.offset) { index, concept in
                                row(title: concept, detail: nil, divider: index > 0, done: true)
                            }
                        }
                    }
                    if let today {
                        group("Dagens pass") {
                            Text(today)
                                .font(LumenFont.text(17, .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onQuiz) {
                    TwoLineLabel(title: "Förhör mig", detail: "EarMind börjar med det du behöver öva på")
                }
                .buttonStyle(LumenButtonStyle(height: 62))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(LumenColor.background)
            }
            .lumenScreen()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng", action: onClose).font(LumenFont.text(17, .semibold))
                }
            }
            .navigationTitle("Så redo är du")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ReadinessRing(percent: readiness.readyPct ?? 0, size: 148, lineWidth: 12)
            Text("redo för \(plan.name.lowercased())")
                .font(LumenFont.text(20, .semibold, relativeTo: .title3))
                .multilineTextAlignment(.center)
            if let explain = readiness.explain, !explain.isEmpty {
                Text(explain)
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func row(title: String, detail: String?, divider: Bool, done: Bool = false) -> some View {
        VStack(spacing: 0) {
            if divider { Rectangle().fill(LumenColor.line).frame(height: 1).padding(.leading, 16) }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(LumenFont.text(17, .semibold))
                    if let detail { Text(detail).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted) }
                }
                Spacer(minLength: 8)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(LumenColor.blue)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .accessibilityElement(children: .combine)
        }
    }

    /// K33's reasons, with a capital letter.
    nonisolated static func reason(_ why: String) -> String {
        guard let first = why.first else { return why }
        return first.uppercased() + why.dropFirst()
    }
}
