import MediaPlayer
import SwiftUI

/// A6.4: Settings › Röstkommandon. Every action with its phrases; the user adds and removes phrases. Default phrases
/// can be removed and come back with "Återställ". The whole utterance must match, as before.
struct VoiceCommandsView: View {
    @Bindable var store: CommandPhraseStore
    let music: MusicRemote
    @Bindable var voice: VoiceSettings
    @Bindable var tips: CommandTipStore
    @State private var search = ""

    private var actions: [CommandAction] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return CommandAction.allCases }
        return CommandAction.allCases.filter { action in
            action.title.lowercased().contains(query) || store.phrases(for: action).contains { $0.contains(query) }
        }
    }

    var body: some View {
        List {
            Section {
                Text("Säg frasen som hela meningen. Med \"Lumen\" först fungerar alla, utan \"Lumen\" bara musik och \"det där var fel\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Tips om kommandon (högst ett om dagen)", isOn: $tips.enabled)
                Toggle("Ton när du kan säga \"ja\" för mer", isOn: $voice.moreTone)
                Toggle("Korta ord utan \"Lumen\" i Provläge och Frågor", isOn: $voice.universalCommands)
                Text("\"Upprepa\", \"viska\", \"högre\", \"kortare\", \"snabbare\" och \"utveckla\" som hela meningen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(actions) { action in
                PhraseSection(store: store, action: action)
            }
            MusicPlayersSection(music: music)
        }
        .searchable(text: $search, prompt: "Sök kommando")
        .navigationTitle("Röstkommandon")
    }
}

private struct PhraseSection: View {
    @Bindable var store: CommandPhraseStore
    let action: CommandAction
    @State private var draft = ""
    @State private var warnings: [CommandWarning] = []

    var body: some View {
        Section {
            ForEach(store.phrases(for: action), id: \.self) { phrase in
                HStack {
                    Text(phrase)
                    Spacer()
                    if store.isDefault(phrase, for: action) {
                        Text("standard").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Ta bort", role: .destructive) { store.remove(phrase, from: action) }
                }
            }
            HStack {
                TextField(action.isPrefix ? "Ny fras (följs av fler ord)" : "Ny fras", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: draft) { _, value in
                        warnings = value.isEmpty ? [] : store.warnings(for: value, action: action)
                    }
                    .onSubmit(add)
                Button("Lägg till", action: add)
                    .disabled(warnings.contains(where: \.blocks) || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(warnings, id: \.text) { warning in
                Label(warning.text, systemImage: warning.blocks ? "xmark.octagon" : "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(warning.blocks ? .red : .orange)
            }
        } header: {
            HStack {
                Text(action.title)
                Spacer()
                Button("Återställ") { store.reset(action) }.font(.caption)
            }
        } footer: {
            if action == .backToLumen {
                Text("När musiken spelar hör Lumen inget. Säg \"Hej Siri, starta Lumen\" eller använd kontrollen på låsskärmen.")
            }
        }
    }

    private func add() {
        let found = store.add(draft, to: action)
        if found.contains(where: \.blocks) {
            warnings = found
        } else {
            draft = ""
            warnings = []
        }
    }
}

/// Which players the music commands reach (A6.3).
private struct MusicPlayersSection: View {
    let music: MusicRemote
    @State private var appleMusic = MPMediaLibrary.authorizationStatus()
    @State private var spotifyStatus = ""

    var body: some View {
        Section {
            if let spotify = music.spotify {
                HStack {
                    Text("Spotify")
                    Spacer()
                    Text(spotifyStatus.isEmpty ? spotify.status : spotifyStatus).foregroundStyle(.secondary)
                }
                Button("Koppla Spotify (öppnar Spotify)") {
                    spotify.link()
                    spotifyStatus = spotify.status
                }
            } else {
                Text("Spotify: inte aktiverat i den här versionen (Client ID saknas).").foregroundStyle(.secondary)
            }
            if appleMusic == .authorized {
                Label("Apple Music kan styras", systemImage: "checkmark")
            } else {
                Button("Tillåt styrning av Apple Music") {
                    // The async form: the callback form runs on a background queue (the main-actor trap of 2026-11-07).
                    Task { appleMusic = await MPMediaLibrary.requestAuthorization() }
                }
            }
        } header: {
            Text("Musik")
        } footer: {
            Text("\"Nästa låt\" och \"förra låten\" byter låt i Spotify när den är kopplad, annars i Apple Music. Annars: tryck två gånger på AirPods.")
        }
        .onAppear { spotifyStatus = music.spotify?.status ?? "" }
    }
}
