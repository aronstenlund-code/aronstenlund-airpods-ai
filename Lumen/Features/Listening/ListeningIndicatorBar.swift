import SwiftUI

/// The in-app listening indicator (ARCHITECTURE §12, D68), D86 words: a slim line above every screen while the
/// microphone is live or paused, except on the listening screen, which is the indicator itself. "Avsluta" stops with
/// one tap; a tap on the line opens the listening screen. Hidden when the session is idle or in error.
struct ListeningIndicatorBar: View {
    let state: SessionState
    let onStop: () -> Void
    let onResume: () -> Void
    var onOpen: (() -> Void)?

    var body: some View {
        switch state {
        case .listening:
            bar(title: "Lyssnar", active: true, action: "Avsluta", perform: onStop)
        case .paused(let reason):
            bar(title: pausedTitle(reason), active: false, action: "Fortsätt", perform: onResume)
        case .idle, .error:
            EmptyView()
        }
    }

    private func pausedTitle(_ reason: PauseReason) -> String {
        switch reason {
        case .user: "Pausad"
        case .interruption, .awaitingUserResume: "Pausad, tryck Fortsätt för att lyssna igen"
        case .outputDeviceLost: "Pausad, AirPods kopplades bort"
        case .mediaServicesReset: "Pausad, ljudet startades om"
        }
    }

    private func bar(title: String, active: Bool, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button {
                onOpen?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(active ? LumenColor.red : LumenColor.orange)
                        .symbolEffect(.pulse, isActive: active)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(LumenFont.text(14, .semibold, relativeTo: .footnote))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(onOpen == nil ? "" : "Öppnar lyssnarskärmen")
            Button(action, action: perform)
                .font(LumenFont.text(14, .semibold, relativeTo: .footnote))
                .foregroundStyle(active ? LumenColor.red : LumenColor.blue)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(LumenColor.ink)
        .background(LumenColor.chip)
        .overlay(alignment: .bottom) { Rectangle().fill(LumenColor.line).frame(height: 1) }
    }
}
