import SwiftUI
import WidgetKit

/// A170 (Deangelo 2026-11-27): "Fortsätt öva" on the home screen. What one was doing last in the repetition (A168):
/// the quiz's name and how far one came, or that there is a text in Säg i AirPods to play again. The app writes this
/// into the shared app group; the widget only reads it. Nothing else leaves the app: no questions, no answers, no
/// audio, and never the said text itself (it can be anything). A tap opens the right place in the app.
struct PracticeWidgetSnapshot: Codable, Equatable, Sendable {
    static let key = "widget.practice"
    static let kind = "com.rsolutions.lumen.widget.practice"

    enum What: String, Codable, Sendable {
        /// A quiz with questions.
        case quiz
        /// A text read aloud (Läs upp texten).
        case text
        /// The latest text in Säg i AirPods.
        case said
    }

    var what: What
    /// The quiz's name (empty for a said text: it is never written here).
    var title: String
    /// Where one was, from 1, and of how many (questions, or sentences of a text). Nil when not started.
    var place: Int?
    var total: Int?
    var drillID: UUID?
    var updatedAt: Date

    /// Where a tap goes: the quiz's own screen, or Start with Säg i AirPods.
    var link: URL {
        if what != .said, let drillID { return Self.link(drill: drillID) }
        return Self.sayLink
    }

    static func link(drill id: UUID) -> URL { URL(string: "earmind://continue/\(id.uuidString)")! }
    static let sayLink = URL(string: "earmind://say")!

    /// The quiz a link from the widget opens; nil for any other link.
    static func drillID(in url: URL) -> UUID? {
        guard url.scheme == "earmind", url.host() == "continue" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    static func isSayLink(_ url: URL) -> Bool { url.scheme == "earmind" && url.host() == "say" }

    static func load(_ defaults: UserDefaults? = UserDefaults(suiteName: ExamWidgetSnapshot.appGroup)) -> PracticeWidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PracticeWidgetSnapshot.self, from: data)
    }

    func save(_ defaults: UserDefaults? = UserDefaults(suiteName: ExamWidgetSnapshot.appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }

    static func clear(_ defaults: UserDefaults? = UserDefaults(suiteName: ExamWidgetSnapshot.appGroup)) {
        defaults?.removeObject(forKey: key)
    }

    /// The same, apart from when it was written.
    func sameContent(as other: PracticeWidgetSnapshot?) -> Bool {
        guard var other else { return false }
        other.updatedAt = updatedAt
        return other == self
    }
}

/// The words of the widget.
enum PracticeWidgetText {
    static var name: String { String(localized: "Fortsätt öva") }
    static var description: String { String(localized: "Det du höll på med sist, ett tryck bort.") }
    static var caption: String { String(localized: "Fortsätt öva") }
    static func line(_ snapshot: PracticeWidgetSnapshot) -> String {
        switch snapshot.what {
        case .said: return String(localized: "Spela din senaste text igen")
        case .quiz, .text:
            guard let place = snapshot.place, let total = snapshot.total else { return String(localized: "Inte startat än") }
            return snapshot.what == .quiz ? String(localized: "Fråga \(place) av \(total)") : String(localized: "Mening \(place) av \(total)")
        }
    }
    static func title(_ snapshot: PracticeWidgetSnapshot) -> String {
        snapshot.what == .said ? String(localized: "Säg i AirPods") : snapshot.title
    }
    static func button(_ snapshot: PracticeWidgetSnapshot) -> String {
        snapshot.what == .said ? String(localized: "Spela") : snapshot.place == nil ? String(localized: "Starta") : String(localized: "Fortsätt")
    }
    static var emptyTitle: String { String(localized: "Inget att öva på än") }
    static var emptyLine: String { String(localized: "Skapa ett prov eller spela in själv i EarMind.") }
}

/// The widget's face, small or medium. In `Shared/` so the app's pictures can show it too.
struct PracticeWidgetView: View {
    let snapshot: PracticeWidgetSnapshot?
    var isMedium = false

    var body: some View {
        if let snapshot { filled(snapshot) } else { empty }
    }

    private func filled(_ snapshot: PracticeWidgetSnapshot) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    LumenLogo(size: 18)
                    Text(verbatim: PracticeWidgetText.caption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumenColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(verbatim: PracticeWidgetText.title(snapshot))
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(verbatim: PracticeWidgetText.line(snapshot))
                    .font(.subheadline)
                    .foregroundStyle(LumenColor.muted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let place = snapshot.place, let total = snapshot.total, total > 0 {
                    ProgressView(value: Double(min(place, total)), total: Double(total))
                        .tint(LumenColor.blue)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isMedium {
                Text(verbatim: PracticeWidgetText.button(snapshot))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LumenColor.onBlue)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .background(LumenColor.blue, in: Capsule())
                    .accessibilityHidden(true) // the whole widget is the button
            }
        }
        .foregroundStyle(LumenColor.ink)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            LumenLogo(size: 22)
            Spacer(minLength: 0)
            Text(verbatim: PracticeWidgetText.emptyTitle).font(.headline).lineLimit(2)
            Text(verbatim: PracticeWidgetText.emptyLine)
                .font(.footnote)
                .foregroundStyle(LumenColor.muted)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(LumenColor.ink)
        .accessibilityElement(children: .combine)
    }
}
