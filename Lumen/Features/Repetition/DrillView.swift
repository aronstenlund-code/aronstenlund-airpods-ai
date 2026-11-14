import SwiftUI
import UIKit

/// A79–A81 (D142), rebuilt in A87 (D160, Kelly Ke53 `apple/fragor.png`): one exam as the system's list. The title is
/// the navigation title, the questions are rows in playing order (tap to edit), Dela and a "…" menu sit in the
/// toolbar (Börja om, Publicera prov, Ändra ordning, Ta bort provet), and **Starta prov** is fixed at the bottom so
/// the next step shows with 20 questions too. No dialog asks where to start: the button says "Fortsätt" when there is
/// a place to go on from.
struct DrillView: View {
    let model: RepetitionModel
    let drillID: UUID
    /// Kept for the callers (the repShare screenshots). Dela is in the toolbar now.
    var showsShare = false
    @State private var editing: EditTarget?
    @State private var checkingControls = false
    @State private var pendingIndex = 0
    @State private var share: DrillShareResult?
    @State private var showsShareSheet = false
    @State private var shareProblem: String?
    @State private var isSharing = false
    @State private var confirmDelete = false
    @State private var publishing = false // A83
    @State private var showsChatGPT = false // A93
    @State private var editMode: EditMode = .inactive
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    struct EditTarget: Identifiable, Equatable {
        let id: UUID
        let isNew: Bool
    }

    private var drill: Drill? { model.store.drill(drillID) }

    var body: some View {
        Group {
            if let drill {
                content(drill)
            } else {
                ContentUnavailableView("Provet finns inte längre", systemImage: "doc")
            }
        }
        .navigationTitle(drill?.title ?? "Prov")
        .navigationBarTitleDisplayMode(typeSize.isAccessibilitySize ? .inline : .large)
        .toolbar {
            if let drill { barItems(drill) }
        }
        .sheet(item: $editing) { target in
            if let drill {
                DrillItemEditor(model: model, drill: drill, itemID: target.isNew ? nil : target.id)
            }
        }
        .sheet(isPresented: $checkingControls) {
            if let drill {
                ControlCheckView(hub: model.remote, sound: firstQuestionSound(drill), help: model) {
                    controlsChecked = true
                    checkingControls = false
                    let index = pendingIndex
                    Task { await model.start(drill, at: index) }
                } onLater: {
                    checkingControls = false
                }
            }
        }
        .sheet(isPresented: $publishing) { if let drill { PublishSheet(model: model, drill: drill) } } // A83
        .sheet(isPresented: $showsChatGPT) { // A93 (D169): the exam's questions go into the prompt, new ones are added
            if let drill {
                ChatGPTImportView(model: model, title: drill.title,
                                  questions: max(model.newDrillSettings.questions, drill.items.count + 5),
                                  drill: drill) { _ in }
            }
        }
        .sheet(isPresented: $showsShareSheet) {
            if let share, let drill {
                ActivityView(text: "Plugga \(drill.title) med mig i Earmind", url: share.url)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Det gick inte att dela", isPresented: Binding(get: { shareProblem != nil },
                                                              set: { if !$0 { shareProblem = nil } })) {
            Button("Okej") { shareProblem = nil }
        } message: {
            Text(verbatim: shareProblem ?? "")
        }
        .confirmationDialog("Ta bort \(drill?.title ?? "provet")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Ta bort provet", role: .destructive) {
                if let drill { model.delete(drill) }
                dismiss()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Frågorna, svaren och ljudet försvinner från alla dina enheter. Kopior som du har delat finns kvar hos de andra.")
        }
        .task { if let drill, !model.isAudioReady(drill) || drill.needsUpload == true { model.prepareAudio(drill) } }
    }

