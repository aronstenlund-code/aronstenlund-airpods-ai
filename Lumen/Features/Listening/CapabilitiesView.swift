import AlarmKit
import EventKit
import SwiftUI

/// A52 (D125, Kelly Ke29): what Lumen can do, what you say, and whether something has to be set up first. The status
/// is real: Kalender, Påminnelser and Alarm come from the phone's permissions, not from a flag; what is not built says
/// "Kommer snart" and has no button. A tap on a row without a button does nothing, and no row starts Lumen.
struct LumenCapability: Identifiable, Equatable, Sendable {
    enum Group: String, CaseIterable, Sendable {
        case study = "Plugg"
        case everyday = "Vardag"
        case musicAndCalls = "Musik och samtal"
        case more = "Mer"
    }

    /// What has to happen first.
    enum Setup: Equatable, Sendable {
        case nothing
        case permission(Permission)
        /// Not built yet: no button (Ke29).
        case soon
        /// A place in the app, not a setting ("I Provläget", "Byt läge").
        case place(String)
    }

    enum Permission: String, Sendable {
        case calendar = "Kalender"
        case reminders = "Påminnelser"
        /// AlarmKit: timers and alarms (iOS asks the first time).
        case alarms = "Alarm"
    }

    let id: String
    let group: Group
    let title: String
    let symbol: String
    /// What you say, in Swedish quotes, or what you do.
    let say: String
    let setup: Setup

    /// Ke29's rows, in order. Spotify and calls stay "Kommer snart" until K36 works in the app (Ke29 S2).
    static let all: [LumenCapability] = [
        .init(id: "quiz", group: .study, title: "Förhör", symbol: "graduationcap", say: "”Lumen, förhör mig på fotosyntes”", setup: .nothing),
        .init(id: "questions", group: .study, title: "Svar på frågor", symbol: "questionmark.bubble", say: "”Lumen, vad betyder ambivalent?”", setup: .nothing),
        .init(id: "myAnswers", group: .study, title: "Mina svar", symbol: "text.badge.checkmark", say: "Dina egna svar på provfrågor, i örat", setup: .place("I Provläget")),
        .init(id: "calendar", group: .everyday, title: "Kalender", symbol: "calendar", say: "”Lumen, vad har jag i dag?”", setup: .permission(.calendar)),
        .init(id: "reminders", group: .everyday, title: "Påminnelser", symbol: "checklist", say: "”Lumen, påminn mig om träningen kl. 18”", setup: .permission(.reminders)),
        .init(id: "timer", group: .everyday, title: "Timer", symbol: "timer", say: "”Lumen, sätt en timer på 10 minuter”", setup: .permission(.alarms)),
        .init(id: "alarm", group: .everyday, title: "Larm", symbol: "alarm", say: "”Lumen, väck mig kvart i sju”", setup: .permission(.alarms)),
        .init(id: "notes", group: .everyday, title: "Anteckningar", symbol: "note.text", say: "”Lumen, spara det”", setup: .nothing),
        .init(id: "training", group: .everyday, title: "Träning", symbol: "figure.run", say: "”Lumen, ge mig ett styrkepass på 20 minuter”", setup: .nothing),
        .init(id: "spotify", group: .musicAndCalls, title: "Spotify", symbol: "music.note", say: "”Lumen, kör spellistan Plugg”", setup: .soon),
        .init(id: "call", group: .musicAndCalls, title: "Ring", symbol: "phone", say: "”Lumen, ring mamma”", setup: .soon),
        .init(id: "interview", group: .more, title: "Intervju", symbol: "briefcase", say: "Färdiga svar på intervjufrågor", setup: .place("Byt läge")),
        .init(id: "sleep", group: .more, title: "Sömn", symbol: "moon.stars", say: "Tryck Sov på kvällen. Morgonrapport när du vaknar", setup: .nothing),
    ]

    var permission: Permission? {
        if case .permission(let permission) = setup { return permission }
        return nil
    }

    /// The three that work without connecting anything, for the sheet after the first answer (Ke29).
    static let firstExamples = ["quiz", "calendar", "timer"]
}

/// What a permission is right now.
enum CapabilityAccess: Equatable, Sendable {
    case allowed
    /// iOS asks when the button is tapped (or the first time Lumen uses it).
    case notAsked
    /// Said no earlier: the button opens Settings.
    case denied

    nonisolated static func current(_ permission: LumenCapability.Permission) -> CapabilityAccess {
        switch permission {
        case .calendar: of(EKEventStore.authorizationStatus(for: .event))
        case .reminders: of(EKEventStore.authorizationStatus(for: .reminder))
        case .alarms:
            switch AlarmManager.shared.authorizationState {
            case .authorized: .allowed
            case .denied: .denied
            default: .notAsked
            }
        }
    }

