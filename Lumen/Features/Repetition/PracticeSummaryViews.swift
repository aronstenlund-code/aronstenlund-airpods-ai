import SwiftUI

/// A168 (Deangelo 2026-11-27): after Avsluta, one short sheet on Start: how much was heard, the questions whose
/// answer was asked for, and one button to practise just those again. Nothing is counted and nothing is asked of the
/// server: the sound is on the phone. A half sheet that goes away with a tap or a pull.
struct PracticeSummarySheet: View {
    let summary: PracticeSummary
    let onPractise: () -> Void
    let onDone: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At most this many questions are listed; the rest are counted.
    static let listed = 4

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("practiceSummary.sheet")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: PracticeSummaryText.title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(verbatim: PracticeSummaryText.heard(summary.heard, title: summary.title))
                    .foregroundStyle(LumenColor.secondaryText)
            }
            if summary.missed.isEmpty {
                Text(verbatim: PracticeSummaryText.noneAsked)
            } else {
                Text(verbatim: PracticeSummaryText.asked(summary.missed.count)).font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(summary.missed.prefix(Self.listed).enumerated()), id: \.offset) { _, question in
                        Label {
                            Text(verbatim: question).lineLimit(2)
                        } icon: {
                            Image(systemName: "questionmark.circle").foregroundStyle(.tint)
                        }
                    }
                    if summary.missed.count > Self.listed {
                        Text(verbatim: PracticeSummaryText.more(summary.missed.count - Self.listed))
                            .font(.subheadline)
                            .foregroundStyle(LumenColor.secondaryText)
                    }
                }
            }
            Spacer(minLength: 4)
            if !summary.missed.isEmpty {
                Button(action: onPractise) {
                    FilledButtonLabel {
                        Label(PracticeSummaryText.practise(summary.missed.count), systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("practiceSummary.practise")
            }
            Button(action: onDone) {
                Text(verbatim: PracticeSummaryText.done).frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("practiceSummary.done")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

/// The words of the summary. Honest about what the player knows: which answers were asked for, not right or wrong.
enum PracticeSummaryText {
    static var title: String { String(localized: "Bra jobbat") }
    static func heard(_ n: Int, title: String) -> String {
        String(localized: "\(title) · du hörde \(DrillText.questions(n))")
    }
    static func asked(_ n: Int) -> String {
        n == 1 ? String(localized: "Du bad om svaret på 1 fråga") : String(localized: "Du bad om svaret på \(n) frågor")
    }
    static var noneAsked: String { String(localized: "Du bad inte om något svar. Spela provet igen när du vill.") }
    static func more(_ n: Int) -> String { String(localized: "och \(n) till") }
    static func practise(_ n: Int) -> String {
        n == 1 ? String(localized: "Öva den igen") : String(localized: "Öva de \(n) igen")
    }
    static var done: String { String(localized: "Klar") }
}
