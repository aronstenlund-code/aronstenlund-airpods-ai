import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A79 (D142, Kelly Ke49): "Nytt prov". Material (several photos in a row with the camera, several from the photo
/// library, pasted text, PDF/Word/text), the number of questions and the long answers' length (D146), then
/// "Skapa frågor" → "Läser ditt material" → "Stämmer det här?" (the summary, correctable with one line) → saved.
/// The material is sent once and never kept (B4).
struct NewDrillView: View {
    let model: RepetitionModel
    let onSaved: (Drill) -> Void
    @Environment(\.dismiss) private var dismiss

    private enum Stage: Equatable { case material, making, confirm }

    @State private var stage: Stage = .material
    @State private var title = ""
    @State private var pages: [Data] = []
    @State private var pasted = ""
    @State private var documents: [(name: String, text: String)] = []
    @State private var scannedPDFPages: [Data] = []
    @State private var settings = DrillSettings()
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isTakingPhotos = false
    @State private var isImporting = false
    @State private var draft: DrillDraft?
    @State private var correction = ""
    @State private var problem: String?
    @State private var making: Task<Void, Never>?

    private var material: DrillMaterial {
        let text = ([pasted] + documents.map(\.text)).filter { !$0.isEmpty }.joined(separator: "\n\n")
        return DrillMaterial(pages: pages + scannedPDFPages, text: text)
    }

    private var addedCount: Int {
        pages.count + documents.count + (pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
            + (scannedPDFPages.isEmpty ? 0 : 1)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .material: materialForm
                case .making: makingView
                case .confirm: confirmView
                }
            }
            .lumenScreen()
            .navigationTitle(title.isEmpty ? "Nytt prov" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { making?.cancel(); dismiss() }
                }
            }
        }
        .sheet(isPresented: $isTakingPhotos) {
            PagePhotoPicker { image in
                if let data = ExamMaterials.jpeg(image) { pages.append(data) }
                isTakingPhotos = false
            } onCancel: {
                isTakingPhotos = false
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.pdf, .plainText, .text, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { Task { await addDocuments(urls) } }
        }
        .onChange(of: photoItems) { _, items in
            Task { await addPhotos(items) }
        }
    }

    // MARK: Material

    private var materialForm: some View {
        Form {
            Section {
                TextField("Till exempel Biologiprovet", text: $title)
            } header: { Text("Provets namn") }

            Section {
                Button { isTakingPhotos = true } label: {
                    Label("Fota sidor (flera i följd)", systemImage: "camera")
                }
                PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                    Label("Ur bildbiblioteket", systemImage: "photo.on.rectangle")
                }
                Button { isImporting = true } label: {
                    Label("PDF, Word, text", systemImage: "doc")
                }
                TextField("Eller klistra in text", text: $pasted, axis: .vertical)
                    .lineLimit(3...8)
            } header: { Text("Material") } footer: {
                Text(addedCount == 0 ? "Foton, dokument och text skickas en gång för att göra frågorna och sparas inte."
                     : "Tillagt: \(addedCount) \(addedCount == 1 ? "sak" : "saker") (\(pages.count) foton, \(documents.count) dokument).")
            }

            if !documents.isEmpty {
                Section {
                    ForEach(documents.indices, id: \.self) { i in
                        Text(documents[i].name)
                    }
                    .onDelete { documents.remove(atOffsets: $0) }
                } header: { Text("Dokument") }
            }

            Section {
                Stepper(value: $settings.questions, in: DrillSettings.questionRange) {
                    Text("Antal frågor: \(settings.questions)")
                }
                Picker("Långa svar", selection: $settings.length) {
                    ForEach(DrillSettings.Length.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: { Text("Frågor och svar") } footer: {
                Text("Långa svar är ett fullständigt A-svar, omkring \(settings.length.words) ord. Det korta svaret är alltid den första meningen.")
            }

            if let problem {
                Section { Text(problem).foregroundStyle(LumenColor.red) }
            }

            Section {
                Button {
                    create(correction: nil)
                } label: {
                    Text("Skapa frågor").frame(maxWidth: .infinity)
                }
                .buttonStyle(LumenButtonStyle(height: 54))
                .disabled(material.isEmpty)
                .listRowBackground(Color.clear)
            }
        }
        .lumenForm()
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
               let jpeg = ExamMaterials.jpeg(image) {
                pages.append(jpeg)
            }
        }
        photoItems = []
    }

    private func addDocuments(_ urls: [URL]) async {
        for url in urls {
            let name = url.lastPathComponent
            if url.pathExtension.lowercased() == "docx" {
                // iOS cannot read Word: the server does (K45 doc_text).
                let scoped = url.startAccessingSecurityScopedResource()
                let data = try? Data(contentsOf: url)
                if scoped { url.stopAccessingSecurityScopedResource() }
                guard let data else { problem = "\(name) gick inte att öppna."; continue }
                do {
                    let text = try await model.maker.documentText(docx: data)
                    documents.append((name, text))
                } catch {
                    problem = "\(name): Word-filer går inte att läsa än. Spara som PDF och lägg till den i stället."
                }
                continue
            }
            do {
                let text = try DocumentText.read(url)
                documents.append((name, text))
            } catch {
                if url.pathExtension.lowercased() == "pdf" {
                    // A scanned PDF has no text: its pages go as photos.
                    let scanned = await ExamMaterials.pages(from: url)
                    if scanned.isEmpty { problem = "\(name) gick inte att läsa." } else { scannedPDFPages += scanned }
                } else {
                    problem = "\(name) gick inte att läsa."
                }
            }
        }
    }

    // MARK: Making

    private var makingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Läser ditt material").font(LumenFont.text(24, .bold, relativeTo: .title2))
            Text("Tar reda på ämne och årskurs, gör frågor och skriver svar. Det tar ungefär en minut.")
                .font(LumenFont.text(16))
                .foregroundStyle(LumenColor.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    private func create(correction: String?) {
        problem = nil
        stage = .making
        let material = self.material
        let settings = self.settings
        let summary = draft?.summary
        making = Task {
            do throws(DrillMakingError) {
                let made = try await model.make(material, settings: settings, correction: correction,
                                                subject: summary?.subject, grade: summary?.grade)
                guard !Task.isCancelled else { return }
                draft = made
                if title.isEmpty { title = made.summary.subject.isEmpty ? "Nytt prov" : "\(made.summary.subject)provet" }
                self.correction = ""
                stage = .confirm
            } catch {
                guard !Task.isCancelled else { return }
                problem = error == .noMaterial ? "Lägg till material först."
                    : "Earmind kunde inte göra frågor just nu. Försök igen om en stund."
                stage = draft == nil ? .material : .confirm
            }
        }
    }

    // MARK: Stämmer det här?

    private var confirmView: some View {
        Form {
            if let draft {
                Section {
                    LabeledContent("Ämne", value: draft.summary.subject)
                    LabeledContent("Årskurs", value: draft.summary.grade)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provet handlar om").font(LumenFont.text(13, .semibold)).foregroundStyle(LumenColor.muted)
                        Text(draft.summary.covers)
                    }
                } header: { Text("Stämmer det här?") }

                Section {
                    TextField("Till exempel ”Det är åk 8” eller ”Ta inte med cellandning”", text: $correction, axis: .vertical)
                    Button("Gör om med rättelsen") { create(correction: correction) }
                        .disabled(correction.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: { Text("Något fel? Skriv det") }

                Section {
                    ForEach(draft.items.prefix(5)) { item in
                        Text(item.question)
                    }
                    if draft.items.count > 5 { Text("och \(draft.items.count - 5) till").foregroundStyle(LumenColor.muted) }
                } header: { Text("\(draft.items.count) frågor") } footer: {
                    Text("Du kan ändra, ta bort och lägga till frågor efteråt.")
                }

                if let problem {
                    Section { Text(problem).foregroundStyle(LumenColor.red) }
                }

                Section {
                    Button {
                        let drill = model.save(Drill(title: title.isEmpty ? "Nytt prov" : title, summary: draft.summary,
                                                     items: draft.items, questionCount: settings.questions,
                                                     longWords: settings.length.words))
                        onSaved(drill)
                        dismiss()
                    } label: {
                        Text("Ser rätt ut").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LumenButtonStyle(height: 54))
                    .listRowBackground(Color.clear)
                }
            }
        }
        .lumenForm()
    }
}
