import SwiftUI

/// The in-app listening indicator (ARCHITECTURE §12, D68). A slim line above every screen while the microphone is
/// live or paused: it says what is happening and stops with one tap. Hidden when the session is idle or in error.
struct ListeningIndicatorBar: View {
    let state: SessionState
    let onStop: () -> Void
    let onResume: () -> Void

    var body: some View {
        switch state {
        case .listening:
            bar(title: "Listening", symbolActive: true, action: "Stop", role: .destructive, perform: onStop)
        case .paused(let reason):
            bar(title: pausedTitle(reason), symbolActive: false, action: "Resume", role: nil, perform: onResume)
        case .idle, .error:
            EmptyView()
        }
    }

    private func pausedTitle(_ reason: PauseReason) -> LocalizedStringKey {
        switch reason {
        case .user: "Paused"
        case .interruption, .awaitingUserResume: "Paused — tap to listen again"
        case .outputDeviceLost: "Paused — AirPods disconnected"
        case .mediaServicesReset: "Paused — audio system reset"
        }
    }

    private func bar(title: LocalizedStringKey, symbolActive: Bool, action: LocalizedStringKey,
                     role: ButtonRole?, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(symbolActive ? .red : .orange)
                .symbolEffect(.pulse, isActive: symbolActive)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            Button(action, role: role, action: perform)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 26)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
