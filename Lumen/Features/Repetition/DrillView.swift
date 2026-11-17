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
    /// A106 (Ke63 §4.1): a text's presses mean other things, so the check is shown the first time a text is started.
    @AppStorage("repetition.textControlsChecked") private var textControlsChecked = false
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
                if drill.isText { textContent(drill) } else { content(drill) } // A106 (D185)
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
                ControlCheckView(hub: model.remote, sound: firstQuestionSound(drill), forText: drill.isText, help: model) {
                    if drill.isText { textControlsChecked = true } else { controlsChecked = true }
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
                ActivityView(text: "Plugga \(drill.title) med mig i EarMind", url: share.url)
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
            Text(drill?.isText == true
                 ? "Texten och ljudet försvinner från alla dina enheter. Kopior som du har delat finns kvar hos de andra."
                 : "Frågorna, svaren och ljudet försvinner från alla dina enheter. Kopior som du har delat finns kvar hos de andra.")
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
                if !DrillShareGate.isOffered(model.store.drill(drill.id) ?? drill) {
                    // A110 (D198): hidden, not grey, until the exam has been started; the line under the list says why.
                } else if isSharing {
                    ProgressView().accessibilityLabel("Gör en länk")
                } else {
                    Button {
                        shareTapped(drill)
                    } label: {
                        Label("Dela", systemImage: "square.and.arrow.up")
                    }
                    // D143: otherwise the receiver would make the same sound again. A104: a link needs the network.
                    .disabled(!model.isAudioReady(drill) || model.isOffline)
                }
                Menu {
                    if drill.isText {
                        if model.savedSentence(drill) != nil {
                            Button("Börja om från början", systemImage: "arrow.counterclockwise") { begin(drill, at: 0) }
                        }
                    } else if model.savedIndex(drill) != nil {
                        Button("Börja om från fråga 1", systemImage: "arrow.counterclockwise") { begin(drill, at: 0) }
                    }
                    if model.canPublish, drill.publication == nil, // A83 (Ke52)
                       DrillShareGate.isOffered(model.store.drill(drill.id) ?? drill) { // A110 (D198)
                        Button("Publicera prov", systemImage: "building.columns") { publishing = true }
                            .disabled(!model.isAudioReady(drill) || model.isOffline) // A104
                    }
                    if !drill.isText { // Ke63: a text has no order to change and no questions to add
                        Button("Ändra ordning", systemImage: "arrow.up.arrow.down") {
                            withAnimation { editMode = .active }
                        }
                        Button("Gör med ChatGPT", systemImage: "doc.on.clipboard") { showsChatGPT = true } // A93
                    }
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

            if model.isOffline { // A104 (A103): said once, quietly; playing works, Dela and Publicera wait
                Section {
                    Label("Ingen internetanslutning. Dela och Publicera fungerar när du är uppkopplad.",
                          systemImage: "wifi.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if model.quotaExceeded(drill) { // A84 (D155): the month's questions are used up
                Section { // A104: say what happened, then the way on
                    Text(verbatim: Self.usedUpLine)
                    if model.canPublish {
                        NavigationLink("Hämta andras prov") { SchoolExamsView(model: model) }
                    }
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
                                .accessibilityLabel("Fråga \(number + 1)") // A95: not a bare number
                            VStack(alignment: .leading, spacing: 2) {
                                // A102 (K66): the screen shows numbers and formulas as written; the voice reads the
                                // spoken text. An exam without the field shows what it always did.
                                Text(verbatim: item.shownQuestion).fontWeight(.semibold).foregroundStyle(Color.primary)
                                if model.isReadingAloudOff(drill) {
                                    // A112 (D200): no sound for now, so the answer is here to read, all of it.
                                    Text(verbatim: item.shownLong).font(.subheadline).foregroundStyle(Color.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text(verbatim: item.shownShort).font(.subheadline).foregroundStyle(Color.secondary).lineLimit(1)
                                }
                                // A99 (D176, Kelly): quiet, and nothing on a question of normal length.
                                if let length = item.lengthClass?.label {
                                    Text(verbatim: length).font(.footnote).foregroundStyle(Color.secondary)
                                }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: footnote(drill))
                    if !DrillShareGate.isOffered(drill) { Text(verbatim: DrillShareGate.startFirstLine) } // A110 (D198)
                }
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
            // A100 (K62): when the sound cannot be made the button is grey with the reason under it, no spinner.
            // A112 (D200): while reading aloud is off the calm line stands under the button, also for an exam that is not
            // started (Starta prov then asks again and costs nothing, K78).
            let soundProblem = canStart && !model.isReadingAloudOff(drill) ? nil : model.audio.problem(for: drill)
            MainActionBar(title: canStart ? (saved == nil ? "Starta prov" : "Fortsätt")
                              : (soundProblem == nil ? "Gör ljudet …" : "Starta prov"),
                          systemImage: "play.fill",
                          // A104: while the sound is being made, the line says why the button is grey.
                          note: soundProblem ?? (canStart ? nil : "Ljudet görs. Du kan starta när första frågan är klar." as String?)
                              ?? startCost(drill)?.line
                              ?? saved.map { "Du var på fråga \($0 + 1) av \(drill.items.count)." }
                              ?? "Spelas i dina AirPods. Mikrofonen används inte.",
                          isBusy: (!canStart && soundProblem == nil) || model.isStartingAudio(drill),
                          // A112b (Kelly U1): blue for questions and for a text while reading aloud is off; the player
                          // then shows the text and is stepped by hand.
                          isDisabled: !model.isReadingAloudOff(drill)
                              && (!canStart || model.isStartingAudio(drill) || startCost(drill)?.tooMany == true)) {
                begin(drill, at: saved ?? 0)
            }
        }
    }

    /// A106 (D185, Kelly Ke63 `lasa/text.png`): a text read aloud. The whole text in one card, the headings bold; a
    /// tap on a sentence starts the player there. Starta prov is fixed at the bottom, as for questions.
    private func textContent(_ drill: Drill) -> some View {
        let saved = model.savedSentence(drill)
        let canStart = model.canStart(drill)
        return List {
            Section {
                if typeSize.isAccessibilitySize { WrappingTitleRow(title: drill.title) }
                statusLine(drill)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    .listRowSeparator(.hidden)
            }

            if model.isOffline { // A104
                Section {
                    Label("Ingen internetanslutning. Dela och Publicera fungerar när du är uppkopplad.",
                          systemImage: "wifi.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if model.quotaExceeded(drill) {
                Section {
                    Text(verbatim: Self.usedUpLine)
                    if model.canPublish {
                        NavigationLink("Hämta andras prov") { SchoolExamsView(model: model) }
                    }
                }
            }

            Section {
                SentenceText(parts: drill.readingParts) { sentence in begin(drill, at: sentence) }
                    .padding(.vertical, 6)
                    .accessibilityLabel(drill.readingParts.map { $0.sentences.joined(separator: " ") }.joined(separator: "\n"))
                    .accessibilityHint("Starta prov läser upp texten.")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tryck på en mening för att börja där.")
                    if !DrillShareGate.isOffered(drill) { Text(verbatim: DrillShareGate.startFirstLine) } // A110 (D198)
                }
            }

            if model.canPublish, let publication = drill.publication {
                Section {
                    PublishedRow(model: model, drill: drill, publication: publication, editing: $publishing)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            // A112 (D200): while reading aloud is off the calm line stands under the button, also for an exam that is not
            // started (Starta prov then asks again and costs nothing, K78).
            let soundProblem = canStart && !model.isReadingAloudOff(drill) ? nil : model.audio.problem(for: drill)
            MainActionBar(title: canStart ? (saved == nil ? "Starta prov" : "Fortsätt")
                              : (soundProblem == nil ? "Gör ljudet …" : "Starta prov"),
                          systemImage: "play.fill",
                          note: soundProblem ?? (canStart ? nil : "Ljudet görs. Du kan starta när första stycket är klart." as String?)
                              ?? startCost(drill)?.line
                              ?? saved.map { "Du var på mening \($0 + 1) av \(drill.sentenceCount)." }
                              ?? "Spelas i dina AirPods. Mikrofonen används inte.",
                          isBusy: (!canStart && soundProblem == nil) || model.isStartingAudio(drill),
                          // A112 (Kelly U1): a text can always be opened while reading aloud is off: the player shows
                          // it and the sentence is moved by hand.
                          isDisabled: !model.isReadingAloudOff(drill)
                              && (!canStart || model.isStartingAudio(drill) || startCost(drill)?.tooMany == true)) {
                begin(drill, at: saved ?? 0)
            }
        }
    }

    /// A107 (D191, Kelly Ke64b N1): the month's questions are counted at Starta prov, so an exam that is not started
    /// says what it counts as before the button is pressed, and the button is grey when the month does not cover it.
    /// Nil for a started exam and while the quota is not known.
    private func startCost(_ drill: Drill) -> (line: String, tooMany: Bool)? {
        guard model.awaitsAudioStart(drill), !model.isReadingAloudOff(drill), let quota = model.quota else { return nil }
        if quota.isUnlimited { return nil } // A133 (D216): no cost is said to an account without a limit
        if quota.isCredits { // A131 (D213, K90): the server's number, in credits; nothing is counted here
            guard let cost = drill.startCost else { return nil }
            if cost > quota.left {
                return (CreditText.notEnough(cost: cost, left: quota.left, resetsDay: quota.resetsDay), true)
            }
            return (CreditText.cardLine(cost: cost) + ".", false)
        }
        let chars = drill.items.reduce(0) { $0 + $1.long.count }
        let counts = drill.isText ? DrillTextDraft.countsAs(chars: chars) : drill.items.count
        if counts > quota.left {
            let what = drill.isText ? "Texten räknas som \(DrillText.questions(counts))" : "Provet har \(DrillText.questions(counts))"
            return ("\(what) och du har \(quota.left) kvar den här månaden. "
                    + "\(drill.isText ? "Vänta" : "Ta bort frågor eller vänta") till den 1 \(ChatGPTImportView.nextMonth()).", true)
        }
        return ("Räknas som \(counts) av dina \(quota.left) frågor kvar.", false)
    }

    /// Kelly (A99): "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 december."
    private static var usedUpLine: String {
        "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 \(ChatGPTImportView.nextMonth())."
    }

    /// "5 frågor · åk 9 · ljud klart" under the title, or the sound's progress while it is made.
    private func statusLine(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        // A106 (Ke63): "Text · 9 meningar · cirka 1 min · ljud klart".
        let facts = drill.isText
            ? "Text · \(ReadingText.sentences(drill.sentenceCount)) · cirka \(ReadingText.minutes(drill)) min"
            : DrillText.questions(drill.items.count) + (drill.summary.grade.isEmpty ? "" : " · \(drill.summary.grade)")
        return VStack(alignment: .leading, spacing: 6) {
            if ready {
                Text(verbatim: "\(facts) · ljud klart")
            } else if model.isReadingAloudOff(drill) {
                // A112 (D200): the calm line under the facts (below); no counter, no bar.
                Text(verbatim: facts)
            } else if model.awaitsAudioStart(drill) {
                // A107 (D190): the sound is made at Starta prov; no "Ljud: 0 av N" that looks stuck.
                Text(verbatim: facts)
                Text(verbatim: model.isStartingAudio(drill) ? "Gör ljudet …" : "Ljudet görs när du startar provet.")
            } else if drill.audioTrimmed == true {
                // A135 (Angela Schrute): the sound was removed from the phone for space and is fetched again at Starta
                // prov. No counter that stands still.
                Text(verbatim: facts)
                Text(verbatim: "Ljudet hämtas när du startar provet.")
            } else if model.quotaExceeded(drill) {
                // Kelly Ke64 T1: nothing more is made this month, so no counter and no bar that seem to move.
                Text(verbatim: facts)
                Text(verbatim: "Ljud: \(p.ready) av \(p.total) klara. Resten görs den 1 \(ChatGPTImportView.nextMonth()), när du har frågor kvar.")
                    .monospacedDigit()
            } else if model.audio.problem(for: drill) != nil {
                Text(verbatim: facts) // A100 (K62): no counter that stands still; the problem is the next line
            } else {
                Text(verbatim: facts)
                Text(verbatim: "Ljud: \(p.ready) av \(p.total) klara" + (drill.isText ? "" : " · Görs i spelordning")).monospacedDigit()
                // Kelly R1: the line under the text, with room (it was drawn across the text between the two lines).
                ProgressView(value: Double(p.ready), total: Double(max(p.total, 1)))
                    .padding(.top, 6)
            }
            // A112 (D200): the calm line stands once, under the button (not here too); another problem is said here.
            if let problem = model.audio.problem(for: drill), !model.isReadingAloudOff(drill) {
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
        // A107 (D190): until Starta prov nothing costs anything, so say that the answers can be changed.
        if model.isReadingAloudOff(drill) { return "Tryck på en fråga för att ändra frågan eller svaret." } // A112
        if model.awaitsAudioStart(drill) { return "Tryck på en fråga för att ändra frågan eller svaret." } // Kelly N2
        let p = model.progress(drill)
        if p.total == 0 || p.ready < p.total {
            // A100 (K62): no counter that stands still when the sound cannot be made.
            if model.audio.problem(for: drill) != nil { return "Delas när ljudet är klart." }
            return "Delas när ljudet är klart (\(p.ready) av \(p.total))."
        }
        return "Delar du provet får kompisarna samma frågor, svar och ljud. De behöver ett gratis EarMind-konto."
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
        if model.isReadingAloudOff(drill) {
            // A112b (D200, Kelly U1): no sound for now, so no check of the AirPods' presses either. Starta prov asks
            // once more (it costs nothing, K78); if the sound still cannot be made the player opens with the text.
            Task { await model.start(drill, at: index) }
            return
        }
        if drill.isText ? textControlsChecked : controlsChecked {
            Task { await model.start(drill, at: index) }
        } else {
            pendingIndex = index
            checkingControls = true
        }
    }

    private func firstQuestionSound(_ drill: Drill) -> URL? {
        if drill.isText { return model.audio.reading(for: drill, part: 0)?.url } // A106: the first paragraph
        return model.audio.track(for: drill, at: 0)?.question
    }
}

/// A110 (D198): Dela and Publicera are offered only once the exam has been started: the user has seen the answers and
/// the sound exists (D190). Before that the buttons are not shown at all, and one line says what to do.
enum DrillShareGate {
    static let startFirstLine = "Starta provet först så kan du dela det."

    static func isOffered(_ drill: Drill) -> Bool { !drill.awaitsAudioStart }
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
/// A95: the label of a filled (`.borderedProminent`) button. In light mode the accent is dark and the label white
/// (7.6:1). In dark mode the accent is light (#7F9BFF) and the system's white label on it is 2.6:1, so the label is
/// `LumenColor.onBlue` (dark, 6.9:1). A disabled button keeps the system's grey label.
struct FilledButtonLabel<Content: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @ViewBuilder var content: Content

    var body: some View {
        if isEnabled {
            content.foregroundStyle(LumenColor.onBlue)
        } else {
            content
        }
    }
}

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
                FilledButtonLabel {
                    HStack(spacing: 8) {
                        // A95: the symbol and the spinner only repeat the title; VoiceOver reads the title alone.
                        if isBusy {
                            ProgressView().accessibilityHidden(true)
                        } else if let systemImage {
                            Image(systemName: systemImage).accessibilityHidden(true)
                        }
                        Text(verbatim: title)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isDisabled)
            // A95: the bar stops growing at the first accessibility size, so a long press shows the title large
            // (the system's large content viewer, as for tab bars).
            .accessibilityShowsLargeContentViewer()
            if let note {
                // A95 (audit 43590746967): secondary text on the bar's material failed the contrast check; the
                // note says why the button is grey or that the microphone is off, so it has the text colour.
                Text(verbatim: note)
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
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

    /// The saved question's length class from the server; gone once the text is changed (it is not known again
    /// until the server has seen the new text).
    private var lengthNote: String? {
        guard let itemID, let item = drill.items.first(where: { $0.id == itemID }),
              item.shownQuestion == question, item.shownAnswer == answer else { return nil }
        return item.lengthClass?.editorNote
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Fråga", text: $question, axis: .vertical)
                } header: {
                    Text("Fråga · \(Self.words(question)) ord")
                } // A99 (D176): no five-word rule any more
                Section {
                    TextField("Svar", text: $answer, axis: .vertical).lineLimit(4...16)
                } header: {
                    Text("Svar · \(Self.words(answer)) ord")
                } footer: {
                    if short.isEmpty {
                        Text("Första meningen blir det korta svaret (2 tryck). Hela svaret är det långa (1 tryck).")
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "Kort svar (2 tryck): \(DrillItem.shownShort(short))") // Kelly Ke61 F1: no full stop after a formula
                            // A99 (D176, Kelly): the server's length class for this question, as it was saved.
                            if let note = lengthNote { Text(verbatim: note) }
                        }
                    }
                }
                Section {
                    Button(isWriting ? "Skriver svaret …" : (answer.isEmpty ? "Låt EarMind skriva svaret" : "Nytt förslag")) {
                        writeAnswers()
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isWriting)
                } footer: {
                    // A107 (D190): before Starta prov there is no sound yet, so a change costs nothing.
                    Text(model.awaitsAudioStart(drill) ? "Ljudet görs när du startar provet. Ändra så mycket du vill först."
                                                       : "Sparar du en ändring görs nytt ljud bara för den här frågan.")
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
                    question = item.shownQuestion // A102: the editor shows and edits what the screen shows
                    answer = item.shownAnswer
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
                answer = item.shownAnswer // A102
            } catch {
                problem = "EarMind kunde inte skriva svaret just nu. Skriv det själv eller försök igen."
            }
            isWriting = false
        }
    }

    private func save() {
        guard var changed = model.store.drill(drill.id) else { dismiss(); return }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if let itemID, let i = changed.items.firstIndex(where: { $0.id == itemID }) {
            // A102: `edited` keeps both texts of a field that was not changed, the server id and the sound; a
            // changed field is spoken and shown as written.
            let old = changed.items[i]
            let item = old.edited(question: question, answer: text)
            if old.sameText(as: item) && old.screen == item.screen { dismiss(); return }
            changed.items[i] = item
        } else {
            changed.items.append(DrillItem(id: UUID(), question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                                           short: DrillItem.firstSentence(text), long: text))
        }
        model.save(changed) // clears the sound whose text changed (only this question's)
        dismiss()
    }
}
