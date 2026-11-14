import SwiftUI

/// A80 (D142), rebuilt in A87 (D160, Kelly Ke53 `apple/hem-tom.png`, `hem.png`, `fortsatt.png`): Start as the
/// system's own parts. Without an exam: the system's empty state with **Nytt prov** as the one filled button. With
/// exams: a list, the next exam first with **Starta prov** (or **Fortsätt** and "Du var på fråga 3 av 5", no dialog),
/// the other exams as rows with ▶, and Nytt prov in the bottom toolbar, as in Påminnelser. The listening modes are
/// one row, "Fler lägen". No tip boxes, no cards in cards, and the streak only as a line of text.
struct RepetitionHomeSection: View {
    let model: RepetitionModel
    /// The days in a row (A38), shown as text under the next exam once there is one.
    var streakDays = 0
    /// A76: the test mode is on (shown in the navigation bar for as long as it is).
    var testModeOn = false
    /// A49: last night's line, for 16 hours after waking.
    var lastNight: String?
    var onLastNight: () -> Void = {}
    var onSettings: () -> Void = {}
    var onMoreModes: () -> Void = {}

    @State private var isCreating = false
    @State private var opened: UUID?
    /// "Styr med dina AirPods" before the first Starta prov, straight from Start (one tap less than through the exam).
    @State private var checking: Drill?
    @State private var showsSchool = false
    @State private var askingCode = false
    @State private var pastedCode = ""
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false
    @Environment(\.dynamicTypeSize) private var typeSize

    /// A100 (Deangelo 2026-11-14, Toby T21 finding 2): "Fler lägen · Beta · använder mikrofonen" is shown only once
    /// the user has started a first exam (the control check before the first Starta prov sets `controlsChecked`).
    /// Before that a new user sees the exam and Starta prov, nothing about BETA or the microphone.
    private var showsMoreModes: Bool { controlsChecked }