    @ToolbarContentBuilder
    private func barItems(_ drill: Drill) -> some ToolbarContent {
        if editMode.isEditing {
            ToolbarItem(placement: .confirmationAction) {
                Button("Klar") { withAnimation { editMode = .inactive } }
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSharing {
                    ProgressView()
                } else {
                    Button {
                        shareTapped(drill)
                    } label: {
                        Label("Dela", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!model.isAudioReady(drill)) // D143: otherwise the receiver would make the same sound again
                }
                Menu {
                    if model.savedIndex(drill) != nil {
                        Button("Börja om från fråga 1", systemImage: "arrow.counterclockwise") { begin(drill, at: 0) }
                    }
                    if model.canPublish, drill.publication == nil { // A83 (Ke52)
                        Button("Publicera prov", systemImage: "building.columns") { publishing = true }
                            .disabled(!model.isAudioReady(drill))
                    }
                    Button("Ändra ordning", systemImage: "arrow.up.arrow.down") {
                        withAnimation { editMode = .active }
                    }
                    Button("Gör med ChatGPT", systemImage: "doc.on.clipboard") { showsChatGPT = true } // A93
                    Divider()
                    Button("Ta bort provet", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("Mer", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private func content(_ drill: Drill) -> some View {
        let saved = model.savedIndex(drill)
        let canStart = model.canStart(drill)
        return List {
            Section {
                if typeSize.isAccessibilitySize { WrappingTitleRow(title: drill.title) }
                statusLine(drill)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    .listRowSeparator(.hidden)
            }

            if model.quotaExceeded(drill), model.canPublish { // A84 (D155): the month's questions are used up
                Section {
                    NavigationLink("Hämta andras prov") { SchoolExamsView(model: model) }
                }
            }

            Section {
                ForEach(Array(drill.items.enumerated()), id: \.element.id) { number, item in
                    Button {
                        editing = EditTarget(id: item.id, isNew: false)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            // In a button's label `.primary` is the tint: the rows are the label colour.
                            Text(verbatim: "\(number + 1)").monospacedDigit().foregroundStyle(Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: item.question).fontWeight(.semibold).foregroundStyle(Color.primary)
                                Text(verbatim: item.short).font(.subheadline).foregroundStyle(Color.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Ändrar frågan")
                }
                .onMove { from, to in
                    var changed = drill
                    changed.items.move(fromOffsets: from, toOffset: to)
                    model.save(changed)
                }
                .onDelete { offsets in
                    var changed = drill
                    changed.items.remove(atOffsets: offsets)
                    guard !changed.items.isEmpty else { return }
                    model.save(changed)
                }
                Button {
                    editing = EditTarget(id: UUID(), isNew: true)
                } label: {
                    Label("Lägg till fråga", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Frågor")
            } footer: {
                Text(verbatim: footnote(drill))
            }

            if !drill.summary.covers.isEmpty {
                Section("Sammanfattning") {
                    Text(verbatim: drill.summary.covers)
                }
            }

            if model.canPublish, let publication = drill.publication { // A83 (Ke52 "Publicerat")
                Section {
                    PublishedRow(model: model, drill: drill, publication: publication, editing: $publishing)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom) {
            MainActionBar(title: canStart ? (saved == nil ? "Starta prov" : "Fortsätt") : "Gör ljud …",
                          systemImage: "play.fill",
                          note: saved.map { "Du var på fråga \($0 + 1) av \(drill.items.count)." }
                              ?? "Spelas i dina AirPods. Mikrofonen används inte.",
                          isBusy: !canStart,
                          isDisabled: !canStart) {
                begin(drill, at: saved ?? 0)
            }
        }
    }

    /// "5 frågor · åk 9 · ljud klart" under the title, or the sound's progress while it is made.
    private func statusLine(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        let facts = DrillText.questions(drill.items.count) + (drill.summary.grade.isEmpty ? "" : " · \(drill.summary.grade)")
        return VStack(alignment: .leading, spacing: 6) {
            if ready {
                Text(verbatim: "\(facts) · ljud klart")
            } else {
                Text(verbatim: facts)
                Text(verbatim: "Ljud: \(p.ready) av \(p.total) klara · Görs i spelordning").monospacedDigit()
                // Kelly R1: the line under the text, with room (it was drawn across the text between the two lines).
                ProgressView(value: Double(p.ready), total: Double(max(p.total, 1)))
                    .padding(.top, 6)
            }
            if let problem = model.audio.problem(for: drill) {
                Text(verbatim: problem).foregroundStyle(.primary)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// One line under the questions: how to reorder while reordering, else what Dela gives (or why it is off).
    private func footnote(_ drill: Drill) -> String {
        if editMode.isEditing { return "Dra för att ändra ordning. Ordningen är den du hör." }
        let p = model.progress(drill)
        if p.total == 0 || p.ready < p.total { return "Delas när ljudet är klart (\(p.ready) av \(p.total))." }
        return "Delar du provet får kompisarna samma frågor, svar och ljud. De behöver ett gratis Earmind-konto."
    }

    private func shareTapped(_ drill: Drill) {
        if share != nil {
            showsShareSheet = true
            return
        }
        isSharing = true
        shareProblem = nil
        Task {
            do throws(DrillShareError) {
                share = try await model.shareLink(drill)
                showsShareSheet = true
            } catch {
                shareProblem = error.userMessage
            }
            isSharing = false
        }
    }

    /// Through "Styr med dina AirPods" the first time, else straight to the question.
    private func begin(_ drill: Drill, at index: Int) {
        if controlsChecked {
            Task { await model.start(drill, at: index) }
        } else {
            pendingIndex = index
            checkingControls = true
        }
    }

    private func firstQuestionSound(_ drill: Drill) -> URL? {
        model.audio.track(for: drill, at: 0)?.question
    }
}

/// Kelly (SYSTEM §10 rule 4): a big title is never cut off. With the accessibility sizes the navigation title goes
/// inline and the title is the list's first row, where it wraps ("Prov från di…", "Biologiprov…" with the largest text).
struct WrappingTitleRow: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.largeTitle.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            .listRowSeparator(.hidden)
    }
}

/// A87 (D160, SYSTEM §0.1): the screen's one filled button, fixed at the bottom (`.safeAreaInset(edge: .bottom)`) so
/// the next step shows without scrolling, with at most one line under it.
struct MainActionBar: View {
    let title: String
    var systemImage: String?
    var note: String?
    var isBusy = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView()
                    } else if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(verbatim: title)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isDisabled)
            if let note {
                Text(verbatim: note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        // Like the system's bars, the bar stops growing at the first accessibility size: with the largest text it
        // took half the screen and the list above it could not be read (CI 43521643151, iPhone SE).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() } // Kelly S4/S5
    }
}

/// The system's share sheet for a link that is made when Dela is tapped (a `ShareLink` needs the link beforehand).
struct ActivityView: UIViewControllerRepresentable {
    let text: String
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = [text, url]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A79 (Kelly Ke49 "Redigera en fråga"), A87: a form with two fields, the question and the answer. D145: the answer's
/// first sentence is the short answer (shown in the footnote), so the short and the long answer can never disagree.
/// A saved change makes new sound for this question only.
struct DrillItemEditor: View {
    let model: RepetitionModel
    let drill: Drill
    let itemID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var answer = ""
    @State private var isWriting = false
    @State private var problem: String?

    private static func words(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }

    private var short: String { DrillItem.firstSentence(answer) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Fråga", text: $question, axis: .vertical)
                } header: {
                    Text("Fråga · \(Self.words(question)) ord")
                } footer: {
                    if Self.words(question) > 5 { Text("Helst högst fem ord.") }
                }
                Section {
                    TextField("Svar", text: $answer, axis: .vertical).lineLimit(4...16)
                } header: {
                    Text("Svar · \(Self.words(answer)) ord")
                } footer: {
                    if short.isEmpty {
                        Text("Första meningen blir det korta svaret (2 tryck). Hela svaret är det långa (1 tryck).")
                    } else {
                        Text(verbatim: "Kort svar (2 tryck): \(short)")
                    }
                }
                Section {
                    Button(isWriting ? "Skriver svaret …" : (answer.isEmpty ? "Låt Earmind skriva svaret" : "Nytt förslag")) {
                        writeAnswers()
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isWriting)
                } footer: {
                    Text("Sparar du en ändring görs nytt ljud bara för den här frågan.")
                }
                if let problem { Section { Text(verbatim: problem) } }
            }
            .navigationTitle(itemID.flatMap { id in drill.items.firstIndex { $0.id == id } }.map { "Fråga \($0 + 1)" } ?? "Ny fråga")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || short.isEmpty)
                }
            }
            .onAppear {
                if let itemID, let item = drill.items.first(where: { $0.id == itemID }) {
                    question = item.question
                    answer = DrillItem.long(item.long, startingWith: item.short)
                }
            }
        }
    }

    private func writeAnswers() {
        isWriting = true
        problem = nil
        Task {
            do throws(DrillMakingError) {
                let item = try await model.newAnswer(for: question, in: drill)
                answer = DrillItem.long(item.long, startingWith: item.short)
            } catch {
                problem = "Earmind kunde inte skriva svaret just nu. Skriv det själv eller försök igen."
            }
            isWriting = false
        }
    }

    private func save() {
        guard var changed = model.store.drill(drill.id) else { dismiss(); return }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = DrillItem.firstSentence(text)
        var item = DrillItem(id: itemID ?? UUID(), question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                             short: first, long: text)
        if let itemID, let i = changed.items.firstIndex(where: { $0.id == itemID }) {
            let old = changed.items[i]
            item.serverID = old.serverID
            if old.sameText(as: item) { dismiss(); return }
            item.questionAudio = old.questionAudio
            item.longAudio = old.longAudio
            item.shortEndMs = old.shortEndMs
            changed.items[i] = item
        } else {
            changed.items.append(item)
        }
        model.save(changed) // clears the sound whose text changed (only this question's)
        dismiss()
    }
}
