import AVFoundation
import SwiftUI

/// A49 (D123): the night. Calm and dark, little to read: the moon, one sentence, what stays on the phone, and
/// "Vakna" (the one main button). Kelly draws the morning report properly in Ke27; this follows SYSTEM.md until then.
struct SleepView: View {
    let sleep: SleepController

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "moon.stars")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(LumenColor.blue)
                .accessibilityHidden(true)
            Text("Sov gott").font(LumenFont.text(34, .bold, relativeTo: .largeTitle))
            Text("Earmind lyssnar på telefonen i natt: om du pratar i sömnen, snarkar eller sover oroligt.")
                .font(LumenFont.text(17))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                Label("Lägg telefonen nära sängen, med laddaren i.", systemImage: "bolt")
                Label("Inget skickas. Klippen sparas bara på telefonen och raderas efter 30 dagar.", systemImage: "lock")
                Label("Delar du rum kan även den andras prat spelas in. Säg till dem.", systemImage: "person.2")
            }
            .font(LumenFont.text(15))
            .foregroundStyle(LumenColor.muted)
            .padding(16)
            .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 16))
            if let problem = sleep.problem {
                Text(problem).font(LumenFont.text(15)).foregroundStyle(LumenColor.red)
            }
            Spacer()
            Button("Vakna") { sleep.stop() }
                .buttonStyle(LumenButtonStyle())
        }
        .padding(20)
        .lumenScreen()
    }
}

/// The morning report: how many times the student talked, the words and the clips, the snoring, the restless parts on
/// a timeline, and the battery the night took.
struct SleepReportView: View {
    let night: SleepNight
    let clipURL: (SleepTalk) -> URL
    let onDelete: () -> Void
    let onClose: () -> Void
    @State private var player = ClipPlayer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(Self.span(night))
                        Text(night.talkLine).font(LumenFont.text(28, .bold, relativeTo: .title))
                        Text(summary).font(LumenFont.text(17)).foregroundStyle(LumenColor.muted)
                    }
                    timeline
                    if !night.talks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Det du sa").padding(.leading, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(night.talks.enumerated()), id: \.element.id) { index, talk in
                                    talkRow(talk, divider: index > 0)
                                }
                            }
                            .background(LumenColor.surface, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    Button("Radera natten", role: .destructive, action: onDelete)
                        .font(LumenFont.text(16, .semibold))
                        .foregroundStyle(LumenColor.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(20)
            }
            .lumenScreen()
            .navigationTitle("I natt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar", action: onClose) }
            }
            .onDisappear { player.stop() }
        }
    }

    private var summary: String {
        var parts = [night.snoreMinutes == 0 ? "Ingen snarkning" : "Snarkade \(night.snoreMinutes) min"]
        let restless = night.restlessPeriods
        parts.append(restless == 0 ? "lugn natt" : (restless == 1 ? "1 orolig period" : "\(restless) oroliga perioder"))
        if let battery = night.batteryUsed { parts.append(String(format: "batteri %.0f %%", battery)) }
        return parts.joined(separator: " · ")
    }

    private var timeline: some View {
        let slots = night.timeline()
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Natten").padding(.leading, 4)
            HStack(spacing: 2) {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.color(slot.kind))
                        .frame(height: slot.kind == .calm ? 14 : 28)
                }
            }
            .frame(height: 28, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
            HStack(spacing: 14) {
                legend(.talk, "Prat")
                legend(.snoring, "Snarkning")
                legend(.restless, "Oroligt")
                legend(.calm, "Lugnt")
            }
            .font(LumenFont.text(13))
            .foregroundStyle(LumenColor.muted)
            .accessibilityHidden(true)
        }
    }

    private func legend(_ kind: SleepSlot.Kind, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Self.color(kind)).frame(width: 8, height: 8)
            Text(text)
        }
    }

    /// One accent (SYSTEM.md): the blue in steps, `soft` for calm.
    private static func color(_ kind: SleepSlot.Kind) -> Color {
        switch kind {
        case .talk: LumenColor.blue
        case .snoring: LumenColor.blue.opacity(0.6)
        case .restless: LumenColor.blue.opacity(0.3)
        case .calm: LumenColor.soft
        }
    }

    private func talkRow(_ talk: SleepTalk, divider: Bool) -> some View {
        VStack(spacing: 0) {
            if divider { Rectangle().fill(LumenColor.line).frame(height: 1).padding(.leading, 16) }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(talk.at.formatted(date: .omitted, time: .shortened))
                        .font(LumenFont.text(13, .semibold)).foregroundStyle(LumenColor.muted)
                    Text(talk.text.map { "”\($0)”" } ?? "Gick inte att höra vad du sa")
                        .font(LumenFont.text(17))
                        .foregroundStyle(talk.text == nil ? LumenColor.muted : LumenColor.ink)
                }
                Spacer(minLength: 8)
                Button {
                    player.toggle(clipURL(talk))
                } label: {
                    Image(systemName: player.playing == clipURL(talk) ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(LumenColor.soft, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(LumenColor.blue)
                .accessibilityLabel(player.playing == clipURL(talk) ? "Stoppa klippet" : "Spela klippet")
            }
            .padding(16)
        }
    }

    /// "23:10–06:45".
    static func span(_ night: SleepNight) -> String {
        let start = night.start.formatted(date: .omitted, time: .shortened)
        guard let end = night.end else { return start }
        return start + "–" + end.formatted(date: .omitted, time: .shortened)
    }
}

/// Plays one clip at a time from the report.
@MainActor
@Observable
final class ClipPlayer {
    private(set) var playing: URL?
    @ObservationIgnored private var player: AVAudioPlayer?

    func toggle(_ url: URL) {
        if playing == url { stop(); return }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.play()
        self.player = player
        playing = url
    }

    func stop() {
        player?.stop()
        player = nil
        playing = nil
    }
}
