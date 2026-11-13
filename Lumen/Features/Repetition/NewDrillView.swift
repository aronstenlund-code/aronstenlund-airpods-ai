import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A79 (D142, Kelly Ke49), rebuilt in A87 (D160, Kelly Ke53 `apple/nytt.png`): "Nytt prov" as an ordinary form in a
/// sheet. The material as four rows with a symbol (several pages in a row with the camera, several from the photo
/// library, pasted text, PDF/Word/text), the number of questions with the system's stepper, then **Skapa frågor**
/// fixed at the bottom (with the reason while it is grey) → "Läser ditt material" (steps, not an endless spinner) →
/// "Stämmer det här?" (the summary, correctable with one line, **Ser rätt ut** fixed at the bottom) → saved. K45 runs
/// in two steps: the questions first (Haiku), the answers while the user reads the summary (Sonnet). The material is
/// sent once and never kept (B4); a correction is made from K45's notes, never from the photos again.
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
    /// A89 (D162): the long answers' length comes from Inställningar › Avancerat (`model.newDrillSettings`).
    @State private var settings = DrillSettings()
    /// A88 (D161): "Vilken årskurs?", the profile's grade chosen again.
    @State private var grade: StudyProfile.Grade?
    @State private var gradeLoaded = false
    /// A84 (D151): the exam's voice, chosen on "Stämmer det här?" before the sound is made.
    @State private var voice = "A"
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
            if let problem { // first, so it is seen without scrolling
                Section {
                    Text(verbatim: problem)
                    if !material.isEmpty { Button("Försök igen") { create(correction: nil) } } // A85
                }
            }

            Section {
                TextField("Provets namn", text: $title)
            }

            Section {
                Button { isTakingPhotos = true } label: { Self.materialRow("Fota sidor", "camera.fill", Color.blue) }
                PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                    Self.materialRow("Välj bilder", "photo.fill", Color.green)
                }
                Button { isAddingText = true } label: { Self.materialRow("Skriv text", "text.alignleft", Color.orange) }
                Button { isImporting = true } label: { Self.materialRow("Lägg till dokument", "doc.fill", Color.gray) }
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
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Läser dokumentet …").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Material")
            } footer: {
                Text("Foton, dokument och text skickas en gång för att göra frågorna och sparas inte.")
            }

            Section {
                Stepper(value: $settings.questions, in: DrillSettings.questionRange) {
                    LabeledContent("Antal frågor", value: "\(settings.questions)").monospacedDigit()
                }
            } header: {
                Text("Frågor")
            } footer: {
                Text("Varje fråga får ett kort och ett långt svar.") // D162: both answers are always made
            }

            GradeChoice(grade: $grade) // A88
        }
        .safeAreaInset(edge: .bottom) {
            // Kelly N3: the reason while the button is grey. A84 (D155): else what is left of the month's questions.
            MainActionBar(title: "Skapa frågor",
                          note: material.isEmpty ? "Lägg till minst en sida, bild eller text." : model.quota?.line,
                          isDisabled: material.isEmpty || readingDocument) {
                create(correction: nil)
            }
        }
        .onAppear {
            if !gradeLoaded {
                grade = model.preferredGrade // A88
                settings = model.newDrillSettings // A89
                gradeLoaded = true
            }
            if let stagedProblem, problem == nil {
                problem = stagedProblem
                if pasted.isEmpty { pasted = "Fotosyntes. Växter gör socker av koldioxid och vatten med ljusets energi." }
            }
        }
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

    /// A row of the material list: the symbol on a coloured square, as in Inställningar (SYSTEM §0.4).
    /// nonisolated: PhotosPicker builds its label outside the main actor (CI 43493961075).
    nonisolated private static func materialRow(_ title: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
            Text(title)
        }
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
                            Image(systemName: "xmark.circle.fill").font(.title3)
                                .foregroundStyle(Color.white, Color.black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ta bort sida \(i + 1)")
                    }
                }
            }
        }
        .accessibilityLabel("\(pages.count) sidor")
    }

    private func added(_ title: String, _ detail: String, remove: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).lineLimit(1)
                Text(verbatim: detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: remove) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain)
                .accessibilityLabel("Ta bort \(title)")
        }
    }

    private var textSheet: some View {
        NavigationStack {
            TextEditor(text: $pasted)
                .padding(.horizontal, 12)
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
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("Läser ditt material").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                if !materialLine.isEmpty { Text(verbatim: materialLine).foregroundStyle(.secondary) }
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.steps.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Group {
                            if i < stepsDone {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if i == stepsDone {
                                ProgressView()
                            } else {
                                Image(systemName: "circle").foregroundStyle(.tertiary)
                            }
                        }
                        .font(.title3)
                        .frame(width: 28)
                        Text(verbatim: Self.steps[i])
                            .foregroundStyle(i <= stepsDone ? Color.primary : Color.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(i < stepsDone ? "klart" : i == stepsDone ? "pågår" : "")
                }
            }
            Text("Det tar ungefär en minut. Du kan lämna appen.").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        model.preferredGrade = grade // A88: chosen again next time
        let gradeCode = grade?.rawValue ?? summary?.grade // K52: the profile's code, or what the summary found
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
                                                subject: summary?.subject, grade: gradeCode)
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
                    if !draft.summary.grade.isEmpty { LabeledContent("Årskurs", value: draft.summary.grade) }
                }

                Section("Provet handlar om") {
                    Text(verbatim: draft.summary.covers)
                }

                Section {
                    TextField("Till exempel ”Det är åk 8” eller ”Ta inte med cellandning”", text: $correction, axis: .vertical)
                    Button("Gör om med rättelsen") { create(correction: correction) }
                        .disabled(correction.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Något fel? Skriv det")
                }

                Section {
                    ForEach(draft.items.prefix(5)) { item in
                        Text(verbatim: item.question)
                    }
                    if draft.items.count > 5 { Text("och \(draft.items.count - 5) till").foregroundStyle(.secondary) }
                } header: {
                    Text("Frågor")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let note = draft.note { Text(verbatim: note) } // K51 (D159)
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
                        Text(verbatim: problem)
                        if answersMissing && !isAnswering { Button("Försök igen") { self.problem = nil; writeAnswers() } }
                    }
                }

                DrillVoiceChoice(voice: $voice) // A84 (D151): before the sound is made, it cannot be changed afterwards
            }
        }
        .safeAreaInset(edge: .bottom) {
            MainActionBar(title: isAnswering ? "Skriver svar …" : "Ser rätt ut",
                          isBusy: isAnswering,
                          isDisabled: answersMissing) {
                if let draft { save(draft) }
            }
        }
    }

    private func save(_ draft: DrillDraft) {
        let name = title.trimmingCharacters(in: .whitespaces)
        let subject = draft.summary.subject.trimmingCharacters(in: .whitespaces)
        var made = Drill(title: name.isEmpty ? (subject.isEmpty ? "Nytt prov" : "\(subject)provet") : name,
                         summary: draft.summary, items: draft.items.filter { !$0.short.isEmpty },
                         questionCount: settings.questions, longWords: settings.length.words)
        made.voiceModel = voice // A84: sent with the first save
        let drill = model.save(made)
        onSaved(drill)
        dismiss()
    }
}
