import SwiftUI

/// D86 screen 2: "Lägg till prov". Grade, area → subject, a real date, optionally what is on the exam, or say it.
/// Several exams are kept (`ExamPlanStore`); saving one makes it Provläge's profile.
/// A22 (Kelly Ke9, PLAN 2b): in the first start it is "Har du prov snart?": the voice first (Lumen already listens),
/// then one row of subjects, the date and the grade on one line each (the grade remembered), "Inte nu" to skip.
/// The full form stays for "Lägg till prov" from Start and for editing.
struct AddExamView: View {
    @Bindable var model: ListeningModel
    var isFirstStart = false
    /// A66 (Toby T8c finding 2, Ke35): Starta in Provläge without an exam: "Har du prov snart?" and "Inte nu", which
    /// starts Provläge anyway.
    var forProvlage = false
    var editing: ExamPlan?
    let onClose: () -> Void
    @Environment(AppearanceSettings.self) private var appearance

    @State private var grade: StudyProfile.Grade?
    @State private var course = ""
    @State private var area: ExamPlan.Area = .no
    @State private var subject = "Biologi"
    @State private var otherSubject = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var pickedDate = false
    @State private var topics = ""
    @State private var listeningForVoice = false

    static let grades: [(StudyProfile.Grade, String)] = [(.y6, "Åk 6"), (.y7, "Åk 7"), (.y8, "Åk 8"), (.y9, "Åk 9"),
                                                         (.gy1, "Gy 1"), (.gy2, "Gy 2"), (.gy3, "Gy 3"), (.university, "Högskola")]

    @State private var pickedSubject = false
    /// A33 (D109): in the first start the voice comes first; the form is the fallback behind "Skriv i stället".
    @State private var showsForm = false

    /// Listening as shown: the model's, or "listening" in a screenshot (A46, Kelly Ke18: the Simulator has no microphone).
    private var listeningShown: Bool {
        #if DEBUG
        if model.screenshotShows != nil { return true }
        #endif
        return model.isListening
    }

    /// The short form (A22): the first start, and since A47 (Kelly Ke14/Ke18) "Lägg till prov" from Start too. The full
    /// form stays for changing an exam.
    private var isQuick: Bool { editing == nil }

    var body: some View {
        Group {
            if isQuick { quickBody } else { fullBody }
        }
        // A60 (Toby T8b finding 1): once the exam step is gone, the next sentence is an ordinary one again.
        .onDisappear { model.stopListeningForExamStatement() }
    }

    // MARK: A22 the first start: "Har du prov snart?"

    private static let quickAreas: [ExamPlan.Area] = [.matte, .no, .so, .sprak, .annat]

