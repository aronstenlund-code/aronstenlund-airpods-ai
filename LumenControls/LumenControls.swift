import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen / Dynamic Island / Control Center surfaces for pausing and resuming listening (D33).
@main
struct LumenControlsBundle: WidgetBundle {
    var body: some Widget {
        ListeningLiveActivity()
        ListeningControl()
    }
}

struct ListeningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            HStack(spacing: 12) {
                ListeningStatus(isPaused: context.state.isPaused)
                Spacer()
                ToggleButton(isPaused: context.state.isPaused)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ListeningStatus(isPaused: context.state.isPaused)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ToggleButton(isPaused: context.state.isPaused)
                }
            } compactLeading: {
                StatusSymbol(isPaused: context.state.isPaused)
            } compactTrailing: {
                Text(context.state.isPaused ? "Paused" : "Listening")
                    .font(.caption2)
            } minimal: {
                StatusSymbol(isPaused: context.state.isPaused)
            }
        }
    }
}

/// A plain button: the extension cannot read the app's state, so the action is a toggle.
struct ListeningControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rsolutions.lumen.controls.listening") {
            ControlWidgetButton(action: ToggleListeningIntent()) {
                Label("Pause or resume", systemImage: "waveform")
            }
        }
        .displayName("Lumen listening")
        .description("Pause listening to play music, resume with one tap.")
    }
}

private struct StatusSymbol: View {
    let isPaused: Bool

    var body: some View {
        Image(systemName: isPaused ? "pause.circle.fill" : "mic.fill")
            .foregroundStyle(isPaused ? .orange : .red)
    }
}

private struct ListeningStatus: View {
    let isPaused: Bool

    var body: some View {
        Label {
            Text(isPaused ? "Paused" : "Listening")
                .font(.headline)
        } icon: {
            StatusSymbol(isPaused: isPaused)
        }
    }
}

private struct ToggleButton: View {
    let isPaused: Bool

    var body: some View {
        Button(intent: ToggleListeningIntent()) {
            Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
        }
    }
}
