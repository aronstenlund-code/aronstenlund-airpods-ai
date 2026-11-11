import SwiftUI

/// D86 screen 3: Start, in the system of `docs/design/SYSTEM.md` (A18, Kelly Ke12). A50 (D124, D126, Aron's first
/// phone test: "man förstår inte hur man börjar ställa frågor"): the one blue button is **Starta Lumen** at the top,
/// with the chosen mode under it ("Standardläge · Byt"; "Byt" opens the modes and Sov). Under it "Lumen kan allt" with
/// examples that change. Then the nearest exam as a card ("NÄSTA PROV", the days left, the name, the date, a well
/// with "Öva mer på", and **Förhör mig** as a secondary button with its line), the other exams as a list and
/// "+ Lägg till prov". "Få A-svar till provet" is gone from Start (it becomes "Mina svar" inside Provläge, A53), and
/// so are "Bara fråga" and "Fler lägen" (the Start button and "Byt" do both). Without an exam: "Har du prov snart?"
/// with a secondary "Lägg till prov". No instruction line (the voice commands show up when they are needed).
struct HomeView: View {
    @Bindable var model: ListeningModel
    /// A50: "Byt" under the Start button.
    @State private var isPickingMode = false
    @State private var pickedMode: ConversationMode?
    /// A52 (Ke29 S1): "Allt Lumen kan ›" pushes "Vad kan Lumen?".
    @State private var showsCapabilities = false
    /// A52: the sheet after the first answer, once.
    @State private var showsCapabilitiesIntro = false
    @AppStorage(CapabilitiesIntroSheet.shownKey) private var capabilitiesIntroShown = false
    /// Ke35: "Här startar du Earmind" once, until the first Starta or ×.
    @AppStorage("ke35.startHintShown") private var startHintShown = false
    /// Toby T8b finding 4: the last Starta did not start anything.
    @State private var startFailed = false
    /// A54 (D127): the logo vote when the app opens, after the first answer.
    @State private var showsLogoVote = false
    @State private var logoOrder: [LogoChoice] = LogoChoice.allCases
    @Environment(\.scenePhase) private var scenePhase
    /// Ke37 (SYSTEM.md §10): at the five largest text sizes, two-part rows stack.
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var logoSize: CGFloat = 24
    /// A36: the exam whose page is being photographed.
    @State private var photographing: ExamPlan?
    /// A46: the flip cards being tapped through.
    @State private var flipping: FlipSession?
    /// A43: the exam whose "Så redo är du" is open.
    @State private var readinessPlan: ExamPlan?
    /// A24 (Kelly Ke10, T3 finding 3): a start with the microphone off shows the screen that fixes it.
    @State private var isShowingMicrophoneDenied = false