    private var quickBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isFirstStart || forProvlage ? "Har du prov snart?" : "Lägg till prov")
                        .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text("Säg det, så förhör EarMind dig inför provet.")
                        .font(LumenFont.text(16))
                        .foregroundStyle(LumenColor.muted)
                }
                if listeningForVoice {
                HStack(spacing: 14) {
                    ListeningRings(size: 40, active: listeningShown)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(listeningShown ? "Säg till exempel" : "Startar …").font(LumenFont.text(15, .semibold))
                        Text("Jag har prov i biologi på fredag")
                            .font(appearance.questionFont(19))
                            .foregroundStyle(LumenColor.blue)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
                } else {
                    // A47: from Start the microphone starts only when the student asks for it.
                    Button {
                        listeningForVoice = true
                        Task { await model.askAboutExamByVoice(firstStart: false) }
                    } label: {
                        Label("Säg det i stället", systemImage: "mic")
                    }
                    .font(LumenFont.text(16, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(minHeight: 44)
                }
                if !showsForm {
                    Button("Skriv i stället") { withAnimation(.easeOut(duration: 0.2)) { showsForm = true } }
                        .font(LumenFont.text(16, .semibold))
                        .foregroundStyle(LumenColor.blue)
                        .frame(minHeight: 44)
                }
                if showsForm { quickForm }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                if showsForm {
                    Button("Spara prov", action: save)
                        .buttonStyle(SystemButton())
                        .disabled(!pickedSubject || subjectName.isEmpty)
                }
                Button(isFirstStart || forProvlage ? "Inte nu" : "Avbryt", action: onClose)
                    .font(LumenFont.text(16, .medium))
                    .foregroundStyle(LumenColor.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(LumenColor.background)
        }
        .lumenScreen()
        .onAppear {
            load()
            // A33 (D109): in the first start (already listening) Lumen asks aloud; "biologi på fredag" saves the exam
            // (via /study-profile) and closes this. A22's form stays as the fallback. A47: from Start the form shows
            // at once, and the voice is one tap away.
            if isFirstStart {
                listeningForVoice = true
                Task { await model.askAboutExamByVoice(firstStart: true) }
            } else {
                showsForm = true
            }
        }
        .onChange(of: model.examPlans?.plans.count ?? 0) { old, new in
            if new > old { onClose() }
        }
        .onChange(of: model.examQuestionDeclined) { _, declined in
            if declined, !showsForm { onClose() } // A33: "nej" is "Inte nu"
        }
    }

    /// A22's quick form: one row of areas, date and grade.
    private var quickForm: some View {
        VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Välj ämne").font(LumenFont.text(16, .semibold)).accessibilityAddTraits(.isHeader)
                    FlowChips(items: Self.quickAreas.map { ($0.title, pickedSubject && area == $0) }) { index in
                        area = Self.quickAreas[index]
                        subject = ""
                        pickedSubject = true
                    }
                    if pickedSubject, !area.subjects.isEmpty {
                        // Optional: without a choice the exam is called by the area ("NO") and Provläge asks.
                        FlowChips(items: area.subjects.map { ($0, subject == $0) }) { index in subject = area.subjects[index] }
                            .padding(12)
                            .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
                    }
                    if pickedSubject, area == .annat {
                        labeledField("Vilket ämne?", placeholder: "T.ex. Teknik eller Filosofi", text: $otherSubject)
                    }
                    if pickedSubject {
                        // A47: optional; the study plan (A19) and the quiz use it.
                        labeledField("Vad handlar provet om? (valfritt)", placeholder: "T.ex. cellandning och fotosyntes", text: $topics)
                    }
                }
                VStack(spacing: 0) {
                    Rectangle().fill(LumenColor.line).frame(height: 1)
                    DatePicker("Datum", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        .font(LumenFont.text(17, .semibold))
                        .environment(\.locale, Locale(identifier: "sv_SE"))
                        .frame(minHeight: 52)
                    Rectangle().fill(LumenColor.line).frame(height: 1)
                    HStack {
                        Text("Årskurs").font(LumenFont.text(17, .semibold))
                        Spacer()
                        Picker("Årskurs", selection: $grade) {
                            Text("Välj").tag(nil as StudyProfile.Grade?)
                            ForEach(Self.grades.indices, id: \.self) { index in
                                Text(Self.grades[index].1).tag(StudyProfile.Grade?.some(Self.grades[index].0))
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: 52)
                    Rectangle().fill(LumenColor.line).frame(height: 1)
                }
            }
    }

    // MARK: The full form

    private var fullBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                voiceRow
                gradeSection
                subjectSection
                dateSection
                topicsField
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button("Spara prov", action: save)
                    .buttonStyle(SystemButton())
                    .disabled(subjectName.isEmpty)
                Button(isFirstStart ? "Hoppa över" : "Avbryt", action: onClose)
                    .font(LumenFont.text(16, .medium))
                    .foregroundStyle(LumenColor.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(LumenColor.background)
        }
        .lumenScreen()
        .onAppear(perform: load)
        .onChange(of: model.examPlans?.plans.count ?? 0) { old, new in
            // Said by voice ("jag har prov i biologi på fredag"): saved through the statement, so close.
            if listeningForVoice, new > old { onClose() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("Lägg till prov")
                    .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                IconButton(systemName: "xmark", label: "Stäng", action: onClose)
            }
            Text("Då pratar EarMind på din nivå, hör dina ämnesord rätt och vet vad du ska öva på.")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
        }
    }

    private var voiceRow: some View {
        HStack(spacing: 14) {
            Button {
                listeningForVoice = true
                Task { await model.listenForExamStatement() }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(LumenColor.onBlue)
                    .background(LumenColor.blue, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Berätta med rösten")
            VStack(alignment: .leading, spacing: 2) {
                Text(listeningForVoice ? "Lyssnar, säg det nu" : "Eller säg det").font(LumenFont.text(15, .semibold))
                Text("Jag har prov i biologi på fredag, om fotosyntes")
                    .font(appearance.questionFont(18))
                    .foregroundStyle(LumenColor.blue)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
    }

    private var gradeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Årskurs").font(LumenFont.text(16, .semibold)).accessibilityAddTraits(.isHeader)
            FlowChips(items: Self.grades.map { ($0.1, grade == $0.0) }) { index in grade = Self.grades[index].0 }
            if grade?.isGymnasium == true || grade == .university {
                labeledField("Kurs", placeholder: "T.ex. Biologi 1 eller Matematik 1c", text: $course)
            }
        }
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ämne").font(LumenFont.text(16, .semibold)).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ExamPlan.Area.allCases, id: \.self) { item in
                    Chip(label: item.title, selected: area == item, bold: true, fill: true) {
                        area = item
                        subject = item.subjects.first ?? ""
                    }
                }
            }
            if !area.subjects.isEmpty {
                FlowChips(items: area.subjects.map { ($0, subject == $0) }) { index in subject = area.subjects[index] }
                    .padding(12)
                    .background(LumenColor.chip, in: RoundedRectangle(cornerRadius: 10))
            }
            if area == .annat {
                labeledField("Vilket ämne?", placeholder: "T.ex. Teknik eller Filosofi", text: $otherSubject)
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Datum").font(LumenFont.text(16, .semibold)).accessibilityAddTraits(.isHeader)
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
            HStack(spacing: 8) {
                Chip(label: "Imorgon", selected: Calendar.current.isDate(date, inSameDayAs: tomorrow)) {
                    date = tomorrow
                    pickedDate = true
                }
                DatePicker("Välj datum", selection: $date, in: today..., displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "sv_SE"))
                    .onChange(of: date) { pickedDate = true }
                    .accessibilityLabel("Välj datum")
            }
            Text(ExamPlan.shortDate(date) + ", " + ExamPlan.inDays(daysUntil(date)))
                .font(LumenFont.text(14))
                .foregroundStyle(LumenColor.muted)
        }
    }

    private var topicsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vad kommer på provet?").font(LumenFont.text(16, .semibold))
            Text("Valfritt. Kapitel, områden eller begrepp.").font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
            TextField("T.ex. fotosyntes, cellandning, kapitel 4", text: $topics, axis: .vertical)
                .textFieldStyle(LumenFieldStyle())
                .accessibilityLabel("Vad kommer på provet?")
        }
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
            TextField(placeholder, text: text)
                .textFieldStyle(LumenFieldStyle())
                .accessibilityLabel(label)
        }
    }

    private var subjectName: String {
        switch area {
        case .matte: "Matematik"
        case .annat: otherSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        default: subject.isEmpty ? area.title : subject // A22: "NO" until Provläge knows more
        }
    }

    private func daysUntil(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    private func load() {
        let source: ExamPlan?
        if let editing { source = editing } else { source = nil }
        if let plan = source {
            grade = plan.grade
            course = plan.course
            area = plan.area
            subject = plan.subject
            if plan.area == .annat { otherSubject = plan.subject }
            date = plan.date
            topics = plan.topics
            pickedDate = true
        } else {
            grade = model.studyProfile.profile.grade
        }
    }

    private func save() {
        var plan = editing ?? ExamPlan(area: area, subject: subjectName, date: date)
        plan.grade = grade
        plan.course = (grade?.isGymnasium == true || grade == .university) ? course.trimmingCharacters(in: .whitespaces) : ""
        plan.area = area
        plan.subject = subjectName
        plan.date = Calendar.current.startOfDay(for: date)
        plan.topics = topics.trimmingCharacters(in: .whitespacesAndNewlines)
        model.saveExamPlan(plan)
        onClose()
    }
}

/// A selectable chip, at least 44 pt tall.
struct Chip: View {
    let label: String
    let selected: Bool
    var bold = false
    var fill = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LumenFont.text(15, selected || bold ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(maxWidth: fill ? .infinity : nil, minHeight: 44)
                .foregroundStyle(selected ? LumenColor.blue : LumenColor.ink)
                .background(selected ? LumenColor.soft : LumenColor.background, in: Capsule()) // A46 (SYSTEM.md §3): chips are round
                .overlay {
                    Capsule()
                        .strokeBorder(selected ? LumenColor.blue : LumenColor.line, lineWidth: selected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Chips that wrap onto several lines.
struct FlowChips: View {
    let items: [(String, Bool)]
    let pick: (Int) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Chip(label: item.0, selected: item.1) { pick(index) }
            }
        }
    }
}

/// A simple wrapping layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct LumenFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(LumenFont.text(16))
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(LumenColor.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(LumenColor.line, lineWidth: 1) }
    }
}
