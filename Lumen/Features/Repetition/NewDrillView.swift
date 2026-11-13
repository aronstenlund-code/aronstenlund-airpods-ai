import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A79 (D142, Kelly Ke49): "Nytt prov". Material (several pages in a row with the camera, several from the photo
/// library, pasted text, PDF/Word/text), the number of questions and the long answers' length (D146), then
/// "Skapa frågor" → "Läser ditt material" (steps, not an endless spinner) → "Stämmer det här?" (the summary,
/// correctable with one line) → saved. K45 runs in two steps: the questions first (Haiku), the answers while the user
/// reads the summary (Sonnet). The material is sent once and never kept (B4); a correction is made from K45's notes,
/// never from the photos again.
struct NewDrillView: View {
    let model: RepetitionModel
    let onSaved: (Drill) -> Void
    /// The screenshots (Kelly: repMakeError): the material form showing this problem.
    var stagedProblem: String? = nil
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
    @State private var isAddingText = false
    @State private var draft: DrillDraft?
    @State private var correction = ""
    @State private var problem: String?
    @State private var making: Task<Void, Never>?
    @State private var answering: Task<Void, Never>?
    @State private var isAnswering = false
    @State private var stepsDone = 0
    @State private var readingDocument = false

    private var material: DrillMaterial {
        let text = ([pasted] + documents.map(\.text)).filter { !$0.isEmpty }.joined(separator: "\n\n")
        return DrillMaterial(pages: pages + scannedPDFPages, text: text)
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
            .navigationTitle(stage == .confirm ? "Stämmer det här?" : "Nytt prov")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { making?.cancel(); answering?.cancel(); dismiss() }
                }
            }
        }
        .sheet(isPresented: $isTakingPhotos) { camera.ignoresSafeArea() }
        .sheet(isPresented: $isAddingText) { textSheet }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.pdf, .plainText, .text, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { Task { await addDocuments(urls) } }
        }
        .onChange(of: photoItems) { _, items in
            Task { await addPhotos(items) }
        }
    }

    @ViewBuilder
    private var camera: some View {
        if PageScanner.isAvailable {
            PageScanner { images in
                pages += images.compactMap { ExamMaterials.jpeg($0) }
                isTakingPhotos = false
            } onCancel: {
                isTakingPhotos = false
            }
        } else {
            PagePhotoPicker { image in
                if let data = ExamMaterials.jpeg(image) { pages.append(data) }
                isTakingPhotos = false
            } onCancel: {
                isTakingPhotos = false
            }
        }
    }

    // MARK: Material

    private var materialForm: some View {
        Form {
            Section {
                TextField("Provets namn, till exempel Biologiprovet", text: $title)
            }

            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("Fota sidor", "Flera i följd", "camera") { isTakingPhotos = true }
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                        Self.tileLabel("Välj bilder", "Ur bildbiblioteket", "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)
                    tile("Skriv text", "Eller klistra in", "text.alignleft") { isAddingText = true }
                    tile("Dokument", "PDF, Word, text", "doc") { isImporting = true }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                if addedCount > 0 {
                    Text("TILLAGT · \(DrillText.things(addedCount))")
                        .font(LumenFont.text(13, .semibold))
                        .foregroundStyle(LumenColor.muted)
                }
                if !pages.isEmpty { thumbnails }
                if !pasted.isEmpty {
                    added("Text", "\(pasted.split(whereSeparator: \.isWhitespace).count) ord") { pasted = "" }
                }
                ForEach(documents.indices, id: \.self) { i in
                    added(documents[i].name, "Dokument") { documents.remove(at: i) }
                }
                if !scannedPDFPages.isEmpty {
                    added("Skannad PDF", "\(scannedPDFPages.count) sidor") { scannedPDFPages = [] }
                }
                if readingDocument {
                    HStack { ProgressView(); Text("Läser dokumentet …").foregroundStyle(LumenColor.muted) }
                }
            } footer: {
                Text("Foton, dokument och text skickas en gång för att göra frågorna och sparas inte.")
            }

            Section {
                Stepper(value: $settings.questions, in: DrillSettings.questionRange) {
                    LabeledContent("Antal frågor", value: "\(settings.questions)").monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Långa svar")
                    Picker("Långa svar", selection: $settings.length) {
                        ForEach(DrillSettings.Length.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            } footer: {
                Text(settings.length == .normal
                     ? "Normal är ett fullt A-svar på cirka \(settings.length.words) ord. Det korta svaret är första meningen."
                     : "Cirka \(settings.length.words) ord. Det korta svaret är första meningen.")
            }

            if let problem {
                Section {
                    Text(problem).foregroundStyle(LumenColor.ink)
                    if !material.isEmpty { Button("Försök igen") { create(correction: nil) } } // A85
                }
            }

            Section {
                Button {
                    create(correction: nil)
                } label: {
                    Text("Skapa frågor").frame(maxWidth: .infinity)
                }
                .buttonStyle(LumenButtonStyle(height: 54))
                .disabled(material.isEmpty || readingDocument)
                .listRowBackground(Color.clear)
            } footer: {
                if material.isEmpty { Text("Lägg till minst en sida, bild eller text.") } // Kelly N3
            }
        }
        .lumenForm()
        .onAppear {
            if let stagedProblem, problem == nil {
                problem = stagedProblem
                if pasted.isEmpty { pasted = "Fotosyntes. Växter gör socker av koldioxid och vatten med ljusets energi." }
            }
        }
    }

    private var addedCount: Int {
        pages.count + documents.count + (pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
            + (scannedPDFPages.isEmpty ? 0 : 1)
    }

    /// Ke50 §3: "{6 foton, 1 PDF och 1 text}."
    private var materialLine: String {
        var parts: [String] = []
        let photos = pages.count + scannedPDFPages.count
        if photos > 0 { parts.append(photos == 1 ? "1 foto" : "\(photos) foton") }
        if !documents.isEmpty { parts.append(documents.count == 1 ? "1 dokument" : "\(documents.count) dokument") }
        if !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("1 text") }
        guard let last = parts.popLast() else { return "" }
        return (parts.isEmpty ? last : parts.joined(separator: ", ") + " och " + last) + "."
    }

    private func tile(_ title: String, _ detail: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Self.tileLabel(title, detail, symbol) }.buttonStyle(.plain)
    }

    /// nonisolated: PhotosPicker builds its label outside the main actor (CI 43493961075).
    nonisolated private static func tileLabel(_ title: String, _ detail: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(LumenColor.blue)
            Text(title).font(LumenFont.text(16, .semibold)).foregroundStyle(LumenColor.ink)
            Text(detail).font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: LumenCard.radius))
        .contentShape(Rectangle())
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    ZStack(alignment: .topTrailing) {
                        if let image = UIImage(data: pages[i]) {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 64, height: 84).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Button { pages.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 20))
                                .foregroundStyle(.white, LumenColor.ink.opacity(0.7))
                        }
                        .accessibilityLabel("Ta bort sida \(i + 1)")
                    }
                }
            }
        }
        .accessibilityLabel("\(pages.count) sidor")
    }

    private func added(_ title: String, _ detail: String, remove: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).lineLimit(1)
                Text(detail).font(LumenFont.text(14)).foregroundStyle(LumenColor.muted)
            }
            Spacer()
            Button(action: remove) { Image(systemName: "xmark.circle.fill").foregroundStyle(LumenColor.muted) }
                .buttonStyle(.plain)
                .accessibilityLabel("Ta bort \(title)")
        }
    }

    private var textSheet: some View {
        NavigationStack {
            TextEditor(text: $pasted)
                .padding(12)
                .lumenScreen()
                .navigationTitle("Skriv text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Klar") { isAddingText = false } }
                }
        }
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
        readingDocument = true
        defer { readingDocument = false }
        for url in urls {
            let name = url.lastPathComponent
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if url.pathExtension.lowercased() == "docx" {
                // iOS cannot read Word: the server does (K45 doc_text, no model, no cost).
                guard let data = try? Data(contentsOf: url) else { problem = "\(name) gick inte att öppna."; continue }
                do {
                    let text = try await model.maker.documentText(docx: data)
                    documents.append((name, text))
                } catch {
                    problem = "\(name) gick inte att läsa. Spara det som PDF och lägg till det i stället."
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
                    if scanned.isEmpty { problem = "\(name) har ingen text som går att läsa. Fota sidorna i stället." } else { scannedPDFPages += scanned }
                } else {
                    problem = "\(name) har ingen text som går att läsa. Fota sidorna i stället."
                }
            }
        }
    }

    // MARK: Läser materialet

    private static let steps = ["Läser sidorna", "Tar reda på ämne och årskurs", "Gör frågor", "Skriver svar"]

    private var makingView: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("Läser ditt material").font(LumenFont.text(28, .bold, relativeTo: .title))
            if !materialLine.isEmpty { Text(materialLine).font(LumenFont.text(17)).foregroundStyle(LumenColor.muted) }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.steps.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Group {
                            if i < stepsDone {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(LumenColor.ok)
                            } else if i == stepsDone {
                                ProgressView()
                            } else {
                                Image(systemName: "circle").foregroundStyle(LumenColor.line)
                            }
                        }
                        .frame(width: 26)
                        Text(Self.steps[i]).font(LumenFont.text(18))
                            .foregroundStyle(i <= stepsDone ? LumenColor.ink : LumenColor.muted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(i < stepsDone ? "klart" : i == stepsDone ? "pågår" : "")
                }
            }
            Text("Det tar ungefär en minut. Du kan lämna appen.").font(LumenFont.text(16)).foregroundStyle(LumenColor.muted)
            Spacer()
        }
        .padding(24)
    }

    private func create(correction: String?) {
        problem = nil
        stage = .making
        stepsDone = 0
        answering?.cancel()
        isAnswering = false
        // A correction is made again from K45's notes, never from the photos (B4: they are not kept anyway).
        let material = correction != nil && draft != nil ? DrillMaterial(text: draft?.notes ?? "") : self.material
        let settings = self.settings
        let summary = draft?.summary
        making = Task {
            // K45 step 1 is one call: the first two marks follow the clock, "Gör frågor" ends with the answer.
            let ticks = Task {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                stepsDone = max(stepsDone, 1)
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                stepsDone = max(stepsDone, 2)
            }
            defer { ticks.cancel() }
            do throws(DrillMakingError) {
                let made = try await model.make(material, settings: settings, correction: correction,
                                                subject: summary?.subject, grade: summary?.grade)
                guard !Task.isCancelled else { return }
                stepsDone = 3
                draft = made
                self.correction = ""
                stage = .confirm
                writeAnswers()
            } catch {
                guard !Task.isCancelled else { return }
                problem = error.userMessage
                stage = draft == nil ? .material : .confirm
            }
        }
    }

    /// Step 2 of K45 while the summary is read (R1: answers within 90 s).
    private func writeAnswers() {
        guard let draft, draft.items.contains(where: { $0.short.isEmpty }) else { return }
        isAnswering = true
        let settings = self.settings
        answering = Task {
            do throws(DrillMakingError) {
                let items = try await model.maker.answers(for: draft.items, summary: draft.summary, notes: draft.notes,
                                                          longWords: settings.length.words)
                guard !Task.isCancelled, self.draft?.items.map(\.id) == draft.items.map(\.id) else { return }
                self.draft?.items = items
            } catch {
                guard !Task.isCancelled else { return }
                problem = "Earmind kunde inte skriva svaren just nu. Försök igen om en stund."
            }
            isAnswering = false
        }
    }

    // MARK: Stämmer det här?

    private var missingAnswers: Int { draft?.items.filter { $0.short.isEmpty }.count ?? 0 }
    /// "Ser rätt ut" waits for the answers; once they are written, the questions without one are left out.
    private var answersMissing: Bool {
        guard let draft else { return true }
        return isAnswering || !draft.items.contains { !$0.short.isEmpty }
    }

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
                }

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
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let note = draft.note { Text(note) } // K51 (D159)
                        Text("\(DrillText.questions(draft.items.count)). Du kan ändra, ta bort och lägga till efteråt.")
                    }
                }

                // K51: a question whose answer could not be written ("Gör om"); the others can be saved.
                if !isAnswering, missingAnswers > 0, missingAnswers < draft.items.count, problem == nil {
                    Section {
                        Text("\(DrillText.questions(missingAnswers)) fick inget svar.")
                        Button("Gör om") { writeAnswers() }
                    }
                }

                if let problem {
                    Section {
                        Text(problem)
                        if answersMissing && !isAnswering { Button("Försök igen") { self.problem = nil; writeAnswers() } }
                    }
                }

                Section {
                    Button {
                        save(draft)
                    } label: {
                        HStack(spacing: 10) {
                            if isAnswering { ProgressView().tint(.white) }
                            Text(isAnswering ? "Skriver svar …" : "Ser rätt ut")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LumenButtonStyle(height: 54))
                    .disabled(answersMissing)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .lumenForm()
    }

    private func save(_ draft: DrillDraft) {
        let name = title.trimmingCharacters(in: .whitespaces)
        let subject = draft.summary.subject.trimmingCharacters(in: .whitespaces)
        let drill = model.save(Drill(title: name.isEmpty ? (subject.isEmpty ? "Nytt prov" : "\(subject)provet") : name,
                                     summary: draft.summary, items: draft.items.filter { !$0.short.isEmpty },
                                     questionCount: settings.questions, longWords: settings.length.words))
        onSaved(drill)
        dismiss()
    }
}
