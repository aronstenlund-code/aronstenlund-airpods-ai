import SwiftUI

/// D86 screen 3: Start. A18 (Kelly Ke9, Deangelo's user journey): one blue button per screen. The nearest exam as a
/// squared card (name, date, the red pen's "N dagar kvar", "Öva mer på", **Förhör mig**), the other exams as plain
/// rows, "Lägg till prov", then two quiet choices: "Bara fråga" (Frågor) and "Fler lägen" (Provläge without a quiz,
/// Intervju, Socialt, Rizz 18+). Without an exam: "Har du ett prov snart?" with "Lägg till prov" as the blue button.
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
                Task { await model.startQuiz(for: plan) }
            } label: {
                Label("Förhör mig", systemImage: "mic")
            }
            .buttonStyle(LumenButtonStyle(height: 54))
            .padding(.top, 16)
            .accessibilityHint("Lumen förhör dig inför \(plan.name.lowercased()). Du kan också fråga själv.")
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
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LumenColor.muted)
                    }
                    .padding(.vertical, 10)
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
            Text("Har du prov snart?")
                .font(LumenFont.text(30, .bold, relativeTo: .largeTitle))
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
            Text("Eller säg").font(LumenFont.text(15)).foregroundStyle(LumenColor.muted).padding(.top, 4)
            Text("Lumen, jag har prov i engelska på onsdag")
                .font(appearance.questionFont(19))
                .foregroundStyle(LumenColor.blue)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridPaper() // A18 (Kelly Ke10): the same card as with an exam
    }

    // MARK: Modes

    /// A18: two quiet choices instead of five round buttons. "Bara fråga" is Frågor; Provläge (without a quiz) and the
    /// other modes are under "Fler lägen". The voice commands reach every mode as before (A13.5).
    private var modes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    Task { await model.startMode(.standard) }
                } label: {
                    Label("Bara fråga", systemImage: "questionmark")
                        .font(LumenFont.text(16, .semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LumenColor.line, lineWidth: 1) }
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(LumenColor.ink)
                .accessibilityHint("Lumen svarar kort på frågor, utan prov")
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showsMoreModes.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("Fler lägen")
                        Image(systemName: showsMoreModes ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .bold))
                    }
                    .font(LumenFont.text(16, .semibold))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(LumenColor.blue)
                Spacer(minLength: 0)
            }
            if showsMoreModes {
                VStack(spacing: 0) {
                    ForEach([ConversationMode.prov, .interview, .social, .rizz]) { mode in
                        Button {
                            Task { await model.startMode(mode) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(LumenColor.background)
                                    .frame(width: 34, height: 34)
                                    .background(mode.color, in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mode.shortName).font(LumenFont.text(17, .semibold))
                                    Text(mode.tagline).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LumenColor.muted)
                            }
                            .padding(.vertical, 10)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(LumenColor.line).frame(height: 1)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.top, 4)
    }
}
