import SwiftUI

/// D86 screen 4: Lyssnar. The squared header with the exam and the mode, "Byt läge" (a sheet with every mode; the
/// listening goes on), the latest question in handwriting and its answer large, the one before dimmed, a thumb down,
/// one spoken command with a "Kommandon" sheet of the five that matter (A18), and Pausa / Avsluta: quiet, the same
/// weight, red only for errors (A18, Kelly Ke9).
struct ListeningScreen: View {
    @Bindable var model: ListeningModel
    let onBack: () -> Void
    @Environment(AppearanceSettings.self) private var appearance
    @State private var isSwitching = false
    @State private var isShowingCommands = false
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
        .sheet(isPresented: $isShowingCommands) {
            CommandsSheet(mode: mode)
                .presentationDetents([.medium])
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
                Spacer(minLength: 0)
                // A13.2: moves when someone talks, so you can see that Lumen hears (nothing while it cannot, A11).
                LevelMeter(levelDBFS: model.isListening && model.isHearing ? model.controller.level.rmsDBFS : nil)
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
        if let quiz = model.silentQuiz {
            return "Tyst förhör, fråga \(max(1, quiz.asked)) av \(SilentQuiz.questions). Nicka för ja, skaka för nej." // A20.2
        }
        return switch model.state {
        case .paused: "Tryck Lyssna igen eller säg ”Lumen, fortsätt”"
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
        } else if mode == .prov {
            // A13.3 / A18: something to start from, for whoever does not want to talk first. "Förhör mig" is the
            // screen's one blue button, with the same words as the voice command.
            VStack(alignment: .leading, spacing: 16) {
                Text("Fråga om det du pluggar, eller bli förhörd.")
                    .font(LumenFont.text(18))
                    .foregroundStyle(LumenColor.muted)
                let terms = Array(ExamKeyterms.terms(profile: model.studyProfile.profile).prefix(8))
                if !terms.isEmpty {
                    TermChips(terms: terms)
                }
                Button {
                    model.askForQuiz()
                } label: {
                    Text("Förhör mig")
                }
                .buttonStyle(LumenButtonStyle(height: 54))
                .padding(.top, 4)
                Text("Eller säg ”Lumen, förhör mig”.")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                // A20.2: for the bus or the library, answered with the head.
                Button("Tyst förhör: svara genom att nicka") { model.startSilentQuiz() }
                    .font(LumenFont.text(16, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
            }
        } else {
            Text("Svaren hörs i örat och syns här.")
                .font(LumenFont.text(18))
                .foregroundStyle(LumenColor.muted)
        }
    }

    /// A13.3: the session's earlier questions and answers, newest first, dimmed (it was only the one before).
    @ViewBuilder
    private var previous: some View {
        let answers = model.conversation.answers
        let skip = model.conversation.streamingAnswer == nil ? 1 : 0
        if model.rizz == nil, answers.count > skip {
            let earlier = Array(answers.dropLast(skip).suffix(30).reversed())
            ForEach(Array(earlier.enumerated()), id: \.offset) { _, turn in
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
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(commandsLine)
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
                    .fixedSize(horizontal: false, vertical: true) // A12: the whole line, never "…"
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Kommandon") { isShowingCommands = true }
                    .font(LumenFont.text(15, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
                    .accessibilityHint("Visar de fem viktigaste röstkommandona")
            }
            if model.isOfferingMore {
                // A15: the window after a short answer.
                Text("Säg ja för mer")
                    .font(LumenFont.text(17, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                    Text(model.isListening ? "Pausa" : "Lyssna igen")
                }
                // A18 (Kelly Ke10): while paused, going on is the one thing to do, so it is the blue button.
                .buttonStyle(LumenButtonStyle(kind: model.isListening ? .secondary : .primary, height: 54))
                Button {
                    Task { await model.endSession() }
                } label: {
                    Text("Avsluta") // the voice's word ("Lumen, avsluta"); "klar" means something in Intervjuläge
                }
                .buttonStyle(LumenButtonStyle(kind: .secondary, height: 54))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(LumenColor.background)
    }

    /// A9.1 / A18: from the command table (the user's own phrases show here too), one command at a time.
    private var commandsLine: String {
        if model.silentQuiz != nil { return "Säg ”Lumen, sluta” för att avsluta förhöret" } // A20.2
        return CommandTips.firstLine(for: mode, table: CommandBook.shared.table)
    }

    private var isReporting: Binding<Bool> {
        Binding(get: { reportingTurn != nil }, set: { if !$0 { reportingTurn = nil } })
    }
}

/// A18: the five voice commands a beginner needs in this mode. The rest: Inställningar › Röstkommandon.
struct CommandsSheet: View {
    let mode: ConversationMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CommandTips.essentials(for: mode), id: \.self) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("”" + CommandTips.spoken(action, table: CommandBook.shared.table) + "”")
                                .font(LumenFont.text(17, .semibold))
                            Text(action.title)
                                .font(LumenFont.text(15))
                                .foregroundStyle(LumenColor.muted)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text("Fler kommandon och egna fraser finns i Inställningar › Röstkommandon.")
                }
            }
            .lumenForm()
            .navigationTitle("Kommandon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
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


/// A13.2: a small, quiet level meter in the app's blue: five bars that follow the microphone (−60…−15 dBFS).
struct LevelMeter: View {
    let levelDBFS: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func fraction(_ dbfs: Double?) -> Double {
        guard let dbfs else { return 0 }
        return min(1, max(0, (dbfs + 60) / 45))
    }

    var body: some View {
        let fraction = Self.fraction(levelDBFS)
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                let threshold = Double(index) / 5
                let lit = fraction > threshold
                Capsule()
                    .fill(lit ? LumenColor.blue : LumenColor.grid)
                    .frame(width: 4, height: 8 + CGFloat(index) * 4)
            }
        }
        .frame(height: 26)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: fraction)
        .accessibilityHidden(true)
    }
}


/// A13.3: the exam's words as plain chips (not selectable), wrapping with `FlowLayout` from AddExamView.
struct TermChips: View {
    let terms: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(terms, id: \.self) { term in
                Text(term)
                    .font(LumenFont.text(15, .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(LumenColor.chip, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ämnesord: " + terms.joined(separator: ", "))
    }
}
