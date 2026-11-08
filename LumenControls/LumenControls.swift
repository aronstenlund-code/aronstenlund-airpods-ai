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
        // D86: logo, the exam's name, "Lyssnar", the latest answer on one line, Pausa and Avsluta.
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    LumenLogo(size: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: context.state.title ?? "Lumen")
                            .font(LumenFont.text(17, .bold))
                            .lineLimit(1)
                        ListeningStatus(isPaused: context.state.isPaused)
                    }
                    Spacer()
                }
                if let answer = context.state.latestAnswer, context.state.suggestions.isEmpty {
                    Text(verbatim: answer)
                        .font(LumenFont.text(15))
                        .lineLimit(1)
                }
                SuggestionList(state: context.state)
                HStack(spacing: 10) {
                    ToggleButton(isPaused: context.state.isPaused)
                    StopButton()
                }
            }
            .padding()
            .activityBackgroundTint(LumenColor.background)
            .foregroundStyle(LumenColor.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        LumenLogo(size: 22)
                        Text(verbatim: context.state.title ?? "Lumen").font(LumenFont.text(15, .bold)).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ListeningStatus(isPaused: context.state.isPaused)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let answer = context.state.latestAnswer, context.state.suggestions.isEmpty {
                            Text(verbatim: answer).font(LumenFont.text(14)).lineLimit(1)
                        }
                        SuggestionList(state: context.state)
                        HStack(spacing: 10) {
                            ToggleButton(isPaused: context.state.isPaused)
                            StopButton()
                        }
                    }
                }
            } compactLeading: {
                LumenLogo(size: 18)
            } compactTrailing: {
                Text(context.state.isPaused ? "Pausad" : "Lyssnar")
                    .font(LumenFont.text(12, .semibold))
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
        Image(systemName: isPaused ? "pause.circle.fill" : "circle.fill")
            .font(.system(size: isPaused ? 14 : 9))
            .foregroundStyle(isPaused ? LumenColor.muted : LumenColor.red)
            .accessibilityHidden(true)
    }
}

private struct ListeningStatus: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 6) {
            StatusSymbol(isPaused: isPaused)
            Text(isPaused ? "Pausad" : "Lyssnar").font(LumenFont.text(14, .semibold))
        }
        .accessibilityElement(children: .combine)
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
                            .font(LumenFont.text(14, index == state.currentSuggestion ? .semibold : .regular))
                            .foregroundStyle(index == state.currentSuggestion ? LumenColor.ink : LumenColor.muted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button(intent: NextSuggestionIntent()) {
                    Label("Nästa", systemImage: "forward.fill")
                }
                .tint(LumenColor.blue)
            }
        }
    }
}

/// "Pausa" / "Fortsätt": the same words as in the app and by voice.
private struct ToggleButton: View {
    let isPaused: Bool

    var body: some View {
        Button(intent: ToggleListeningIntent()) {
            Label(isPaused ? "Fortsätt" : "Pausa", systemImage: isPaused ? "play.fill" : "pause.fill")
                .font(LumenFont.text(15, .semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .tint(LumenColor.chip)
        .foregroundStyle(LumenColor.ink)
    }
}

private struct StopButton: View {
    var body: some View {
        Button(intent: StopListeningIntent()) {
            Label("Avsluta", systemImage: "stop.fill")
                .font(LumenFont.text(15, .semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .tint(LumenColor.red)
        .foregroundStyle(LumenColor.onRed)
    }
}
