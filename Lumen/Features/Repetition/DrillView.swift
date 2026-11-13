import SwiftUI

/// A79–A81 (D142, Kelly Ke49 "Frågelistan"): one exam. "Starta prov" (through "Styr med dina AirPods" the first
/// time), the sound's progress ("Ljud: 36 av 40 klara · Görs i spelordning"), the questions in playing order (Ändra:
/// drag to reorder, delete; tap to edit), "Lägg till fråga" and Dela (only when all the sound is ready, D143).
struct DrillView: View {
    let model: RepetitionModel
    let drillID: UUID
    @State private var editing: EditTarget?
    @State private var checkingControls = false
    @State private var resumeAsk = false
    @State private var share: DrillShareResult?
    @State private var shareProblem: String?
    @State private var isSharing = false
    @State private var confirmDelete = false
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false
    @Environment(\.dismiss) private var dismiss

    struct EditTarget: Identifiable, Equatable {
        let id: UUID
        let isNew: Bool
    }

    private var drill: Drill? { model.store.drill(drillID) }

    var body: some View {
        Group {
            if let drill { content(drill) } else { Text("Provet finns inte längre.").foregroundStyle(LumenColor.muted) }
        }
        .lumenScreen()
        .navigationTitle(drill?.title ?? "Prov")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { EditButton() }
        .sheet(item: $editing) { target in
            if let drill {
                DrillItemEditor(model: model, drill: drill, itemID: target.isNew ? nil : target.id)
            }
        }
        .sheet(isPresented: $checkingControls) {
            if let drill {
                ControlCheckView(hub: model.remote, sound: firstQuestionSound(drill)) {
                    controlsChecked = true
                    checkingControls = false
                    Task { await model.start(drill) }
                } onLater: {
                    checkingControls = false
                }
            }
        }
        .confirmationDialog("Fortsätt där du var?", isPresented: $resumeAsk, titleVisibility: .visible) {
            if let drill, let index = model.savedIndex(drill) {
                Button("Fortsätt från fråga \(index + 1)") { Task { await model.start(drill, at: index) } }
                Button("Börja från fråga 1") { Task { await model.start(drill) } }
            }
        }
        .alert("Ta bort \(drill?.title ?? "provet")?", isPresented: $confirmDelete) {
            Button("Ta bort", role: .destructive) {
                if let drill { model.delete(drill) }
                dismiss()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Frågorna, svaren och ljudet försvinner från alla dina enheter. Kopior som du har delat finns kvar hos de andra.")
        }
        .task { if let drill, !model.isAudioReady(drill) || drill.needsUpload == true { model.prepareAudio(drill) } }
    }

    private func content(_ drill: Drill) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(DrillText.questions(drill.items.count))\(drill.summary.grade.isEmpty ? "" : " · \(drill.summary.grade)")")
                        .font(LumenFont.text(15))
                        .foregroundStyle(LumenColor.muted)
                    audioLine(drill)
                    Button {
                        startTapped(drill)
                    } label: {
                        Label(model.canStart(drill) ? "Starta prov" : "Gör ljud …", systemImage: "play.fill")
                            .font(LumenFont.text(22, .bold, relativeTo: .title2))
                    }
                    .buttonStyle(LumenButtonStyle(height: 72))
                    .disabled(!model.canStart(drill))
                    Text("Spelar frågorna i dina AirPods. Earmind använder inte mikrofonen.")
                        .font(LumenFont.text(14))
                        .foregroundStyle(LumenColor.muted)
                }
                .listRowBackground(Color.clear)
            }

            if !drill.summary.covers.isEmpty {
                Section {
                    Text(drill.summary.covers)
                } header: { Text("Sammanfattning") }
            }

            Section {
                ForEach(Array(drill.items.enumerated()), id: \.element.id) { number, item in
                    Button {
                        editing = EditTarget(id: item.id, isNew: false)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(number + 1)").monospacedDigit().foregroundStyle(LumenColor.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.question).font(LumenFont.text(17, .semibold)).foregroundStyle(LumenColor.ink)
                                Text(item.short).font(LumenFont.text(15)).foregroundStyle(LumenColor.muted).lineLimit(1)
                            }
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
                    Label("Lägg till fråga", systemImage: "plus")
                }
            } header: { Text("Frågor och svar") } footer: {
                Text("Dra för att ändra ordning. Ordningen är den du hör.")
            }

            Section {
                shareRow(drill)
            } header: { Text("Dela med klassen") } footer: {
                Text("Ändrar någon en fråga i sin kopia ändras inte ditt prov.")
            }

            Section {
                Button("Ta bort provet", role: .destructive) { confirmDelete = true }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func audioLine(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        let ready = p.total > 0 && p.ready == p.total
        return VStack(alignment: .leading, spacing: 6) {
            if ready {
                Label("Ljud klart", systemImage: "checkmark.circle.fill")
                    .font(LumenFont.text(15, .semibold))
                    .foregroundStyle(LumenColor.ok)
            } else {
                ProgressView(value: Double(p.ready), total: Double(max(p.total, 1)))
                    .tint(LumenColor.blue)
                Text("Ljud: \(p.ready) av \(p.total) klara · Görs i spelordning")
                    .font(LumenFont.text(14))
                    .foregroundStyle(LumenColor.muted)
                    .monospacedDigit()
            }
            if let problem = model.audio.problem(for: drill) {
                Text(problem).font(LumenFont.text(14)).foregroundStyle(LumenColor.ink)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func shareRow(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        Text("Kompisarna får samma frågor, svar och ljud. De behöver ett gratis Earmind-konto.")
            .font(LumenFont.text(15))
        LabeledContent("Frågor och svar", value: "\(drill.items.count)")
        LabeledContent("Ljud", value: "\(p.ready) av \(p.total)").monospacedDigit()
        LabeledContent("Foton och dokument", value: "delas inte").foregroundStyle(LumenColor.muted)
        if let share {
            ShareLink(item: share.url, subject: Text(drill.title),
                      message: Text("Plugga \(drill.title) med mig i Earmind: \(share.url.absoluteString)")) {
                Label("Dela", systemImage: "square.and.arrow.up")
            }
        } else if p.total == 0 || p.ready < p.total {
            // D143: otherwise the receiver would make the same sound again.
            VStack(alignment: .leading, spacing: 4) {
                Label("Dela", systemImage: "square.and.arrow.up").foregroundStyle(LumenColor.muted)
                Text("Delas när ljudet är klart (\(p.ready) av \(p.total))")
                    .font(LumenFont.text(14))
                    .foregroundStyle(LumenColor.muted)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        } else {
            Button {
                isSharing = true
                shareProblem = nil
                Task {
                    do throws(DrillShareError) {
                        share = try await model.shareLink(drill)
                    } catch {
                        shareProblem = error.userMessage
                    }
                    isSharing = false
                }
            } label: {
                Label(isSharing ? "Gör en länk …" : "Dela", systemImage: "square.and.arrow.up")
            }
            .disabled(isSharing)
        }
        if let shareProblem { Text(shareProblem).foregroundStyle(LumenColor.muted) }
    }

    private func startTapped(_ drill: Drill) {
        if model.savedIndex(drill) != nil {
            resumeAsk = true
        } else if !controlsChecked {
            checkingControls = true
        } else {
            Task { await model.start(drill) }
        }
    }

    private func firstQuestionSound(_ drill: Drill) -> URL? {
        model.audio.track(for: drill, at: 0)?.question
    }
}

/// A79 (Kelly Ke49 "Redigera en fråga"): two fields, the question and the answer. D145: the answer's first sentence is
/// the short answer (shown under the field), so the short and the long answer can never disagree. A saved change makes
/// new sound for this question only.
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
                } header: { Text("Fråga · \(Self.words(question)) ord") } footer: {
                    if Self.words(question) > 5 { Text("Helst högst fem ord.").foregroundStyle(LumenColor.muted) }
                }
                Section {
                    TextField("Svar", text: $answer, axis: .vertical).lineLimit(4...16)
                } header: { Text("Svar · \(Self.words(answer)) ord") } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if !short.isEmpty {
                            Text(short)
                                .font(LumenFont.text(14, .semibold))
                                .padding(6)
                                .background(LumenColor.soft, in: RoundedRectangle(cornerRadius: 6))
                                .accessibilityLabel("Kort svar: \(short)")
                        }
                        Text("Första meningen är det korta svaret (2 tryck). Hela svaret är det långa (1 tryck).")
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
                if let problem { Section { Text(problem) } }
            }
            .lumenForm()
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
