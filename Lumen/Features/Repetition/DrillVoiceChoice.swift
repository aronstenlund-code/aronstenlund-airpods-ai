import AVFAudio
import SwiftUI

/// A84 (D151): the exam's voice, chosen with a sample before the sound is made. The voice cannot be changed afterwards
/// (K50 `voice_locked`), so the screen says so. The samples are the blind test's three sentences, bundled.
struct DrillVoiceChoice: View {
    @Binding var voice: String
    @State private var player: AVAudioPlayer?
    @State private var playing: String?

    var body: some View {
        Section {
            ForEach(RepetitionModel.voices, id: \.self) { v in
                HStack {
                    Button { voice = v } label: {
                        HStack {
                            Text("Röst \(v)").foregroundStyle(.primary)
                            Spacer()
                            if voice == v { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button { toggle(v) } label: {
                        Image(systemName: playing == v ? "stop.circle" : "play.circle").font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(playing == v ? "Stoppa röst \(v)" : "Lyssna på röst \(v)")
                }
            }
        } header: {
            Text("Röst")
        } footer: {
            Text("Rösten går inte att byta efteråt, eftersom ljudet görs med den.")
        }
        .onDisappear { player?.stop() }
    }

    private func toggle(_ v: String) {
        player?.stop()
        if playing == v { playing = nil; return }
        guard let url = RepetitionModel.voiceSample(v), let sample = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        sample.play()
        player = sample
        playing = v
    }
}
