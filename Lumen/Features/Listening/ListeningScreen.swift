import SwiftUI

/// D86 screen 4: Lyssnar. The squared header with the exam and the mode, "Byt läge" (a sheet with every mode; the
/// listening goes on), the latest question in handwriting and its answer large, the one before dimmed, a thumb down,
/// the spoken commands, and Pausa / Avsluta (the same words in the app, on the lock screen and by voice).
struct ListeningScreen: View {
    @Bindable var model: ListeningModel
    let onBack: () -> Void
    @Environment(AppearanceSettings.self) private var appearance
    @State private var isSwitching = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var reportingTurn: AnswerTurn?
    @State private var reportComment = ""

    private var mode: ConversationMode { model.study.isActive ? model.mode : .standard }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let problem = model.problem {
                        ErrorCard(problem: problem) { model.act(on: problem) }
                    }
                    latest
                    previous
                    notices
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            footer
        }
        .lumenScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isSwitching) {
            ModeSwitchSheet(model: model, current: mode)
                .presentationDetents([.medium, .large])
        }
        .alert("Fel svar?", isPresented: isReporting, presenting: reportingTurn) { turn in
            TextField("Vad var fel? (valfritt)", text: $reportComment)
            Button("Skicka") { Task { await model.report(turn, comment: reportComment) } }
            Button("Avbryt", role: .cancel) {}
        } message: { _ in
            Text("Din fråga och svaret skickas ordagrant till utvecklarna.")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                IconButton(systemName: "chevron.left", label: "Tillbaka till start", background: LumenColor.background, action: onBack)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(LumenFont.text(18, .bold, relativeTo: .headline)).lineLimit(2).minimumScaleFactor(0.7)
                    Text(subtitle).font(LumenFont.text(14, relativeTo: .subheadline)).foregroundStyle(LumenColor.muted).lineLimit(2).minimumScaleFactor(0.7)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button {
                    isSwitching = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Byt läge")
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                    }
                    .font(LumenFont.text(15, .semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(LumenColor.background, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 14) {
                ListeningRings(size: 64, active: model.isListening)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stateTitle).font(LumenFont.text(22, .bold, relativeTo: .title2))
                    Text(stateDetail).font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 26)
        .background {
            GridPaper(cornerRadius: 0).ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(LumenColor.grid).frame(height: 1) }
    }

    private var plan: ExamPlan? {
        guard mode == .prov else { return nil }
        let subject = model.studyProfile.profile.subject
        return model.examPlans?.upcoming().first { $0.subject.caseInsensitiveCompare(subject) == .orderedSame || ($0.area == .matte && subject == "Matematik") }
    }

    private var title: String { plan?.name ?? mode.shortName.replacingOccurrences(of: " 18+", with: "") }

    private var subtitle: String {
        if let plan { return "Provläge, " + ExamPlan.shortDate(plan.date).lowercased() }
        return mode.tagline
    }

    private var stateTitle: String {
        switch model.state {
        case .listening: model.speaker.status != .idle ? "Svarar" : (model.isHearing ? "Lyssnar" : "Hör inte, försöker igen") // A11
        case .paused: "Pausad"
        case .idle, .error: "Startar …"
        }
    }

    private var stateDetail: String {
        switch model.state {
        case .paused: "Tryck Fortsätt eller säg ”Lumen, fortsätt”"
        default: mode.isLive ? "Lumen ger ett förslag i pausen" : "Ställ en fråga när du vill"
        }
    }

    // MARK: Answers

    @ViewBuilder
    private var latest: some View {
        if let line = model.rizz?.current {
            VStack(alignment: .leading, spacing: 10) {
                Text("Förslag").font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
                Text(line).font(LumenFont.text(23, .medium, relativeTo: .title3))
                Button("Nästa förslag") { model.nextSuggestion() }
                    .font(LumenFont.text(16, .semibold))
                    .frame(minHeight: 44)
            }
        } else if let turn = model.conversation.streamingAnswer ?? model.conversation.answers.last {
            VStack(alignment: .leading, spacing: 12) {
                if !turn.question.isEmpty {
                    Text(turn.question).font(appearance.questionFont(20)).foregroundStyle(LumenColor.blue)
                        .accessibilityLabel("Fråga: \(turn.question)")
                }
                if turn.answer.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Tänker …").foregroundStyle(LumenColor.muted)
                    }
                } else {
                    Text(turn.answer)
                        .font(LumenFont.text(23, .medium, relativeTo: .title3))
                        .textSelection(.enabled)
                }
                if model.conversation.streamingAnswer == nil {
                    HStack {
                        Spacer()
                        Button {
                            reportComment = ""
                            reportingTurn = turn
                        } label: {
                            Image(systemName: "hand.thumbsdown")
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 44, height: 44)
                                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LumenColor.line, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(LumenColor.muted)
                        .accessibilityLabel("Fel svar, skicka till utvecklarna")
                    }
                }
            }
        } else {
            Text(mode == .prov ? "Ställ en fråga om det du pluggar. Svaret hörs i örat." : "Svaren hörs i örat och syns här.")
                .font(LumenFont.text(18))
                .foregroundStyle(LumenColor.muted)
        }
    }

    @ViewBuilder
    private var previous: some View {
        let answers = model.conversation.answers
        let skip = model.conversation.streamingAnswer == nil ? 1 : 0
        if model.rizz == nil, answers.count > skip, let turn = answers.dropLast(skip).last {
            VStack(alignment: .leading, spacing: 8) {
                if !turn.question.isEmpty {
                    Text(turn.question).font(appearance.questionFont(18)).foregroundStyle(LumenColor.muted)
                }
                Text(turn.answer).font(LumenFont.text(16)).foregroundStyle(LumenColor.muted)
            }
            .padding(.top, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(LumenColor.line).frame(height: 1) }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var notices: some View {
        ForEach(model.visibleNotices, id: \.self) { notice in
            Text(notice).font(LumenFont.text(15)).foregroundStyle(LumenColor.muted)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 14) {
            Text(commandsLine)
                .font(LumenFont.text(15))
                .foregroundStyle(LumenColor.muted)
                .fixedSize(horizontal: false, vertical: true) // A12: the whole line, never "…"
                .frame(maxWidth: .infinity, alignment: .leading)
            if let tip = model.tipNotice {
                Text(tip)
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // A12: at the accessibility text sizes the two buttons stack, so each gets the whole width.
            let buttonRow = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            buttonRow {
                Button {
                    Task { await model.togglePause() }
                } label: {
                    Label(model.isListening ? "Pausa" : "Fortsätt", systemImage: model.isListening ? "pause.fill" : "play.fill")
                }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 54))
                Button {
                    Task { await model.endSession() }
                } label: {
                    Label("Avsluta", systemImage: "stop.fill")
                }
                .buttonStyle(LumenButtonStyle(kind: .danger, height: 54))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(LumenColor.background)
    }

    /// A9.1: from the command table, so the user's own phrases show here too.
    private var commandsLine: String {
        model.commandsLine(for: mode)
    }

    private var isReporting: Binding<Bool> {
        Binding(get: { reportingTurn != nil }, set: { if !$0 { reportingTurn = nil } })
    }
}

/// "Byt läge": every mode, the current one marked. Listening goes on while switching.
struct ModeSwitchSheet: View {
    @Bindable var model: ListeningModel
    let current: ConversationMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach([ConversationMode.prov, .standard, .interview, .social, .rizz]) { mode in
                        Button {
                            dismiss()
                            Task { await model.switchMode(to: mode) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: mode.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(LumenColor.background)
                                    .frame(width: 44, height: 44)
                                    .background(mode.color, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.shortName).font(LumenFont.text(17, .semibold))
                                    Text(mode.tagline).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
                                }
                                Spacer()
                                if mode == current {
                                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(LumenColor.blue)
                                }
                            }
                            .padding(12)
                            .frame(minHeight: 60)
                            .background(mode == current ? LumenColor.soft : LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(mode == current ? .isSelected : [])
                    }
                    Text("Lumen lyssnar vidare när du byter. Du kan också säga ”Lumen, byt till socialt”.")
                        .font(LumenFont.text(15))
                        .foregroundStyle(LumenColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .lumenScreen()
            .navigationTitle("Byt läge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
    }
}
