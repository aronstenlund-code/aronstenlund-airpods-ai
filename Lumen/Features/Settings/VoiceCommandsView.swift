import MediaPlayer
import SwiftUI

/// A6.4: Settings › Röstkommandon. Every action with its phrases; the user adds and removes phrases. Default phrases
/// can be removed and come back with "Återställ". The whole utterance must match, as before.
/// A18: the commands a beginner needs come first; the rest and the switches sit under "Alla kommandon". Search
/// still finds every command.
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

    /// The commands in Provläge's and Frågor's "Kommandon" sheet, in that order, each once.
    static var essentials: [CommandAction] {
        var seen: [CommandAction] = []
        for action in CommandTips.essentials(for: .prov) + CommandTips.essentials(for: .standard) where !seen.contains(action) {
            seen.append(action)
        }
        return seen
    }

    var body: some View {
        List {
            if search.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    ForEach(Self.essentials) { action in
                        PhraseSection(store: store, action: action)
                    }
                } header: {
                    Text("De viktigaste")
                } footer: {
                    Text("Börja med \"Lumen\", till exempel \"Lumen, förhör mig\". Du kan lägga till egna fraser.")
                }
                Section {
                    NavigationLink("Alla kommandon") {
                        AllVoiceCommandsView(store: store, music: music, voice: voice, tips: tips)
                    }
                }
            } else {
                ForEach(actions) { action in
                    PhraseSection(store: store, action: action)
                }
            }
        }
        .searchable(text: $search, prompt: "Sök kommando")
        .navigationTitle("Röstkommandon")
    }
}

/// A18: everything that is not for the first day: every command, the switches and the music players.
private struct AllVoiceCommandsView: View {
    @Bindable var store: CommandPhraseStore
    let music: MusicRemote
    @Bindable var voice: VoiceSettings
    @Bindable var tips: CommandTipStore

    var body: some View {
        List {
            Section {
                Text("Säg frasen som hela meningen. Med \"Lumen\" först fungerar alla, utan \"Lumen\" bara musik och \"det där var fel\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Tips om kommandon (högst ett om dagen)", isOn: $tips.enabled)
                Toggle("Ton när du kan säga \"ja\" för mer", isOn: $voice.moreTone)
                Toggle("Ljud när Earmind börjar och slutar lyssna", isOn: $voice.listeningCues) // A34
                Toggle("Korta ord utan \"Lumen\" i Provläge och Standardläge", isOn: $voice.universalCommands)
                Text("\"Upprepa\", \"viska\", \"högre\", \"kortare\", \"snabbare\" och \"utveckla\" som hela meningen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(CommandAction.allCases.filter { !VoiceCommandsView.essentials.contains($0) }) { action in
                PhraseSection(store: store, action: action)
            }
            MusicPlayersSection(music: music)
        }
        .navigationTitle("Alla kommandon")
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
                Text("När musiken spelar hör Earmind inget. Säg \"Hej Siri, starta Earmind\" eller använd kontrollen på låsskärmen.")
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