    private var plans: [ExamPlan] { model.examPlans?.upcoming() ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topBar
                if model.problem == .microphoneDenied {
                    // A12: a start that cannot get the microphone says so here (it did nothing before).
                    ErrorCard(problem: .microphoneDenied) { ErrorCard.openSettings() }
                }
                startCard
                LumenCanDoAll { showsCapabilities = true }
                lastNight
                if let nearest = plans.first {
                    examCard(nearest)
                    otherExams(Array(plans.dropFirst()))
                } else {
                    emptyCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .lumenScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isPickingMode, onDismiss: {
            // After the sheet is gone: ListeningView's onChange may present Rizz's age question (D63), and a sheet
            // cannot open while another is closing.
            if let picked = pickedMode { model.selectedMode = picked }
            pickedMode = nil
        }) {
            ModeSwitchSheet(model: model, current: model.selectedMode) { mode in
                pickedMode = mode
            } onSleep: {
                Task { await model.startSleep() }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingMicrophoneDenied) {
            MicrophoneDeniedView { isShowingMicrophoneDenied = false }
                .lumenScreen()
        }
        .onChange(of: model.problem == .microphoneDenied) { _, denied in
            if denied { isShowingMicrophoneDenied = true }
        }
        .task { await model.refreshStudyPlan() } // A19: today's pass and the reminders
        .navigationDestination(isPresented: $showsCapabilities) { CapabilitiesView() }
        .task { await showSheetOnOpen() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await showSheetOnOpen() } } }
        .sheet(isPresented: $showsCapabilitiesIntro) { CapabilitiesIntroSheet() }
        .sheet(isPresented: $showsLogoVote) {
            LogoVoteSheet(order: logoOrder) { choice in
                await model.logoVoteClient?.vote(choice)
            } onVoted: {
                var schedule = LogoVoteSchedule.load()
                schedule.voted = true
                schedule.save()
            } onLater: {
                var schedule = LogoVoteSchedule.load()
                schedule.later(now: Date())
                schedule.save()
            }
        }
        .sheet(item: $readinessPlan) { plan in
            if let readiness = model.readiness(for: plan) {
                ReadinessView(plan: plan, readiness: readiness, known: model.knownConcepts(for: plan),
                              today: model.todayLine(for: plan)) {
                    readinessPlan = nil
                    Task { await model.startQuiz(for: plan) }
                } onClose: {
                    readinessPlan = nil
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { model.sleep.isSleeping || model.sleep.report != nil }, set: { _ in })) {
            // A49 (D123): the night, then the morning report.
            if model.sleep.isSleeping {
                SleepView(sleep: model.sleep)
            } else if let night = model.sleep.report {
                SleepReportView(night: night, clipURL: { model.sleep.store.clipURL($0, in: night) }) {
                    model.sleep.store.delete(night)
                    model.sleep.report = nil
                } onClose: {
                    model.sleep.report = nil
                }
            }
        }
        .fullScreenCover(item: $flipping) { session in
            FlipCardsView(plan: session.plan, deck: session.deck) { card, knew in
                model.recordFlip(card, knew: knew, for: session.plan)
            } onClose: {
                flipping = nil
                Task { await model.refreshStudyPlan() } // A19: today's pass follows the answers
            }
        }
        .fullScreenCover(item: $photographing) { plan in
            PagePhotoPicker { image in
                photographing = nil
                Task { await model.studyPhotographedPage(image, for: plan) }
            } onCancel: {
                photographing = nil
            }
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                LumenLogo(size: logoSize) // Ke37 §10.6: follows the text size
                Text("Earmind").font(LumenFont.text(24, .bold, relativeTo: .title2))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            if model.streak.current > 0 { StreakBadge(streak: model.streak) }
            IconButton(systemName: "gearshape", label: "Inställningar") { model.isShowingSettings = true }
        }
    }

    /// When Start opens, at most one sheet, and only after the first answer (the first start ends with it, or Lumen
    /// has answered before): A52's "Lumen kan mer än svara" once (Ke29), else A54's logo vote when it is due (D127).
    private func showSheetOnOpen() async {
        #if DEBUG
        if ScreenshotStage.requested != nil { return }
        #endif
        let hasAnswered = !model.history.entries.isEmpty || !model.conversation.answers.isEmpty
        guard hasAnswered, !showsCapabilitiesIntro, !showsLogoVote else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, !model.isShowingAddExam, model.showingMyAnswers == nil, !model.isShowingSettings,
              !(model.isActiveSession && model.showsListeningScreen) else { return }
        if !capabilitiesIntroShown {
            capabilitiesIntroShown = true
            showsCapabilitiesIntro = true
            return
        }
        var schedule = LogoVoteSchedule.load()
        guard model.logoVoteClient != nil, schedule.shouldShow(now: Date(), hasAnswered: hasAnswered) else { return }
        var generator = SystemRandomNumberGenerator()
        schedule.ensureOrder(using: &generator) // Ke31: the place should not steer the vote
        schedule.save()
        logoOrder = schedule.order
        showsLogoVote = true
    }

    // MARK: Start (A50, D124)

