import SwiftUI

/// Settings → Feedback & suggestions (D57): free text to the developers, and the opt-in for sharing history.
struct FeedbackView: View {
    let model: ListeningModel
    @State private var kind = "app"
    @State private var text = ""
    @State private var result: LocalizedStringKey?

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    Text("About the app").tag("app")
                    Text("Suggestion").tag("suggestion")
                }
                .pickerStyle(.segmented)
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                Button("Send") {
                    Task {
                        if await model.sendFeedback(type: kind, text: text) {
                            text = ""
                            result = "Sent"
                        } else {
                            result = "Could not send. Try again later."
                        }
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let result {
                    Text(result).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Tell the developers")
            }
            if let share = model.feedback?.settings {
                Section {
                    Toggle("Share history to improve the app", isOn: Binding(get: { share.isSharing }, set: { model.setSharing($0) }))
                } footer: {
                    Text("Off by default. When on, your own questions and Lumen's answers are uploaded without your name and kept for at most 12 months. Other people's speech is never sent. Turning it off deletes what was shared.")
                }
            }
        }
        .lumenForm()
        .navigationTitle("Feedback och förslag")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Asked once, right after consent (D57). Saying no is the plain choice.
struct ShareHistoryPromptView: View {
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Help improve Lumen?")
                .font(.title.bold())
            Text("You can share your own questions and Lumen's answers with the developers, without your name, for at most 12 months. Other people's speech is never sent. You can change your mind at any time in Settings, and what was shared is then deleted.")
            Spacer()
            Button {
                onAnswer(false)
            } label: {
                Text("Don't share").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            Button {
                onAnswer(true)
            } label: {
                Text("Share history").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .interactiveDismissDisabled()
    }
}
