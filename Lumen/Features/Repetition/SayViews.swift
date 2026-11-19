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
    /// A148: the fields' placeholders. 0.45 was 3.8:1 on the card ("Contrast failed" in the audit); 0.6 is 6:1 and
    /// still clearly lighter than a written text.
    static let promptOpacity = 0.6

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
    /// A140: the voice the server chose from the style, for the screenshots (no server there).
    static var stagedPicked: (voiceID: String, reason: String?)?
    /// A135: the button is "Försök igen" (with a staged line), for the screenshots.
    static var stagedRetry = false
    /// A144: Spela still waits (the spinner), for the screenshots of the 8 s line.
    static var stagedStarting = false
    /// Toby (T36): the line on the playing card while the first sound is waited for, for the screenshots.
    static var stagedWaitNote: String?
    /// A150: the card goes through its states by itself, for the recording of how it moves.
    static var stagedMotion = false
    /// A150 (Kelly Ke83): the player pulls itself down, for the recording.
    static var stagedFold = false
    /// A153: the keyboard is up, with the big field ("text") or the style field ("style") in focus, for the
    /// screenshots; `stagedKeyboardNumbers` also writes where the button and the keyboard are under the card.
    static var stagedKeyboard: String?
    static var stagedKeyboardNumbers = false
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

    /// A144 (D225, after Toby's T50 and Kevin's times: saving and starting a new text takes 9–10 s today). While
    /// Spela waits for a new text: after 8 s it says that it takes longer than usual, which is not an error (the
    /// spinner goes on); after 25 s, or as soon as the phone knows it has no network, it gives up with the error line
    /// and Försök igen. Sound that is already on the phone plays at once and never comes here.
    static let slowAfter: Duration = .seconds(8)
    static let giveUpAfter: Duration = .seconds(25)
    static let slowServerLine = "Det tar längre tid än vanligt." // Kelly
    static let slowLine = "Ljudet kunde inte hämtas. Kolla nätet." // Kelly: the button says the rest
    static let failedLine = "Ljudet kunde inte hämtas." // the network is up: it is not blamed
    static func slowLine(online: Bool) -> String { online ? failedLine : slowLine }

    enum Wait: Equatable { case quiet, slow, gaveUp }

    /// What Spela shows after this long without an answer (or, with the answer, without any sound yet).
    static func wait(after elapsed: Duration, online: Bool, giveUpAfter limit: Duration = giveUpAfter) -> Wait {
        if !online || elapsed >= limit { return .gaveUp }
        return elapsed >= slowAfter ? .slow : .quiet
    }

    /// Toby (T36 after K100): the server now answers in a second or two and the card says "Gör ljudet …" before
    /// there is any sound, so the same clock goes on until the first sound. Making the sound of a long first part
    /// takes its time, and that is not an error: a second more per 100 characters, at most two minutes in all.
    static func giveUpAfter(waitingForChars chars: Int) -> Duration {
        giveUpAfter + .seconds(min(95, max(0, chars) / 100))
    }

    /// A136 (D220, Kelly Ke75): the words of the style row and of "Skriv i takt".
    static let stylePrompt = "Hur ska det låta?"
    static let paceTitle = "Skriv i takt"
    static let paceCapsule = "I takt"
    static let voiceCapsule = "Röst" // no voice chosen: the server's own
    static let inPaceKey = "say.inPace"
    static let voiceKey = "say.voiceID"
    static let mixKey = "say.mixVoices"
    // A140 (D223): mine, for Kelly to review.
    static let mixCapsule = "Blandat"

    /// A140 (K99, Kelly): why the server chose the voice in the capsule beside it: "Vald efter stilen · Lugn och tydlig."
    static func pickedLine(reason: String?) -> String {
        let why = (reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return why.isEmpty ? "Vald efter stilen." : "Vald efter stilen · \(why)"
    }

    /// A140 (D223): "Spelar i AirPods · Astrid" while it plays.
    static func playingLine(voice: String?) -> String { voice.map { "Spelar i AirPods · \($0)" } ?? "Spelar i AirPods" }

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
    /// Kelly (stil-och-roster.md, A136 point 2): the voice's name only when it is not the default voice.
    static func soundMark(_ drill: Drill, voices: [SayVoice], defaultName: String? = nil) -> String? {
        if let style = Drill.cleanStyle(drill.style), let word = style.split(whereSeparator: { $0 == " " || $0 == "," }).first {
            return String(word)
        }
        if drill.mixVoices == true { return mixCapsule } // A140
        guard let id = drill.voiceID, let name = voices.first(where: { $0.voice_id == id })?.name, name != defaultName else { return nil }
        return name
    }

    // MARK: A148 (Kelly Ke79): what VoiceOver says

    /// "Kostar 120 krediter", "Kostar 120 krediter, du har 88". "Ingår" and "Veckans tak är nått" stand as they are.
    static func spokenCost(_ line: String) -> String {
        let spoken = line.replacingOccurrences(of: " · ", with: ", ")
        return spoken.first?.isNumber == true ? "Kostar \(spoken)" : spoken
    }

    /// "Tempo, normal" for 1,0×; "Tempo, 1,25 gånger" else.
    static func spokenTempo(_ value: Double) -> String {
        value == 1 ? "Tempo, normal" : "Tempo, \(tempo(value).replacingOccurrences(of: "×", with: " gånger"))"
    }

    /// A capsule in Senaste: the whole text (the screen cuts it with "…"), then its style or voice.
    static func spokenCapsule(_ text: String, mark: String?) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        let whole = flat.count > 300 ? String(flat.prefix(300)) : flat
        return mark.map { "\(whole), \($0)" } ?? whole
    }

    /// The card while it plays, as one: "Spelar i AirPods med Astrid, 7 minuter kvar". The minutes are the ones on
    /// the clock (7:07 is "7 minuter kvar", Kelly Ke79 round 5), and the last minute is "under en minut kvar".
    static func spokenPlaying(voice: String?, secondsLeft: Int, paused: Bool) -> String {
        let minutes = max(0, secondsLeft) / 60
        let left = minutes == 0 ? "under en minut kvar" : minutes == 1 ? "1 minut kvar" : "\(minutes) minuter kvar"
        return "Spelar i AirPods" + (voice.map { " med \($0)" } ?? "") + ", \(left)" + (paused ? ", pausad" : "")
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
    /// Toby (T36): said on the playing card while the first sound is still waited for (D225: after 8 s).
    @State private var waitNote: String?
    /// K92: the server's answer for the text it was asked about.
    @State private var asked: (text: String, sound: SaySound, cost: Int, left: Int?, voiceID: String?, reason: String?)?
    /// A140 (D223): "Blanda röster", off by default, kept to the next time.
    @AppStorage(SayText.mixKey) private var mixVoices = false
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
    /// A153 (D238): the card's own Spela is behind the keyboard, so Spela stands in the row above the keyboard.
    @State private var playHidden = false
    @State private var keyboard = SayKeyboard.Geometry()
    /// A153: how wide the card is; a narrow screen has room for three of the style's suggestions beside Spela.
    @State private var cardWidth: CGFloat = 0
    #if DEBUG
    @State private var keyboardNumbers = ""
    #endif
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SayMotion.reduces(systemReduceMotion) }

    /// A150 (D231): what decides how the card looks. When any of it changes, the card moves to its new shape with a
    /// spring that does not overshoot (a cross-fade with Reduce Motion) instead of jumping there. Typing does not
    /// animate anything: only the first and the last character change the shape.
    private struct CardLook: Hashable {
        var plays: Bool
        var isEmpty: Bool
        var cost: Int?
        var left: Int?
        var refused: String?
        var waitNote: String?
        var picked: String?
        var materialNote: String?
        var hasPlayed: Bool
        var canRetry: Bool
        var isStarting: Bool
        var isReading: Bool
        var hasVoices: Bool
        var waitsForSound: Bool
    }

    private var shape: CardLook {
        CardLook(plays: playing != nil, isEmpty: isEmpty, cost: credits?.cost, left: credits?.left, refused: refused,
              waitNote: waitNote, picked: picked?.voiceID, materialNote: materialNote, hasPlayed: hasPlayed,
              canRetry: canRetry, isStarting: isStarting, isReading: isReadingMaterial, hasVoices: !model.sayVoices.isEmpty,
                 waitsForSound: playing.map { $0.reader.phase == .waitingForAudio && !$0.reader.hasSounded } ?? false)
    }

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
    private var sound: SaySound { SaySound(voiceID: voice?.voice_id, style: style, mix: mixVoices && !model.sayVoices.isEmpty) }
    /// A140 (K99): with a style and no chosen voice the server chooses one. What it chose for this text: from its
    /// answer about the cost, or from the text as it was played before.
    private var picked: (voiceID: String, reason: String?)? {
        guard sound.serverPicksVoice else { return nil }
        #if DEBUG
        if let staged = SayText.stagedPicked { return staged }
        #endif
        if let same = sameAsMade, same.voicePicked == true, let id = same.voiceID { return (id, same.voiceReason) }
        if let asked, asked.text == text, asked.sound == sound, let id = asked.voiceID { return (id, asked.reason) }
        return nil
    }
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
        asked = (text, sound, answer.cost, answer.remaining, answer.voice_id, answer.voice_reason)
    }

    /// What the cost is asked about: asked again when the text, the style or the voice changes.
    private struct Asked: Hashable {
        var text: String
        var sound: SaySound
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if DEBUG
            if SayText.stagedKeyboardNumbers { Text(verbatim: keyboardNumbers).font(.caption2.monospaced()) }
            #endif
            card
            if playing == nil { recents.transition(SayMotion.appear) }
        }
        .animation(SayMotion.change(reduceMotion), value: playing != nil)
        // A150: the phone answers what the eye may miss: a no from the server or a Spela that gave up is felt once.
        .sensoryFeedback(trigger: refused) { (_: String?, new: String?) -> SensoryFeedback? in
            guard let new, new != SayText.slowServerLine else { return nil }
            return .error
        }
        .task(id: Asked(text: text, sound: sound)) { await askCost(for: text, sound: sound) } // cancelled and asked again
        .task { await model.loadSayVoices() }
        #if DEBUG
        .task { if SayText.stagedMotion { await runMotionDemo() } }
        #endif
        .onChange(of: sound) { refused = nil; canRetry = false }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
        // The row above the keyboard. It is set here, outside the card: inside it the row took the card's own
        // look (always dark, light ink, monospaced), and its words could not be read on the row's glass when the
        // glass changed with what lay behind it (seen in the pictures of 2026-11-19).
        .toolbar {
            if focused {
                // A153 (D238, Toby T53): the field has many rows, so return makes a new row and nothing put the
                // keyboard down. "Klar" does, where the system has it; and Spela stands beside it when the
                // card's own Spela is behind the keyboard (the largest text, a small screen).
                ToolbarItemGroup(placement: .keyboard) {
                    if playStandsAboveKeyboard { keyboardPlay(compact: false) }
                    Spacer()
                    Button("Klar") { focused = false }.fontWeight(.semibold)
                }
            } else if styleFocused {
                // Ke75 §2: four suggestions above the keyboard; a tap writes the word.
                ToolbarItemGroup(placement: .keyboard) {
                    // A153 (Kelly): Spela stands where it stands for the big field, first in the row.
                    if playStandsAboveKeyboard { keyboardPlay(compact: true) }
                    ForEach(styleSuggestions, id: \.self) { word in
                        Button(word) { style = SaySound.adding(word, to: style) }
                    }
                    Spacer()
                }
            }
        }
        // A153: where the keyboard begins, as the system says it before it moves.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboard.keyboardTop = SayKeyboard.top(from: note)
            lookAtPlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboard.keyboardTop = nil
            lookAtPlay()
        }
        #if DEBUG
        .task {
            guard let field = SayText.stagedKeyboard else { return }
            try? await Task.sleep(for: .seconds(1.5))
            if field == "style" { styleFocused = true } else { focused = true }
        }
        #endif
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
            // A text that has played and stopped leaves no press waiting: Spela can be pressed again, whatever became
            // of the answer that press waited for.
            if !plays, isStarting {
                Log.repetition.info("Say: the card stopped while a press still waited; Spela is free again")
                isStarting = false
            }
        }
        // Toby (T36 44312213280, without a network): the press on Spela did not reach `play()` at all (the keyboard
        // stayed up and Senaste got no new text), so the button could not be pressed. Why is in the log from now on.
        .onChange(of: blocked) { _, why in
            let line = why.map { "cannot be pressed (" + $0 + ")" } ?? "can be pressed"
            Log.repetition.info("Say: Spela \(line, privacy: .public)")
        }
    }

    /// A153: the answer changes the row above the keyboard; the numbers behind it change all the time.
    private func lookAtPlay() {
        let hidden = keyboard.hidesPlay
        if hidden != playHidden { playHidden = hidden }
        #if DEBUG
        if SayText.stagedKeyboardNumbers {
            let button = keyboard.button.map { "\(Int($0.lowerBound))–\(Int($0.upperBound))" } ?? "-"
            keyboardNumbers = "knapp \(button) · tangentbord \(keyboard.keyboardTop.map { String(Int($0)) } ?? "-") · \(hidden ? "skymd" : "syns")"
        }
        #endif
    }

    /// A153 (D238): Spela in the row above the keyboard, when the card's own is behind the keyboard. The same
    /// button: the same words, the same press. In the style row there is room for the symbol only.
    @ViewBuilder
    private func keyboardPlay(compact: Bool) -> some View {
        let title = canRetry ? "Försök igen" : SayText.playTitle(minutes)
        let narrow = SayKeyboard.isNarrow(cardWidth: cardWidth, largeText: typeSize.isAccessibilitySize)
        let cost = compact ? nil : keyboardCost
        if creditsShort, !compact {
            // Kelly (2026-11-19): the credits do not cover the text, so the button is the way to more of them.
            // (In the style row there is no room for the words: Spela stands there greyed out, see below.)
            Button {
                focused = false
                styleFocused = false
                showsCredits = true
            } label: {
                HStack(spacing: 8) {
                    Text(verbatim: ShopText.refill).font(.subheadline.weight(.semibold))
                    if let cost { keyboardCostWords(cost, narrow: narrow) }
                }
                .fixedSize()
                .foregroundStyle(Color.black)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(SayText.accent)
            .accessibilityLabel(cost.map { "\(SayText.spokenCost($0)). \(ShopText.refill)" } ?? ShopText.refill)
        } else {
            Button {
                play()
            } label: {
                // Black on the accent, as on the card (the bar's own white is too weak on this light blue).
                HStack(spacing: 8) {
                    Image(systemName: canRetry ? "arrow.clockwise" : "play.fill")
                    if !compact {
                        Text(verbatim: SayKeyboard.playWords(title, narrow: narrow, withCost: cost != nil && !canRetry))
                            .font(.subheadline.weight(.semibold))
                        // Kelly (2026-11-19): at the largest text the card's cost is behind the keyboard, so it is
                        // said here, in the button it is the price of.
                        if let cost, !canRetry { keyboardCostWords(cost, narrow: narrow) }
                    }
                }
                .fixedSize()
                .foregroundStyle(tooMany ? Color.primary : Color.black)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(SayText.accent)
            .disabled(isStarting || tooMany)
            // The whole of it, also when the row has room for "Spela" or the symbol only; then the cost. Kelly
            // (2026-11-19): greyed out for want of credits it says so, so that the press does not end in a no.
            .accessibilityLabel(tooMany && model.quota?.isCredits == true ? "\(title), krediterna räcker inte"
                                : cost.map { "\(title). \(SayText.spokenCost($0))" } ?? title)
        }
    }

    /// The cost inside the button above the keyboard: smaller and lighter than the button's own words.
    private func keyboardCostWords(_ cost: String, narrow: Bool) -> some View {
        Text(verbatim: SayKeyboard.costWords(cost, narrow: narrow))
            .font(.footnote)
            .monospacedDigit()
            .opacity(0.75)
    }

    /// The credits do not cover this text, and there is a shop to get more from.
    private var creditsShort: Bool { model.shop != nil && (credits.map { $0.cost > $0.left } ?? false) }

    /// A153: the cost as the card says it ("120 krediter", "120 krediter · du har 88", "Ingår"), for the row above
    /// the keyboard. Nil while the server has not said it, and for an account without a limit.
    private var keyboardCost: String? {
        credits.map { SayText.costLine(cost: $0.cost, left: $0.left, subscription: model.quota?.subscription) }
    }

    /// A153: Spela stands in the row above the keyboard: a field of the card has the keyboard, there is a text,
    /// and the card's own Spela is behind the keyboard. The card's own then steps aside (one Spela at a time).
    private var playStandsAboveKeyboard: Bool { playHidden && !isEmpty && (focused || styleFocused) }

    /// A153: the style's suggestions that have room. Beside Spela on a narrow screen the last one gives way.
    private var styleSuggestions: [String] {
        let all = SaySound.suggestions
        return playStandsAboveKeyboard && cardWidth < SayKeyboard.widthForAllSuggestions ? Array(all.dropLast()) : all
    }

    /// Why Spela cannot be pressed although there is a text; nil when it can (or the field is empty).
    private var blocked: String? {
        isEmpty ? nil : isStarting ? "an earlier press is still waiting" : tooMany ? "the text costs more than is left" : nil
    }

    private func lookAtClipboard() { clipboardHasText = UIPasteboard.general.hasStrings }

    #if DEBUG
    /// A150 (D231): the card's changes, one after another, for the Simulator recording that Kelly reviews: a text
    /// arrives, the cost comes and changes, Spela waits, the card plays, and Spela gives up. No server, no sound.
    private func runMotionDemo() async {
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        await pause(2.5)
        text = "Fotosyntes: koldioxid + vatten + ljus blir socker och syre."
        await pause(1.5)
        asked = (text, sound, 120, nil, nil, nil)
        await pause(1.5)
        asked = (text, sound, 1251, nil, nil, nil)
        await pause(1.5)
        isStarting = true
        await pause(1)
        refused = SayText.slowServerLine
        await pause(1.5)
        isStarting = false
        refused = nil
        RepetitionDemo.stagePlaying(model, text: text, waiting: true)
        await pause(1.5)
        waitNote = SayText.slowServerLine
        await pause(1.5)
        waitNote = nil
        RepetitionDemo.stagePlaying(model, text: text, waiting: false)
        await pause(2)
        model.end()
        refused = SayText.failedLine
        canRetry = true
    }
    #endif

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
                    Text("Senaste").font(.footnote).foregroundStyle(LumenColor.secondaryText)
                    ForEach(said) { drill in
                        Button {
                            text = String(drill.saidText.prefix(SaidText.maxChars))
                            // A136 (Ke75 §7.3): one tap puts back all three: the text, its voice and its style.
                            style = drill.style ?? ""
                            storedVoice = drill.voicePicked == true ? "" : drill.voiceID ?? "" // a voice the server chose is chosen again
                            mixVoices = drill.mixVoices == true
                        } label: {
                            // Kelly (review of A136): the text is cut first; what tells two sounds apart stays.
                            HStack(spacing: 4) {
                                Text(verbatim: SayText.capsule(drill.saidText))
                                if let mark = SayText.soundMark(drill, voices: model.sayVoices, defaultName: model.sayDefaultVoice) {
                                    Text(verbatim: "· \(mark)").foregroundStyle(LumenColor.secondaryText)
                                }
                            }
                            .font(.footnote)
                            .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.primary)
                        // Ke79: the whole text and its style or voice, not the cut one with "…".
                        .accessibilityLabel(SayText.spokenCapsule(drill.saidText, mark: SayText.soundMark(drill, voices: model.sayVoices, defaultName: model.sayDefaultVoice)))
                        .accessibilityHint("Lägger tillbaka texten i fältet")
                        .contextMenu {
                            Button("Ta bort", systemImage: "trash", role: .destructive) { model.delete(drill) }
                        }
                        .transition(SayMotion.appear)
                    }
                }
                .animation(SayMotion.change(reduceMotion), value: said.map(\.id)) // A150: a removed capsule fades, the rest close the gap
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
        // Ke79: every 20 s, so the minutes VoiceOver says are the ones on the clock below.
        TimelineView(.periodic(from: .now, by: 20)) { _ in
            HStack(spacing: 6) {
                Circle().fill(SayText.accent).frame(width: 8, height: 8).accessibilityHidden(true)
                // A140 (D223): which voice speaks now (the part's own when they are mixed).
                Text(verbatim: waiting ? "Gör ljudet …" : SayText.playingLine(voice: model.speakingVoice(drill, part: reader.position?.part)))
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(SayText.accent)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .accessibilityElement(children: .ignore)
            // Ke79: the row as one: "Spelar i AirPods med Astrid, 7 minuter kvar". The clock below is for the eye.
            .accessibilityLabel(waiting ? "Gör ljudet" : SayText.spokenPlaying(voice: model.speakingVoice(drill, part: reader.position?.part),
                                                                               secondsLeft: Int(model.session.repeatSecondsLeft), paused: reader.isPaused))
            .accessibilityAddTraits(.isStaticText) // Ke79 round 5: it is read, not pressed
        }
        if waiting, !reader.hasSounded, let waitNote {
            Text(verbatim: waitNote)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .transition(SayMotion.appear)
        }
        Button {
            Log.repetition.info("Say: the text on the card pressed (the player opens)")
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
        .buttonStyle(.pressFeedback) // A150: answers the touch on the way down
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityHint("Öppnar spelaren med meningarna")
        HStack(spacing: 12) {
            if waiting, !reader.hasSounded {
                // Kelly Ke83: nothing is heard yet, so there is nothing to pause. A small spinner stands where the
                // pause button will be; Stoppa is there all the time.
                ProgressView()
                    .controlSize(.small)
                    .tint(SayText.ink)
                    .frame(width: 44, height: 44)
                    .background(SayText.accent.opacity(0.25), in: Circle())
                    .accessibilityHidden(true) // the row above says "Gör ljudet"
                    .transition(SayMotion.appear)
            } else {
            Button {
                model.session.press(.long)
            } label: {
                Image(systemName: reader.isPaused ? "play.fill" : "pause.fill")
                    .contentTransition(.symbolEffect(.replace)) // A150: the symbol changes in place
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(width: 44, height: 44)
                    .background(SayText.accent, in: Circle())
            }
            .buttonStyle(.pressFeedbackRound)
            .accessibilityLabel(reader.isPaused ? "Fortsätt" : "Pausa")
            .transition(SayMotion.appear)
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(verbatim: "\(SayText.clock(model.session.repeatSecondsLeft)) kvar" + (reader.isPaused ? " · pausad" : ""))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityHidden(true) // Ke79: said in the row above, in minutes
            }
            Spacer(minLength: 8)
            Button {
                model.end()
            } label: {
                Text("Stoppa").font(.body).lineLimit(1).fixedSize()
                    .frame(minHeight: 44) // A150: a whole finger's height to hit
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressFeedback)
            .foregroundStyle(SayText.accent)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            // A150 (D231): the two faces of the card change by fading where they stand, and the card takes its new
            // height with a spring that does not overshoot.
            if let playing {
                Group { playingCard(playing.reader, playing.drill) }.transition(SayMotion.swap(reduceMotion))
            } else {
                Group { writingCard }.transition(SayMotion.swap(reduceMotion))
            }
        }
        // The card grows and shrinks from its top edge, and what is on its way in or out stays inside it.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(SayMotion.change(reduceMotion), value: shape)
        .onChange(of: text) { refused = nil; canRetry = false }
        .padding(16)
        .foregroundStyle(SayText.ink)
        .background(scheme == .dark ? SayText.fieldDark : SayText.field, in: RoundedRectangle(cornerRadius: 16))
        // Kelly S3: in dark mode the field is almost the colour of the screen, so a hairline shows where it ends.
        .overlay { if scheme == .dark { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5) } }
        .clipShape(RoundedRectangle(cornerRadius: 16)) // A150: nothing shows outside the card while it changes
        .environment(\.colorScheme, .dark) // the system's controls are dark inside the field, in light mode too
        #if DEBUG
        .onAppear {
            if let staged = SayText.stagedForScreenshots, text.isEmpty { text = staged }
            if let line = SayText.stagedRefusal { // after the text's own onChange
                Task {
                    refused = line
                    canRetry = SayText.stagedRetry
                    if SayText.stagedStarting { isStarting = true }
                }
            }
            if SayText.stagedVoicesSheet { showsVoices = true }
            if let note = SayText.stagedWaitNote { waitNote = note }
        }
        #endif
        // A116: presented from outside the field's dark colour scheme, so the system's sheets look as usual.
        .sheet(isPresented: $isTakingPhotos) { camera.ignoresSafeArea() }
        .sheet(isPresented: $showsVoices) { SayVoicesSheet(model: model, chosen: $storedVoice, mix: $mixVoices) }
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
            TextField("", text: $text, prompt: Text(typeSize.isAccessibilitySize ? "Skriv här" : "Skriv eller klistra in det du vill höra").foregroundStyle(SayText.ink.opacity(SayText.promptOpacity)),
                      axis: .vertical)
                // A132 (D215.4): at most 5 rows, then it scrolls inside; 3 rows when it is not being written in.
                .lineLimit(focused ? (typeSize.isAccessibilitySize ? 2...5 : 3...5) : (typeSize.isAccessibilitySize ? 2...3 : 3...3))
                .focused($focused)
                .tint(SayText.accent)
                .accessibilityLabel("Säg i AirPods") // Ke79: VoiceOver says "textfält" itself
        }
        .font(.body.monospaced())
        .dynamicTypeSize(...DynamicTypeSize.accessibility3) // the field stays a field on a small screen
        // Ke72 §2: without focus the three rows fade downwards, so a longer text is seen to go on.
        .mask {
            // A150: one gradient whose last stop fades, so the change with the focus is a fade and not a jump.
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.62),
                                   .init(color: .black.opacity(focused || isEmpty ? 1 : 0.25), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .animation(SayMotion.change(reduceMotion), value: focused)
        if isReadingMaterial || materialNote != nil {
            HStack(spacing: 8) {
                if isReadingMaterial { ProgressView().controlSize(.small) }
                Text(verbatim: isReadingMaterial ? "Läser materialet …" : materialNote ?? "")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        if !isEmpty { Group { styleRow }.transition(SayMotion.appear) }
        if !hasPlayed { // D215.2: said until Spela has been pressed once, then never
            Text(verbatim: SayText.lockLine)
                .font(.footnote)
                .opacity(0.7)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .fixedSize(horizontal: false, vertical: true)
                .transition(SayMotion.appear)
        }
        Group { costRow }.transition(SayMotion.appear)
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
                        Text(verbatim: voiceLabel).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Röst, \(voiceLabel)")
                .smallSayControl()
            }
            TextField("", text: $style, prompt: Text(verbatim: SayText.stylePrompt).foregroundStyle(SayText.ink.opacity(SayText.promptOpacity)))
                .font(.subheadline)
                .focused($styleFocused)
                .tint(SayText.accent)
                .submitLabel(.done)
                .onChange(of: style) { _, new in
                    if new.count > SaidText.maxStyleChars { style = String(new.prefix(SaidText.maxStyleChars)) }
                }
                .accessibilityLabel(SayText.stylePrompt)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                // A148: a finger's size. The field itself stays one line high (the audit still measures that line), so
                // the 44 points around it take the tap and put the cursor in the field.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture { styleFocused = true }
        }
        #if DEBUG
        .onAppear { if let staged = SayText.stagedStyle, style.isEmpty { style = staged } }
        #endif
        // A140 (K99): the voice the server chose for this style, and why. The capsule changes it before Spela.
        if let picked, model.sayVoiceName(picked.voiceID) != nil {
            Text(verbatim: SayText.pickedLine(reason: picked.reason))
                .font(.footnote)
                .opacity(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }

    /// The voice capsule: "Blandat", the chosen voice, the one the server chose from the style, else the server's own
    /// voice by name (Kelly), else "Röst".
    private var voiceLabel: String {
        if sound.mix { return SayText.mixCapsule }
        return voice?.name ?? picked.flatMap { model.sayVoiceName($0.voiceID) } ?? model.sayDefaultVoice ?? SayText.voiceCapsule
    }

    /// Ke72: the cost as a short line just above the main button; the server's own line when it refused (D212).
    @ViewBuilder
    private var costRow: some View {
        // Kelly (kop.md §2): after the server's no (402) the row is the same as before it, "120 krediter · du har 88 ·
        // Fyll på", when the credits are known; the sheet that Fyll på opens says when new credits come.
        if let refused, !isEmpty, !creditsShort {
            Text(verbatim: refused)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
            // A134 (D218): the server said the credits do not cover it; the packs are one tap away.
            if model.shop != nil, tooMany || refused.contains("krediter") {
                Button(ShopText.refill) { showsCredits = true }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.pressFeedback)
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
                            .frame(minHeight: 44) // A148: a finger's size (the audit: "Hit area is too small")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressFeedback) // A150: answers the touch on the way down
                    .accessibilityLabel("\(SayText.spokenCost(line)). \(ShopText.refill)") // Ke79
                } else {
                    // A150: the number rolls in place when the server's answer comes or the text changes.
                    Text(verbatim: line).contentTransition(SayMotion.number(reduceMotion))
                        .accessibilityLabel(SayText.spokenCost(line)) // Ke79: "Kostar 120 krediter"
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
            // A153 (Kelly): in one row they are all behind the keyboard's row when Spela is; the whole row steps
            // aside, so nothing of it shows through the row's glass.
            .opacity(playStandsAboveKeyboard ? 0 : 1)
            .accessibilityHidden(playStandsAboveKeyboard)
            .animation(SayMotion.change(reduceMotion), value: playStandsAboveKeyboard)
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
        .accessibilityLabel(inPace ? "Tempo, \(SayText.paceTitle)" : SayText.spokenTempo(tempo)) // Ke79
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
                    // Kelly: Försök igen must not look as if it plays at once.
                    if isStarting { ProgressView().controlSize(.small) } else { Image(systemName: canRetry ? "arrow.clockwise" : "play.fill").contentTransition(.symbolEffect(.replace)).accessibilityHidden(true) }
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
            // A148: a button that cannot be pressed still says what it is. Black on the dimmed fill was unreadable
            // ("Contrast failed" in the audit); the card's own text colour is 9:1 on it.
            .foregroundStyle(isEmpty || isStarting || tooMany ? SayText.ink.opacity(0.85) : Color.black)
            .disabled(isEmpty || isStarting || tooMany)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1) // as the small buttons beside it
            // A153: while Spela stands above the keyboard this one is behind the keyboard, wholly or half. It
            // steps aside (it keeps its place), so there is one Spela to see and one for VoiceOver to find.
            .opacity(playStandsAboveKeyboard ? 0 : 1)
            .accessibilityHidden(playStandsAboveKeyboard)
            .animation(SayMotion.change(reduceMotion), value: playStandsAboveKeyboard)
            // A153: where this button is on the screen, to know when the keyboard is in front of it.
            .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                let frame = proxy.frame(in: .global)
                return min(frame.minY, frame.maxY)...max(frame.minY, frame.maxY)
            } action: { span in
                keyboard.button = span
                lookAtPlay()
            }
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
        let picked = self.picked // A140: the voice the server chose, as it was shown
        refused = nil
        canRetry = false
        attempt += 1
        let mine = attempt
        // Toby (T36, 2026-11-18 18:00: without a network a new text said nothing at all): what Spela did is in the
        // log, one line per step, so the next run shows where it stopped.
        Log.repetition.info("Say: Spela pressed (attempt \(mine, privacy: .public), online \(NetworkStatus.shared.isOnline, privacy: .public))")
        Task {
            // A130: the model knows whether this text is already an exam (the same text never becomes two).
            let drill = await model.say(text, repeatMinutes: minutes, sound: sound, inPace: inPace, picked: picked)
            guard mine == attempt, isStarting else { // given up meanwhile: the line below stands
                Log.repetition.info("Say: answered after it was given up (attempt \(mine, privacy: .public))")
                return
            }
            if let drill {
                refused = model.sayRefusal(drill)
                if let refused { AccessibilityNotification.Announcement(refused).post() }
            }
            // Never silent: a Spela that neither plays nor has a line says the plain one.
            if refused == nil, !model.isSayingOnCard, !model.showsPlayer {
                refused = SayText.slowLine(online: NetworkStatus.shared.isOnline)
                canRetry = true
            }
            Log.repetition.info("Say: answered (plays \(model.isSayingOnCard || model.showsPlayer, privacy: .public), line \(refused ?? "-", privacy: .public))")
            isStarting = false
        }
        Task {
            // A135 (D219.3, Aron's phone 20:24): no spinner without an end. A144 (D225): looked at once a second.
            // After 8 s the line says that it takes longer than usual and the spinner goes on; after 25 s, or without
            // a network, it gives up: the error line and Försök igen. Nothing starts to play by itself later.
            // Toby (T36 after K100): the server answers fast now, and the card turns to "Gör ljudet …" before there
            // is any sound. The same clock goes on there until the first sound is heard; a text that plays is left
            // alone, and so is the player with the text on the screen.
            let started = ContinuousClock.now
            let firstPart = SaidText.parts(text).first?.count ?? 0
            var saidSlow = false
            waitNote = nil
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard mine == attempt else { waitNote = nil; return }
                // The text plays (or is read on the screen): nothing is waited for any more, so the button must not
                // stay "starting" after this, even if the call that started it has not come back.
                guard !model.showsPlayer else { waitNote = nil; isStarting = false; return }
                let onCard = model.isSayingOnCard
                if onCard {
                    guard let reader = model.session.reader, !reader.hasSounded else { waitNote = nil; isStarting = false; return }
                    if reader.isPaused { continue }
                } else if !isStarting {
                    return
                }
                let online = NetworkStatus.shared.isOnline
                let limit = onCard ? SayText.giveUpAfter(waitingForChars: firstPart) : SayText.giveUpAfter
                switch SayText.wait(after: ContinuousClock.now - started, online: online, giveUpAfter: limit) {
                case .quiet:
                    continue
                case .slow:
                    if onCard { waitNote = SayText.slowServerLine } else { refused = SayText.slowServerLine }
                    if !saidSlow {
                        saidSlow = true
                        AccessibilityNotification.Announcement(SayText.slowServerLine).post()
                    }
                case .gaveUp:
                    Log.repetition.info("Say: gave up (on the card \(onCard, privacy: .public), online \(online, privacy: .public))")
                    model.giveUpSay()
                    if onCard { model.end() } // back to the field; the sound goes on being made for Försök igen
                    waitNote = nil
                    isStarting = false
                    canRetry = true
                    let line = SayText.slowLine(online: online)
                    refused = line
                    AccessibilityNotification.Announcement(line).post()
                    return
                }
            }
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
