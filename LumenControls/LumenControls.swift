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
        StartListeningControl()
    }
}

/// Opens the app and starts listening (D58).
struct StartListeningControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rsolutions.lumen.controls.start") {
            ControlWidgetButton(action: StartListeningIntent()) {
                Label("Start Lumen", systemImage: "mic.fill")
            }
        }
        .displayName("Start Lumen")
        .description("Opens Lumen and starts listening.")
    }
}

struct ListeningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ListeningStatus(isPaused: context.state.isPaused)
                    Spacer()
                    ToggleButton(isPaused: context.state.isPaused)
                }
                SuggestionList(state: context.state)
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
                DynamicIslandExpandedRegion(.bottom) {
                    SuggestionList(state: context.state)
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

/// Rizzläge: every option, the one being spoken marked, and the button for the next.
private struct SuggestionList: View {
    let state: ListeningActivityAttributes.ContentState

    var body: some View {
        if !state.suggestions.isEmpty {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.suggestions.enumerated()), id: \.offset) { index, line in
                        Text(verbatim: line)
                            .font(.footnote.weight(index == state.currentSuggestion ? .semibold : .regular))
                            .foregroundStyle(index == state.currentSuggestion ? .primary : .secondary)
                    }
                }
                Spacer()
                Button(intent: NextSuggestionIntent()) {
                    Label("Next", systemImage: "forward.fill")
                }
            }
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
