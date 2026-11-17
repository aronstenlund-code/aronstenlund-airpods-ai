import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// A115 (D203, Kelly Ke69 `docs/design/sag-i-airpods.md`): "Säg i AirPods", the free text at the top of Start. A dark,
// calm field in the system's monospaced type (Terminal and the Xcode console, not a hacker film), with how long and the
// tempo under it and **Spela**. What it counts as is said before anything is made (D205), and without credits the
// text is shown and nothing is counted (D200). It only ever plays with the reading player on the screen, which says
// "Spelar i AirPods" all the time; nothing is scheduled and nothing makes the app look like something else.

/// The words and colours of the field (Ke69 §3–§4).
@MainActor
enum SayText {
    static let field = Color(red: 0x10 / 255, green: 0x13 / 255, blue: 0x19 / 255)
    static let fieldDark = Color(red: 0x15 / 255, green: 0x18 / 255, blue: 0x1F / 255)
    static let ink = Color(red: 0xE7 / 255, green: 0xE9 / 255, blue: 0xEF / 255)
    static let accent = Color(red: 0x7F / 255, green: 0x9B / 255, blue: 0xFF / 255)

    static let repeats = [5, 10, 20]

    #if DEBUG
    /// The screenshots: a text already written in the field.
    static var stagedForScreenshots: String?
    #endif

    /// "En gång" or "10 min" on the button.
    static func howLong(_ minutes: Int) -> String { minutes == 0 ? "En gång" : "\(minutes) min" }

    /// "1,0×", "1,25×".
    static func tempo(_ tempo: Double) -> String {
        let text = tempo == tempo.rounded() || (tempo * 10) == (tempo * 10).rounded() ? String(format: "%.1f", tempo)
            : String(format: "%.2f", tempo)
        return text.replacingOccurrences(of: ".", with: ",") + "×"
    }

    /// Ke69 asks for 0,5 · 0,75 · 1,0 · 1,25 · 1,5. The tempos the player takes are decided in D151 (and pinned by
    /// `A84VoiceTempoTests`), and 1,25 is not one of them, so it is left out until that is decided.
    static let tempos: [Double] = [0.5, 0.75, 1.0, 1.5]

    /// "7:12".
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The line under the field: what the text counts as, or why it cannot be played now.
    /// A122 (D209, Aron 2026-11-17): the phone does not have to be out. The player goes on with the screen locked
    /// (background audio) and is steered from the Lock Screen and the AirPods.
    static let lockLine = "Du kan låsa telefonen och lägga undan den. Det hörs i AirPods ändå."

    static func costLine(counts: Int, left: Int?, readingAloudOff: Bool) -> String {
        if readingAloudOff { return CloudDrillAudio.unavailableLine }
        if let left, counts > left {
            return "Texten räknas som \(DrillText.questions(counts)), och du har \(left) kvar. "
                + "Korta texten eller vänta till den 1 \(ChatGPTImportView.nextMonth())."
        }
        return "Räknas som \(DrillText.questions(counts)). Upprepningar kostar inget."
    }
}