    /// The one blue button, and the mode it starts under it. While a session runs it goes back to Lyssnar.
    private var startCard: some View {
        VStack(spacing: 6) {
            if !startHintShown, !model.isActiveSession {
                // Ke35: once, after the first start: where Lumen starts.
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Här startar du Earmind").font(LumenFont.text(17, .semibold))
                        Text("Sen lyssnar den tills du trycker Avsluta. Du ser alltid när den lyssnar.")
                            .font(LumenFont.text(15))
                            .foregroundStyle(LumenColor.muted)
                    }
                    Spacer(minLength: 0)
                    Button {
                        startHintShown = true
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(LumenColor.muted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Stäng")
                }
                .padding(.leading, 16)
                .padding(.vertical, 6)
                .background(LumenColor.soft, in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 6)
            }
            Button {
                if model.isActiveSession {
                    model.showsListeningScreen = true
                } else {
                    startHintShown = true
                    startFailed = false
                    Task {
                        await model.startSelectedMode()
                        // Toby T8b finding 4: a start that did not take says so (the microphone card says it itself).
                        startFailed = !model.isActiveSession && model.problem == nil && !model.isShowingAgeGate
                            && !model.isShowingLiveStart && !model.isShowingInterviewSetup && !model.isShowingAddExam && !model.isShowingStudyOnboarding
                    }
                }
            } label: {
                Label(model.isActiveSession ? "Tillbaka till Earmind" : "Starta Earmind", systemImage: "waveform")
                    .font(LumenFont.text(20, .bold, relativeTo: .title3))
            }
            .buttonStyle(LumenButtonStyle(height: 64))
            .overlay {
                if !startHintShown, !model.isActiveSession {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(LumenColor.soft, lineWidth: 4).padding(-4) // Ke35
                }
            }
            .accessibilityHint(model.isActiveSession
                ? "Visar Lyssnar"
                : "Earmind börjar lyssna i \(model.selectedMode.shortName.lowercased())")
            if startFailed {
                Text("Earmind kom inte igång. Tryck igen om en stund.")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.red)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            Button {
                isPickingMode = true
            } label: {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 6))
                layout {
                    HStack(spacing: 6) {
                        Image(systemName: model.selectedMode.symbol)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(LumenColor.muted)
                        Text(model.selectedMode.shortName)
                            .font(LumenFont.text(16, .semibold))
                            .foregroundStyle(LumenColor.ink)
                    }
                    if !typeSize.isAccessibilitySize {
                        Text("·").font(LumenFont.text(16)).foregroundStyle(LumenColor.muted)
                    }
                    Text("Byt")
                        .font(LumenFont.text(16, .semibold))
                        .foregroundStyle(LumenColor.blue)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                // Toby T8b finding 7, Ke35: one element, no "punkt".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Läge: \(model.selectedMode.shortName). Byt läge")
            }
            .buttonStyle(.plain)
        }
    }

    /// A49: last night's report, for 16 hours after waking.
    @ViewBuilder
    private var lastNight: some View {
        if let night = model.sleep.store.latest, let end = night.end, Date().timeIntervalSince(end) < 16 * 3600 {
            Button {
                model.sleep.report = night
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(LumenColor.blue)
                        .frame(width: 36, height: 36)
                        .background(LumenColor.soft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I natt").font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
                        Text(night.talkLine).font(LumenFont.text(17, .semibold)).foregroundStyle(LumenColor.ink)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(LumenColor.muted)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: The nearest exam

    private func examCard(_ plan: ExamPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ke37: the badge goes under the heading at the largest sizes.
            let header = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(alignment: .center))
            header {
                SectionLabel("Nästa prov")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                RedPenRing(text: ExamPlan.daysLeftText(plan.daysLeft()))
            }
            HStack(alignment: .center, spacing: 12) {
                Text(plan.name)
                    .font(LumenFont.text(28, .bold, relativeTo: .title))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if let readiness = model.readiness(for: plan), let percent = readiness.readyPct {
                    // A43 (K33): "68 %" in a ring; a tap shows what is known and what to practise.
                    Button {
                        readinessPlan = plan
                    } label: {
                        ReadinessRing(percent: percent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(percent) procent redo")
                    .accessibilityHint("Visar vad du kan och vad du ska öva på")
                }
            }
            .padding(.top, 10)
            let dateRow = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            dateRow {
                Text(plan.dateLine())
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                // A42 (Deangelo G2): the exam's date and grade are changed here, not in Inställningar.
                Button("Ändra") { model.editingExam = plan }
                    .font(LumenFont.text(15, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Ändra \(plan.name.lowercased())")
            }
            .padding(.top, 2)
            if let today = model.todayLine(for: plan) {
                // A19 (K17): today's pass from the study plan
                VStack(alignment: .leading, spacing: 6) {
                    Text(today).font(LumenFont.text(16, .semibold))
                    if model.canAskForReminders {
                        Button("Påminn mig kl. \(LumenNotifications.timeText())") { Task { await model.refreshStudyPlan(askForReminders: true) } }
                            .font(LumenFont.text(15, .semibold))
                            .frame(minHeight: 44)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 16)
            } else if let practise = model.practiseHint(for: plan) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Öva mer på").font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
                    Text(practise).font(LumenFont.text(16, .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 16)
                .accessibilityElement(children: .combine)
            }
            VStack(spacing: 10) {
                Button {
                    Task { await model.startQuiz(for: plan) }
                } label: {
                    TwoLineLabel(title: "Förhör mig", detail: "Earmind frågar ut dig och svarar på dina frågor")
                }
                // A50 (D124): secondary, the Start button is the screen's one blue button. "Få A-svar till provet"
                // moved into Provläge ("Mina svar", A53, D126).
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 62))
                .accessibilityHint("Startar förhöret inför \(plan.name.lowercased())")
                if let store = model.myAnswers {
                    // A53 (D126, Kelly Ke30): the student's own answers for this exam, always here (also with 0).
                    let count = store.count(for: plan.id)
                    Button {
                        model.showingMyAnswers = MyAnswersRoute(examID: plan.id)
                    } label: {
                        let row = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                            : AnyLayout(HStackLayout())
                        row { // Ke37: two lines at the largest sizes
                            Text("Mina svar").font(LumenFont.text(16, .semibold)).foregroundStyle(LumenColor.ink)
                            if !typeSize.isAccessibilitySize { Spacer() }
                            HStack(spacing: 4) {
                                Text(count == 0 ? "Lägg till" : "\(count) sparade")
                                    .font(LumenFont.text(15))
                                    .foregroundStyle(LumenColor.muted)
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(LumenColor.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(count == 0 ? "Mina svar, inga sparade" : "Mina svar, \(count) sparade")
                    .accessibilityHint("Bestäm själv vad Earmind säger på provfrågor")
                }
                // A36 (D115): photograph the page you study; Lumen quizzes on it.
                if model.isReadingPage || model.pagePhotoStatus != nil {
                    HStack(spacing: 10) {
                        if model.isReadingPage { ProgressView() }
                        Text(model.pagePhotoStatus ?? "").font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
                        Spacer(minLength: 0)
                        if !model.isReadingPage {
                            Button("Stäng") { model.clearPagePhotoStatus() }.font(LumenFont.text(15, .semibold))
                        }
                    }
                    .frame(minHeight: 44)
                } else {
                    Button {
                        photographing = plan
                    } label: {
                        Label("Fota sidan du pluggar", systemImage: "camera")
                    }
                    .font(LumenFont.text(16, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
                    .accessibilityHint("Earmind läser sidan och förhör dig på den")
                }
                if let deck = model.flipDeck(for: plan) {
                    // A46 (N6): the cards on the screen, without the voice.
                    Button {
                        flipping = FlipSession(plan: plan, deck: deck)
                    } label: {
                        Label("Öva med \(deck.cards.count) vändkort", systemImage: "rectangle.on.rectangle")
                    }
                    .font(LumenFont.text(16, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
                    .accessibilityHint("Frågan på ett kort, tryck för svaret, utan ljud")
                }
                if let cards = model.studyCards, !cards.current().isEmpty {
                    // D81: five questions by voice from the study cards.
                    Button("Minitest, 5 frågor") { Task { await model.startMiniTest() } }
                        .font(LumenFont.text(16, .semibold))
                        .foregroundStyle(LumenColor.blue)
                        .frame(minHeight: 44)
                }
            }
            .padding(.top, 18)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridPaper()
    }

    private func otherExams(_ others: [ExamPlan]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !others.isEmpty { SectionLabel("Andra prov").padding(.leading, 4) }
            VStack(spacing: 0) {
                ForEach(others) { plan in
                    Button {
                        Task { await model.startProv(for: plan) }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.subject).font(LumenFont.text(17, .semibold))
                                Text(plan.whenLine()).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LumenColor.muted)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Plugga till \(plan.name.lowercased()), \(plan.whenLine())")
                    .contextMenu {
                        Button("Ändra provet") { model.editingExam = plan } // A42
                        Button("Ta bort provet", role: .destructive) { model.examPlans?.delete(plan.id) }
                    }
                    Rectangle().fill(LumenColor.line).frame(height: 1).padding(.leading, 16)
                }
                Button {
                    model.isShowingAddExam = true
                } label: {
                    Label("Lägg till prov", systemImage: "plus")
                        .font(LumenFont.text(17, .semibold))
                        .foregroundStyle(LumenColor.blue)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(LumenColor.raised, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(LumenColor.line, lineWidth: 1) }
        }
    }

    // MARK: Without an exam

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Har du prov snart?")
                .font(LumenFont.text(28, .bold, relativeTo: .title))
                .accessibilityAddTraits(.isHeader)
            Text("Säg det, så förhör Earmind dig inför provet.")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
            Button {
                model.isShowingAddExam = true
            } label: {
                Label("Lägg till prov", systemImage: "plus")
            }
            .buttonStyle(LumenButtonStyle(kind: .secondary, height: 54)) // A50: Start is the one blue button
            .padding(.top, 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Eller säg").font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
                Text("”Lumen, jag har prov i engelska på onsdag”").font(LumenFont.text(16, .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridPaper()
    }
}

/// A18: a button's title with the line that says what it does (D97's two buttons).
struct TwoLineLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
            Text(detail)
                .font(LumenFont.text(13, relativeTo: .footnote))
                .opacity(0.85)
                .lineLimit(nil) // Ke37 §10.5: the line wraps and the button grows (the style says one line)
                .minimumScaleFactor(1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// A18 (SYSTEM.md): a section heading, 13 semibold, capitals, muted ("NÄSTA PROV", "ANDRA PROV").
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(LumenFont.text(13, .semibold, relativeTo: .footnote))
            .foregroundStyle(LumenColor.muted)
            .lineLimit(1) // Ke37 §10.3: never broken, may shrink a little
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A38 (K31): the streak, small, next to the settings: a flame and the number of days in a row (SYSTEM.md badge,
/// `soft` and blue). While today's question is not done the flame is hollow and VoiceOver says what keeps it.
struct StreakBadge: View {
    let streak: QuizDays.Streak

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: streak.doneToday ? "flame.fill" : "flame")
                .font(.system(size: 15, weight: .semibold))
            Text("\(streak.current)")
                .font(LumenFont.text(16, .bold, relativeTo: .subheadline))
                .monospacedDigit()
        }
        .foregroundStyle(LumenColor.blue)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(LumenColor.soft, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak.current == 1 ? "Svit: 1 dag" : "Svit: \(streak.current) dagar i rad")
        .accessibilityHint(streak.doneToday ? "Dagens fråga är gjord" : "Gör en förhörsfråga i dag, annars börjar sviten om")
    }
}

/// A46: one round of flip cards from the exam card.
struct FlipSession: Identifiable {
    let id = UUID()
    let plan: ExamPlan
    let deck: FlipDeck
}

/// A50 (D126): "Lumen kan allt" under the Start button, three things to say that change every few seconds. With
/// Reduce Motion they stand still. VoiceOver reads the first three once, not the changes.
struct LumenCanDoAll: View {
    /// A52 (Ke29 S1): "Allt Lumen kan ›" at the end of the box.
    var onShowAll: (() -> Void)?
    /// Aron's examples (D126), only for what works today (Kelly Ke29 S2): calendar, reminders and timers (A48), Minne
    /// for the recipe, Provläge's quiz. ”Lumen, kör spellistan Plugg” goes back first when Spotify playlists work
    /// (K36), and ”ring” when calls do.
    nonisolated static let examples = [
        "”Lumen, kolla min kalender, vad har jag i dag?”",
        "”Lumen, vad är mitt favoritrecept för pannkakor?”",
        "”Lumen, förhör mig på fotosyntes”",
        "”Lumen, sätt en timer på 10 minuter”",
        "”Lumen, påminn mig om träningen kl. 18”",
    ]
    nonisolated static let shown = 3

    /// The examples on screen at `step`: a window of `shown` that moves one at a time and wraps.
    nonisolated static func window(at step: Int) -> [String] {
        let start = ((step % examples.count) + examples.count) % examples.count
        return (0..<shown).map { examples[(start + $0) % examples.count] }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            examplesBox
            if let onShowAll {
                Button(action: onShowAll) {
                    HStack(spacing: 4) {
                        Text("Allt Earmind kan")
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .font(LumenFont.text(16, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, onShowAll == nil ? 16 : 4)
        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .task(id: reduceMotion) {
            guard !reduceMotion, !Self.isScreenshot else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                step += 1
            }
        }
    }

    private var examplesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Earmind kan allt")
                    .font(LumenFont.text(20, .bold, relativeTo: .title3))
                    .accessibilityAddTraits(.isHeader)
                Text("Säg ”Lumen” och vad du vill.")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.window(at: step), id: \.self) { line in
                    Text(line)
                        .font(LumenFont.text(16, .semibold))
                        .foregroundStyle(LumenColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: step)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Earmind kan allt. Säg Lumen och vad du vill, till exempel: "
            + Self.window(at: 0).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "”")) }.joined(separator: ", "))
    }

    /// The Simulator screenshots stand still at the first three.
    private static var isScreenshot: Bool {
        #if DEBUG
        ScreenshotStage.requested != nil
        #else
        false
        #endif
    }
}
