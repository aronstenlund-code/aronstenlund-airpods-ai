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

    /// A124 (D210, Aron 2026-11-17): how long the text goes round: 10 min to 1 hour in steps of 5. It replaces
    /// "En gång" and 5/10/20. Spela plays at once; nothing starts later.
    static let repeats = Array(stride(from: 10, through: 60, by: 5))
    static let defaultRepeat = 10
    /// A stored value that is no longer on offer (0 = "En gång", 5) becomes the default.
    static func repeatMinutes(_ stored: Int) -> Int { repeats.contains(stored) ? stored : defaultRepeat }

    #if DEBUG
    /// The screenshots: a text already written in the field.
    static var stagedForScreenshots: String?
    /// A130: the line after a refused Spela, for the screenshots.
    static var stagedRefusal: String?
    /// A132: the server's cost, for the screenshots (no server there).
    static var stagedCost: Int?
    /// A136: a style already written, and the voice sheet open, for the screenshots.
    static var stagedStyle: String?
    static var stagedVoicesSheet = false
    #endif

    /// "10 min" … "1 timme" on the button.
    static func howLong(_ minutes: Int) -> String { minutes == 60 ? "1 timme" : "\(minutes) min" }

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
    /// A132 (D215.2, Kelly Ke72): shorter, and only until Spela has been pressed once.
    static let lockLine = "Du kan låsa telefonen. Det hörs i AirPods ändå."
    static let hasPlayedKey = "say.hasPlayed"

    /// A135 (D219.3): how long Spela shows its spinner, and what is said after that.
    static let patience: Duration = .seconds(10)
    static let slowLine = "Ljudet kunde inte hämtas. Kolla nätet." // Kelly: the button says the rest

    /// A136 (D220, Kelly Ke75): the words of the style row and of "Skriv i takt".
    static let stylePrompt = "Hur ska det låta?"
    static let paceTitle = "Skriv i takt"
    static let paceCapsule = "I takt"
    static let voiceCapsule = "Röst" // no voice chosen: the server's own
    static let inPaceKey = "say.inPace"
    static let voiceKey = "say.voiceID"

    /// A132 (Ke72): the main button says how long: "Spela i 10 min", "Spela i 1 timme".
    static func playTitle(_ minutes: Int) -> String { "Spela i \(howLong(minutes))" }

    /// A132 (Ke72): the cost as two words by the button: "120 krediter", "0 krediter", or "120 krediter · du har 88".
    static func creditsLine(cost: Int, left: Int) -> String {
        cost > left ? "\(CreditText.credits(cost)) · du har \(CreditText.short(left, .down))" : CreditText.credits(cost)
    }

    /// A134 (Ke73 §3): the cost by the button with the weekly card. While the week covers the text it is "Ingår"; when
    /// nothing covers it, "Veckans tak är nått"; when the week is out and other credits pay, the usual line.
    static func costLine(cost: Int, left: Int, subscription: DrillQuota.Subscription?) -> String {
        guard let subscription, subscription.active == true else { return creditsLine(cost: cost, left: left) }
        if cost > left { return ShopText.weekIsOut }
        return ShopText.weekIsOut(subscription) ? creditsLine(cost: cost, left: left) : ShopText.included
    }

    /// A134 (Ke73 §2): "120 krediter · du har 88 · Fyll på" as one text, the last words in the accent colour.
    static func refillLine(_ line: String) -> AttributedString {
        var all = AttributedString("\(line) · ")
        all.foregroundColor = ink
        var link = AttributedString(ShopText.refill)
        link.foregroundColor = accent
        all.append(link)
        return all
    }

    /// A136 (Kelly's review): what a capsule in "Senaste" says after the text: the style's first word, else the name
    /// of the chosen voice. Nil for a text with the server's own voice and no style.
    static func soundMark(_ drill: Drill, voices: [SayVoice]) -> String? {
        if let style = Drill.cleanStyle(drill.style), let word = style.split(whereSeparator: { $0 == " " || $0 == "," }).first {
            return String(word)
        }
        guard let id = drill.voiceID else { return nil }
        return voices.first { $0.voice_id == id }?.name
    }

    /// A132 (Ke72): a said text as a capsule under the field: its beginning, at most about 24 characters.
    static func capsule(_ text: String) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return flat.count > 24 ? String(flat.prefix(23)).trimmingCharacters(in: .whitespaces) + "…" : flat
    }

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
    /// A130 (D212): what the server said when Spela started nothing; cleared when the text changes.
    @State private var refused: String?
    /// D215.2: the line about the locked phone is said until Spela has been pressed once.
    @AppStorage(SayText.hasPlayedKey) private var hasPlayed = false
    /// Ke72: the clipboard has text (asked without reading it, so the system shows no notice).
    @State private var clipboardHasText = false
    /// A135: which press is waited for, and that the last one took too long (the button is then Försök igen).
    @State private var attempt = 0
    @State private var canRetry = false
    /// K92: the server's answer for the text it was asked about.
    @State private var asked: (text: String, sound: SaySound, cost: Int, left: Int?)?
    /// A136 (D220.2): "Hur ska det låta?", for this text. Empty = no style.
    @State private var style = ""
    @FocusState private var styleFocused: Bool
    /// A136 (D220.3): the chosen catalog voice ("" = the server's own), kept to the next time.
    @AppStorage(SayText.voiceKey) private var storedVoice = ""
    @State private var showsVoices = false
    /// A134 (Ke73 §2): "Fyll på" by the cost opens the credits sheet with the packs.
    @State private var showsCredits = false
    /// A136 (D220.1): "Skriv i takt" instead of a tempo, kept to the next time.
    @AppStorage(SayText.inPaceKey) private var inPace = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("say.repeatMinutes") private var storedMinutes = SayText.defaultRepeat
    private var minutes: Int { SayText.repeatMinutes(storedMinutes) }
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
    private var counts: Int { SaidText.countsAs(text, perQuestion: model.quota?.prices?.read?.chars_per_question) }
    private var isEmpty: Bool { chars == 0 }
    /// The exam of this very text, if it was played before.
    private var sameAsMade: Drill? {
        model.saidDrill(for: text, sound: sound) // A132: also a text put back from "Senaste"
    }
    /// A136: the chosen voice, if the catalog still has it.
    private var voice: SayVoice? { model.sayVoices.first { $0.voice_id == storedVoice } }
    /// A136: how the text is to sound. The same text with another voice or style is new sound (and another exam).
    private var sound: SaySound { SaySound(voiceID: voice?.voice_id, style: style) }
    private var readingAloudOff: Bool { sameAsMade.map(model.isReadingAloudOff) ?? false }
    /// The month does not cover the text (only a new text counts; the same sound again is free).
    private var tooMany: Bool {
        if let credits { return credits.cost > credits.left } // A131
        guard sameAsMade == nil, let quota = model.quota else { return false }
        return counts > quota.left
    }

    /// A131 (D213), A132 (D215.8, K92): the month in credits, and what Spela costs as the server says it: asked a
    /// moment after the typing stops, without saving anything (`cost`). A text that is already an exam and started
    /// costs 0. While the server has not answered, nothing is said (Ke72), and the server answers at Spela anyway.
    /// A133 (D216): an account without a limit is told no cost.
    private var credits: (cost: Int, left: Int, resetsDay: String?)? {
        guard let quota = model.quota, quota.isCredits, !quota.isUnlimited, !isEmpty else { return nil }
        #if DEBUG
        if let staged = SayText.stagedCost { return (staged, quota.left, quota.resetsDay) }
        #endif
        if let same = sameAsMade, !model.awaitsAudioStart(same) { return (0, quota.left, quota.resetsDay) }
        if let asked, asked.text == text, asked.sound == sound { return (asked.cost, asked.left ?? quota.left, quota.resetsDay) }
        if let known = sameAsMade?.startCost { return (known, quota.left, quota.resetsDay) }
        return nil
    }

    /// K92: asks the server what this text costs, 0.7 s after the last key (at most 20 a minute there).
    private func askCost(for text: String, sound: SaySound) async {
        guard model.quota?.isCredits == true, model.quota?.isUnlimited != true, SaidText.chars(text) > 0 else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled, let answer = await model.sayCost(text, sound: sound), !Task.isCancelled else { return }
        asked = (text, sound, answer.cost, answer.remaining)
    }

    /// What the cost is asked about: asked again when the text, the style or the voice changes.
    private struct Asked: Hashable {
        var text: String
        var sound: SaySound
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            card
            if playing == nil { recents }
        }
        .task(id: Asked(text: text, sound: sound)) { await askCost(for: text, sound: sound) } // cancelled and asked again
        .task { await model.loadSayVoices() }
        .onChange(of: sound) { refused = nil; canRetry = false }
        .onChange(of: isEmpty) { _, empty in if empty { style = "" } } // the style belongs to the text
        .onAppear { lookAtClipboard(); setStage() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { lookAtClipboard() } }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in lookAtClipboard() }
        .onChange(of: isEmpty) { setStage() }
        .onChange(of: tooMany) { setStage() }
        .onChange(of: model.isSayingOnCard) { _, plays in
            setStage()
            // What was counted while it played shows in the capsule when it has stopped.
            if !plays { Task { await model.refreshQuota() } }
        }
    }

    private func lookAtClipboard() { clipboardHasText = UIPasteboard.general.hasStrings }

    /// D215.1: at most one filled button on Start. Spela is filled when there is a text that can be played (or one
    /// plays); then Starta prov is toned down.
    private func setStage() { model.sayHoldsTheStage = model.isSayingOnCard || (!isEmpty && !tooMany) }

    /// A132 (D215.3, Kelly Ke72): "Senaste". The three latest said texts as capsules in a row under the card; a tap
    /// puts the text back in the field (it does not play), a long press removes it. They are not exams: they are never
    /// "Nästa prov" and never among "Andra prov".
    @ViewBuilder
    private var recents: some View {
        let said = Array(model.recentSaid.prefix(3)) // A135 (D219.4): every text once
        if !said.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Senaste").font(.footnote).foregroundStyle(.secondary)
                    ForEach(said) { drill in
                        Button {
                            text = String(drill.saidText.prefix(SaidText.maxChars))
                            // A136 (Ke75 §7.3): one tap puts back all three: the text, its voice and its style.
                            style = drill.style ?? ""
                            storedVoice = drill.voiceID ?? ""
                        } label: {
                            // Kelly (review of A136): the text is cut first; what tells two sounds apart stays.
                            HStack(spacing: 4) {
                                Text(verbatim: SayText.capsule(drill.saidText))
                                if let mark = SayText.soundMark(drill, voices: model.sayVoices) {
                                    Text(verbatim: "· \(mark)").foregroundStyle(.secondary)
                                }
                            }
                            .font(.footnote)
                            .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.primary)
                        .accessibilityHint("Lägger tillbaka texten i fältet")
                        .contextMenu {
                            Button("Ta bort", systemImage: "trash", role: .destructive) { model.delete(drill) }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    // MARK: A132, playing on the card (D215.6)

    /// The text that is being read on the card, if one is.
    private var playing: (reader: ReadingPlayer, drill: Drill)? {
        guard model.isSayingOnCard, let reader = model.session.reader, let drill = model.session.drill else { return nil }
        return (reader, drill)
    }

    /// Ke72 "Spelar": "● Spelar i AirPods", the text (a tap opens the player with the sentences), pause, the time
    /// that is left and Stoppa. It is always seen that something plays, and it is stopped with one tap.
    @ViewBuilder
    private func playingCard(_ reader: ReadingPlayer, _ drill: Drill) -> some View {
        let waiting = reader.phase == .waitingForAudio
        HStack(spacing: 6) {
            Circle().fill(SayText.accent).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(waiting ? "Gör ljudet …" : "Spelar i AirPods").font(.footnote.weight(.semibold))
        }
        .foregroundStyle(SayText.accent)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .combine)
        Button {
            model.showsPlayer = true
        } label: {
            Text(verbatim: drill.saidText)
                .font(.body.monospaced())
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .opacity(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityHint("Öppnar spelaren med meningarna")
        HStack(spacing: 12) {
            Button {
                model.session.press(.long)
            } label: {
                Image(systemName: reader.isPaused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(width: 44, height: 44)
                    .background(SayText.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reader.isPaused ? "Fortsätt" : "Pausa")
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(verbatim: "\(SayText.clock(model.session.repeatSecondsLeft)) kvar" + (reader.isPaused ? " · pausad" : ""))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            Button {
                model.end()
            } label: {
                Text("Stoppa").font(.body).lineLimit(1).fixedSize()
            }
            .buttonStyle(.plain)
            .foregroundStyle(SayText.accent)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let playing {
                playingCard(playing.reader, playing.drill)
            } else {
                writingCard
            }
        }
        .onChange(of: text) { refused = nil; canRetry = false }
        .padding(16)
        .foregroundStyle(SayText.ink)
        .background(scheme == .dark ? SayText.fieldDark : SayText.field, in: RoundedRectangle(cornerRadius: 16))
        // Kelly S3: in dark mode the field is almost the colour of the screen, so a hairline shows where it ends.
        .overlay { if scheme == .dark { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5) } }
        .environment(\.colorScheme, .dark) // the system's controls are dark inside the field, in light mode too
        #if DEBUG
        .onAppear {
            if let staged = SayText.stagedForScreenshots, text.isEmpty { text = staged }
            if let line = SayText.stagedRefusal { Task { refused = line } } // after the text's own onChange
            if SayText.stagedVoicesSheet { showsVoices = true }
        }
        #endif
        // A116: presented from outside the field's dark colour scheme, so the system's sheets look as usual.
        .sheet(isPresented: $isTakingPhotos) { camera.ignoresSafeArea() }
        .sheet(isPresented: $showsVoices) { SayVoicesSheet(model: model, chosen: $storedVoice) }
        .sheet(isPresented: $showsCredits) { CreditsSheet(model: model) }
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
    /// Ke72: the card has only the field and the row of buttons. No heading and no character count: the placeholder
    /// says what the field is for, and the cost stands by the button.
    @ViewBuilder
    private var writingCard: some View {
        HStack(alignment: .top, spacing: 8) { // the empty field keeps three rows: the mark stands at the first
            Text(verbatim: "›").foregroundStyle(SayText.accent).accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(typeSize.isAccessibilitySize ? "Skriv här" : "Skriv eller klistra in det du vill höra").foregroundStyle(SayText.ink.opacity(0.45)),
                      axis: .vertical)
                // A132 (D215.4): at most 5 rows, then it scrolls inside; 3 rows when it is not being written in.
                .lineLimit(focused ? (typeSize.isAccessibilitySize ? 2...5 : 3...5) : (typeSize.isAccessibilitySize ? 2...3 : 3...3))
                .focused($focused)
                .tint(SayText.accent)
                .accessibilityLabel("Säg i AirPods, textfält")
        }
        .font(.body.monospaced())
        .dynamicTypeSize(...DynamicTypeSize.accessibility3) // the field stays a field on a small screen
        // Ke72 §2: without focus the three rows fade downwards, so a longer text is seen to go on.
        .mask {
            if focused || isEmpty {
                Rectangle()
            } else {
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.62),
                                       .init(color: .black.opacity(0.25), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        if isReadingMaterial || materialNote != nil {
            HStack(spacing: 8) {
                if isReadingMaterial { ProgressView().controlSize(.small) }
                Text(verbatim: isReadingMaterial ? "Läser materialet …" : materialNote ?? "")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        if !isEmpty { styleRow }
        if !hasPlayed { // D215.2: said until Spela has been pressed once, then never
            Text(verbatim: SayText.lockLine)
                .font(.footnote)
                .opacity(0.7)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .fixedSize(horizontal: false, vertical: true)
        }
        costRow
        controls
    }

    /// A136 (D220, Kelly Ke75 §1): everything about how it sounds on one row, only when the field has text: the voice
    /// as a capsule (when the server has voices to choose) and the style as a free line. With the largest text the
    /// two stand on a row each.
    @ViewBuilder
    private var styleRow: some View {
        Rectangle().fill(SayText.ink.opacity(0.14)).frame(height: 0.5).accessibilityHidden(true)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            if !model.sayVoices.isEmpty {
                Button {
                    focused = false
                    styleFocused = false
                    showsVoices = true
                } label: {
                    HStack(spacing: 4) {
                        Text(verbatim: voice?.name ?? SayText.voiceCapsule).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Röst, \(voice?.name ?? "EarMinds egen")")
                .smallSayControl()
            }
            TextField("", text: $style, prompt: Text(verbatim: SayText.stylePrompt).foregroundStyle(SayText.ink.opacity(0.45)))
                .font(.subheadline)
                .focused($styleFocused)
                .tint(SayText.accent)
                .submitLabel(.done)
                .onChange(of: style) { _, new in
                    if new.count > SaidText.maxStyleChars { style = String(new.prefix(SaidText.maxStyleChars)) }
                }
                .accessibilityLabel(SayText.stylePrompt)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .toolbar {
                    // Ke75 §2: four suggestions above the keyboard; a tap writes the word.
                    if styleFocused {
                        ToolbarItemGroup(placement: .keyboard) {
                            ForEach(SaySound.suggestions, id: \.self) { word in
                                Button(word) { style = SaySound.adding(word, to: style) }
                            }
                            Spacer()
                        }
                    }
                }
        }
        #if DEBUG
        .onAppear { if let staged = SayText.stagedStyle, style.isEmpty { style = staged } }
        #endif
    }

    /// Ke72: the cost as a short line just above the main button; the server's own line when it refused (D212).
    @ViewBuilder
    private var costRow: some View {
        if let refused, !isEmpty {
            Text(verbatim: refused)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
            // A134 (D218): the server said the credits do not cover it; the packs are one tap away.
            if model.shop != nil, tooMany || refused.contains("krediter") {
                Button(ShopText.refill) { showsCredits = true }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(SayText.accent)
                    .frame(minHeight: 32)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
        } else if readingAloudOff {
            Text(verbatim: CloudDrillAudio.unavailableLine).font(.footnote).opacity(0.7).fixedSize(horizontal: false, vertical: true)
        } else if let credits {
            let short = credits.cost > credits.left
            let line = SayText.costLine(cost: credits.cost, left: credits.left, subscription: model.quota?.subscription)
            Group {
                if short, model.shop != nil {
                    // A134 (Ke73 §2): "120 krediter · du har 88 · Fyll på"; the last words open the packs.
                    Button {
                        showsCredits = true
                    } label: {
                        // Kelly (review of A134): one text that flows, so "Fyll på" breaks like any word.
                        Text(SayText.refillLine(line))
                            .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(line). \(ShopText.refill)")
                } else {
                    Text(verbatim: line)
                }
            }
            .font(short ? .footnote.weight(.semibold) : .footnote)
            .monospacedDigit()
            .opacity(short ? 1 : 0.7)
            .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else if !isEmpty, model.quota?.isCredits != true {
            // A server that still counts questions.
            Text(verbatim: SayText.costLine(counts: counts, left: sameAsMade == nil ? model.quota?.left : nil, readingAloudOff: false))
                .font(.footnote)
                .opacity(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Ke72: +, how long, tempo and the main button in one row; with the largest text the main button is a row of its
    /// own in full width. Nothing is cut with "…".
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                addMenu
                howLongMenu
                tempoMenu
                Spacer(minLength: 8)
                mainButton(wide: false)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    addMenu
                    howLongMenu
                    tempoMenu
                }
                mainButton(wide: true)
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

    /// Ke72: the timer symbol without words; the main button says the time. The menu's heading is "Spela i".
    private var howLongMenu: some View {
        Menu {
            Picker("Spela i", selection: Binding(get: { minutes }, set: { storedMinutes = $0 })) {
                ForEach(SayText.repeats, id: \.self) { Text(verbatim: SayText.howLong($0)).tag($0) }
            }
        } label: {
            Image(systemName: "timer")
        }
        .accessibilityLabel("Hur länge, \(minutes == 60 ? "1 timme" : "\(minutes) minuter")")
        .smallSayControl()
    }

    private var tempoMenu: some View {
        // A136 (D220.1, Ke75 §3): "Skriv i takt" stands first; it is a tempo of its own (0,85× and pauses).
        let choice = Binding<Double>(get: { inPace ? Self.paceTag : tempo },
                                     set: { new in
                                         inPace = new == Self.paceTag
                                         if new != Self.paceTag { tempo = new }
                                     })
        return Menu {
            Picker("Tempo", selection: choice) {
                Text(verbatim: SayText.paceTitle).tag(Self.paceTag)
                ForEach(SayText.tempos, id: \.self) { Text(verbatim: SayText.tempo($0)).tag($0) }
            }
        } label: {
            Text(verbatim: inPace ? SayText.paceCapsule : SayText.tempo(tempo)).monospacedDigit().lineLimit(1).fixedSize()
        }
        .accessibilityLabel(inPace ? "Tempo, \(SayText.paceTitle)" : "Tempo, \(SayText.tempo(tempo))")
        .smallSayControl()
    }

    /// The menu's tag for "Skriv i takt" (not a tempo).
    private static let paceTag: Double = -1

    /// Ke72 (D215.1): the one button that says what happens: "Spela i 10 min", filled only when there is a text that
    /// can be played. With an empty field and text on the clipboard it is "Klistra in" (toned down).
    @ViewBuilder
    private func mainButton(wide: Bool) -> some View {
        if isEmpty, clipboardHasText {
            Button {
                if let pasted = UIPasteboard.general.string { text = String(pasted.prefix(SaidText.maxChars)) }
            } label: {
                Text("Klistra in").font(.subheadline.weight(.semibold)).lineLimit(1)
                    .fixedSize(horizontal: !wide, vertical: false)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: wide ? .infinity : nil)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(SayText.accent)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } else {
            Button {
                play()
            } label: {
                HStack(spacing: 6) {
                    if isStarting { ProgressView().controlSize(.small) } else { Image(systemName: "play.fill").accessibilityHidden(true) }
                    // In a row of its own (the largest text) it may shrink; it must never be wider than the card.
                    Text(verbatim: canRetry ? "Försök igen" : SayText.playTitle(minutes)).lineLimit(1)
                        .fixedSize(horizontal: !wide, vertical: false)
                        .minimumScaleFactor(0.6)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: wide ? .infinity : nil)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(SayText.accent)
            .foregroundStyle(Color.black)
            .disabled(isEmpty || isStarting || tooMany)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1) // as the small buttons beside it
        }
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
        styleFocused = false
        hasPlayed = true
        isStarting = true
        let text = self.text
        let minutes: Int? = self.minutes // A124: it always goes round for the chosen time
        let sound = self.sound // A136: its voice and style
        let inPace = self.inPace
        refused = nil
        canRetry = false
        attempt += 1
        let mine = attempt
        Task {
            // A130: the model knows whether this text is already an exam (the same text never becomes two).
            let drill = await model.say(text, repeatMinutes: minutes, sound: sound, inPace: inPace)
            guard mine == attempt, isStarting else { return } // given up meanwhile: the line below stands
            if let drill {
                refused = model.sayRefusal(drill)
                if let refused { AccessibilityNotification.Announcement(refused).post() }
            }
            isStarting = false
        }
        Task {
            // A135 (D219.3, Aron's phone 20:24): no spinner without an end. After 10 s it is said that the sound could
            // not be fetched, and the button is Försök igen. Nothing starts to play by itself later.
            try? await Task.sleep(for: SayText.patience)
            guard mine == attempt, isStarting, !model.isSayingOnCard, !model.showsPlayer else { return }
            model.giveUpSay()
            isStarting = false
            canRetry = true
            refused = SayText.slowLine
            AccessibilityNotification.Announcement(SayText.slowLine).post()
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
