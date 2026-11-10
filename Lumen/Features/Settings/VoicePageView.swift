import SwiftUI

/// A26 R5 (Kelly, `docs/design/bilder/system/rost.png`): Inställningar › Röst. Each voice is described, not named
/// ("Adam" does not show), with ▶ on its row to hear it and ✓ on the chosen one; the speed is three steps.
struct VoicePageView: View {
    let model: ListeningModel
    @State private var playingID: String?

    var body: some View {
        @Bindable var voice = model.speaker.settings
        Form {
            Section {
                ForEach(choices) { choice in
                    row(choice, chosen: choice == voice.voice) { voice.voice = choice }
                }
            } header: {
                Text("Välj röst")
            } footer: {
                catalogStatus
            }

            Section {
                Picker("Talhastighet", selection: Binding(get: { SpeedChoice.nearest(to: voice.rate) },
                                                          set: { voice.rate = $0.rate; model.speaker.applyRate() })) {
                    ForEach(SpeedChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(LumenColor.raised)
            } header: {
                Text("Talhastighet")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tryck ▶ för att höra rösten.")
                    if let notice = model.speaker.notice {
                        Text(notice).foregroundStyle(LumenColor.muted)
                    }
                }
            }
        }
        .lumenForm()
        .navigationTitle("Röst")
        .navigationBarTitleDisplayMode(.large)
        .task { await model.voices.refreshIfNeeded() }
        .onChange(of: model.speaker.status) { _, status in
            if status == .idle { playingID = nil }
        }
    }

    /// The service's voices first (the default leads), then the iPhone's own. The chosen voice is always a row, with
    /// its ✓, also while the service's list is still loading (A30, Kelly Ke20).
    private var choices: [VoiceChoice] {
        let service = model.voices.voices.sorted { a, b in
            (a.voiceID == model.voices.defaultID ? 0 : 1) < (b.voiceID == model.voices.defaultID ? 0 : 1)
        }
        // A46 (Kelly Ke18): one iPhone voice, not the default and "Alva" as two look-alike rows.
        let all = service + [VoiceChoice.appleDefault]
        let chosen = model.speaker.settings.voice
        return all.contains(chosen) ? all : [chosen] + all
    }

    private func row(_ choice: VoiceChoice, chosen: Bool, choose: @escaping () -> Void) -> some View {
        let words = VoiceDescription.words(for: choice, described: model.voices.descriptions[choice.voiceID])
        let playing = playingID == choice.id && model.speaker.status != .idle
        return HStack(spacing: 12) {
            Button(action: choose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(words.title).font(LumenFont.text(17)).foregroundStyle(LumenColor.ink)
                    Text(words.detail).font(LumenFont.text(13)).foregroundStyle(LumenColor.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(chosen ? .isSelected : [])

            Button {
                if playing {
                    model.speaker.interrupt()
                    playingID = nil
                } else {
                    playingID = choice.id
                    model.previewVoice(choice)
                }
            } label: {
                Image(systemName: playing ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LumenColor.blue)
                    .frame(width: 36, height: 36)
                    .background(LumenColor.surface, in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? "Stoppa" : "Lyssna på \(words.title)")

            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LumenColor.blue)
                .opacity(chosen ? 1 : 0)
                .frame(width: 18)
                .accessibilityHidden(true)
        }
        .listRowBackground(LumenColor.raised)
    }

    @ViewBuilder
    private var catalogStatus: some View {
        switch model.voices.status {
        case .loading:
            Text("Hämtar fler röster …")
        case .failed:
            Text("Fler röster kunde inte hämtas just nu. iPhonens röst fungerar alltid.")
        case .idle, .loaded:
            EmptyView()
        }
    }
}

/// A26 R5: words for a voice. The service may send a description ("Mansröst, lugn"); otherwise the few voices we
/// know are described here, and an unknown voice keeps its name so two rows never read the same.
enum VoiceDescription {
    struct Words: Equatable {
        var title: String
        var detail: String
    }

    /// Voices described from the reports (K14: Adam is a Swedish narrator voice; O12: Saga and Max are as clear,
    /// with more long pauses). Keyed by the lowercased first word of the service's name.
    static let known: [String: Words] = [
        "adam": Words(title: "Lugn berättarröst", detail: "Svensk, tydlig"),
    ]

    static func words(for choice: VoiceChoice, described: String? = nil) -> Words {
        switch choice.kind {
        case .apple:
            if choice.voiceID.isEmpty { return Words(title: "iPhonens röst", detail: "Fungerar utan nät") }
            let name = choice.name.replacingOccurrences(of: "Apple · ", with: "") // "Apple · Alva" → "Alva"
            return Words(title: name, detail: "iPhonens röst, fungerar utan nät")
        case .elevenLabs:
            if let described, !described.trimmingCharacters(in: .whitespaces).isEmpty {
                return Words(title: described, detail: "Svensk röst")
            }
            let key = choice.name.split(separator: " ").first.map { $0.lowercased() } ?? ""
            return known[key] ?? Words(title: choice.name, detail: "Svensk röst")
        }
    }
}
