import SwiftUI
import WidgetKit

/// A170 (Deangelo 2026-11-27): "Fortsätt öva", small and medium. Reads what the app wrote (`PracticeWidgetSnapshot`)
/// and opens the right place with one tap. Works without a network and without credits: it only shows what the app
/// already knows.
struct PracticeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PracticeWidgetSnapshot.kind, provider: PracticeWidgetProvider()) { entry in
            PracticeWidgetFace(entry: entry)
                .environment(\.locale, AppLanguage.current.locale) // D253: the language chosen in the app
                .containerBackground(for: .widget) { LumenColor.background }
                .widgetURL(entry.snapshot?.link) // without anything to continue, a tap opens the app
        }
        .configurationDisplayName(PracticeWidgetText.name)
        .description(PracticeWidgetText.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PracticeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PracticeWidgetSnapshot?
}

struct PracticeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PracticeWidgetEntry {
        PracticeWidgetEntry(date: Date(), snapshot: Self.demo)
    }

    func getSnapshot(in context: Context, completion: @escaping (PracticeWidgetEntry) -> Void) {
        completion(PracticeWidgetEntry(date: Date(), snapshot: PracticeWidgetSnapshot.load() ?? (context.isPreview ? Self.demo : nil)))
    }

    /// The app reloads the widget when it writes; nothing here changes with the clock.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PracticeWidgetEntry>) -> Void) {
        completion(Timeline(entries: [PracticeWidgetEntry(date: Date(), snapshot: PracticeWidgetSnapshot.load())], policy: .never))
    }

    static var demo: PracticeWidgetSnapshot {
        PracticeWidgetSnapshot(what: .quiz, title: String(localized: "Biologiprovet"), place: 3, total: 12, drillID: nil, updatedAt: Date())
    }
}

private struct PracticeWidgetFace: View {
    let entry: PracticeWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        PracticeWidgetView(snapshot: entry.snapshot, isMedium: family == .systemMedium)
    }
}
