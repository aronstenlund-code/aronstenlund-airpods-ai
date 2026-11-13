import SwiftUI

/// A80 (D142, Kelly Ke49 "Uppspelning"): "Fråga 7 av 20 · Varv 2", a mark per question, the question big, what
/// happens now (a ring for "Tänk", "Långt svar"/"Kort svar", "Gör ljud …", "Pausad"), the three presses as a quiet row
/// and a big neutral Avsluta: the only way to end. No buttons for the answers (rule 2): the AirPods steer, the phone
/// ends. While paused the whole screen is a button that goes on.
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
                Text(endedLine).foregroundStyle(LumenColor.muted)
                Spacer()
            }
            Button {
                model.end()
            } label: {
                Text("Avsluta").font(LumenFont.text(20, .bold, relativeTo: .title3)).frame(maxWidth: .infinity)
            }
            .buttonStyle(LumenButtonStyle(kind: .secondary, height: 64))
            .accessibilityHint("Avslutar provet. Du kan fortsätta där du var nästa gång.")
        }
        .padding(20)
        .contentShape(Rectangle())
        .onTapGesture {
            // Kelly Ke49: while paused, a tap anywhere but Avsluta goes on.
            if session.player?.isPaused == true { session.press(.long) }
        }
        .lumenScreen()
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
        VStack(spacing: 10) {
            HStack {
                Text("Fråga \(player.index + 1) av \(player.count)")
                    .font(LumenFont.text(17, .semibold))
                    .monospacedDigit()
                Spacer()
                if player.lap > 0 { // Kelly R-granskning: "Varv" from lap 2
                    Text("Varv \(player.lap + 1)")
                        .font(LumenFont.text(15, .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(LumenColor.surface, in: Capsule())
                }
            }
            if player.count <= 60 {
                HStack(spacing: 3) {
                    ForEach(0..<player.count, id: \.self) { i in
                        Capsule()
                            .fill(i < player.index ? LumenColor.blue.opacity(0.5) : i == player.index ? LumenColor.blue : LumenColor.line)
                            .frame(height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
            Text(drill.title)
                .font(LumenFont.text(13, .semibold))
                .foregroundStyle(LumenColor.muted)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(LumenColor.surface, in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private func question(_ player: RepetitionPlayer, _ drill: Drill) -> some View {
        let item = drill.items.indices.contains(player.index) ? drill.items[player.index] : nil
        return VStack(spacing: 14) {
            Text(item?.question ?? "")
                .font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
                .foregroundStyle(player.isPaused ? LumenColor.muted : LumenColor.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                // Kelly R4: no answer buttons on the screen; VoiceOver still has the three as actions.
                .accessibilityAction(named: "Långt svar") { session.press(.long) }
                .accessibilityAction(named: "Kort svar") { session.press(.short) }
                .accessibilityAction(named: player.isPaused ? "Fortsätt" : "Paus") { session.press(.pauseToggle) }
            if case .answer(_, let kind) = player.phase, let item, !player.isPaused {
                Text(kind == .short ? item.short : item.long)
                    .font(LumenFont.text(17))
                    .foregroundStyle(LumenColor.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
            }
        }
    }

    @ViewBuilder
    private func status(_ player: RepetitionPlayer) -> some View {
        if player.isPaused {
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill").font(.system(size: 56)).foregroundStyle(LumenColor.muted)
                Text("Pausad")
                    .font(LumenFont.text(15, .semibold))
                    .foregroundStyle(LumenColor.muted)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(LumenColor.surface, in: Capsule())
                Text("Tryck på AirPods för att fortsätta")
                    .font(LumenFont.text(20, .bold, relativeTo: .title3))
                    .multilineTextAlignment(.center)
                Text("Fortsätter från samma ord")
                    .font(LumenFont.text(15))
                    .foregroundStyle(LumenColor.muted)
            }
            .accessibilityElement(children: .combine)
        } else {
            switch player.phase {
            case .thinking:
                ThinkingRing(started: player.thinkingStarted ?? Date(), seconds: player.thinkingSeconds)
            case .answer(_, let kind):
                Label(kind == .long ? "Långt svar" : "Kort svar", systemImage: "waveform")
                    .font(LumenFont.text(17, .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(LumenColor.soft, in: Capsule())
            case .waitingForAudio:
                HStack(spacing: 8) { ProgressView(); Text("Gör ljud …") }
                    .font(LumenFont.text(17))
                    .foregroundStyle(LumenColor.muted)
            case .question, .idle:
                Color.clear.frame(height: 1)
            }
        }
    }
}

/// The thinking time counting down, with the seconds in the middle and "Tänk" under.
private struct ThinkingRing: View {
    let started: Date
    let seconds: Double

    var body: some View {
        let started = self.started
        let seconds = self.seconds
        return TimelineView(.periodic(from: started, by: 0.1)) { context in
            let left = min(seconds, max(0, seconds - context.date.timeIntervalSince(started)))
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(LumenColor.line, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: seconds > 0 ? left / seconds : 0)
                        .stroke(LumenColor.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(left.rounded(.up)))")
                        .font(LumenFont.text(28, .bold))
                        .monospacedDigit()
                }
                .frame(width: 84, height: 84)
                Text("Tänk").font(LumenFont.text(17, .semibold)).foregroundStyle(LumenColor.muted)
            }
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
            : AnyLayout(HStackLayout(spacing: 14))
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
            Text(String(repeating: "●", count: dots)).font(.system(size: 8))
            Text(title).font(LumenFont.text(14, .semibold))
        }
        .foregroundStyle(lit == event ? LumenColor.blue : LumenColor.muted)
        .accessibilityLabel("\(title), \(dots) tryck på AirPods")
    }
}
