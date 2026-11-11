import SwiftUI

/// A53: which exam's "Mina svar" is open, and an answer to open straight away ("Ändra svaret" on Lyssnar).
struct MyAnswersRoute: Identifiable, Equatable {
    let id = UUID()
    var examID: UUID?
    var editing: UUID? = nil
}

/// A53 (D126, Kelly Ke30): "Mina svar" for one exam. A list of the student's own questions and answers, "Skriv en
/// fråga" (Lumen suggests, the student edits) and "Spela in ett svar" (compressed when Klar is tapped). Swipe to
/// delete. In SYSTEM.md: one blue button (the empty state's "Skriv en fråga"), iOS lists, no exclamation marks.
struct MyAnswersView: View {
    @Bindable var model: ListeningModel
    let route: MyAnswersRoute
    @State private var examID: UUID?
    @State private var path: [MyAnswersStep] = []
    @Environment(\.dismiss) private var dismiss

    init(model: ListeningModel, route: MyAnswersRoute) {
        self.model = model
        self.route = route
        _examID = State(initialValue: route.examID ?? model.examPlans?.nearest()?.id)
        _path = State(initialValue: route.editing.map { [.edit($0)] } ?? [])
    }

    private var store: MyAnswerStore? { model.myAnswers }
    private var plans: [ExamPlan] { model.examPlans?.upcoming() ?? [] }
    private var items: [MyAnswer] { store?.answers(for: examID) ?? [] }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if items.isEmpty { empty } else { list }
            }
            .lumenScreen()
            .navigationTitle("Mina svar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
            .navigationDestination(for: MyAnswersStep.self) { step in
                switch step {
                case .new:
                    MyAnswerEditor(model: model, examID: examID, existing: nil, draft: nil) { path.removeAll() }
                case .edit(let id):
                    MyAnswerEditor(model: model, examID: examID, existing: store?.answer(id), draft: nil) { path.removeAll() }
                case .record:
                    MyAnswerRecordView(model: model, examID: examID) { draft in
                        path = [.recorded(draft)]
                    } onCancel: {
                        path.removeAll()
                    }
                case .recorded(let draft):
                    MyAnswerEditor(model: model, examID: examID, existing: nil, draft: draft) { path.removeAll() }
                }
            }
        }
    }

    // MARK: First time

    private var empty: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                examPicker
                Text("Bestäm själv vad Earmind säger")
                    .font(LumenFont.text(28, .bold, relativeTo: .title))
                    .accessibilityAddTraits(.isHeader)
                Text("Skriv en provfråga och hur du vill svara. När frågan kommer i Provläget säger Earmind ditt svar, ordagrant.")
                    .font(LumenFont.text(17))
                    .foregroundStyle(LumenColor.muted)
                Button {
                    path.append(.new)
                } label: {
                    Label("Skriv en fråga", systemImage: "square.and.pencil")
                }
                .buttonStyle(LumenButtonStyle(height: 54))
                .padding(.top, 8)
                recordButton
                if store?.isEnabled == false { offLine }
            }
            .padding(20)
        }
    }

    // MARK: The list

    private var list: some View {
        List {
            if plans.count > 1 {
                Section { examPicker.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
            }
            Section {
                ForEach(items) { item in
                    Button {
                        path.append(.edit(item.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.question)
                                    .font(LumenFont.text(17, .semibold))
                                    .foregroundStyle(LumenColor.ink)
                                    .multilineTextAlignment(.leading)
                                if item.recorded {
                                    Text("Inspelat")
                                        .font(LumenFont.text(12, .semibold, relativeTo: .caption))
                                        .foregroundStyle(LumenColor.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(LumenColor.soft, in: Capsule())
                                }
                            }
                            Text(item.answer)
                                .font(LumenFont.text(15))
                                .foregroundStyle(LumenColor.muted)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Radera", role: .destructive) { store?.delete(item.id) }
                    }
                }
            } header: {
                Text("När frågan kommer i Provläget säger Earmind ditt svar, ordagrant.")
                    .textCase(nil)
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
            } footer: {
                if store?.isEnabled == false { offLine }
            }
            Section {
                Button {
                    path.append(.new)
                } label: {
                    Label("Skriv en fråga", systemImage: "square.and.pencil")
                }
                Button {
                    path.append(.record)
                } label: {
                    Label("Spela in ett svar", systemImage: "mic")
                }
                .disabled(model.isActiveSession)
            } footer: {
                if model.isActiveSession {
                    Text("Avsluta Earmind för att spela in.")
                }
            }
        }
        .lumenForm()
    }

    private var recordButton: some View {
        VStack(spacing: 6) {
            Button {
                path.append(.record)
            } label: {
                Label("Spela in ett svar", systemImage: "mic")
            }
            .buttonStyle(LumenButtonStyle(kind: .secondary, height: 54))
            .disabled(model.isActiveSession)
            if model.isActiveSession {
                Text("Avsluta Earmind för att spela in.")
                    .font(LumenFont.text(13, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
            }
        }
    }

    private var offLine: some View {
        Text("”Säg mina svar” är av i Inställningar. Earmind svarar själv tills du sätter på det.")
            .font(LumenFont.text(13, relativeTo: .footnote))
            .foregroundStyle(LumenColor.muted)
    }

    /// One exam at a time, as round chips (only with more than one exam).
    @ViewBuilder
    private var examPicker: some View {
        if plans.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(plans) { plan in
                        let selected = plan.id == examID
                        Button(plan.subject) { examID = plan.id }
                            .font(LumenFont.text(15, .semibold))
                            .foregroundStyle(selected ? LumenColor.onBlue : LumenColor.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(selected ? LumenColor.blue : LumenColor.surface, in: Capsule())
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// A53: what a recording became, for the editor ("FRÅN DIN INSPELNING · 2:14").
struct MyAnswerDraft: Hashable {
    var question: String
    var answer: String
    var transcript: String
    var seconds: TimeInterval
}

enum MyAnswersStep: Hashable {
    case new
    case edit(UUID)
    case record
    case recorded(MyAnswerDraft)
}

/// A53 (Ke30): FRÅGA, LUMENS FÖRSLAG (or the recording's excerpt), DITT SVAR · DET HÄR SÄGER LUMEN, Spara. Lumen's
/// suggestion is fetched when the question is done (the keyboard's Nästa); typing first means it is not used. Spelling
/// is fixed when saving (K37 only fixes spelling; a bigger change is refused by the backend).
struct MyAnswerEditor: View {
    @Bindable var model: ListeningModel
    let examID: UUID?
    let existing: MyAnswer?
    let draft: MyAnswerDraft?
    let onDone: () -> Void

    @State private var question = ""
    @State private var answer = ""
    @State private var suggestion: String?
    @State private var isSuggesting = false
    @State private var isSaving = false
    @State private var corrected: String?
    @State private var isShowingVersions = false
    @State private var isConfirmingDelete = false
    @State private var loaded = false
    @FocusState private var focus: Field?

    private enum Field { case question, answer }

    private var title: String {
        if draft != nil { return "Nytt svar" }
        return existing == nil ? "Ny fråga" : "Ändra svar"
    }

    private var canSave: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                field("Fråga") {
                    TextField("Skriv provfrågan", text: $question, axis: .vertical)
                        .font(LumenFont.text(17))
                        .focused($focus, equals: .question)
                        .submitLabel(.next)
                        .onSubmit { Task { await fetchSuggestion() } }
                        .padding(14)
                        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
                }
                if let draft {
                    field("Från din inspelning · \(MyAnswerText.clock(draft.seconds))") {
                        Text(MyAnswerText.excerpt(draft.transcript))
                            .font(LumenFont.text(15))
                            .foregroundStyle(LumenColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                } else if let suggestion, !suggestion.isEmpty {
                    field("Earminds förslag") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestion)
                                .font(LumenFont.text(15))
                                .foregroundStyle(LumenColor.muted)
                                .textSelection(.enabled)
                            if answer != suggestion {
                                Button("Använd förslaget igen") { answer = suggestion }
                                    .font(LumenFont.text(15, .semibold))
                                    .frame(minHeight: 44)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                field("Ditt svar · det här säger Earmind") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $answer)
                            .font(LumenFont.text(17))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .focused($focus, equals: .answer)
                        if answer.isEmpty {
                            Text(isSuggesting ? "Earmind skriver ett förslag …" : "Skriv hur du vill svara")
                                .font(LumenFont.text(17))
                                .foregroundStyle(LumenColor.muted)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(10)
                    .background(LumenColor.raised, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(LumenColor.blue, lineWidth: 1.5) }
                }
                if let corrected {
                    Text("Rättat: \(corrected)")
                        .font(LumenFont.text(15, .semibold))
                        .foregroundStyle(LumenColor.blue)
                        .transition(.opacity)
                } else {
                    Text("Stavfel rättas när du sparar.")
                        .font(LumenFont.text(13, relativeTo: .footnote))
                        .foregroundStyle(LumenColor.muted)
                }
            }
            .padding(20)
        }
        .lumenScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Avbryt", action: onDone) }
            if existing != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Tidigare versioner", systemImage: "clock.arrow.circlepath") { isShowingVersions = true }
                        Button("Radera svaret", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Mer")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving { ProgressView() } else {
                    Button("Spara") { Task { await save() } }.disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $isShowingVersions) {
            if let existing, let store = model.myAnswers {
                MyAnswerVersionsView(store: store, answerID: existing.id) { restored in
                    question = restored.question
                    answer = restored.answer
                }
            }
        }
        .confirmationDialog("Radera svaret?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Radera svaret", role: .destructive) {
                if let existing { model.myAnswers?.delete(existing.id) }
                onDone()
            }
        } message: {
            Text("Frågan och alla versioner försvinner från telefonen.")
        }
        .onAppear(perform: load)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(label).padding(.leading, 4)
            content()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            question = existing.question
            answer = existing.answer
            suggestion = existing.suggestion
        } else if let draft {
            question = draft.question
            answer = draft.answer
            suggestion = draft.answer
        } else {
            focus = .question
        }
    }

    /// Nästa on the question: Lumen's suggestion goes into DITT SVAR unless the student has started writing.
    private func fetchSuggestion() async {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty, answer.isEmpty, draft == nil, let client = model.myAnswersClient else {
            focus = .answer
            return
        }
        isSuggesting = true
        focus = .answer
        let reply = await client.suggest(question: asked, context: model.myAnswersContext(for: examID))
        isSuggesting = false
        guard let reply, !reply.answer.isEmpty else { return }
        suggestion = reply.answer
        if question.trimmingCharacters(in: .whitespacesAndNewlines) == asked, !reply.q.isEmpty { question = reply.q }
        if answer.isEmpty { answer = reply.answer }
    }

    private func save() async {
        guard canSave, let store = model.myAnswers else { return }
        isSaving = true
        var q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        var a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        var fixed: [String] = []
        if let client = model.myAnswersClient, let reply = await client.proofread(question: q, answer: a) {
            if reply.changed?.q == true, !reply.q.isEmpty {
                fixed += MyAnswerText.changedWords(from: q, to: reply.q)
                q = reply.q
            }
            if reply.changed?.a == true, !reply.a.isEmpty {
                fixed += MyAnswerText.changedWords(from: a, to: reply.a)
                a = reply.a
            }
        }
        let unchangedSuggestion = suggestion.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) == answer.trimmingCharacters(in: .whitespacesAndNewlines) } ?? false
        let author: MyAnswer.Author = unchangedSuggestion ? (draft != nil ? .recording : .lumen) : .mine
        store.save(id: existing?.id, examID: existing?.examID ?? examID, question: q, answer: a, author: author,
                   suggestion: suggestion, recorded: existing?.recorded ?? (draft != nil))
        question = q
        answer = a
        isSaving = false
        if fixed.isEmpty {
            onDone()
        } else {
            withAnimation { corrected = fixed.prefix(4).joined(separator: ", ") }
            try? await Task.sleep(for: .seconds(3)) // Ke30: the student sees what was fixed
            onDone()
        }
    }
}

/// A53 (Ke30): "Tidigare versioner": now and the older versions, who wrote them, and Återställ (a new version; nothing
/// disappears).
struct MyAnswerVersionsView: View {
    let store: MyAnswerStore
    let answerID: UUID
    let onRestore: (MyAnswer.Version) -> Void
    @Environment(\.dismiss) private var dismiss

    private var versions: [MyAnswer.Version] { (store.answer(answerID)?.versions ?? []).reversed() }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(index == 0 ? "Nu" : version.author.title)
                                .font(LumenFont.text(15, .semibold))
                            Spacer()
                            Text(version.savedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(LumenFont.text(13))
                                .foregroundStyle(LumenColor.muted)
                        }
                        Text(version.answer)
                            .font(LumenFont.text(15))
                            .foregroundStyle(index == 0 ? LumenColor.ink : LumenColor.muted)
                        if index > 0 {
                            Button("Återställ") {
                                if store.restore(version.id, of: answerID) != nil { onRestore(version) }
                                dismiss()
                            }
                            .font(LumenFont.text(15, .semibold))
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .lumenForm()
            .navigationTitle("Tidigare versioner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
    }
}

/// A53 (Ke30): "Spela in ett svar". The question first (optional), the red dot and the time while it records, the
/// level meter, and Klar. Nothing is done with the audio before Klar (D126); then the phone writes it out and Lumen
/// compresses the words to one answer.
struct MyAnswerRecordView: View {
    @Bindable var model: ListeningModel
    let examID: UUID?
    let onDone: (MyAnswerDraft) -> Void
    let onCancel: () -> Void
    @State private var recorder = AnswerRecorder()
    @State private var question = ""
    @State private var isCompressing = false
    @State private var problem: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Fråga").padding(.leading, 4)
                TextField("Vilken fråga svarar inspelningen på? (valfritt)", text: $question, axis: .vertical)
                    .font(LumenFont.text(17))
                    .padding(14)
                    .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                if isCompressing || recorder.state == .transcribing {
                    ProgressView()
                    Text("Earmind gör ett svar …").font(LumenFont.text(17, .semibold))
                } else if recorder.state == .recording {
                    HStack(spacing: 8) {
                        Circle().fill(LumenColor.red).frame(width: 12, height: 12) // Ke30: iOS's sign for recording
                        Text(recorder.reachedLimit ? "Tiden är slut" : "Spelar in").font(LumenFont.text(17, .semibold))
                    }
                    .accessibilityElement(children: .combine)
                    Text("\(MyAnswerText.clock(recorder.elapsed)) av \(MyAnswerText.clock(AnswerRecorder.limit))")
                        .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                        .monospacedDigit()
                    LevelMeter(levelDBFS: recorder.levelDBFS)
                } else if let message = problem ?? failure {
                    Text(message)
                        .font(LumenFont.text(17))
                        .multilineTextAlignment(.center)
                }
                Text("Earmind gör inget med ljudet förrän du trycker Klar. Ljudet stannar på telefonen och raderas sedan; bara texten skickas.")
                    .font(LumenFont.text(13, relativeTo: .footnote))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Button("Klar") { Task { await finish() } }
                .buttonStyle(LumenButtonStyle(height: 54))
                .disabled(recorder.state != .recording || isCompressing)
        }
        .padding(20)
        .lumenScreen()
        .navigationTitle("Spela in")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    recorder.cancel()
                    onCancel()
                }
            }
        }
        .task { if !model.isActiveSession { await recorder.start() } }
        .onDisappear { if recorder.state == .recording { recorder.cancel() } }
    }

    private var failure: String? {
        if model.isActiveSession { return "Avsluta Earmind för att spela in." }
        if case .failed(let message) = recorder.state { return message }
        return nil
    }

    private func finish() async {
        let seconds = recorder.elapsed
        guard let transcript = await recorder.finish() else { return }
        isCompressing = true
        let plan = model.examPlans?.plans.first { $0.id == examID }
        let reply = await model.myAnswersClient?.compress(transcript: transcript, question: question, subject: plan?.subject)
        isCompressing = false
        guard let reply, !reply.answer.isEmpty else {
            problem = reply == nil ? "Earmind kunde inte göra ett svar just nu. Försök igen." : "Earmind hörde inget svar i inspelningen."
            return
        }
        onDone(MyAnswerDraft(question: reply.q.isEmpty ? question : reply.q, answer: reply.answer,
                             transcript: transcript, seconds: seconds))
    }
}
