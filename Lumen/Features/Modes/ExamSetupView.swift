import SwiftUI
import UniformTypeIdentifiers

/// D84: upload an exam and its marking instructions (PDF or photos), then practise it by voice in Provläge.
struct ExamSetupView: View {
    @Bindable var model: ListeningModel
    @Bindable var materials: ExamMaterials
    let client: ExamClient
    @Environment(\.dismiss) private var dismiss
    @State private var isPicking = false

    var body: some View {
        Form {
            Section {
                Button("Lägg till provet och bedömningsanvisningen (PDF eller bilder)") { isPicking = true }
                    .disabled(materials.isReading)
                if materials.isReading { ProgressView() }
                if let status = materials.status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Sidorna skickas som bilder till Lumens server för att läsas en gång, och bara uppgifterna sparas, på den här telefonen. Inget prov sparas på servern. Välj gärna provet och anvisningen samtidigt.")
            }
            if materials.isReady {
                Section("Uppgifter (\(materials.paper.tasks.count))") {
                    ForEach(materials.paper.tasks) { task in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Uppgift \(task.no)").font(.subheadline.weight(.semibold))
                            Text(task.text).font(.footnote).lineLimit(3)
                        }
                    }
                }
                Section {
                    Button("Starta provsession") { Task { await model.startExam() } }
                    Button("Rensa provet", role: .destructive) { materials.clear() }
                } footer: {
                    Text("Under provsessionen svarar Lumen bara på \"Lumen, …\": uppgift sju, ledtråd, rätta jag fick …, nästa, starta provtid nittio minuter, hur gick det, avsluta provet. Med röstprofil räknas bara din röst.")
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
        .navigationTitle("Provsession")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Stäng") { dismiss() } }
        }
    }
}
