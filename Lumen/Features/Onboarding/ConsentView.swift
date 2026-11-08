import SwiftUI

/// Consent screen (ARCHITECTURE §12, MVP item 1). Shown before the first session and again when the policy
/// version changes; the same text is reachable later from the Listening screen as "Privacy & consent".
struct ConsentView: View {
    enum Mode {
        case onboarding(onAccept: () -> Void)
        case review(grantedAt: Date?, onWithdraw: () -> Void)
        /// A2: "Läs mer" from the intro's consent card: the full text, nothing to press.
        case readMore
    }

    let mode: Mode
    @State private var confirmingWithdrawal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before you start")
                        .font(.largeTitle.bold())
                    Text("Lumen is a listening companion for lectures, meetings and studying. This is exactly what it does with sound and text.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    point(symbol: "mic.fill",
                          title: "It listens only while a session is on",
                          text: "You start and stop listening yourself. While the microphone is live, a red indicator is shown in the app and iOS shows its own microphone indicator.")
                    point(symbol: "waveform",
                          title: "Speech goes to ElevenLabs",
                          text: "While you listen, the audio is streamed to ElevenLabs, which writes it out. ElevenLabs handles it under its own terms. Lumen saves no audio, and the live transcript is forgotten when the session ends. You can keep everything on the iPhone instead under Settings, with weaker recognition.")
                    point(symbol: "clock.arrow.circlepath",
                          title: "History and memory stay on your iPhone",
                          text: "Your own questions and Lumen's answers are saved word for word with a short summary, and memories only when you ask for it. Other people's speech is not saved. Delete it in Settings at any time; it is deleted automatically after 2 years.")
                    point(symbol: "cloud",
                          title: "Answers come from the internet",
                          text: "To answer a question, the transcribed text is sent to Lumen's server, which asks Claude by Anthropic. Without a connection there are no answers.")
                    point(symbol: "paperplane",
                          title: "Reports and sharing are your choice",
                          text: "When you report an answer, your question and that answer go to the developers word for word. Sharing your history to improve the app is off unless you turn it on. Other people's speech is never sent this way.")
                    point(symbol: "person.2",
                          title: "Tell the people around you",
                          text: "You are responsible for informing anyone whose speech is transcribed. Do not use Lumen where recording is not allowed, for example during exams.")
                    point(symbol: "hand.raised",
                          title: "You can stop at any time",
                          text: "One tap stops the microphone. You can withdraw this consent later under Privacy & consent; the consent screen then returns.")
                }

                if case .review(let grantedAt, _) = mode, let grantedAt {
                    Text("Consent given \(grantedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitle: LocalizedStringKey {
        switch mode {
        case .review: return "Integritet och samtycke"
        case .readMore: return "Läs mer"
        case .onboarding: return ""
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .onboarding(let onAccept):
            VStack(spacing: 8) {
                Button(action: onAccept) {
                    Text("I understand — start using Lumen")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                Text("By continuing you confirm that you have read the points above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(.bar)
        case .review(_, let onWithdraw):
            Button(role: .destructive) {
                confirmingWithdrawal = true
            } label: {
                Text("Withdraw consent")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .padding(20)
            .background(.bar)
            .confirmationDialog("Withdraw consent?", isPresented: $confirmingWithdrawal, titleVisibility: .visible) {
                Button("Stop listening and withdraw", role: .destructive, action: onWithdraw)
            } message: {
                Text("Listening stops, this session's transcript is cleared and the consent screen is shown again.")
            }
        case .readMore:
            EmptyView()
        }
    }

    private func point(symbol: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}
