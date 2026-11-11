import AlarmKit
@preconcurrency import Contacts
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

    enum Permission: String, CaseIterable, Sendable {
        case calendar = "Kalender"
        case reminders = "Påminnelser"
        /// AlarmKit: timers and alarms (iOS asks the first time).
        case alarms = "Alarm"
        /// A58: "ring mamma" looks the name up in Kontakter.
        case contacts = "Kontakter"

        /// A77 (K44): the name in `Shared/capabilities.json` and in `context.capabilities`.
        var key: String {
            switch self {
            case .calendar: "calendar"
            case .reminders: "reminders"
            case .alarms: "alarms"
            case .contacts: "contacts"
            }
        }

        init?(key: String) {
            guard let match = Self.allCases.first(where: { $0.key == key }) else { return nil }
            self = match
        }
    }

    let id: String
    let group: Group
    let title: String
    let symbol: String
    /// What you say, in Swedish quotes, or what you do.
    let say: String
    let setup: Setup

    /// A77 (K44, D118): the one list, `Shared/capabilities.json`, shared with the server, so the screen and the spoken
    /// "kan du …?" answer say the same thing. `fallback` only if the file is missing from the bundle.
    static let all: [LumenCapability] = CapabilityList.load().map(\.rows) ?? fallback

    /// The app's own part of a row: the symbol, and the place for rows that are done in the app, not said.
    static let symbols: [String: String] = [
        "questions": "questionmark.bubble", "quiz": "graduationcap", "myAnswers": "text.badge.checkmark", "calendar": "calendar",
        "reminders": "checklist", "timer": "timer", "alarm": "alarm", "notes": "note.text", "training": "figure.run",
        "call": "phone", "music": "music.note.list", "spotify": "music.note", "interview": "briefcase",
        "social": "person.2.wave.2", "sleep": "moon.stars", "translate": "character.bubble", "web": "globe",
    ]
    static let places: [String: String] = [
        "music": "Öppnar Spotify med sökningen", "interview": "Byt läge", "social": "Byt läge",
    ]

    /// Ke29's rows, the list before A77 (used only without the file).
    static let fallback: [LumenCapability] = [
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
        .init(id: "call", group: .musicAndCalls, title: "Ring", symbol: "phone", say: "”Lumen, ring mamma”", setup: .permission(.contacts)), // A58
        .init(id: "music", group: .musicAndCalls, title: "Öppna musik", symbol: "music.note.list", say: "”Lumen, spela lugn pluggmusik”", setup: .place("Öppnar Spotify med sökningen")), // A58
        .init(id: "interview", group: .more, title: "Intervju", symbol: "briefcase", say: "Färdiga svar på intervjufrågor", setup: .place("Byt läge")),
        .init(id: "sleep", group: .more, title: "Sömn", symbol: "moon.stars", say: "Tryck Sov på kvällen. Morgonrapport när du vaknar", setup: .nothing),
    ]

    var permission: Permission? {
        if case .permission(let permission) = setup { return permission }
        return nil
    }

    /// The three that work without connecting anything, for the sheet after the first answer (Ke29).
    static let firstExamples = ["quiz", "calendar", "timer"]

    /// A77: the granted permissions for `context.capabilities` (K44), so the server never says "allow it first" about
    /// something already allowed, nor "ja" about something that needs a permission.
    @MainActor
    static func grantedPermissions() -> [String] {
        Permission.allCases.filter { CapabilityAccess.current($0) == .allowed }.map(\.key)
    }
}

/// A77 (K44): `Shared/capabilities.json` as the app reads it.
struct CapabilityList: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        var id: String
        var group: String
        var name: String
        var say: String
        var status: String
        var permission: String?
    }
    var capabilities: [Item]

    static func load(bundle: Bundle = .main) -> CapabilityList? {
        guard let url = bundle.url(forResource: "capabilities", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CapabilityList.self, from: data)
    }

    var rows: [LumenCapability] { capabilities.compactMap(Self.row) }

    static func row(_ item: Item) -> LumenCapability? {
        let group: LumenCapability.Group
        switch item.group {
        case "skola": group = .study
        case "vardag": group = .everyday
        case "musik och samtal": group = .musicAndCalls
        case "mer": group = .more
        default: return nil
        }
        let setup: LumenCapability.Setup
        if item.status == "kommer" { setup = .soon }
        else if let key = item.permission, let permission = LumenCapability.Permission(key: key) { setup = .permission(permission) }
        else if let place = LumenCapability.places[item.id] { setup = .place(place) }
        else { setup = .nothing }
        return LumenCapability(id: item.id, group: group, title: item.name, symbol: LumenCapability.symbols[item.id] ?? "sparkles",
                               say: spoken(item.say), setup: setup)
    }

    /// "Lumen, …" is said, so it is quoted, with the wake word as it is now (A75: a new name is one line).
    static func spoken(_ say: String) -> String {
        guard say.hasPrefix("Lumen,") else { return say }
        return "”" + WakeWord.name + String(say.dropFirst("Lumen".count)) + "”"
    }
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
        case .contacts:
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized, .limited: .allowed
            case .notDetermined: .notAsked
            default: .denied
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
        case .contacts: return (try? await CNContactStore().requestAccess(for: .contacts)) == true
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
    /// Ke37 §10.4: at the largest sizes the big title is text in the list (it wraps) and the bar gets the small one.
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if typeSize.isAccessibilitySize {
                        Text("Vad kan Earmind?")
                            .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
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
        .navigationTitle("Vad kan Earmind?")
        .navigationBarTitleDisplayMode(typeSize.isAccessibilitySize ? .inline : .large)
        .toolbar(.visible, for: .navigationBar)
        .task { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } } // back from Settings
    }

    private func refresh() {
        for permission in [LumenCapability.Permission.calendar, .reminders, .alarms, .contacts] {
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
                        Text("Earmind kan mer än svara")
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
                    Button("Visa allt Earmind kan") { showsAll = true }
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
