import AppIntents
import SwiftUI
import WidgetKit

/// A44 (N2): the nearest exam on the home screen: the days left, the streak, and "Förhör mig" (opens Lumen in the
/// quiz). Small: the exam and the button. Medium: also how ready the student is (A43). The app writes the snapshot
/// (`ExamWidgetSnapshot`); the timeline turns over at midnight so the days left stay right without the app.
struct ExamWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ExamWidgetSnapshot.kind, provider: ExamWidgetProvider()) { entry in
            ExamWidgetView(entry: entry)
                .containerBackground(for: .widget) { LumenColor.background }
        }
        .configurationDisplayName("Nästa prov")
        .description("Dagar kvar, din svit och Förhör mig.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ExamWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ExamWidgetSnapshot?
}

struct ExamWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExamWidgetEntry {
        ExamWidgetEntry(date: Date(), snapshot: Self.demo)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExamWidgetEntry) -> Void) {
        completion(ExamWidgetEntry(date: Date(), snapshot: ExamWidgetSnapshot.load() ?? (context.isPreview ? Self.demo : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = ExamWidgetSnapshot.load()
        let calendar = Calendar.current
        // Today, and each of the next days at midnight: "5 dagar kvar" becomes "4 dagar kvar" without the app.
        let entries = (0..<4).compactMap { offset -> ExamWidgetEntry? in
            guard offset > 0 else { return ExamWidgetEntry(date: now, snapshot: snapshot) }
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
            return ExamWidgetEntry(date: day, snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static let demo = ExamWidgetSnapshot(examName: "Biologiprovet", examDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                                         streak: 3, doneToday: true, readyPct: 68, updatedAt: Date())
}

struct ExamWidgetView: View {
    let entry: ExamWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot, let name = snapshot.examName, let left = snapshot.daysLeftText(now: entry.date) {
            switch family {
            case .systemMedium: medium(snapshot, name: name, left: left)
            default: small(snapshot, name: name, left: left)
            }
        } else {
            empty
        }
    }

    private func small(_ snapshot: ExamWidgetSnapshot, name: String, left: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                LumenLogo(size: 18)
                Spacer(minLength: 4)
                streak(snapshot.liveStreak(now: entry.date))
            }
            Spacer(minLength: 0)
            Text(verbatim: name)
                .font(LumenFont.text(17, .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            badge(left)
            quizButton
        }
        .foregroundStyle(LumenColor.ink)
    }

    private func medium(_ snapshot: ExamWidgetSnapshot, name: String, left: String) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    LumenLogo(size: 18)
                    Text("NÄSTA PROV").font(LumenFont.text(12, .semibold)).foregroundStyle(LumenColor.muted)
                }
                Spacer(minLength: 0)
                Text(verbatim: name).font(LumenFont.text(20, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    badge(left)
                    streak(snapshot.liveStreak(now: entry.date))
                }
                quizButton
            }
            if let percent = snapshot.readyPct {
                VStack(spacing: 4) {
                    ZStack {
                        Circle().stroke(LumenColor.soft, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(min(max(percent, 0), 100)) / 100)
                            .stroke(LumenColor.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(verbatim: "\(percent) %").font(LumenFont.text(18, .bold)).monospacedDigit()
                    }
                    .frame(width: 86, height: 86)
                    Text("redo").font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(percent) procent redo")
            }
        }
        .foregroundStyle(LumenColor.ink)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            LumenLogo(size: 22)
            Spacer(minLength: 0)
            Text("Har du prov snart?").font(LumenFont.text(17, .bold)).lineLimit(2)
            Text("Lägg till det i EarMind.").font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
            quizButton
        }
        .foregroundStyle(LumenColor.ink)
    }

    private var quizButton: some View {
        Button(intent: StartQuizIntent()) {
            Text("Förhör mig")
                .font(LumenFont.text(15, .semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(LumenColor.onBlue)
        .background(LumenColor.blue, in: RoundedRectangle(cornerRadius: 12))
    }

    private func badge(_ text: String) -> some View {
        Text(verbatim: text)
            .font(LumenFont.text(13, .semibold))
            .foregroundStyle(LumenColor.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(LumenColor.soft, in: Capsule())
    }

    @ViewBuilder
    private func streak(_ days: Int) -> some View {
        if days > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.system(size: 12, weight: .semibold))
                Text(verbatim: "\(days)").font(LumenFont.text(14, .bold)).monospacedDigit()
            }
            .foregroundStyle(LumenColor.blue)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(days == 1 ? "Svit: 1 dag" : "Svit: \(days) dagar i rad")
        }
    }
}
