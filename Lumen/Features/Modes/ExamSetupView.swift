import SwiftUI
import UniformTypeIdentifiers

/// D84 / A16: add a practice exam (PDF, photos or pasted text) and see its questions; then run it by voice in
/// Provläge, one question at a time ("Kör övningsprovet", K15), or as the timed exam session (D84).
struct ExamSetupView: View {
    @Bindable var model: ListeningModel
    @Bindable var materials: ExamMaterials
    let client: ExamClient
    /// Pushed from Förberedelser (no "Stäng"), or a sheet from Inställningar.
    var isSheet = true
    @Environment(\.dismiss) private var dismiss
    @State private var isPicking = false
    @State private var pasted = ""

    var body: some View {
        Form {
            if materials.isReady {
                Section {
                    Button("Kör övningsprovet") { Task { await model.startPracticeExam() } }
                        .font(LumenFont.text(17, .semibold))
                } footer: {
                    Text("Earmind läser upp en fråga i taget, du svarar högt och Earmind rättar och förklarar. Säg nästa, förra, fråga sju, hoppa över, upprepa eller avsluta.")
                }
                Section("Frågor (\(materials.paper.tasks.count))") {
                    ForEach(materials.paper.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Fråga \(task.no)").font(LumenFont.text(15, .semibold))
                                if let topic = task.topic, !topic.isEmpty {
                                    Text(topic).font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
                                }
                                Spacer()
                                if task.isOwnAnswer {
                                    Text("Earminds svar").font(LumenFont.text(12, .semibold)).foregroundStyle(LumenColor.muted)
                                        .accessibilityLabel("Facit saknas, Earmind har skrivit svaret")
                                }
                            }
                            Text(task.text).font(LumenFont.text(15)).lineLimit(3)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Section {
                Button(materials.isReady ? "Byt prov: PDF eller bilder" : "Lägg till övningsprov: PDF eller bilder") { isPicking = true }
                    .disabled(materials.isReading)
                TextField("Eller klistra in frågorna här", text: $pasted, axis: .vertical)
                    .lineLimit(3...8)
                if !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Läs in texten") {
                        let text = pasted
                        let profile = model.studyProfile.profile
                        Task {
                            await materials.read(text: text, name: "Övningsprov", with: client,
                                                 subject: profile.subject.isEmpty ? nil : profile.subject,
                                                 grade: profile.grade?.rawValue)
                            if materials.isReady { pasted = "" }
                        }
                    }
                    .disabled(materials.isReading)
                }
                if materials.isReading { ProgressView() }
                if let status = materials.status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Provet skickas till Earminds server för att läsas en gång, och bara frågorna sparas, på den här telefonen. Saknas facit skriver Earmind egna svar och säger det.")
            }
            if materials.isReady {
                Section {
                    Button("Starta provsession med provtid") { Task { await model.startExam() } }
                    Button("Rensa provet", role: .destructive) { materials.clear() }
                } footer: {
                    Text("Provsessionen är som på riktigt: Earmind svarar bara på ”Lumen, …”: uppgift sju, ledtråd, rätta jag fick …, nästa, starta provtid nittio minuter, hur gick det, avsluta provet.")
                }
            }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            let profile = model.studyProfile.profile
            Task {
                await materials.read(urls, with: client, subject: profile.subject.isEmpty ? nil : profile.subject,
                                     grade: profile.grade?.rawValue)
            }
        }
        .lumenForm()
        .navigationTitle("Övningsprov")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } }
            }
        }
    }
}
