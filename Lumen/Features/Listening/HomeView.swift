import SwiftUI

/// D86 screen 3: Start, in the system of `docs/design/SYSTEM.md` (A18, Kelly Ke12). The nearest exam as a card ("NÄSTA
/// PROV", a badge with the days left, the name, the date, a well with "Öva mer på", and D97's two buttons: **Förhör
/// mig** (blue: Lumen quizzes and answers) and **Få A-svar till provet** (secondary: answers only), each with a line
/// that says the difference). The other exams as a list without microphones, "+ Lägg till prov", then two secondary
/// buttons: "Bara fråga" (Frågor) and "Fler lägen" (a sheet: Provläge, Intervju, Socialt, Rizz 18+). Without an exam:
/// "Har du prov snart?" with "Lägg till prov" as the one blue button. No instruction line (the voice commands show up
/// when they are needed).
struct HomeView: View {
    @Bindable var model: ListeningModel
    @State private var isShowingMoreModes = false
    /// A36: the exam whose page is being photographed.
    @State private var photographing: ExamPlan?
    /// A46: the flip cards being tapped through.
    @State private var flipping: FlipSession?
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
                if let nearest = plans.first {
                    examCard(nearest)
                    otherExams(Array(plans.dropFirst()))
                } else {
                    emptyCard
                }
                modes
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .lumenScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingMoreModes) {
            MoreModesSheet(model: model)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingMicrophoneDenied) {
            MicrophoneDeniedView { isShowingMicrophoneDenied = false }
                .lumenScreen()
        }
        .onChange(of: model.problem == .microphoneDenied) { _, denied in
            if denied { isShowingMicrophoneDenied = true }
        }
        .task { await model.refreshStudyPlan() } // A19: today's pass and the reminders
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
                LumenLogo(size: 24)
                Text("Lumen").font(LumenFont.text(24, .bold, relativeTo: .title2))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            if model.streak.current > 0 { StreakBadge(streak: model.streak) }
            IconButton(systemName: "gearshape", label: "Inställningar") { model.isShowingSettings = true }
        }
    }

    // MARK: The nearest exam

    private func examCard(_ plan: ExamPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                SectionLabel("Nästa prov")
                Spacer(minLength: 8)
                RedPenRing(text: ExamPlan.daysLeftText(plan.daysLeft()))
            }
            Text(plan.name)
                .font(LumenFont.text(28, .bold, relativeTo: .title))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 10)
            HStack(alignment: .firstTextBaseline) {
                Text(plan.dateLine())
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                Spacer(minLength: 8)
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
                    TwoLineLabel(title: "Förhör mig", detail: "Lumen frågar ut dig och svarar på dina frågor")
                }
                .buttonStyle(LumenButtonStyle(height: 62))
                .accessibilityHint("Startar förhöret inför \(plan.name.lowercased())")
                // D97 (owner, final): the second button answers questions and never quizzes. Its name is Aron's.
                Button {
                    Task { await model.startAnswersOnly(for: plan) }
                } label: {
                    TwoLineLabel(title: "Få A-svar till provet", detail: "Lumen svarar bara när du frågar")
                }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 62))
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
                    .accessibilityHint("Lumen läser sidan och förhör dig på den")
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
            Text("Säg det, så förhör Lumen dig inför provet.")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
            Button {
                model.isShowingAddExam = true
            } label: {
                Label("Lägg till prov", systemImage: "plus")
            }
            .buttonStyle(LumenButtonStyle(height: 54))
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

    // MARK: Modes

    /// Two secondary buttons. "Bara fråga" is Frågor; Provläge (without a quiz) and the other modes are in "Fler
    /// lägen". The voice commands reach every mode as before (A13.5).
    private var modes: some View {
        HStack(spacing: 10) {
            Button("Bara fråga") { Task { await model.startMode(.standard) } }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 50))
                .accessibilityHint("Lumen svarar kort på frågor, utan prov")
            Button("Fler lägen") { isShowingMoreModes = true }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 50))
        }
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
            .accessibilityAddTraits(.isHeader)
    }
}

/// "Fler lägen" on Start: Provläge (without a quiz) and the modes for other situations, as plain rows.
struct MoreModesSheet: View {
    @Bindable var model: ListeningModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach([ConversationMode.prov, .interview, .social, .rizz]) { mode in
                    Button {
                        dismiss()
                        Task { await model.startMode(mode) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(LumenColor.blue)
                                .frame(width: 36, height: 36)
                                .background(LumenColor.soft, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.shortName).font(LumenFont.text(17, .semibold)).foregroundStyle(LumenColor.ink)
                                Text(mode.tagline).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .lumenForm()
            .navigationTitle("Fler lägen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
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
