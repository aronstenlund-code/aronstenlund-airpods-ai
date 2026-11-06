import SwiftUI

/// Start screen for Intervjuläge: the role or job ad, practice or preparation.
struct InterviewSetupView: View {
    @Bindable var model: ListeningModel
    @Bindable var settings: ModeSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Role or job ad") {
                TextEditor(text: $settings.interviewSetup)
                    .frame(minHeight: 140)
            }
            Section {
                Button("Start practice interview") {
                    dismiss()
                    Task { await model.startHandsFree(.interview) }
                }
                Button("Prepare questions and answers") {
                    dismiss()
                    model.prepareInterview()
                }
            } footer: {
                Text("Practice: a friend asks, you get the outline of an answer, then feedback on yours. Use live support only where it is allowed and the others know, for example a mock interview.")
            }
            .disabled(settings.interviewSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Intervjuläge")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Rizzläge is for adults (D63): asked the first time, remembered on this phone.
struct AgeGateView: View {
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rizzläge is only for people aged 18 or older")
                .font(.title2.bold())
            Spacer()
            Button {
                onAnswer(true)
            } label: {
                Text("I am 18 or older").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            Button {
                onAnswer(false)
            } label: {
                Text("Cancel").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

/// Start screen for the live modes (D42/D43/D63): consent first, then what the suggestions may build on.
struct LiveStartView: View {
    @Bindable var model: ListeningModel
    @Bindable var settings: ModeSettings
    let mode: ConversationMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Label("Try it with a friend", systemImage: "person.2.fill")
                    .font(.headline)
                Text("Tell them the app is listening. What you both say goes to ElevenLabs and Anthropic to create suggestions. The words are forgotten when the session ends.")
                    .font(.subheadline)
            }
            Section("About you") {
                TextField("Interests, separated by commas", text: $settings.rizzInterests)
                TextField("Profile or bio", text: $settings.rizzProfile, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section {
                Button("They know the app is listening. Start") {
                    dismiss()
                    Task { await model.startHandsFree(mode) }
                }
                .font(.headline)
            } footer: {
                Text("Suggestions are shown on the Lock Screen and the best one is spoken in a pause. Say \"nästa\" for the next one.")
            }
        }
        .navigationTitle(mode == .rizz ? "Rizzläge" : "Socialt läge")
        .navigationBarTitleDisplayMode(.inline)
    }
}
