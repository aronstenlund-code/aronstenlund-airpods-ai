import SwiftUI

/// A92 (D166, Kelly Ke57 `docs/design/hjalp.md`): "Fråga om Earmind", a sheet with Klar. Empty: one line of what it
/// is, three suggestions as rows (a tap sends the question) and "Prova på en kort text". After a question: bubbles as
/// in Meddelanden, the question to the right in the accent colour and the answer to the left, whole at once (no
/// typing animation, so VoiceOver reads one thing at a time). No mascot, no avatar, no sparkle. The answers come from
/// `HelpAnswering` (K57); they are only about the app.
struct HelpChatView: View {
    let model: RepetitionModel
    /// A question offered first: "Hur fungerar trycken?" from the controls, "Vad kan jag fota?" from Nytt prov.
    var suggestion: String?
    /// Sends `suggestion` at once when the sheet opens (a caller that already knows the question, and the scenes).
    var askNow = false
    /// Opens the place an answer points at ("Öppna Styr med dina AirPods"). Without it the link is not shown.
    var onOpen: ((HelpPlace) -> Void)?
    @Environment(\.dismiss) private var dismiss

    private struct Message: Identifiable, Equatable {
        let id = UUID()
        var question: String
        var answer: HelpAnswer?
        var problem: String?
    }

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var isAsking = false
    @State private var showsTry = false

    private static let suggestions = ["Hur fungerar trycken?", "Hur delar jag ett prov?", "Varför blev det färre frågor?"]

    private var offered: [String] {
        guard let suggestion, !Self.suggestions.contains(suggestion) else { return Self.suggestions }
        return [suggestion] + Self.suggestions
    }

    var body: some View {
        NavigationStack {
            Group {
                if messages.isEmpty { start } else { conversation }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle("Fråga om Earmind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
            .navigationDestination(isPresented: $showsTry) {
                HelpTryView(model: model) { dismiss() }
            }
            .onAppear {
                if askNow, messages.isEmpty, let suggestion { ask(suggestion) }
            }
        }
    }

    // MARK: Empty

    private var start: some View {
        List {
            Section {
                Text("Fråga hur något i Earmind fungerar. Svaren handlar bara om appen.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
            Section("Förslag") {
                ForEach(offered, id: \.self) { question in
                    Button {
                        ask(question)
                    } label: {
                        Text(verbatim: question)
                    }
                }
            }
            Section("Prova") {
                Button {
                    showsTry = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.badge.plus")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prova på en kort text").foregroundStyle(Color.primary)
                            Text("Earmind gör 3 frågor med svar. Räknas mot dina frågor.")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: The conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(messages) { message in
                        bubbles(message)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages) {
                withAnimation { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func bubbles(_ message: Message) -> some View {
        Text(verbatim: message.question)
            .foregroundStyle(LumenColor.onBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.tint, in: RoundedRectangle(cornerRadius: 18))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 48)
            .accessibilityLabel("Du: \(message.question)")

        VStack(alignment: .leading, spacing: 8) {
            if let answer = message.answer {
                Text(verbatim: answer.text)
                if let hint = answer.hint, !hint.isEmpty {
                    Text(verbatim: hint)
                }
                if let place = answer.place, let onOpen {
                    Button {
                        onOpen(place)
                    } label: {
                        Text(verbatim: place.title)
                    }
                }
            } else if let problem = message.problem {
                Text(verbatim: problem)
                Button("Försök igen") { retry(message) }
            } else {
                ProgressView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 48)
    }

    // MARK: The field

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Fråga om Earmind", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .submitLabel(.send)
                .onSubmit { ask(draft) }
            Button {
                ask(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAsking)
            .accessibilityLabel("Skicka")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: Asking

    private func ask(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isAsking, let help = model.help else { return }
        draft = ""
        // The server answers each question on its own; the earlier turns are kept for the screen.
        let history = messages.compactMap { earlier in
            earlier.answer.map { HelpTurn(question: earlier.question, answer: $0.text) }
        }
        let message = Message(question: text)
        messages.append(message)
        isAsking = true
        Task {
            do throws(HelpError) {
                let answer = try await help.answer(text, history: history)
                update(message.id) { $0.answer = answer }
            } catch {
                update(message.id) { $0.problem = error.userMessage }
            }
            isAsking = false
        }
    }

    private func retry(_ message: Message) {
        guard !isAsking else { return }
        messages.removeAll { $0.id == message.id }
        ask(message.question)
    }

    private func update(_ id: UUID, _ change: (inout Message) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[index])
    }
}

/// Ke57 "Prova på en kort text": a form with a text, what it costs, then the three questions with their short
/// answers as rows. **Gör frågor**, then **Spara som prov**, fixed at the bottom; Gör om as a text button.
struct HelpTryView: View {
    let model: RepetitionModel
    let onSaved: () -> Void
    @State private var text = ""
    @State private var draft: DrillDraft?
    @State private var isMaking = false
    @State private var problem: String?

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Form {
            Section {
                TextField("Text", text: $text, axis: .vertical).lineLimit(4...10)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Klistra in eller skriv några meningar. Räknas som 3 av dina frågor.")
                    if let line = model.quota?.line { Text(verbatim: line + ".") }
                }
            }

            if let problem { Section { Text(verbatim: problem) } }

            if let draft {
                Section("Frågor") {
                    ForEach(draft.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: item.question).fontWeight(.semibold)
                            Text(verbatim: item.short).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button("Gör om") { make() }.disabled(isMaking || isEmpty)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if draft == nil {
                MainActionBar(title: "Gör frågor", isBusy: isMaking, isDisabled: isMaking || isEmpty) { make() }
            } else {
                MainActionBar(title: "Spara som prov", isBusy: isMaking, isDisabled: isMaking) { save() }
            }
        }
        .navigationTitle("Prova på en kort text")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// K57 `try`: 3 questions with answers, counted as 3 of the month's questions (D166).
    private func make() {
        guard let help = model.help, !isMaking else { return }
        isMaking = true
        problem = nil
        let source = text
        Task {
            do throws(HelpError) {
                draft = try await help.tryText(source)
            } catch {
                problem = error.userMessage
            }
            isMaking = false
        }
    }

    private func save() {
        guard let draft else { return }
        let subject = draft.summary.subject.trimmingCharacters(in: .whitespaces)
        let items = draft.items.filter { !$0.short.isEmpty }
        guard !items.isEmpty else { return }
        let drill = model.save(Drill(title: subject.isEmpty ? "Nytt prov" : "\(subject)provet",
                                     summary: draft.summary, items: items, questionCount: items.count))
        model.openDrill = drill.id // Start opens it
        onSaved()
    }
}
