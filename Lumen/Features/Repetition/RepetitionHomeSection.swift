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
    @State private var askingReminder = false // A109
    @State private var pastedCode = ""
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false
    @AppStorage("repetition.textControlsChecked") private var textControlsChecked = false // A106 (Ke63 §4.1)
    @Environment(\.dynamicTypeSize) private var typeSize

    /// A100 (Deangelo 2026-11-14, Toby T21 finding 2): "Fler lägen · Beta · använder mikrofonen" is shown only once
    /// the user has started a first exam (the control check before the first Starta prov sets `controlsChecked`).
    /// Before that a new user sees the exam and Starta prov, nothing about BETA or the microphone.
    private var showsMoreModes: Bool { controlsChecked || textControlsChecked }

    var body: some View {
        Group {
            if model.examDrills.isEmpty { emptyState } else { examList }
        }
        // A132 (D215): no large "Prov" heading; the capsule and the gear are enough, and the room goes to the field.
        // The name stays for VoiceOver and for the way back from the screens that are pushed.
        .navigationTitle("Prov")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) } }
        .safeAreaInset(edge: .bottom) { // Kelly S3: a fixed row, nothing floats over the text
            // A100: without an exam the row only held Fler lägen, which a new user does not see yet.
            if !model.examDrills.isEmpty || showsMoreModes { bottomRow }
        }
        .toolbar { barItems }
        .sheet(isPresented: $isCreating) {
            NewDrillView(model: model) { drill in opened = drill.id }
        }
        .sheet(item: $checking) { drill in
            ControlCheckView(hub: model.remote,
                             sound: drill.isText ? model.audio.reading(for: drill, part: 0)?.url
                                 : model.audio.track(for: drill, at: 0)?.question,
                             forText: drill.isText, help: model) {
                if drill.isText { textControlsChecked = true } else { controlsChecked = true }
                checking = nil
                Task { await model.start(drill, at: place(drill) ?? 0) }
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
        // A109 (D194, Ke65): the app's question about a reminder, after the first exam that was played through and
        // once the player is closed (two covers cannot change places at once, so a short wait).
        .sheet(isPresented: $askingReminder) {
            PracticeReminderQuestion(model: model)
        }
        .onChange(of: model.showsPlayer) { offerReminder() }
        .onChange(of: model.asksForReminders) { offerReminder() }
        .onAppear { offerReminder() }
        .task { model.prepareAllAudio() }
        .task { await model.refreshQuota() } // A117: the capsule's number
        // Toby T36 (2026-11-17): the capsule still said 15 after a new text had been played. The number is read again
        // when the player closes, so what was counted (or given back, D200) while it played shows on Start.
        .onChange(of: model.showsPlayer) { _, shows in if !shows { Task { await model.refreshQuota() } } }
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
        if !testModeOn, model.quota != nil {
            // A117 (D205, Ke69): the month's questions, where one can see them. (With the test mode on, its word
            // stands here.)
            ToolbarItem(placement: .topBarLeading) { CreditsCapsule(model: model) }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSettings) {
                Label("Inställningar", systemImage: "gearshape")
            }
        }
        if typeSize.isAccessibilitySize, !model.examDrills.isEmpty {
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
            if model.examDrills.isEmpty {
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
                VStack(spacing: 0) {
                    sayField.padding(.horizontal, 16).padding(.top, 8)
                    emptyContent.frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 220))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label("Kom förberedd till provet", systemImage: "book.closed") // A86 (Aron 22:19)
        } description: {
            // Kelly Ke67: the reading mode is named too, in the same words as the demo page.
            Text("Fota ditt material. EarMind gör frågor och svar, eller läser upp texten, i dina AirPods.")
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

    private func startLabel(_ saved: Int?) -> some View {
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

    /// A115 (D203, Ke69): "Säg i AirPods" is the first thing on Start, above Nästa prov.
    private var sayField: some View {
        SayInAirPodsField(model: model)
    }

    private var examList: some View {
        List {
            Section {
                sayField
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if let next = model.examDrills.first {
                Section {
                    nextExam(next)
                    // Kelly Ke64 L2: a text has no questions.
                    navigationRow(next.isText ? "Texten" : "Frågor och svar", detail: nil) { opened = next.id }
                } footer: {
                    // A109 (D194): the days in a row of the repetition flow (3 questions or 2 minutes of a text a
                    // day), or the listening modes' when that is longer.
                    let days = max(streakDays, model.practice.streak.current)
                    if days > 0 {
                        Label {
                            Text(verbatim: days == 1 ? "1 dag i rad" : "\(days) dagar i rad")
                        } icon: {
                            Image(systemName: "flame").accessibilityHidden(true) // A95 (Toby): not read as "Flamma"
                        }
                    }
                }
            }

            if model.examDrills.count > 1 {
                Section("Andra prov") {
                    ForEach(model.examDrills.dropFirst()) { drill in otherExam(drill) }
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
        let saved = place(drill)
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
                ProgressView(value: Double(saved), total: Double(max(drill.isText ? drill.sentenceCount : drill.items.count, 1)))
                    .accessibilityHidden(true)
            }
            // A132 (D215.1, Kelly Ke72): at most one filled button on Start. While the field has a text to play (or
            // plays one) Spela is the filled one, and Starta prov is toned down.
            Group {
                if model.sayHoldsTheStage {
                    Button {
                        start(drill)
                    } label: {
                        startLabel(saved)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                } else {
                    Button {
                        start(drill)
                    } label: {
                        FilledButtonLabel { startLabel(saved) } // A95
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
            .disabled(!model.canStart(drill) && !model.isReadingAloudOff(drill)) // A112b: the text can be opened
            .accessibilityHint(drill.isText ? "Läser upp texten i dina AirPods. EarMind använder inte mikrofonen."
                                   : "Spelar frågorna i dina AirPods. EarMind använder inte mikrofonen.")
        }
        .padding(.vertical, 6)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    /// "Du var på fråga 3 av 5", "5 frågor · cirka 1 min per varv" or the sound's progress.
    private func facts(_ drill: Drill, saved: Int?) -> String {
        if drill.isText { // A106 (Ke63): "Text · cirka 6 min"; the word says what it is, the card is the same
            if let saved { return "Du var på mening \(saved + 1) av \(drill.sentenceCount)" }
            if let problem = shortProblem(drill) { return "Text · \(problem)" }
            if model.awaitsAudioStart(drill) {
                if let quota = model.quota, quota.isCredits { // A131 (D213): the server's cost, in credits
                    return drill.startCost.map { "Text · \(CreditText.cardLine(cost: $0))" } ?? "Text · Ljudet görs när du startar"
                }
                if let quota = model.quota { return "Text · Räknas som \(startCount(drill)) av dina \(quota.left) när du startar" }
                return "Text · Ljudet görs när du startar"
            }
            let p = model.progress(drill)
            if p.total > 0, p.ready == p.total { return "Text · cirka \(ReadingText.minutes(drill)) min" }
            return "Text · Ljud: \(p.ready) av \(p.total) klara"
        }
        if let saved { return "Du var på fråga \(saved + 1) av \(drill.items.count)" }
        // A100 (K62): when the sound cannot be made, say so instead of a counter that stands still.
        if let problem = shortProblem(drill) { return "\(DrillText.questions(drill.items.count)) · \(problem)" }
        // A107 (D190): not started yet, so no "Ljud: 0 av N".
        if model.awaitsAudioStart(drill) {
            // Kelly Ke64b N5: Starta prov on the card starts at once, so the card says what starting counts as.
            if let quota = model.quota, quota.isCredits { // A131 (D213)
                return drill.startCost.map { "\(DrillText.questions(drill.items.count)) · \(CreditText.cardLine(cost: $0))" }
                    ?? "\(DrillText.questions(drill.items.count)) · Ljudet görs när du startar"
            }
            if let quota = model.quota {
                return "\(DrillText.questions(drill.items.count)) · Räknas som \(startCount(drill)) av dina \(quota.left) när du startar"
            }
            return "\(DrillText.questions(drill.items.count)) · Ljudet görs när du startar"
        }
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
        // Kelly Ke64b N5: when the month does not cover an exam that is not started, the card opens the exam's
        // screen, which says why, instead of starting.
        if model.awaitsAudioStart(drill), let quota = model.quota,
           quota.isCredits ? (drill.startCost ?? 0) > quota.left : startCount(drill) > quota.left {
            opened = drill.id
            return
        }
        if model.isReadingAloudOff(drill) || (drill.isText ? textControlsChecked : controlsChecked) { // A112b: no check without sound
            Task { await model.start(drill, at: place(drill) ?? 0) }
        } else {
            checking = drill
        }
    }

    /// A107 (D191): what starting an exam counts as of the month's questions (a text: every started 800 characters).
    private func startCount(_ drill: Drill) -> Int {
        drill.isText ? DrillTextDraft.countsAs(chars: drill.items.reduce(0) { $0 + $1.long.count }) : drill.items.count
    }

    private func offerReminder() {
        guard model.asksForReminders, !model.showsPlayer, !askingReminder else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if model.asksForReminders, !model.showsPlayer { askingReminder = true }
        }
    }

    /// Where the exam was left: the question, or for a text (A106) the sentence.
    private func place(_ drill: Drill) -> Int? {
        drill.isText ? model.savedSentence(drill) : model.savedIndex(drill)
    }

    /// Kelly R7: the row opens the exam, ▶ starts it directly.
    private func otherExam(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        let what = drill.isText ? "Text · cirka \(ReadingText.minutes(drill)) min" : DrillText.questions(drill.items.count)
        let detail = ready ? "\(what) · ljud klart"
            : shortProblem(drill) ?? (model.awaitsAudioStart(drill) ? what // A107: nothing to count before Starta prov
                : "Ljud: \(p.ready) av \(p.total) klara") // A100 (K62)
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
            .disabled(!model.canStart(drill) && !model.isReadingAloudOff(drill)) // A112b: the text can be opened
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
