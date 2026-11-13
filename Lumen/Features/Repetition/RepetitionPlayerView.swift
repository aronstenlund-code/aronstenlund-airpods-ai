import SwiftUI

/// A80 (D142), rebuilt in A87 (D160, Kelly Ke53 `apple/spelar.png`): the playing screen, like Spelas nu in Podcaster.
/// "Fråga 2 av 5" and the exam's name on one line, a thin progress line, the question big, what happens now (a ring
/// for the thinking time, "Långt svar"/"Kort svar", "Gör ljud …", "Pausad"), the three presses as a quiet row and
/// Avsluta as an ordinary button: the only way to end. No buttons for the answers (rule 2): the AirPods steer, the
/// phone ends. While paused the whole screen is a button that goes on.
struct RepetitionPlayerView: View {
    let model: RepetitionModel

    private var session: RepetitionSession { model.session }

    var body: some View {
        VStack(spacing: 20) {
            if let player = session.player, let drill = session.drill {
                header(player, drill)
                Spacer(minLength: 0)
                question(player, drill)
                status(player)
                Spacer(minLength: 0)
                PressesRow(paused: player.isPaused, lit: lit(player))
            } else {
                Spacer()
                Text(verbatim: endedLine).foregroundStyle(.secondary)
                Spacer()
            }
            Button {
                model.end()
            } label: {
                Text("Avsluta").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.primary)
            .accessibilityHint("Avslutar provet. Du kan fortsätta där du var nästa gång.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // Kelly Ke49: while paused, a tap anywhere but Avsluta goes on.
            if session.player?.isPaused == true { session.press(.long) }
        }
    }

    /// Ke50 §8: "Sparat på fråga {7}." after Avsluta.
    private var endedLine: String {
        if let saved = RepetitionProgress.load() { return "Sparat på fråga \(saved.index + 1)." }
        return "Provet är avslutat."
    }

    private func lit(_ player: RepetitionPlayer) -> RepetitionEvent? {
        switch player.phase {
        case .answer(_, .long): .long
        case .answer(_, .short): .short
        default: player.isPaused ? .pauseToggle : nil
        }
    }

    private func header(_ player: RepetitionPlayer, _ drill: Drill) -> some View {
        // Kelly R-granskning: "Varv" from lap 2.
        let place = "Fråga \(player.index + 1) av \(player.count)" + (player.lap > 0 ? " · Varv \(player.lap + 1)" : "")
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: place).fontWeight(.semibold).monospacedDigit()
                Spacer(minLength: 8)
                Text(verbatim: drill.title).lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            ProgressView(value: Double(player.index + 1), total: Double(max(player.count, 1)))
                .tint(Color.primary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func question(_ player: RepetitionPlayer, _ drill: Drill) -> some View {
        let item = drill.items.indices.contains(player.index) ? drill.items[player.index] : nil
        return VStack(spacing: 14) {
            Text(verbatim: item?.question ?? "")
                .font(.largeTitle.bold())
                .foregroundStyle(player.isPaused ? Color.secondary : Color.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                // Kelly R4: no answer buttons on the screen; VoiceOver still has the three as actions.
                .accessibilityAction(named: "Långt svar") { session.press(.long) }
                .accessibilityAction(named: "Kort svar") { session.press(.short) }
                .accessibilityAction(named: player.isPaused ? "Fortsätt" : "Paus") { session.press(.pauseToggle) }
            if case .answer(_, let kind) = player.phase, let item, !player.isPaused {
                Text(verbatim: kind == .short ? item.short : item.long)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
            }
        }
    }

    @ViewBuilder
    private func status(_ player: RepetitionPlayer) -> some View {
        if player.isPaused {
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill").font(.system(size: 56)).foregroundStyle(.secondary)
                Text("Pausad").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("Tryck på AirPods för att fortsätta")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text("Fortsätter från samma ord").font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            switch player.phase {
            case .thinking:
                VStack(spacing: 12) {
                    ThinkingRing(started: player.thinkingStarted ?? Date(), seconds: player.thinkingSeconds)
                    if player.isFirstLap, player.lap == 0 {
                        Text("Tryck på AirPods för svaret").font(.headline) // Kelly N1
                    } else {
                        Text("Tänk").font(.headline).foregroundStyle(.secondary)
                    }
                }
            case .answer(_, let kind):
                Label(kind == .long ? "Långt svar" : "Kort svar", systemImage: "waveform")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            case .waitingForAudio:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Gör ljud …")
                }
                .foregroundStyle(.secondary)
            case .question, .idle:
                Color.clear.frame(height: 1)
            }
        }
    }
}

/// The thinking time counting down, with the seconds in the middle. The ring is information, not decoration
/// (SYSTEM §0.5), and it is drawn in the text colour, not the accent.
private struct ThinkingRing: View {
    let started: Date
    let seconds: Double

    var body: some View {
        let started = self.started
        let seconds = self.seconds
        return TimelineView(.periodic(from: started, by: 0.1)) { context in
            let left = min(seconds, max(0, seconds - context.date.timeIntervalSince(started)))
            ZStack {
                Circle().stroke(Color(.systemFill), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: seconds > 0 ? left / seconds : 0)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "\(max(1, Int(left.rounded(.up))))") // Kelly B3: counts down to 1, never 0
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 88, height: 88)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tänk")
    }
}

/// Kelly Ke49 §4.1: the presses in the same order everywhere, dots as the symbol (no AirPods pictures, 5.2.5).
struct PressesRow: View {
    var paused = false
    var lit: RepetitionEvent?
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let layout = size >= .accessibility1 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 16))
        layout {
            item(.long, 1, "Långt svar")
            item(.short, 2, "Kort svar")
            item(.pauseToggle, 3, paused ? "Fortsätt" : "Paus")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func item(_ event: RepetitionEvent, _ dots: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: String(repeating: "●", count: dots)).font(.caption2)
            Text(verbatim: title).font(.footnote.weight(lit == event ? .semibold : .regular))
        }
        .foregroundStyle(lit == event ? Color.primary : Color.secondary)
        .accessibilityLabel("\(title), \(dots) tryck på AirPods")
    }
}
