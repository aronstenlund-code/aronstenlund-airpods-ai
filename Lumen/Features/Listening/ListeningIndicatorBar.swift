import SwiftUI

/// The in-app listening indicator (ARCHITECTURE §12). Shown by `RootView` above every screen while the
/// microphone is live or paused, with one-tap stop. Hidden when the session is idle or in error.
struct ListeningIndicatorBar: View {
    let state: SessionState
    let onStop: () -> Void
    let onResume: () -> Void

    var body: some View {
        switch state {
        case .listening:
            bar(title: "Listening", symbolActive: true, action: "Stop", role: .destructive, perform: onStop)
        case .paused(let reason):
            bar(title: pausedTitle(reason), symbolActive: false,
                action: reason == .interruption ? "Stop" : "Resume",
                role: reason == .interruption ? .destructive : nil,
                perform: reason == .interruption ? onStop : onResume)
        case .idle, .error:
            EmptyView()
        }
    }

    private func pausedTitle(_ reason: PauseReason) -> LocalizedStringKey {
        switch reason {
        case .interruption: "Paused — interrupted"
        case .awaitingUserResume: "Paused"
        case .outputDeviceLost: "Paused — AirPods disconnected"
        case .mediaServicesReset: "Paused — audio system reset"
        }
    }

    private func bar(title: LocalizedStringKey, symbolActive: Bool, action: LocalizedStringKey,
                     role: ButtonRole?, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(symbolActive ? .red : .orange)
                .symbolEffect(.pulse, isActive: symbolActive)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(action, role: role, action: perform)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
