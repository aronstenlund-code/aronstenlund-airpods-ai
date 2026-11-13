import SwiftUI

/// A80 (D142, Kelly Ke49): the playing screen. "Fråga 7 av 20 · Varv 2", the question, what happens now ("Tänk",
/// "Långt svar", "Pausad: tryck på AirPods för att fortsätta"), the three controls as buttons on the phone (the same
/// path as AirPods), and a big Avsluta: the only way to end. The screen may be locked; the AirPods keep working.
struct RepetitionPlayerView: View {
    let model: RepetitionModel

    private var session: RepetitionSession { model.session }

    var body: some View {
        VStack(spacing: 24) {
            if let player = session.player, let drill = session.drill {
                header(player, drill)
                Spacer(minLength: 0)
                question(player, drill)
                status(player)
                Spacer(minLength: 0)
                controls(player)
            } else {
                Spacer()
                Text("Provet är avslutat.").foregroundStyle(LumenColor.muted)
                Spacer()
            }
            Button(role: .destructive) {
                model.end()
            } label: {
                Text("Avsluta").font(LumenFont.text(20, .bold, relativeTo: .title3)).frame(maxWidth: .infinity)
            }
            .buttonStyle(LumenButtonStyle(kind: .danger, height: 64))
            .accessibilityHint("Det enda som avslutar. Annars börjar listan om.")
        }
        .padding(20)
        .lumenScreen()
    }

    private func header(_ player: RepetitionPlayer, _ drill: Drill) -> some View {
        HStack {
            Text("Fråga \(player.index + 1) av \(player.tracks.count)")
                .font(LumenFont.text(17, .semibold))
                .monospacedDigit()
            Spacer()
            if player.lap > 0 {
                Text("Varv \(player.lap + 1)")
                    .font(LumenFont.text(15, .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(LumenColor.soft, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func question(_ player: RepetitionPlayer, _ drill: Drill) -> some View {
        let item = drill.items.indices.contains(player.index) ? drill.items[player.index] : nil
        return Text(item?.question ?? "")
            .font(LumenFont.handwriting(34, bold: true, relativeTo: .largeTitle))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func status(_ player: RepetitionPlayer) -> some View {
        let text: String
        if player.isPaused {
            text = "Pausad. Tryck på AirPods för att fortsätta. Fortsätter från samma ord."
        } else {
            switch player.phase {
            case .idle: text = ""
            case .question: text = "Frågan"
            case .thinking: text = "Tänk"
            case .answer(_, .long): text = "Långt svar"
            case .answer(_, .short): text = "Kort svar"
            }
        }
        return Text(text)
            .font(LumenFont.text(20, .semibold, relativeTo: .title3))
            .foregroundStyle(player.isPaused ? LumenColor.red : LumenColor.muted)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func controls(_ player: RepetitionPlayer) -> some View {
        HStack(spacing: 12) {
            control("Långt", "1 tryck", "text.alignleft") { model.session.press(.long) }
            control("Kort", "2 tryck", "text.append") { model.session.press(.short) }
            control(player.isPaused ? "Fortsätt" : "Paus", "3 tryck", player.isPaused ? "play.fill" : "pause.fill") {
                model.session.press(.pauseToggle)
            }
        }
    }

    private func control(_ title: String, _ press: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                Text(title).font(LumenFont.text(16, .semibold))
                Text(press).font(LumenFont.text(12)).foregroundStyle(LumenColor.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
        }
        .buttonStyle(LumenButtonStyle(kind: .secondary, height: 84))
        .accessibilityLabel("\(title), som \(press) på AirPods")
    }
}
