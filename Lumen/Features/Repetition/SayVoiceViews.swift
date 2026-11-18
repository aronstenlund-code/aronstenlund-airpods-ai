import AVFoundation
import SwiftUI

/// A136 (D220.3, Kelly Ke75 §4): listening to a voice before it is chosen. The file is the voice service's own sample
/// (`preview_url`), fetched as it is; no sound is made, so it costs nothing.
@MainActor
@Observable
final class VoicePreview {
    private(set) var playingID: String?
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var watch: Task<Void, Never>?

    func toggle(_ voice: SayVoice) {
        if playingID == voice.id { stop(); return }
        stop()
        guard let url = voice.previewURL else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let player = AVPlayer(url: url)
        self.player = player
        playingID = voice.id
        let id = voice.id
        watch = Task { [weak self] in
            // The sample ends by itself (the player pauses at its end), fails, or is given up after half a minute.
            var started = false
            for _ in 0..<100 {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !Task.isCancelled, self.playingID == id, let player = self.player else { return }
                if player.currentItem?.status == .failed { break }
                if player.timeControlStatus == .playing { started = true } else if started, player.timeControlStatus == .paused { break }
            }
            guard let self, !Task.isCancelled, self.playingID == id else { return }
            self.stop()
        }
        player.play()
    }

    func stop() {
        watch?.cancel()
        watch = nil
        player?.pause()
        player = nil
        playingID = nil
    }
}

/// Ke75 §4: the sheet "Röst". The chosen catalog voice has a check mark; ▶ plays the sample. The search looks in the
/// voice library; what is found there can be listened to, and chosen when it is in the catalog.
struct SayVoicesSheet: View {
    let model: RepetitionModel
    /// The chosen voice's id; empty = the server's own voice.
    @Binding var chosen: String
    /// A140 (D223): "Blanda röster": the server draws a voice per part. Off by default.
    @Binding var mix: Bool
    @State private var search = ""
    @State private var found: [SayVoice]?
    @State private var isSearching = false
    @State private var preview = VoicePreview()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { SayMotion.reduces(systemReduceMotion) }

    static let footnote = "Provlyssning kostar inget. En ny röst blir nytt ljud."
    // A140 (D223): mine, for Kelly to review.
    static let mixTitle = "Blanda röster"
    static let mixLine = "Varje stycke får en egen röst, samma varje gång."
    static let reviewTitle = "Att provlyssna"
    static let notInCatalog = "Kan bara provlyssnas" // Kelly"

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        Toggle(Self.mixTitle, isOn: $mix)
                    } footer: {
                        Text(verbatim: Self.mixLine)
                    }
                    Section {
                        ForEach(model.sayVoices.filter { !$0.isUnderReview }) { row($0) }
                    } header: {
                        Text("Svenska röster")
                    } footer: {
                        Text(verbatim: Self.footnote)
                    }
                    // K99 (D223): voices under review; the server gives them to the owner's account only.
                    let review = model.sayVoices.filter(\.isUnderReview)
                    if !review.isEmpty {
                        Section {
                            ForEach(review) { row($0) }
                        } header: {
                            Text(verbatim: Self.reviewTitle)
                        }
                    }
                } else {
                    Section {
                        if let found {
                            ForEach(found) { row($0) }
                            if found.isEmpty { Text("Inga röster hittades.").foregroundStyle(LumenColor.secondaryText) }
                        } else if isSearching {
                            HStack(spacing: 8) { ProgressView(); Text("Söker …").foregroundStyle(LumenColor.secondaryText) }
                        } else {
                            Text(verbatim: NetworkStatus.shared.isOnline ? "Det gick inte att söka just nu." : NetworkStatus.noNetworkLine)
                                .foregroundStyle(LumenColor.secondaryText)
                        }
                    } footer: {
                        Text(verbatim: Self.footnote)
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Sök bland alla röster")
            .task(id: query) { await look() }
            .navigationTitle("Röst")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
            .onDisappear { preview.stop() }
            // A150 (D231): the check mark moves to the chosen row with a fade, and the choice is felt.
            .animation(SayMotion.change(reduceMotion), value: chosen)
            .animation(SayMotion.change(reduceMotion), value: mix)
            .sensoryFeedback(.selection, trigger: chosen)
            .sensoryFeedback(.selection, trigger: mix)
        }
    }

    /// The library is asked a moment after the typing stops (the server takes ten searches a minute).
    private func look() async {
        found = nil
        guard !query.isEmpty else { isSearching = false; return }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        let voices = await model.searchVoices(query)
        guard !Task.isCancelled else { return }
        // A voice that is in the catalog can be chosen, whatever the library says.
        let catalog = Set(model.sayVoices.map(\.voice_id))
        found = voices?.map { voice in
            var voice = voice
            if catalog.contains(voice.voice_id) { voice.selectable = true }
            return voice
        }
        isSearching = false
    }

    /// Kelly (review of A136): with the largest text the row is stacked: ▶, the name and the check mark on a row, then
    /// the description in the whole width, without hyphenation.
    @ViewBuilder
    private func row(_ voice: SayVoice) -> some View {
        if typeSize.isAccessibilitySize {
            let line = subtitle(of: voice)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    playButton(voice)
                    Button {
                        choose(voice)
                    } label: {
                        HStack(spacing: 8) {
                            Text(verbatim: voice.name).foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            if chosen == voice.voice_id, !mix {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint).transition(SayMotion.mark(reduceMotion)).accessibilityLabel("Vald")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressFeedback)
                    .disabled(!voice.canBeChosen)
                }
                if !line.isEmpty {
                    Text(verbatim: line).font(.footnote).foregroundStyle(LumenColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            wideRow(voice)
        }
    }

    private func subtitle(of voice: SayVoice) -> String {
        voice.canBeChosen ? voice.line : [voice.line, Self.notInCatalog].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func choose(_ voice: SayVoice) {
        guard voice.canBeChosen else { return }
        if mix {
            mix = false // one voice is chosen instead of the mix
            chosen = voice.voice_id
        } else {
            chosen = chosen == voice.voice_id ? "" : voice.voice_id
        }
    }

    @ViewBuilder
    private func playButton(_ voice: SayVoice) -> some View {
        if voice.previewURL != nil {
            Button {
                preview.toggle(voice)
            } label: {
                Image(systemName: preview.playingID == voice.id ? "pause.circle.fill" : "play.circle.fill")
                    .contentTransition(.symbolEffect(.replace)) // A150: the symbol changes in place
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.pressFeedbackRound)
            .accessibilityLabel(preview.playingID == voice.id ? "Pausa \(voice.name)" : "Provlyssna \(voice.name)")
        }
    }

    private func wideRow(_ voice: SayVoice) -> some View {
        HStack(spacing: 12) {
            playButton(voice)
            Button {
                choose(voice)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: voice.name).foregroundStyle(.primary)
                        let line = subtitle(of: voice)
                        if !line.isEmpty { Text(verbatim: line).font(.footnote).foregroundStyle(LumenColor.secondaryText) }
                    }
                    Spacer(minLength: 8)
                    if chosen == voice.voice_id, !mix {
                        Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint).transition(SayMotion.mark(reduceMotion))
                            .accessibilityLabel("Vald")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressFeedback)
            .disabled(!voice.canBeChosen)
        }
    }
}
