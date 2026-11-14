import SwiftUI
import UIKit

/// A93 (D169, Kelly Ke58 `docs/design/gor-med-chatgpt.md`, `bilder/apple/gpt-*.png`): "Gör med ChatGPT", a sheet with
/// three numbered steps and a button in each: copy the prompt (K58, filled in by `model.chatGPTPrompt`), open
/// ChatGPT, paste the answer. Step 3 is the system's `PasteButton`, so iOS does not ask about the clipboard. A
/// recognised answer (`ChatGPTImport.read`, on the phone, no server call) is shown before anything is saved:
/// "Hittade 20 frågor med svar", the first four, and **Spara frågorna** fixed at the bottom. No ChatGPT logo and no
/// sparkle. The files never pass Earmind on this path; the footnote says so.
struct ChatGPTImportView: View {
    enum Stage: Equatable {
        case steps
        case found(ChatGPTImport)
        case wrong
    }

    let model: RepetitionModel
    /// The new exam's name, grade and number of questions, as chosen in Nytt prov.
    var title = ""
    var grade: StudyProfile.Grade?
    var questions = Drill.defaultQuestionCount
    /// An existing exam: its questions go into the prompt, and only the new ones are added to it.
    var drill: Drill?
    let onSaved: (Drill) -> Void

    @State private var stage: Stage
    @State private var copied = false
    @State private var opened = false
    /// A line under the steps: nothing to paste, the prompt pasted instead of the answer, the month's questions used up.
    @State private var note: String?
    @State private var showsUnreadable = false
    /// D151 (Kelly): the new exam's voice, chosen before the sound is made, as on "Stämmer det här?".
    @State private var voice = "A"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// `start`: `.found` when the answer was pasted under Skriv text (A93 point 2), and for the scenes.
    init(model: RepetitionModel, title: String = "", grade: StudyProfile.Grade? = nil,
         questions: Int = Drill.defaultQuestionCount, drill: Drill? = nil, start: Stage = .steps,
         onSaved: @escaping (Drill) -> Void) {
        self.model = model
        self.title = title
        self.grade = grade
        self.questions = questions
        self.drill = drill
        self.onSaved = onSaved
        _stage = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .steps: steps
                case .found(let found): foundList(found)
                case .wrong: wrong
                }
            }
            .navigationTitle("Gör med ChatGPT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            }
        }
        // A95: what a paste led to is said, not only shown.
        .onChange(of: stage) { AccessibilityNotification.ScreenChanged().post() }
        .onChange(of: note) { _, now in
            if let now { AccessibilityNotification.Announcement(now).post() }
        }
    }

    // MARK: The three steps

    private var steps: some View {
        List {
            Section {
                Text("ChatGPT gör frågor och svar av dina filer. Sedan läser Earmind upp dem.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
            .listSectionSpacing(.compact)

            Section {
                step(1, done: copied, "Kopiera prompten", "Den säger åt ChatGPT exakt vad som ska göras.") {
                    stepButton(copied ? "Kopierad" : "Kopiera prompten", prominent: !copied) { copyPrompt() }
                        .sensoryFeedback(.success, trigger: copied) { _, now in now }
                }
                step(2, done: opened, "Klistra in i ChatGPT",
                     "Bifoga dina filer, till exempel foton av sidorna eller en PDF, och skicka.") {
                    // The next thing to do is the filled button: step 1 until it is done, then this one.
                    stepButton("Öppna ChatGPT", prominent: copied && !opened) { openChatGPT() }
                }
                step(3, done: false, "Klistra in svaret här", "Kopiera hela svaret från ChatGPT.") {
                    pasteButton
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let note { Text(verbatim: note).foregroundStyle(Color.primary) }
                    Text("Det du bifogar i ChatGPT hanteras av ChatGPT, inte av Earmind. ChatGPT är en tjänst från OpenAI.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func step(_ number: Int, done: Bool, _ title: String, _ detail: String,
                      @ViewBuilder button: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle.fill")
                .font(.title2)
                .foregroundStyle(done ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tint))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .font(.headline)
                    .accessibilityLabel("Steg \(number)\(done ? ", klart" : ""). \(title).")
                Text(verbatim: detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                button().padding(.top, 6)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func stepButton(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        if prominent {
            Button(action: action) { FilledButtonLabel { Text(verbatim: title) } } // A95
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        } else {
            Button(title, action: action).buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }

    /// The system's paste button: iOS shows no "Tillåt inklistring?" for it. It is grey until the prompt has been
    /// copied, so one button at a time is the filled one; it works either way.
    private var pasteButton: some View {
        PasteButton(payloadType: String.self) { strings in
            let text = strings.first ?? ""
            Task { @MainActor in pasted(text) }
        }
        .buttonBorderShape(.capsule)
        .tint(copied ? Self.pasteBlue : Self.pasteGrey)
    }

    /// A95: the system's paste button always has a white label. The accent in dark mode (#7F9BFF) is too light for
    /// it (2.6:1), so the button has the light mode's accent in both (7.6:1), and a grey that carries white (5.7:1).
    private static let pasteBlue = Color(red: 0x23 / 255, green: 0x46 / 255, blue: 0xC8 / 255)
    private static let pasteGrey = Color(white: 0.42)

    private func copyPrompt() {
        UIPasteboard.general.string = model.chatGPTPrompt(title: title, grade: grade, questions: questions, drill: drill)
        copied = true
        note = nil
    }

    /// chatgpt.com opens the ChatGPT app when it is installed (a universal link), else Safari.
    private func openChatGPT() {
        guard let url = URL(string: "https://chatgpt.com/") else { return }
        openURL(url)
        opened = true
    }

    private func pasted(_ text: String) {
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            note = "Det finns ingen text att klistra in. Kopiera svaret i ChatGPT först."
            return
        }
        // The prompt is still on the clipboard until the answer is copied, and its own example lines
        // ("Fråga: <frågan>") would be read as questions.
        guard !answer.contains("<frågan>") else {
            note = "Det här är prompten, inte svaret. Kopiera svaret i ChatGPT först."
            return
        }
        note = nil
        if let found = ChatGPTImport.read(answer) {
            stage = .found(found)
        } else {
            stage = .wrong
        }
    }

    // MARK: Recognised

    private func foundList(_ found: ChatGPTImport) -> some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hittade \(DrillText.questions(found.items.count)) med svar").font(.headline)
                        Text("Det korta svaret är första meningen i varje svar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }

            Section {
                ForEach(Array(found.items.prefix(4).enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.question).fontWeight(.semibold)
                        Text(verbatim: item.short).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Fråga \(index + 1). \(item.question) \(item.short)")
                }
                if found.items.count > 4 {
                    Text("och \(DrillText.questions(found.items.count - 4)) till").foregroundStyle(.secondary)
                }
            } header: {
                Text("Frågor")
            } footer: {
                // Kelly: the counter only while there are questions left (D155).
                if let quota = model.quota, quota.left > 0 { Text(verbatim: quota.line + ".") }
            }

            if !found.unreadable.isEmpty { // A93: the lines that could not be read, closed until asked for
                Section {
                    DisclosureGroup(found.unreadable.count == 1
                                        ? "1 rad kunde inte läsas och togs inte med."
                                        : "\(found.unreadable.count) rader kunde inte läsas och togs inte med.",
                                    isExpanded: $showsUnreadable) {
                        ForEach(Array(found.unreadable.prefix(20).enumerated()), id: \.offset) { _, line in
                            Text(verbatim: line).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // The voice is locked at the first save (K50), so an exam that already exists keeps its own.
            if drill == nil { DrillVoiceChoice(voice: $voice) }

            if let note { Section { Text(verbatim: note) } }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            MainActionBar(title: "Spara frågorna", note: "Ljudet görs som vanligt när frågorna är sparade.") {
                save(found)
            }
        }
    }

    private func save(_ found: ChatGPTImport) {
        guard let saved = model.saveImport(found, title: title, grade: grade, voice: voice, into: drill) else {
            note = "Du har inga frågor kvar den här månaden. Nya frågor går att göra från den 1 \(Self.nextMonth())." // D155
            return
        }
        onSaved(saved)
        dismiss()
    }

    /// "december": the month after this one, in Swedish.
    private static func nextMonth(after date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        let month = calendar.component(.month, from: date) // 1...12
        return calendar.monthSymbols[month % 12]
    }

    // MARK: Not recognised

    private var wrong: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Svaret har inte rätt form").font(.headline)
                    Text("Kopiera hela svaret från ChatGPT, från första ”Fråga:” till sista svaret, och försök igen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    PasteButton(payloadType: String.self) { strings in
                        let text = strings.first ?? ""
                        Task { @MainActor in pasted(text) }
                    }
                    .buttonBorderShape(.capsule)
                    .tint(Self.pasteBlue)
                    .padding(.top, 6)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let note { Text(verbatim: note).foregroundStyle(Color.primary) }
                    Text("Du kan också klistra in texten under Skriv text i Nytt prov.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
