import SwiftUI

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

    static let tempos: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5]

    /// "7:12".
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The line under the field: what the text counts as, or why it cannot be played now.
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
            HStack(alignment: .firstTextBaseline) {
                Text("Säg i AirPods").font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if !isEmpty {
                    Text("\(chars) tecken").font(.caption.monospaced()).opacity(0.55)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "›").foregroundStyle(SayText.accent).accessibilityHidden(true)
                TextField("", text: $text, prompt: Text("Skriv eller klistra in det du vill höra").foregroundStyle(SayText.ink.opacity(0.45)),
                          axis: .vertical)
                    .lineLimit(typeSize.isAccessibilitySize ? 2...6 : 3...8)
                    .focused($focused)
                    .tint(SayText.accent)
                    .accessibilityLabel("Säg i AirPods, textfält")
            }
            .font(.body.monospaced())
            if !isEmpty {
                Text(verbatim: SayText.costLine(counts: counts, left: sameAsMade == nil ? model.quota?.left : nil,
                                                 readingAloudOff: readingAloudOff))
                    .font(.footnote)
                    .opacity(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            controls
        }
        .padding(16)
        .foregroundStyle(SayText.ink)
        .background(scheme == .dark ? SayText.fieldDark : SayText.field, in: RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .dark) // the system's controls are dark inside the field, in light mode too
        #if DEBUG
        .onAppear { if let staged = SayText.stagedForScreenshots, text.isEmpty { text = staged } }
        #endif
    }

    private var controls: some View {
        // Ke69 §3.8: with the largest text the small buttons are one row and Spela a row of its own.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            HStack(spacing: 8) {
                Menu {
                    Picker("Hur länge", selection: $minutes) {
                        Text("En gång").tag(0)
                        ForEach(SayText.repeats, id: \.self) { Text("Upprepa \($0) min").tag($0) }
                    }
                } label: {
                    Label(SayText.howLong(minutes), systemImage: "repeat")
                }
                .accessibilityLabel("Hur länge, \(minutes == 0 ? "En gång" : "Upprepa \(minutes) minuter")")
                Menu {
                    Picker("Tempo", selection: $tempo) {
                        ForEach(SayText.tempos, id: \.self) { Text(verbatim: SayText.tempo($0)).tag($0) }
                    }
                } label: {
                    Text(verbatim: SayText.tempo(tempo)).monospacedDigit()
                }
                .accessibilityLabel("Tempo, \(SayText.tempo(tempo))")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Button {
                play()
            } label: {
                HStack(spacing: 6) {
                    if isStarting { ProgressView().controlSize(.small) } else { Image(systemName: "play.fill").accessibilityHidden(true) }
                    Text("Spela")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(SayText.accent)
            .foregroundStyle(Color.black)
            .disabled(isEmpty || isStarting || tooMany)
        }
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
