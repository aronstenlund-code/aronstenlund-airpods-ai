import SwiftUI

/// D86 screen 3: Start. The nearest exam as a squared card (name, date, the red pen's "N dagar kvar", "Öva mer på",
/// "Få A-svar till provet"), the other exams as rows with a microphone, "Lägg till prov", four round mode buttons,
/// and a line about switching by voice. Without an exam: "Har du ett prov snart?".
struct HomeView: View {
    @Bindable var model: ListeningModel
    @Environment(AppearanceSettings.self) private var appearance
    @AppStorage("home.showsMoreModes") private var showsMoreModes = false

    private var plans: [ExamPlan] { model.examPlans?.upcoming() ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                if model.problem == .microphoneDenied {
                    // A12: a start that cannot get the microphone says so here (it did nothing before).
                    ErrorCard(problem: .microphoneDenied) { ErrorCard.openSettings() }
                }
                if let nearest = plans.first {
                    examCard(nearest)
                    otherExams(Array(plans.dropFirst()))
                    modes(title: "Andra lägen")
                } else {
                    emptyCard
                    modes(title: "Eller börja direkt")
                }
                Text("Byt läge utan att ta upp telefonen. Säg ”Lumen, byt till intervju”.")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .lumenScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                LumenLogo(size: 26)
                Text("Lumen").font(LumenFont.text(26, .bold, relativeTo: .title))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            IconButton(systemName: "gearshape", label: "Inställningar") { model.isShowingSettings = true }
        }
    }

    // MARK: The nearest exam

    private func examCard(_ plan: ExamPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.name)
                .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(plan.dateLine()).font(LumenFont.text(17)).foregroundStyle(LumenColor.muted)
                    Spacer(minLength: 0)
                    RedPenRing(text: ExamPlan.daysLeftText(plan.daysLeft()))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.dateLine()).font(LumenFont.text(17)).foregroundStyle(LumenColor.muted)
                    RedPenRing(text: ExamPlan.daysLeftText(plan.daysLeft()))
                }
            }
            .accessibilityElement(children: .combine)
            if let practise = model.practiseHint(for: plan) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Öva mer på").font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
                    Text(practise).font(LumenFont.text(18, .semibold))
                }
                .padding(.top, 14)
                .accessibilityElement(children: .combine)
            }
            Button {
                Task { await model.startProv(for: plan) }
            } label: {
                Label("Få A-svar till provet", systemImage: "mic")
            }
            .buttonStyle(LumenButtonStyle(height: 54))
            .padding(.top, 16)
            .accessibilityHint("Startar Provläget för \(plan.name)")
            if let cards = model.studyCards, !cards.current().isEmpty {
                // D81: five questions by voice from the study cards.
                Button {
                    Task { await model.startMiniTest() }
                } label: {
                    Label("Minitest, 5 frågor", systemImage: "checklist")
                }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 48))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridPaper()
    }

    private func otherExams(_ others: [ExamPlan]) -> some View {
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
                        Image(systemName: "mic")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(LumenColor.blue)
                            .frame(width: 44, height: 44)
                            .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.vertical, 6)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Plugga till \(plan.name.lowercased()), \(plan.whenLine())")
                .contextMenu {
                    Button("Ta bort provet", role: .destructive) { model.examPlans?.delete(plan.id) }
                }
                Rectangle().fill(LumenColor.line).frame(height: 1)
            }
            addExamButton
        }
    }

    private var addExamButton: some View {
        Button {
            model.isShowingAddExam = true
        } label: {
            Label("Lägg till prov", systemImage: "plus")
                .font(LumenFont.text(17, .semibold))
                .foregroundStyle(LumenColor.blue)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: Without an exam

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Har du ett prov snart?")
                .font(LumenFont.text(30, .bold, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)
            Text("Lägg till det, så pratar Lumen på din nivå och vet vad du ska öva på.")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
            Button {
                model.isShowingAddExam = true
            } label: {
                Label("Lägg till prov", systemImage: "plus")
            }
            .buttonStyle(LumenButtonStyle(height: 54))
            .padding(.top, 8)
            Text("Eller säg").font(LumenFont.text(15)).foregroundStyle(LumenColor.muted).padding(.top, 4)
            Text("Lumen, jag har prov i engelska på onsdag")
                .font(appearance.questionFont(19))
                .foregroundStyle(LumenColor.blue)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridPaper(dashed: true)
    }

    // MARK: Modes

    /// A13.5 (owner 2026-11-09): Start shows Frågor and Provläge; Intervju, Socialt and Rizz 18+ sit under "Fler lägen".
    /// The voice commands reach every mode as before.
    private func modes(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(LumenFont.text(17, .semibold)).accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 8) {
                ForEach([ConversationMode.standard, .prov]) { mode in
                    ModeCircle(mode: mode) { Task { await model.startMode(mode) } }
                }
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            Button {
                withAnimation { showsMoreModes.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Fler lägen")
                    Image(systemName: showsMoreModes ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .bold))
                }
                .font(LumenFont.text(16, .semibold))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LumenColor.blue)
            if showsMoreModes {
                HStack(alignment: .top, spacing: 8) {
                    ForEach([ConversationMode.interview, .social, .rizz]) { mode in
                        ModeCircle(mode: mode) { Task { await model.startMode(mode) } }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 4)
    }
}
