import SwiftUI

/// A79–A81 (D142, Kelly Ke49): one exam. "Starta prov" (through "Styr med dina AirPods" the first time), the sound's
/// progress ("Ljud: 36 av 40 klara"), the summary, the questions in playing order (drag to reorder, swipe to delete,
/// tap to edit), "Lägg till fråga" and "Dela med klassen" (only when all the sound is ready, D143).
struct DrillView: View {
    let model: RepetitionModel
    let drillID: UUID
    @State private var editing: EditTarget?
    @State private var checkingControls = false
    @State private var resumeAsk = false
    @State private var shareURL: URL?
    @State private var shareProblem: String?
    @State private var isSharing = false
    @AppStorage("repetition.controlsChecked") private var controlsChecked = false

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
        .navigationBarTitleDisplayMode(.inline)
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
        .task { if let drill, !model.isAudioReady(drill) { model.prepareAudio(drill) } }
    }

    private func content(_ drill: Drill) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(drill.items.count) frågor · \(drill.summary.grade)")
                        .font(LumenFont.text(15))
                        .foregroundStyle(LumenColor.muted)
                    audioLine(drill)
                    Button {
                        startTapped(drill)
                    } label: {
                        Label("Starta prov", systemImage: "play.fill")
                            .font(LumenFont.text(20, .bold, relativeTo: .title3))
                    }
                    .buttonStyle(LumenButtonStyle(height: 60))
                    .disabled(!model.isAudioReady(drill))
                    .accessibilityHint("Spelar frågorna i dina AirPods. Earmind använder inte mikrofonen.")
                    if !model.isAudioReady(drill) {
                        Text("Starta prov går när ljudet är klart.")
                            .font(LumenFont.text(14))
                            .foregroundStyle(LumenColor.muted)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Text(drill.summary.covers)
            } header: { Text("Sammanfattning") }

            Section {
                ForEach(Array(drill.items.enumerated()), id: \.element.id) { number, item in
                    Button {
                        editing = EditTarget(id: item.id, isNew: false)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(number + 1)").monospacedDigit().foregroundStyle(LumenColor.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.question).foregroundStyle(LumenColor.ink)
                                Text(item.short).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted).lineLimit(2)
                            }
                        }
                    }
                }
                .onMove { from, to in
                    var changed = drill
                    changed.items.move(fromOffsets: from, toOffset: to)
                    model.save(changed)
                }
                .onDelete { offsets in
                    var changed = drill
                    changed.items.remove(atOffsets: offsets)
                    model.save(changed)
                }
                Button {
                    editing = EditTarget(id: UUID(), isNew: true)
                } label: {
                    Label("Lägg till fråga", systemImage: "plus")
                }
            } header: { Text("Frågor") } footer: {
                Text("Dra för att ändra ordning. Ordningen är den du hör.")
            }

            Section {
                shareRow(drill)
            } header: { Text("Dela med klassen") } footer: {
                Text("Frågor, svar och ljud delas. Foton och dokument delas inte. Ändrar någon en fråga i sin kopia ändras inte ditt prov.")
            }

            Section {
                Button("Ta bort provet", role: .destructive) { model.delete(drill) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func audioLine(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        return HStack(spacing: 8) {
            Image(systemName: p.ready == p.total && p.total > 0 ? "checkmark.circle.fill" : "waveform")
                .foregroundStyle(p.ready == p.total ? LumenColor.green : LumenColor.blue)
            Text(p.ready == p.total && p.total > 0 ? "Ljud klart" : "Ljud: \(p.ready) av \(p.total) klara")
                .font(LumenFont.text(15, .semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func shareRow(_ drill: Drill) -> some View {
        let p = model.progress(drill)
        if let shareURL {
            ShareLink(item: shareURL, subject: Text(drill.title), message: Text("Plugga \(drill.title) med Earmind")) {
                Label("Skicka länken", systemImage: "square.and.arrow.up")
            }
        } else if p.total == 0 || p.ready < p.total {
            // D143: otherwise the receiver would make the same sound again.
            Label("Delas när ljudet är klart (\(p.ready) av \(p.total))", systemImage: "square.and.arrow.up")
                .foregroundStyle(LumenColor.muted)
        } else {
            Button {
                isSharing = true
                shareProblem = nil
                Task {
                    do throws(DrillShareError) {
                        shareURL = try await model.shareLink(drill)
                    } catch {
                        shareProblem = error == .notAvailable ? "Delning kommer snart." : "Det gick inte att dela just nu."
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
        model.audio.tracks(for: drill)?.first?.question
    }
}

/// A79: one question with its short and long answer. D145: the first sentence of the answer is the short answer; a
/// saved change makes new sound for this question only (the files are named by their text).
struct DrillItemEditor: View {
    let model: RepetitionModel
    let drill: Drill
    let itemID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var short = ""
    @State private var long = ""
    @State private var isWriting = false
    @State private var problem: String?

    private static func words(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Fråga", text: $question, axis: .vertical)
                } header: { Text("Fråga · \(Self.words(question)) ord") } footer: {
                    Text("Helst högst fem ord.")
                }
                Section {
                    TextField("Kort svar", text: $short, axis: .vertical)
                } header: { Text("Kort svar (2 tryck)") }
                Section {
                    TextField("Långt svar", text: $long, axis: .vertical).lineLimit(4...14)
                } header: { Text("Långt svar (1 tryck) · \(Self.words(DrillItem.long(long, startingWith: short))) ord") } footer: {
                    Text("Det långa svaret börjar alltid med det korta. Sparar du en ändring görs nytt ljud bara för den här frågan.")
                }
                if itemID == nil || short.isEmpty {
                    Section {
                        Button(isWriting ? "Skriver svar …" : "Låt Earmind skriva svaren") { writeAnswers() }
                            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isWriting)
                    }
                }
                if let problem { Section { Text(problem).foregroundStyle(LumenColor.red) } }
            }
            .lumenForm()
            .navigationTitle(itemID == nil ? "Ny fråga" : "Ändra fråga")
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
                    short = item.short
                    long = String(item.long.dropFirst(item.long.hasPrefix(item.short) ? item.short.count : 0))
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        }
    }

    private func writeAnswers() {
        isWriting = true
        problem = nil
        Task {
            do {
                let item = try await model.newAnswer(for: question, in: drill)
                short = item.short
                long = String(item.long.dropFirst(item.long.hasPrefix(item.short) ? item.short.count : 0))
                    .trimmingCharacters(in: .whitespaces)
            } catch {
                problem = "Earmind kunde inte skriva svaren just nu. Skriv dem själv eller försök igen."
            }
            isWriting = false
        }
    }

    private func save() {
        guard var changed = model.store.drill(drill.id) else { dismiss(); return }
        let item = DrillItem(id: itemID ?? UUID(), question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                             short: short.trimmingCharacters(in: .whitespacesAndNewlines),
                             long: DrillItem.long(long, startingWith: short))
        if let itemID, let i = changed.items.firstIndex(where: { $0.id == itemID }) {
            changed.items[i] = item
        } else {
            changed.items.append(item)
        }
        model.save(changed)
        dismiss()
    }
}
