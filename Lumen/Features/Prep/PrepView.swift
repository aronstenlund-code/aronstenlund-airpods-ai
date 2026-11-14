import SwiftUI
import UniformTypeIdentifiers

/// Prep mode (item 9): paste text or import a PDF/text file; the extracted terms help recognition and answers.
struct PrepView: View {
    let store: PrepStore
    let goals: GoalsStore
    /// A16: Förberedelser › Övningsprov (the practice exam Provläge reads aloud).
    var model: ListeningModel? = nil
    @State private var pastedText = ""
    @State private var pastedTitle = ""
    @State private var goalsDraft = ""
    @State private var isImportingGoals = false
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        Form {
            if let model, let materials = model.examMaterials, let client = model.examClient {
                Section {
                    NavigationLink {
                        ExamSetupView(model: model, materials: materials, client: client, isSheet: false)
                    } label: {
                        LabeledContent("Provfrågor", value: materials.isReady ? "\(materials.paper.tasks.count) frågor" : "Lägg till")
                    }
                } footer: {
                    Text("Ett prov (PDF, foto eller text) som EarMind läser upp fråga för fråga i Provläge och rättar.")
                }
            }
            Section {
                TextField("Title (optional)", text: $pastedTitle)
                TextEditor(text: $pastedText)
                    .frame(minHeight: 120)
                    .font(.body)
                HStack {
                    Button("Add text") { addPasted() }
                        .buttonStyle(.borderedProminent)
                        .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import PDF or text file", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                if let importError {
                    Text(importError).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("Add material")
            } footer: {
                Text("Key terms are extracted on this iPhone and help speech recognition and answers. The text itself never leaves the phone; only the terms (max 30) are sent with a question.")
            }

            Section("Material") {
                if store.materials.isEmpty {
                    Text("No material yet.").foregroundStyle(.secondary)
                }
                ForEach(store.materials) { material in
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: Binding(get: { material.isEnabled }, set: { store.setEnabled(material, $0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(material.title)
                                Text("\(material.terms.count) termer, \(material.text.count) tecken")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(material.terms.prefix(12).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                .onDelete { offsets in
                    let doomed = offsets.map { store.materials[$0] }
                    for material in doomed { store.delete(material) }
                }
            }

            Section {
                TextEditor(text: $goalsDraft)
                    .frame(minHeight: 90)
                    .font(.body)
                HStack {
                    Button("Save goals") {
                        goals.set(text: goalsDraft)
                        goalsDraft = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(goalsDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        isImportingGoals = true
                    } label: {
                        Label("Import", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if goals.stored != nil {
                        Button("Clear", role: .destructive) { goals.clear() }
                    }
                }
                if goals.stored != nil {
                    Toggle("Use the goals in answers", isOn: Binding(get: { goals.isEnabled }, set: { goals.setEnabled($0) }))
                    Text("\(goals.text.count) tecken, skickas kort (\(goals.compact?.count ?? 0) characters): \(goals.terms.prefix(8).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                }
                if let error = goals.lastError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("Course goals")
            } footer: {
                Text("Paste the course's goals (målbeskrivning). A compact version is sent with each question so answers match the course level.")
            }

            Section("Active terms") {
                let terms = store.sttTerms
                if terms.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                } else {
                    Text(terms.joined(separator: ", "))
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .lumenForm()
        .navigationTitle("Förberedelser")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isImportingGoals, allowedContentTypes: [.pdf, .plainText, .text]) { result in
            switch result {
            case .success(let url):
                do {
                    goals.set(text: try DocumentText.read(url))
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf, .plainText, .text]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }

    private func addPasted() {
        importError = nil
        if store.add(title: pastedTitle, text: pastedText) == nil {
            importError = "No usable terms found in that text."
            return
        }
        pastedText = ""
        pastedTitle = ""
    }

    private func importFile(_ url: URL) {
        importError = nil
        do {
            let text = try DocumentText.read(url)
            if store.add(title: url.deletingPathExtension().lastPathComponent, text: text) == nil {
                importError = "No usable terms found in that file."
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