/// Ke69 `prov-tom.png` and `prov-text.png`: the field with its controls.
struct SayInAirPodsField: View {
    let model: RepetitionModel
    @State private var text = ""
    @State private var isStarting = false
    /// The exam made from the text that is in the field now, so Spela again plays the same sound (it costs nothing).
    @State private var made: (text: String, drillID: UUID)?
    @AppStorage("say.repeatMinutes") private var minutes = 0
    @AppStorage(RepetitionModel.tempoKey) private var tempo: Double = 1
    // A116 (D204, Ke69 `material.png`): "+" takes photos, pictures, a file or a link. What is read from the material is
    // put in the field, so one sees what will be read aloud.
    @State private var isTakingPhotos = false
    @State private var isPickingPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var askingLink = false
    @State private var link = ""
    @State private var isReadingMaterial = false
    @State private var materialNote: String?
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var chars: Int { SaidText.chars(text) }
    private var counts: Int { SaidText.countsAs(text) }
    private var isEmpty: Bool { chars == 0 }
    /// The exam of this very text, if it was played before.
    private var sameAsMade: Drill? {
        guard let made, made.text == text else { return nil }
        return model.store.drill(made.drillID)
    }
    private var readingAloudOff: Bool { sameAsMade.map(model.isReadingAloudOff) ?? false }
    /// The month does not cover the text (only a new text counts; the same sound again is free).
    private var tooMany: Bool {
        guard sameAsMade == nil, let quota = model.quota else { return false }
        return counts > quota.left
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // With the largest text the heading and the count are two rows (they were squeezed side by side on SE).
            let header = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            header {
                Text("Säg i AirPods").font(.subheadline.weight(.semibold))
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                if !isEmpty {
                    Text("\(chars) tecken").font(.caption.monospaced()).opacity(0.55)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            HStack(alignment: .top, spacing: 8) { // the empty field keeps three rows: the mark stands at the first
                Text(verbatim: "›").foregroundStyle(SayText.accent).accessibilityHidden(true)
                TextField("", text: $text, prompt: Text(typeSize.isAccessibilitySize ? "Skriv här" : "Skriv eller klistra in det du vill höra").foregroundStyle(SayText.ink.opacity(0.45)),
                          axis: .vertical)
                    .lineLimit(typeSize.isAccessibilitySize ? 2...6 : 3...8)
                    .focused($focused)
                    .tint(SayText.accent)
                    .accessibilityLabel("Säg i AirPods, textfält")
            }
            .font(.body.monospaced())
            .dynamicTypeSize(...DynamicTypeSize.accessibility3) // the field stays a field on a small screen
            if isReadingMaterial || materialNote != nil {
                HStack(spacing: 8) {
                    if isReadingMaterial { ProgressView().controlSize(.small) }
                    Text(verbatim: isReadingMaterial ? "Läser materialet …" : materialNote ?? "")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if !isEmpty {
                Text(verbatim: SayText.costLine(counts: counts, left: sameAsMade == nil ? model.quota?.left : nil,
                                                 readingAloudOff: readingAloudOff))
                    .font(.footnote)
                    .opacity(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            controls
            Text(verbatim: SayText.lockLine) // A122 (D209)
                .font(.footnote)
                .opacity(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .foregroundStyle(SayText.ink)
        .background(scheme == .dark ? SayText.fieldDark : SayText.field, in: RoundedRectangle(cornerRadius: 16))
        // Kelly S3: in dark mode the field is almost the colour of the screen, so a hairline shows where it ends.
        .overlay { if scheme == .dark { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5) } }
        .environment(\.colorScheme, .dark) // the system's controls are dark inside the field, in light mode too
        #if DEBUG
        .onAppear { if let staged = SayText.stagedForScreenshots, text.isEmpty { text = staged } }
        #endif
        // A116: presented from outside the field's dark colour scheme, so the system's sheets look as usual.
        .sheet(isPresented: $isTakingPhotos) { camera.ignoresSafeArea() }
        .photosPicker(isPresented: $isPickingPhotos, selection: $photoItems, maxSelectionCount: 20, matching: .images)
        .onChange(of: photoItems) { _, items in Task { await addPhotos(items) } }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.pdf, .plainText, .text, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { Task { await addFile(url) } }
        }
        .alert("Klistra in länk", isPresented: $askingLink) {
            TextField("https://", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Lägg till") {
                let pasted = link
                Task { await addLink(pasted) }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("EarMind läser sidans text och lägger den i fältet.")
        }
    }

    /// Kelly (review of A115–A117): the row as it fits. One row; else the small buttons on a row and Spela last; else
    /// every button on a row of its own. Nothing is cut with "…".
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                addMenu
                howLongMenu
                tempoMenu
                Spacer(minLength: 8)
                playButton(wide: false)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    addMenu
                    howLongMenu
                    tempoMenu
                }
                playButton(wide: true)
            }
            VStack(alignment: .leading, spacing: 10) {
                addMenu
                howLongMenu
                tempoMenu
                playButton(wide: true)
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Fota sidor", systemImage: "camera") { takePhotos() }
            Button("Välj bilder", systemImage: "photo") { isPickingPhotos = true }
            Button("Lägg till fil", systemImage: "doc") { isImporting = true }
            Button("Klistra in länk", systemImage: "link") {
                link = ""
                askingLink = true
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Lägg till material")
        .disabled(isReadingMaterial)
        .smallSayControl()
    }

    private var howLongMenu: some View {
        Menu {
            Picker("Hur länge", selection: $minutes) {
                Text("En gång").tag(0)
                ForEach(SayText.repeats, id: \.self) { Text("Upprepa \($0) min").tag($0) }
            }
        } label: {
            // Image and Text, not a Label: the Label lost its words in the row ("En gång" became the symbol alone).
            HStack(spacing: 4) {
                Image(systemName: "repeat").accessibilityHidden(true)
                Text(verbatim: SayText.howLong(minutes)).lineLimit(1)
            }
            .fixedSize()
        }
        .accessibilityLabel("Hur länge, \(minutes == 0 ? "En gång" : "Upprepa \(minutes) minuter")")
        .smallSayControl()
    }

    private var tempoMenu: some View {
        Menu {
            Picker("Tempo", selection: $tempo) {
                ForEach(SayText.tempos, id: \.self) { Text(verbatim: SayText.tempo($0)).tag($0) }
            }
        } label: {
            Text(verbatim: SayText.tempo(tempo)).monospacedDigit().lineLimit(1).fixedSize()
        }
        .accessibilityLabel("Tempo, \(SayText.tempo(tempo))")
        .smallSayControl()
    }

    private func playButton(wide: Bool) -> some View {
        Button {
            play()
        } label: {
            HStack(spacing: 6) {
                if isStarting { ProgressView().controlSize(.small) } else { Image(systemName: "play.fill").accessibilityHidden(true) }
                Text("Spela").lineLimit(1).fixedSize()
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: wide ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(SayText.accent)
        .foregroundStyle(Color.black)
        .disabled(isEmpty || isStarting || tooMany)
    }

    // MARK: A116, material into the field

    @ViewBuilder
    private var camera: some View {
        if PageScanner.isAvailable {
            PageScanner { images in
                isTakingPhotos = false
                let pages = images.compactMap { ExamMaterials.jpeg($0) }
                Task { await readPages(pages) }
            } onCancel: {
                isTakingPhotos = false
            }
        } else {
            PagePhotoPicker { image in
                isTakingPhotos = false
                let pages = [ExamMaterials.jpeg(image)].compactMap { $0 }
                Task { await readPages(pages) }
            } onCancel: {
                isTakingPhotos = false
            }
        }
    }

    /// As in Nytt prov (Ke50 §2): after a no to the camera the form says what to do instead of opening a black camera.
    private func takePhotos() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            materialNote = "EarMind får inte använda kameran. Tillåt den i Inställningar, eller välj bilder ur bildbiblioteket."
        } else {
            materialNote = nil
            isTakingPhotos = true
        }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var pages: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
               let jpeg = ExamMaterials.jpeg(image) {
                pages.append(jpeg)
            }
        }
        photoItems = []
        await readPages(pages)
    }

    /// Photos are read by the server (`/exam read`, K70): the pages' text, cleaned for reading aloud. Nothing is
    /// saved and nothing is counted by reading; the photos are not kept.
    private func readPages(_ pages: [Data]) async {
        guard !pages.isEmpty else { return }
        await reading {
            let draft = try await model.readText(DrillMaterial(pages: pages))
            return draft.parts.map(\.long).joined(separator: "\n")
        }
    }

    private func addFile(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let name = url.lastPathComponent
        if url.pathExtension.lowercased() == "docx" {
            guard let data = try? Data(contentsOf: url) else { materialNote = "\(name) gick inte att öppna."; return }
            await reading { try await model.maker.documentText(docx: data) } // iOS cannot read Word; the server does
            return
        }
        if let text = try? DocumentText.read(url) {
            add(text)
        } else if url.pathExtension.lowercased() == "pdf" {
            let scanned = await ExamMaterials.pages(from: url) // a scanned PDF has no text: its pages go as photos
            if scanned.isEmpty { materialNote = "\(name) har ingen text som går att läsa. Fota sidorna i stället." } else { await readPages(scanned) }
        } else {
            materialNote = "\(name) har ingen text som går att läsa. Fota sidorna i stället."
        }
    }

    /// D204 (Kevin's K81): the server reads the page; only its readable text comes back.
    private func addLink(_ pasted: String) async {
        guard let address = FetchedPage.address(pasted) else {
            materialNote = "Det ser inte ut som en länk."
            return
        }
        await reading { try await model.maker.fetchPage(address).text }
    }

    /// Runs one reading with "Läser materialet …", then puts the text in the field or says why not.
    private func reading(_ work: () async throws -> String) async {
        isReadingMaterial = true
        materialNote = nil
        do {
            let read = try await work()
            if read.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { materialNote = FetchedPage.unreadableLine } else { add(read) }
        } catch DrillMakingError.refused(let message) {
            materialNote = message // the server's own Swedish words (a blocked address, too big, not text …)
        } catch DrillMakingError.offline {
            materialNote = NetworkStatus.noNetworkLine
        } catch {
            materialNote = FetchedPage.unreadableLine
        }
        isReadingMaterial = false
    }

    /// After what is already there, and never more than the server reads.
    private func add(_ more: String) {
        let joined = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? more : text + "\n" + more
        text = String(joined.prefix(SaidText.maxChars))
    }

    /// Spela: the same text again plays the sound that is already made; a new text is saved and started (counted
    /// then, D185). Either way the reading player comes up, and that is where it plays.
    private func play() {
        focused = false
        isStarting = true
        let text = self.text
        let minutes = self.minutes == 0 ? nil : self.minutes
        Task {
            if let again = sameAsMade {
                await model.sayAgain(again, repeatMinutes: minutes)
            } else if let drill = await model.say(text, repeatMinutes: minutes) {
                made = (text, drill.id)
            }
            isStarting = false
        }
    }
}

private extension View {
    /// The field's small buttons: bordered, small, and growing no further than the app's other bars.
    func smallSayControl() -> some View {
        buttonStyle(.bordered)
            .controlSize(.small)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
