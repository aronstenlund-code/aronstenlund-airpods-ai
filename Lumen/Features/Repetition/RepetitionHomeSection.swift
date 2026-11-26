import SwiftUI
import UIKit

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
    @State private var showsLaunchOffer = false // A161 (D259)
    @State private var opensShopAfterOffer = false
    @State private var showsShop = false
    /// A165: the deck whose screen is closing (the sheet's item is already nil when its onDismiss runs).
    @State private var closingOwnDeck: UUID?
    /// A165 (D263): the deck whose screen is up, and the deck to practise once that screen has closed.
    @State private var ownDeck: OwnDeckSheet?
    @State private var practisesOwn: UUID?

    struct OwnDeckSheet: Identifiable {
        let id: UUID
    }

    /// A165: the user's own decks, listed among the quizzes (Ke89 §1).
    private var ownDecks: [OwnDeck] { model.ownDecks?.decks ?? [] }
    /// Start shows its list (not the empty state) when there is a quiz or an own deck.
    private var hasList: Bool { !model.examDrills.isEmpty || !ownDecks.isEmpty }
    @Environment(\.scenePhase) private var scenePhase
    @State private var pastedCode = ""
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false
    @AppStorage("repetition.textControlsChecked") private var textControlsChecked = false // A106 (Ke63 §4.1)
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SayMotion.reduces(systemReduceMotion) }

    /// A100 (Deangelo 2026-11-14, Toby T21 finding 2): "Fler lägen · Beta · använder mikrofonen" is shown only once
    /// the user has started a first exam (the control check before the first Starta prov sets `controlsChecked`).
    /// Before that a new user sees the exam and Starta prov, nothing about BETA or the microphone.
    private var showsMoreModes: Bool { controlsChecked || textControlsChecked }

    /// A153: the keyboard is up (the bottom row then steps aside).
    @State private var keyboardIsUp = false
    /// A153: where the keyboard with its row begins, and where the strip under that row ends (both on the screen).
    @State private var keyboardTop: CGFloat?
    @State private var keyboardStripBottom: CGFloat?
    private var keyboardStripHeight: CGFloat {
        SayKeyboard.stripHeight(bottom: keyboardStripBottom, keyboardTop: keyboardTop)
    }

    /// A161 (D259): asks whether the launch week runs (at most every quarter of an hour) and shows the offer once a
    /// day. Not on top of another sheet.
    private func offerLaunchWeek() async {
        guard let shop = model.shop, !showsLaunchOffer, !showsShop, !isCreating, !askingReminder, checking == nil else { return }
        await shop.loadOffer(maxAge: 900)
        guard shop.shouldShowLaunchSheet() else { return }
        shop.launchSheetShown()
        showsLaunchOffer = true
    }

    /// A165 (D263): nothing of Start's own is over it, so the sheet about "Spela in själv" can come up here.
    private var isFront: Bool {
        !isCreating && !showsShop && !showsLaunchOffer && !askingReminder && !askingCode && checking == nil
            && ownDeck == nil && !model.showsPlayer
    }

    /// A165: the sheet's button was pressed (here or in Nytt prov, which closes first): "Spela in själv" opens.
    private func openOwnDecksIfAsked() {
        guard model.ownOffer.opensDecks, !isCreating, model.ownDecks != nil else { return }
        model.ownOffer.opensDecks = false
        newOwnDeck()
    }

    /// A165 (Ke89 §2): the way in opens the screen of a new deck at once, with its first card to write in.
    private func newOwnDeck() {
        guard let decks = model.ownDecks, ownDeck == nil else { return }
        ownDeck = OwnDeckSheet(id: OwnDeckTidy.newDeck(in: decks).id)
    }

    /// A165: the deck's screen has closed. What was never filled in goes, and Öva starts the deck in the player.
    private func ownDeckClosed(_ id: UUID?) {
        guard let decks = model.ownDecks, let id else { return }
        let kept = OwnDeckTidy.afterEditing(id, in: decks)
        if practisesOwn == id, kept, let deck = decks.deck(id), decks.canStart(deck) {
            Task { await model.start(own: deck) }
        }
        practisesOwn = nil
    }

    var body: some View {
        Group {
            if hasList { examList } else { emptyState }
        }
        // A165 (D263): the screen of an own deck, and the sheet that points there when the server says no.
        .sheet(item: $ownDeck, onDismiss: { ownDeckClosed(closingOwnDeck) }) { item in
            if let decks = model.ownDecks {
                NavigationStack {
                    OwnDeckView(decks: decks, deckID: item.id) {
                        practisesOwn = item.id
                        ownDeck = nil
                    }
                }
            }
        }
        .onChange(of: ownDeck?.id) { old, new in if let new { closingOwnDeck = new } else if old != nil { closingOwnDeck = old } }
        // The sheet's button: once the sheet is down (or Nytt prov, when it was said there), the new deck comes up.
        .modifier(OwnDeckOfferPresenter(model: model, isFront: isFront) { openOwnDecksIfAsked() })
        // A132 (D215): no large "Prov" heading; the capsule and the gear are enough, and the room goes to the field.
        // The name stays for VoiceOver and for the way back from the screens that are pushed.
        .navigationTitle("Prov")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) } }
        .safeAreaInset(edge: .bottom) { // Kelly S3: a fixed row, nothing floats over the text
            // A100: without an exam the row only held Fler lägen, which a new user does not see yet.
            // A153 (D238): not while the keyboard is up. The row rode up on the keyboard and took the room the
            // field needs (on an iPhone SE it lay over the field's own Spela).
            if keyboardIsUp {
                // Kelly (2026-11-19): what stands in the row above the keyboard (Spela, Klar, the style's
                // suggestions) is read against a plain ground. The row is glass and floats over the list; this strip
                // lies under it, from where the keyboard's row begins down to the keys. It also ends the list
                // there, so the line that is being written stays above the row.
                // The strip has the card's colour: the card's fields bring up the dark keyboard and its dark row
                // in light mode too, and on the screen's light ground the row's light words were weak (the
                // pictures of 2026-11-19). In the card's colour the row reads as the foot of the card.
                // On a phone with a home button the content already ends where the row begins (iPhone SE: the strip
                // came out 0 points high and was not there); it is then one point, and its ground reaches down.
                Color.clear
                    .frame(height: max(keyboardStripHeight, 1))
                    .frame(maxWidth: .infinity)
                    .background { (scheme == .dark ? SayText.fieldDark : SayText.field).ignoresSafeArea(.all, edges: .bottom) }
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { keyboardStripBottom = $0 }
                    .accessibilityHidden(true)
            } else if hasList || showsMoreModes {
                bottomRow
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardIsUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardIsUp = false }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboardTop = SayKeyboard.top(from: note)
        }
        .toolbar { barItems }
        .sheet(isPresented: $isCreating, onDismiss: { openOwnDecksIfAsked() }) { // A165: the free way, asked for in Nytt prov
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
                    model.importMessage = String(localized: "Det ser inte ut som en länk till ett prov.")
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
        .onChange(of: model.isSayingOnCard) { offerReminder() }
        .onAppear { offerReminder() }
        .task { model.prepareAllAudio() }
        .task { await model.refreshQuota() } // A117: the capsule's number
        // A161 (D259): during the launch week the offer is said once when the app is opened (once a day at most).
        .task { await offerLaunchWeek() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await offerLaunchWeek() } }
        }
        .sheet(isPresented: $showsLaunchOffer, onDismiss: { if opensShopAfterOffer { opensShopAfterOffer = false; showsShop = true } }) {
            if let offer = model.shop?.activeOffer() {
                LaunchOfferSheet(offer: offer, covers: model.shop?.offerCovers() ?? .init(packs: true, pass: false)) {
                    opensShopAfterOffer = true
                }
            }
        }
        .sheet(isPresented: $showsShop) { CreditsSheet(model: model) }
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
            if !hasList {
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
            if model.ownDecks != nil { // A165 (D263): the free way, right under Nytt prov
                Button { newOwnDeck() } label: { Self.textButton(OwnDeckText.entry) }
                    .accessibilityIdentifier("home.ownDecks")
            }
            if model.canPublish { // A83 (Ke52 "Hem")
                Button { showsSchool = true } label: { Self.textButton(String(localized: "Hitta prov från din skola")) }
            }
            Button { askingCode = true } label: { Self.textButton(String(localized: "Klistra in en länk")) }
            if let lastNight {
                Button(action: onLastNight) { Text(verbatim: String(localized: "I natt: \(lastNight)")) }
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
            Text(saved == nil ? String(localized: "Starta prov") : String(localized: "Fortsätt"))
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
                    navigationRow(next.isText ? String(localized: "Texten") : String(localized: "Frågor och svar"), detail: nil) { opened = next.id }
                } footer: {
                    // A109 (D194): the days in a row of the repetition flow (3 questions or 2 minutes of a text a
                    // day), or the listening modes' when that is longer.
                    let days = max(streakDays, model.practice.streak.current)
                    if days > 0 {
                        Label {
                            Text(verbatim: days == 1 ? String(localized: "1 dag i rad") : String(localized: "\(days) dagar i rad"))
                        } icon: {
                            Image(systemName: "flame").accessibilityHidden(true) // A95 (Toby): not read as "Flamma"
                        }
                        .foregroundStyle(LumenColor.secondaryText) // A148: AA, as the other grey text
                    }
                }
            }

            if model.examDrills.count > 1 || !ownDecks.isEmpty {
                Section {
                    ForEach(model.examDrills.dropFirst()) { drill in otherExam(drill) }
                    // A165 (Ke89 §1): the own decks lie among the quizzes, "Egen inspelning · 5 frågor".
                    ForEach(ownDecks) { deck in ownDeckRow(deck) }
                } header: {
                    // Without a quiz the own decks are the only ones, so the section is named after them.
                    Group {
                        if model.examDrills.isEmpty { Text(verbatim: OwnDeckText.title) } else { Text("Andra prov") }
                    }
                    .foregroundStyle(LumenColor.secondaryText) // A148: AA
                }
            }

            if model.ownDecks != nil || model.canPublish || lastNight != nil || showsMoreModes {
                Section {
                    if model.ownDecks != nil { // A165 (D263, Ke89 §1): "Spela in själv" with the capsule "Helt gratis"
                        OwnDeckEntryRow { newOwnDeck() }
                    }
                    if model.canPublish { // A83 (Ke52 "Hem")
                        navigationRow(String(localized: "Prov från din skola"), detail: nil) { showsSchool = true }
                    }
                    if let lastNight {
                        navigationRow(String(localized: "I natt"), detail: lastNight, action: onLastNight)
                    }
                    if showsMoreModes { // A100
                        navigationRow(String(localized: "Fler lägen"), detail: String(localized: "Beta · använder mikrofonen"), action: onMoreModes)
                            .accessibilityLabel("Fler lägen")
                            .accessibilityHint("Beta. Lägen som lyssnar på vad du säger")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // A153 (D238): a pull on the list takes the keyboard down with the finger, as in the system's own lists.
        .scrollDismissesKeyboard(.interactively)
        // Kelly P3 (iPhone SE): the last row is not left half under the bottom bar: tighter sections, and room to
        // scroll it clear of the bar.
        .listSectionSpacing(.compact)
        .contentMargins(.bottom, 24, for: .scrollContent)
        // A132 (D215.7, Ke72): without the large heading the card stands right under the capsule.
        .contentMargins(.top, 4, for: .scrollContent)
    }

    /// "Nästa prov": the name, one line of facts and the screen's one filled button.
    private func nextExam(_ drill: Drill) -> some View {
        let saved = place(drill)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nästa prov").font(.footnote).foregroundStyle(LumenColor.secondaryText)
                Text(verbatim: drill.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: facts(drill, saved: saved))
                    .font(.subheadline)
                    .foregroundStyle(LumenColor.secondaryText)
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
                    .transition(SayMotion.appear)
                } else {
                    Button {
                        start(drill)
                    } label: {
                        FilledButtonLabel { startLabel(saved) } // A95
                    }
                    .buttonStyle(.borderedProminent)
                    .transition(SayMotion.appear)
                }
            }
            // A150 (D231): the filled button changes places with Spela by fading, not by jumping.
            .animation(SayMotion.change(reduceMotion), value: model.sayHoldsTheStage)
            .controlSize(.large)
            .disabled(!model.canStart(drill) && !model.isReadingAloudOff(drill)) // A112b: the text can be opened
            .accessibilityHint(drill.isText ? String(localized: "Läser upp texten i dina AirPods. EarMind använder inte mikrofonen.")
                                   : String(localized: "Spelar frågorna i dina AirPods. EarMind använder inte mikrofonen."))
        }
        .padding(.vertical, 6)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    /// "Du var på fråga 3 av 5", "5 frågor · cirka 1 min per varv" or the sound's progress.
    private func facts(_ drill: Drill, saved: Int?) -> String {
        if drill.audioTrimmed == true, saved == nil { // A135: removed for space, fetched again at Starta prov
            return (drill.isText ? String(localized: "Text") : DrillText.questions(drill.items.count)) + String(localized: " · Ljudet hämtas när du startar")
        }
        if drill.isText { // A106 (Ke63): "Text · cirka 6 min"; the word says what it is, the card is the same
            if let saved { return String(localized: "Du var på mening \(saved + 1) av \(drill.sentenceCount)") }
            if let problem = shortProblem(drill) { return String(localized: "Text · \(problem)") }
            if model.awaitsAudioStart(drill) {
                if let quota = model.quota, quota.isCredits { // A131 (D213): the server's cost, in credits
                    if quota.isUnlimited { return String(localized: "Text · Ljudet görs när du startar") } // A133 (D216)
                    return drill.startCost.map { String(localized: "Text · \(CreditText.cardLine(cost: $0))") } ?? String(localized: "Text · Ljudet görs när du startar")
                }
                if let quota = model.quota { return String(localized: "Text · Räknas som \(startCount(drill)) av dina \(quota.left) när du startar") }
                return String(localized: "Text · Ljudet görs när du startar")
            }
            let p = model.progress(drill)
            if p.total > 0, p.ready == p.total { return String(localized: "Text · cirka \(ReadingText.minutes(drill)) min") }
            return String(localized: "Text · Ljud: \(p.ready) av \(p.total) klara")
        }
        if let saved { return String(localized: "Du var på fråga \(saved + 1) av \(drill.items.count)") }
        // A100 (K62): when the sound cannot be made, say so instead of a counter that stands still.
        if let problem = shortProblem(drill) { return "\(DrillText.questions(drill.items.count)) · \(problem)" }
        // A107 (D190): not started yet, so no "Ljud: 0 av N".
        if model.awaitsAudioStart(drill) {
            // Kelly Ke64b N5: Starta prov on the card starts at once, so the card says what starting counts as.
            if let quota = model.quota, quota.isCredits { // A131 (D213)
                if quota.isUnlimited { return String(localized: "\(DrillText.questions(drill.items.count)) · Ljudet görs när du startar") } // A133
                return drill.startCost.map { "\(DrillText.questions(drill.items.count)) · \(CreditText.cardLine(cost: $0))" }
                    ?? String(localized: "\(DrillText.questions(drill.items.count)) · Ljudet görs när du startar")
            }
            if let quota = model.quota {
                return String(localized: "\(DrillText.questions(drill.items.count)) · Räknas som \(startCount(drill)) av dina \(quota.left) när du startar")
            }
            return String(localized: "\(DrillText.questions(drill.items.count)) · Ljudet görs när du startar")
        }
        let p = model.progress(drill)
        if p.total > 0, p.ready == p.total {
            return String(localized: "\(DrillText.questions(drill.items.count)) · cirka \(DrillText.minutesPerLap(drill)) min per varv")
        }
        return String(localized: "\(DrillText.questions(drill.items.count)) · Ljud: \(p.ready) av \(p.total) klara")
    }

    /// Kelly (A100): on Start only the first sentence of the sound's problem, without the full stop ("Ljudet kan
    /// inte göras just nu"); the exam's own page has the whole of it ("… Försök igen om en stund.").
    private func shortProblem(_ drill: Drill) -> String? {
        guard let problem = model.audio.problem(for: drill) else { return nil }
        return DrillText.cardProblem(problem, creditsShort: model.quotaExceeded(drill)) // T55
    }

    /// Through "Styr med dina AirPods" the first time; after that one tap, from the question the last run stopped at.
    private func start(_ drill: Drill) {
        // Kelly Ke64b N5: when the month does not cover an exam that is not started, the card opens the exam's
        // screen, which says why, instead of starting.
        // T55: the server has already said the credits do not cover it (a new exam is refused at the save, so it
        // has no cost of its own to compare). Trying again only looked like nothing happened.
        if model.quotaExceeded(drill) {
            opened = drill.id
            return
        }
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
        // Toby T46: a text from "Säg i AirPods" plays on its card, and the question came up over it after the first
        // lap, hiding Pausa and Stoppa. It waits until nothing plays on the card.
        guard model.asksForReminders, !model.showsPlayer, !model.isSayingOnCard, !askingReminder else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if model.asksForReminders, !model.showsPlayer, !model.isSayingOnCard { askingReminder = true }
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
        let what = drill.isText ? String(localized: "Text · cirka \(ReadingText.minutes(drill)) min") : DrillText.questions(drill.items.count)
        let detail = ready ? String(localized: "\(what) · ljud klart")
            : drill.audioTrimmed == true ? String(localized: "\(what) · Ljudet hämtas när du startar") // A135: no counter that stands still
            : shortProblem(drill) ?? (model.awaitsAudioStart(drill) ? what // A107: nothing to count before Starta prov
                : String(localized: "Ljud: \(p.ready) av \(p.total) klara")) // A100 (K62)
        return HStack(spacing: 12) {
            Button {
                opened = drill.id
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: drill.title).foregroundStyle(.primary)
                    Text(verbatim: detail).font(.subheadline).foregroundStyle(LumenColor.secondaryText).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressFeedback) // A150: the row answers the touch on the way down
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

    /// A165 (Ke89 §1): an own deck as a quiz among the others: the row opens its screen, ▶ practises it directly.
    private func ownDeckRow(_ deck: OwnDeck) -> some View {
        HStack(spacing: 12) {
            Button {
                ownDeck = OwnDeckSheet(id: deck.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: deck.title).foregroundStyle(.primary)
                    Text(verbatim: OwnDeckText.deckLine(cards: deck.cards.count))
                        .font(.subheadline).foregroundStyle(LumenColor.secondaryText).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressFeedback)
            .accessibilityHint(String(localized: "Öppnar samlingen"))
            Button {
                Task { await model.start(own: deck) }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .disabled(!(model.ownDecks?.canStart(deck) ?? false))
            .accessibilityLabel("Starta \(deck.title)")
        }
        .accessibilityIdentifier("home.ownDeck")
    }

    /// A row that goes somewhere: the title, at most one line under it and the system's chevron.
    private func navigationRow(_ title: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).foregroundStyle(Color.primary)
                    if let detail {
                        Text(verbatim: detail).font(.subheadline).foregroundStyle(LumenColor.secondaryText)
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
                SectionLabel(String(localized: "Fler lägen"))
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
