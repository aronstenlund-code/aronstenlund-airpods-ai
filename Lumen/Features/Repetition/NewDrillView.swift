import AVFoundation
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
    /// A94 (Kelly Ke55 `docs/design/forsta-starten.md`): set in the first start, where Nytt prov is the screen after
    /// Välkommen. Then a line at the top says what to do, **Fota sidor** is the one bold row in the accent colour,
    /// and "Senare" (not Avbryt) calls this instead of closing a sheet.
    var onLater: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    init(model: RepetitionModel, onSaved: @escaping (Drill) -> Void, stagedProblem: String? = nil) {
        self.model = model
        self.onSaved = onSaved
        self.stagedProblem = stagedProblem
    }

    /// The first start (A94): `NewDrillView(model: model, onLater: { … }) { drill in … }`.
    init(model: RepetitionModel, onLater: @escaping () -> Void, onSaved: @escaping (Drill) -> Void) {
        self.model = model
        self.onSaved = onSaved
        self.onLater = onLater
    }

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
    /// A92 (D166): "Fråga om EarMind" from the toolbar.
    @State private var showsHelp = false
    /// Ke50 §2: iOS has said no to the camera, so Fota sidor says what to do instead of opening a black camera.
    @State private var cameraDenied = false
    @FocusState private var textFocused: Bool
    /// A93 (D169): "Gör med ChatGPT", from its row (the three steps) or from an answer pasted under Skriv text.
    @State private var chatGPT: ChatGPTStart?

    private struct ChatGPTStart: Identifiable {
        let id = UUID()
        let stage: ChatGPTImportView.Stage
    }

    private var isFirstStart: Bool { onLater != nil }

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
                    Button(isFirstStart ? "Senare" : "Avbryt") {
                        making?.cancel()
                        answering?.cancel()
                        if let onLater { onLater() } else { dismiss() }
                    }
                }
                if model.help != nil { // A92 (Kelly Ke57)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsHelp = true
                        } label: {
                            Label("Fråga om EarMind", systemImage: "questionmark.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsHelp) { HelpChatView(model: model, suggestion: "Vad kan jag fota?") }
        .sheet(isPresented: $isTakingPhotos) { camera.ignoresSafeArea() }
        .sheet(isPresented: $isAddingText, onDismiss: offerImport) { textSheet }
        .sheet(item: $chatGPT) { start in
            ChatGPTImportView(model: model, title: title, grade: grade, questions: settings.questions,
                              start: start.stage) { drill in
                onSaved(drill)
                dismiss()
            }
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.pdf, .plainText, .text, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { Task { await addDocuments(urls) } }
        }
        .onChange(of: photoItems) { _, items in
            Task { await addPhotos(items) }
        }
        // A95: the screen changes by itself (Läser ditt material → Stämmer det här?), and a problem appears at the
        // top of the form: VoiceOver is told.
        .onChange(of: stage) { AccessibilityNotification.ScreenChanged().post() }
        // A99 (D175): the month's questions now, from the server (no sound is made by asking).
        .task {
            await model.refreshQuota()
            capQuestions()
        }
        .onChange(of: model.quota) { capQuestions() }
        .onChange(of: problem) { _, now in
            if let now { AccessibilityNotification.Announcement(now).post() }
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

            if model.quotaUsedUp { // A99 (D175, Kelly): said before anything is sent, not as an error afterwards
                Section { Text(verbatim: Self.usedUpLine) }
            }

            if cameraDenied {
                Section {
                    Text("EarMind får inte använda kameran. Tillåt den i Inställningar, eller välj bilder ur bildbiblioteket.")
                    Button("Öppna Inställningar") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }

            if !isFirstStart {
                Section {
                    TextField("Provets namn", text: $title)
                        .accessibilityLabel("Provets namn") // A95: a name of its own, not only the placeholder
                }
            }

            Section {
                // A94: in the first start Fota sidor is the only row in the accent colour, and bold.
                let strong: Bool? = isFirstStart ? true : nil
                let plain: Bool? = isFirstStart ? false : nil
                Button { takePhotos() } label: { Self.materialRow("Fota sidor", "camera.fill", Color.blue, strong) }
                PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                    Self.materialRow("Välj bilder", "photo.fill", Color.green, plain)
                }
                Button { isAddingText = true } label: { Self.materialRow("Skriv text", "text.alignleft", Color.orange, plain) }
                Button { isImporting = true } label: { Self.materialRow("Lägg till dokument", "doc.fill", Color.gray, plain) }
                if !isFirstStart { // A93 (Kelly Ke58): last, after the app's own ways; not in the first start (A94)
                    Button { chatGPT = ChatGPTStart(stage: .steps) } label: {
                        HStack(spacing: 12) {
                            Self.materialIcon("doc.on.clipboard", Color.indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gör med ChatGPT")
                                Text("Låt ChatGPT göra frågorna av dina filer")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .accessibilityHidden(true)
                        }
                    }
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
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Läser dokumentet …").foregroundStyle(.secondary)
                    }
                }
            } header: {
                if isFirstStart {
                    // A94: one line of what to do, in the first section's header so it sits right under the
                    // navigation bar (Kelly 10:51: a row of its own left a gap above it).
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Börja med materialet till ditt nästa prov.")
                            .font(.body)
                            .fontWeight(.regular)
                            .textCase(nil)
                        Text("Material")
                    }
                } else {
                    Text("Material")
                }
            } footer: {
                Text(isFirstStart ? "iOS frågar om kameran första gången. Fotona sparas inte."
                                  : "Foton, dokument och text skickas en gång för att göra frågorna och sparas inte.")
            }

            if isFirstStart {
                // A94 (Kelly `fs-2-nytt.png`): the name, the grade and the number of questions in one section under
                // the material, so the material is the first thing on the screen.
                Section {
                    TextField("Provets namn (valfritt)", text: $title)
                        .accessibilityLabel("Provets namn, valfritt") // A95
                    Picker("Vilken årskurs?", selection: $grade) { // A88, as `GradeChoice`
                        Text("Hoppa över").tag(StudyProfile.Grade?.none)
                        ForEach(GradeChoice.choices, id: \.self) { choice in
                            Text(GradeChoice.label(choice)).tag(StudyProfile.Grade?.some(choice))
                        }
                    }
                    questionStepper
                } header: {
                    Text("Prov")
                } footer: {
                    Text("Varje fråga får ett kort och ett långt svar.")
                }
            } else {
                Section {
                    questionStepper
                } header: {
                    Text("Frågor")
                } footer: {
                    Text("Varje fråga får ett kort och ett långt svar.") // D162: both answers are always made
                }

                GradeChoice(grade: $grade) // A88
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Kelly N3: the reason while the button is grey. A84 (D155): else what is left of the month's questions.
            MainActionBar(title: "Skapa frågor",
                          note: model.quotaUsedUp ? "Inga frågor kvar den här månaden." // Kelly: the long line is at the top
                              : material.isEmpty ? "Lägg till minst en sida, bild eller text." : model.quota.map { $0.line + "." },
                          isDisabled: material.isEmpty || readingDocument || model.quotaUsedUp) {
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

    /// Kelly (A99): "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 december."
    private static var usedUpLine: String {
        "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 \(ChatGPTImportView.nextMonth())."
    }

    /// The stepper never stands above what is left (the quota may arrive after the form is shown).
    private func capQuestions() {
        let range = model.newDrillQuestionRange
        settings.questions = min(max(settings.questions, range.lowerBound), range.upperBound)
    }

    private var questionStepper: some View {
        // A99 (D175): never more questions than are left of the month's.
        Stepper(value: $settings.questions, in: model.newDrillQuestionRange) {
            LabeledContent("Antal frågor", value: "\(settings.questions)").monospacedDigit()
        }
    }

    /// Fota sidor. iOS asks about the camera the first time by itself; after a no the document camera would open
    /// black, so the form says what to do (Kelly Ke50 §2).
    private func takePhotos() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraDenied = status == .denied || status == .restricted
        if !cameraDenied { isTakingPhotos = true }
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
    /// `strong`: nil = as the system's button rows (accent colour); true = bold in the accent colour; false = in the
    /// text colour (A94: in the first start only Fota sidor stands out).
    nonisolated private static func materialRow(_ title: String, _ symbol: String, _ color: Color,
                                                _ strong: Bool? = nil) -> some View {
        HStack(spacing: 12) {
            materialIcon(symbol, color)
            if strong == false {
                Text(title).foregroundStyle(Color.primary)
            } else {
                Text(title).fontWeight(strong == true ? .semibold : .regular)
            }
        }
    }

    nonisolated private static func materialIcon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 30, height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }

    /// A93 point 2: an answer from ChatGPT pasted under Skriv text is shown as "Hittade n frågor med svar" and saved
    /// as it is, instead of being sent as material. The prompt itself (its example lines) is not an answer.
    private func offerImport() {
        guard !pasted.contains("<frågan>"), let found = ChatGPTImport.read(pasted) else { return }
        chatGPT = ChatGPTStart(stage: .found(found))
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    ZStack(alignment: .topTrailing) {
                        if let image = UIImage(data: pages[i]) {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 64, height: 84).clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel("Sida \(i + 1)") // A95
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
            // Toby T21: the sheet was a blank page with no cursor. Now the keyboard comes up by itself and an
            // empty editor says what it is for.
            ZStack(alignment: .topLeading) {
                TextEditor(text: $pasted)
                    .focused($textFocused)
                    .accessibilityLabel("Text") // A95: the editor had no name
                if pasted.isEmpty {
                    Text("Skriv eller klistra in text ur ditt material.")
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .task { textFocused = true }
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
                        .accessibilityHidden(true) // A95: "klart" and "pågår" are the row's value
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
                problem = "EarMind kunde inte skriva svaren just nu. Försök igen om en stund."
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
                        .accessibilityLabel("Rättelse") // A95
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