    var body: some View {
        Group {
            if model.drills.isEmpty { emptyState } else { examList }
        }
        .navigationTitle("Prov")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) { // Kelly S3: a fixed row, nothing floats over the text
            // A100: without an exam the row only held Fler lägen, which a new user does not see yet.
            if !model.drills.isEmpty || showsMoreModes { bottomRow }
        }
        .toolbar { barItems }
        .sheet(isPresented: $isCreating) {
            NewDrillView(model: model) { drill in opened = drill.id }
        }
        .sheet(item: $checking) { drill in
            ControlCheckView(hub: model.remote, sound: model.audio.track(for: drill, at: 0)?.question, help: model) {
                controlsChecked = true
                checking = nil
                Task { await model.start(drill, at: model.savedIndex(drill) ?? 0) }
            } onLater: {
                checking = nil
            }
        }
        .navigationDestination(item: $opened) { id in
            DrillView(model: model, drillID: id)
        }
        .navigationDestination(isPresented: $showsSchool) {
            SchoolExamsView(model: model) // A83 (Ke52)
        }
        .alert("Öppna ett delat prov", isPresented: $askingCode) {
            TextField("Länk eller kod", text: $pastedCode)
            Button("Öppna") {
                if let code = DrillShareClient.code(inText: pastedCode) { model.open(code: code) } else {
                    model.importMessage = "Det ser inte ut som en länk till ett prov."
                }
                pastedCode = ""
            }
            Button("Avbryt", role: .cancel) { pastedCode = "" }
        } message: {
            Text("Klistra in länken du fick, så läggs provet till hos dig med samma ljud.")
        }
        .onChange(of: model.openDrill) { _, id in
            if let id { opened = id; model.openDrill = nil }
        }
        .task { model.prepareAllAudio() }
    }

    @ToolbarContentBuilder
    private var barItems: some ToolbarContent {
        if testModeOn {
            ToolbarItem(placement: .topBarLeading) {
                Button("Testläge", action: onSettings)
                    .tint(.orange) // D140: the test mode's orange, as text only (SYSTEM §0.3)
                    .accessibilityLabel("Testläget är på. Öppna inställningar")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSettings) {
                Label("Inställningar", systemImage: "gearshape")
            }
        }
        if typeSize.isAccessibilitySize, !model.drills.isEmpty {
            // Kelly S3: with the accessibility sizes the bottom row has room for Nytt prov only.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Öppna länk", systemImage: "link") { askingCode = true }
                } label: {
                    Label("Mer", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    /// The bottom row, as in Påminnelser: Nytt prov to the left with its text, Öppna länk to the right; without an
    /// exam, Fler lägen. Kelly S3: a fixed row with the system's material and a hairline, not a floating toolbar
    /// (in iOS 26 the toolbar's buttons lay over the text and over Starta prov, CI 43531494112).
    private var bottomRow: some View {
        HStack(spacing: 12) {
            if model.drills.isEmpty {
                Spacer(minLength: 0)
                Button(action: onMoreModes) {
                    Text("Fler lägen · Beta")
                }
                .accessibilityLabel("Fler lägen")
                .accessibilityHint("Beta. Lägen som lyssnar på vad du säger")
                Spacer(minLength: 0)
            } else {
                Button {
                    isCreating = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").accessibilityHidden(true) // A95
                        Text("Nytt prov")
                    }
                    .fontWeight(.semibold)
                }
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    Button("Öppna länk") { askingCode = true }
                        .accessibilityHint("Öppnar ett prov som någon har delat med dig")
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1) // as `MainActionBar`
        .accessibilityShowsLargeContentViewer() // A95
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Without an exam

    private var emptyState: some View {
        GeometryReader { proxy in
            ScrollView {
                emptyContent.frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label("Kom förberedd till provet", systemImage: "book.closed") // A86 (Aron 22:19)
        } description: {
            Text("Fota ditt material. Earmind gör frågor och svar och läser upp dem i dina AirPods.")
        } actions: {
            Button {
                isCreating = true
            } label: {
                FilledButtonLabel { Text("Nytt prov").font(.headline).frame(minWidth: 200) } // A95
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if model.canPublish { // A83 (Ke52 "Hem")
                Button { showsSchool = true } label: { Self.textButton("Hitta prov från din skola") }
            }
            Button { askingCode = true } label: { Self.textButton("Klistra in en länk") }
            if let lastNight {
                Button(action: onLastNight) { Text(verbatim: "I natt: \(lastNight)") }
            }
        }
    }

    /// A95 (audit: hit area 18 pt high): a text button's whole 44 pt row can be tapped.
    private static func textButton(_ title: String) -> some View {
        Text(verbatim: title)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    // MARK: With exams

    private var examList: some View {
        List {
            if let next = model.drills.first {
                Section {
                    nextExam(next)
                    navigationRow("Frågor och svar", detail: nil) { opened = next.id }
                } footer: {
                    if streakDays > 0 {
                        Label {
                            Text(verbatim: streakDays == 1 ? "1 dag i rad" : "\(streakDays) dagar i rad")
                        } icon: {
                            Image(systemName: "flame")
                        }
                    }
                }
            }

            if model.drills.count > 1 {
                Section("Andra prov") {
                    ForEach(model.drills.dropFirst()) { drill in otherExam(drill) }
                }
            }

            if model.canPublish || lastNight != nil || showsMoreModes {
                Section {
                    if model.canPublish { // A83 (Ke52 "Hem")
                        navigationRow("Prov från din skola", detail: nil) { showsSchool = true }
                    }
                    if let lastNight {
                        navigationRow("I natt", detail: lastNight, action: onLastNight)
                    }
                    if showsMoreModes { // A100
                        navigationRow("Fler lägen", detail: "Beta · använder mikrofonen", action: onMoreModes)
                            .accessibilityLabel("Fler lägen")
                            .accessibilityHint("Beta. Lägen som lyssnar på vad du säger")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // Kelly P3 (iPhone SE): the last row is not left half under the bottom bar: tighter sections, and room to
        // scroll it clear of the bar.
        .listSectionSpacing(.compact)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    /// "Nästa prov": the name, one line of facts and the screen's one filled button.
    private func nextExam(_ drill: Drill) -> some View {
        let saved = model.savedIndex(drill)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nästa prov").font(.footnote).foregroundStyle(.secondary)
                Text(verbatim: drill.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: facts(drill, saved: saved))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine) // A95: "Nästa prov, Biologiprovet, Du var på fråga 3 av 5"
            if let saved {
                ProgressView(value: Double(saved), total: Double(max(drill.items.count, 1)))
                    .accessibilityHidden(true)
            }
            Button {
                start(drill)
            } label: {
                FilledButtonLabel { // A95
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").accessibilityHidden(true)
                        Text(saved == nil ? "Starta prov" : "Fortsätt")
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canStart(drill))
            .accessibilityHint("Spelar frågorna i dina AirPods. Earmind använder inte mikrofonen.")
        }
        .padding(.vertical, 6)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    /// "Du var på fråga 3 av 5", "5 frågor · cirka 1 min per varv" or the sound's progress.
    private func facts(_ drill: Drill, saved: Int?) -> String {
        if let saved { return "Du var på fråga \(saved + 1) av \(drill.items.count)" }
        // A100 (K62): when the sound cannot be made, say so instead of a counter that stands still.
        if let problem = shortProblem(drill) { return "\(DrillText.questions(drill.items.count)) · \(problem)" }
        let p = model.progress(drill)
        if p.total > 0, p.ready == p.total {
            return "\(DrillText.questions(drill.items.count)) · cirka \(DrillText.minutesPerLap(drill)) min per varv"
        }
        return "\(DrillText.questions(drill.items.count)) · Ljud: \(p.ready) av \(p.total) klara"
    }

    /// Kelly (A100): on Start only the first sentence of the sound's problem, without the full stop ("Ljudet kan
    /// inte göras just nu"); the exam's own page has the whole of it ("… Försök igen om en stund.").
    private func shortProblem(_ drill: Drill) -> String? {
        guard let problem = model.audio.problem(for: drill) else { return nil }
        let first = problem.components(separatedBy: ". ").first ?? problem
        return first.hasSuffix(".") ? String(first.dropLast()) : first
    }

    /// Through "Styr med dina AirPods" the first time; after that one tap, from the question the last run stopped at.
    private func start(_ drill: Drill) {
        if controlsChecked {
            Task { await model.start(drill, at: model.savedIndex(drill) ?? 0) }
        } else {
            checking = drill
        }
    }

    /// Kelly R7: the row opens the exam, ▶ starts it directly.
    private func otherExam(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        let detail = ready ? "\(DrillText.questions(drill.items.count)) · ljud klart"
            : shortProblem(drill) ?? "Ljud: \(p.ready) av \(p.total) klara" // A100 (K62)
        return HStack(spacing: 12) {
            Button {
                opened = drill.id
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: drill.title).foregroundStyle(.primary)
                    Text(verbatim: detail).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öppnar provet")
            Button {
                start(drill)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .disabled(!model.canStart(drill))
            .accessibilityLabel("Starta \(drill.title)")
        }
    }

    /// A row that goes somewhere: the title, at most one line under it and the system's chevron.
    private func navigationRow(_ title: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).foregroundStyle(Color.primary)
                    if let detail {
                        Text(verbatim: detail).font(.subheadline).foregroundStyle(Color.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
    }
}

/// A80 (D142): the listening modes are BETA, under the repetition. (The page behind "Fler lägen", not rebuilt in A87.)
struct BetaModesHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                SectionLabel("Fler lägen")
                BetaBadge()
            }
            Text("De här lägena lyssnar på vad du säger. De är i BETA och blir bättre hela tiden.")
                .font(LumenFont.text(15))
                .foregroundStyle(LumenColor.muted)
        }
        .padding(.top, 8)
    }
}

/// Kelly Ke49 §4.4: a grey outline, 11 pt bold capitals, corner 6. A label, not a warning: no colour, no icon.
/// (Used by the listening modes' screens, not rebuilt in A87.)
struct BetaBadge: View {
    var body: some View {
        Text("BETA")
            .font(LumenFont.text(11, .bold, relativeTo: .caption2))
            .foregroundStyle(LumenColor.muted)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(LumenColor.muted, lineWidth: 1))
            .accessibilityLabel("Beta, under utveckling")
    }
}

/// A78/A80: the playing screen over everything, and a shared exam opened from a link (A81). A87 (Kelly Ke53 point 8):
/// no "Fortsätt där du var?" when the app opens; Start's button says "Fortsätt" and where the user was.
struct RepetitionOverlay: ViewModifier {
    let model: RepetitionModel?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        if let model {
            content
                .fullScreenCover(isPresented: Binding(get: { model.showsPlayer }, set: { if !$0 { model.showsPlayer = false } })) {
                    RepetitionPlayerView(model: model)
                }
                .alert(model.importMessage ?? "", isPresented: Binding(get: { model.importMessage != nil },
                                                                      set: { if !$0 { model.importMessage = nil } })) {
                    Button("Okej") { model.importMessage = nil }
                }
                .onOpenURL { url in _ = model.handle(url) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, !model.session.isActive, model.showsPlayer { model.showsPlayer = false }
                }
        } else {
            content
        }
    }
}