    nonisolated static func of(_ status: EKAuthorizationStatus) -> CapabilityAccess {
        switch status {
        case .fullAccess: .allowed
        case .notDetermined: .notAsked
        default: .denied // denied, restricted, write-only (Lumen reads the calendar)
        }
    }

    /// iOS's question. True when allowed afterwards.
    nonisolated static func ask(_ permission: LumenCapability.Permission) async -> Bool {
        switch permission {
        case .calendar: return (try? await EKEventStore().requestFullAccessToEvents()) == true
        case .reminders: return (try? await EKEventStore().requestFullAccessToReminders()) == true
        case .alarms: return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
        }
    }

    /// The status line under a row (Ke29): what is needed, or nothing.
    static func line(for setup: LumenCapability.Setup, access: CapabilityAccess?) -> (text: String, needsAction: Bool) {
        switch setup {
        case .nothing: return ("Inget att ställa in", false)
        case .soon: return ("Kommer snart", false)
        case .place(let place): return (place, false)
        case .permission(let permission):
            switch access ?? .notAsked {
            case .allowed: return ("✓ Tillåtet", false)
            case .notAsked: return ("Behöver tillgång till \(permission.rawValue)", true)
            case .denied: return ("Avstängt i Inställningar", true)
            }
        }
    }
}

/// A52: the screen, pushed from "Allt Lumen kan ›" on Start and from the sheet after the first answer.
struct CapabilitiesView: View {
    @State private var access: [LumenCapability.Permission: CapabilityAccess] = [:]
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Som Siri, fast den förstår vad du frågar och svarar direkt i dina AirPods.")
                        .font(LumenFont.text(17))
                    Text("Säg ”Lumen” och sedan vad du vill. Det som behöver ställas in står på raden.")
                        .font(LumenFont.text(15))
                        .foregroundStyle(LumenColor.muted)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
            }
            ForEach(LumenCapability.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(LumenCapability.all.filter { $0.group == group }) { item in
                        row(item)
                    }
                }
            }
        }
        .lumenForm()
        .navigationTitle("Vad kan Lumen?")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .task { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } } // back from Settings
    }

    private func refresh() {
        for permission in [LumenCapability.Permission.calendar, .reminders, .alarms] {
            access[permission] = CapabilityAccess.current(permission)
        }
    }

    private func row(_ item: LumenCapability) -> some View {
        let permission = item.permission
        let status = CapabilityAccess.line(for: item.setup, access: permission.flatMap { access[$0] })
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(LumenColor.blue)
                .frame(width: 34, height: 34)
                .background(LumenColor.soft, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(LumenFont.text(17, .semibold))
                Text(item.say).font(LumenFont.text(15)).foregroundStyle(LumenColor.ink)
                Text(status.text)
                    .font(LumenFont.text(13, status.needsAction ? .semibold : .regular, relativeTo: .footnote))
                    .foregroundStyle(status.needsAction ? LumenColor.blue : LumenColor.muted)
            }
            Spacer(minLength: 8)
            if let permission, status.needsAction {
                Button("Tillåt") { Task { await allow(permission) } }
                    .font(LumenFont.text(15, .semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Tillåt \(permission.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }

    private func allow(_ permission: LumenCapability.Permission) async {
        if access[permission] == .denied {
            ErrorCard.openSettings() // iOS asks only once; after a no, the switch is in Settings
            return
        }
        _ = await CapabilityAccess.ask(permission)
        refresh()
    }
}

/// A52 (Ke29): once, after the first answer: "Lumen kan mer än svara", three things that work without connecting
/// anything, and "Visa allt Lumen kan". Klar or a swipe closes it for good.
struct CapabilitiesIntroSheet: View {
    static let shownKey = "a52.capabilitiesIntroShown"
    @State private var showsAll = false
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var titleFocused: Bool

    private var examples: [LumenCapability] {
        LumenCapability.firstExamples.compactMap { id in LumenCapability.all.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lumen kan mer än svara")
                            .font(LumenFont.text(28, .bold, relativeTo: .title))
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($titleFocused)
                        Text("Säg ”Lumen” och vad du vill, när du vill.")
                            .font(LumenFont.text(17))
                            .foregroundStyle(LumenColor.muted)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(examples) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 16))
                                    .foregroundStyle(LumenColor.blue)
                                    .frame(width: 34, height: 34)
                                    .background(LumenColor.soft, in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(LumenFont.text(15, .semibold)).foregroundStyle(LumenColor.muted)
                                    Text(item.say).font(LumenFont.text(17, .semibold))
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    Button("Visa allt Lumen kan") { showsAll = true }
                        .buttonStyle(LumenButtonStyle(height: 54))
                }
                .padding(20)
            }
            .lumenScreen()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
            .navigationDestination(isPresented: $showsAll) { CapabilitiesView() }
            .onAppear { titleFocused = true }
        }
    }
}
