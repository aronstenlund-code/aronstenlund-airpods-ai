import Foundation
import MediaPlayer

/// A6.3: "nästa låt", "förra låten", "pausa musiken", "spela musik" for the player the user has. Spotify through its
/// App Remote SDK when the app is linked (needs a Client ID, the Spotify app, and a link made in the foreground),
/// Apple Music through the system music player when it is the one with something loaded. Nothing else can be
/// controlled from another app on iOS. **Untested on device.**
@MainActor
protocol MusicControlling: AnyObject {
    var name: String { get }
    /// The player can take a command right now.
    var isAvailable: Bool { get }
    func perform(_ action: CommandAction)
}

/// Apple Music only: `systemMusicPlayer` is the Music app's queue, so it is used only when that queue has a song.
/// Otherwise `play()` would start Apple Music over the user's Spotify.
@MainActor
final class SystemMusicRemote: MusicControlling {
    let name = "Apple Music"

    var isAvailable: Bool {
        MPMediaLibrary.authorizationStatus() == .authorized && MPMusicPlayerController.systemMusicPlayer.nowPlayingItem != nil
    }

    func perform(_ action: CommandAction) {
        let player = MPMusicPlayerController.systemMusicPlayer
        switch action {
        case .nextTrack: player.skipToNextItem()
        case .previousTrack: player.skipToPreviousItem()
        case .pauseMusic: player.pause()
        case .musicHandOff: player.play()
        default: break
        }
    }
}

/// Picks the player for a music command and says what happened, for the confirmation in the AirPods.
@MainActor
final class MusicRemote {
    enum Outcome: Equatable, Sendable {
        /// A player took the command.
        case done(player: String)
        /// No player can be controlled: the music plays on its own after Lumen let go (D58).
        case notControllable
    }

    let players: [any MusicControlling]
    var onLog: ((String) -> Void)?

    init(players: [any MusicControlling]) {
        self.players = players
    }

    /// The Spotify link, if this build has a Client ID.
    var spotify: (any SpotifyLink)? { players.compactMap { $0 as? any SpotifyLink }.first }

    @discardableResult
    func perform(_ action: CommandAction) -> Outcome {
        guard let player = players.first(where: \.isAvailable) else {
            onLog?("Music: no player to control (\(action.rawValue))")
            return .notControllable
        }
        player.perform(action)
        onLog?("Music: \(action.rawValue) → \(player.name)")
        return .done(player: player.name)
    }

    /// The Client ID comes from the build (`SPOTIFY_CLIENT_ID` → Info.plist `LumenSpotifyClientID`), never the repo.
    static func live(bundle: Bundle = .main) -> MusicRemote {
        var players: [any MusicControlling] = []
        let clientID = (bundle.object(forInfoDictionaryKey: "LumenSpotifyClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let spotify = makeSpotifyLink(clientID: clientID) { players.append(spotify) }
        players.append(SystemMusicRemote())
        return MusicRemote(players: players)
    }
}

/// What Settings shows about Spotify (A6.3), with or without the SDK in the build.
@MainActor
protocol SpotifyLink: MusicControlling {
    /// Opens Spotify once to get a token (about an hour); Spotify starts playing.
    func link()
    /// The redirect back from Spotify. True when it was ours.
    func handle(_ url: URL) -> Bool
    var status: String { get }
}

#if canImport(SpotifyiOS)
@preconcurrency import SpotifyiOS

@MainActor
private func makeSpotifyLink(clientID: String) -> (any SpotifyLink)? {
    clientID.isEmpty ? nil : SpotifyRemote(clientID: clientID)
}

/// Spotify App Remote (A6.3). Limits from Spotify's docs: the Spotify app must be installed and playing when we
/// connect; the token comes from an app switch to Spotify (foreground) and lasts about an hour; Spotify asks apps to
/// disconnect in the background, so we connect for one command and disconnect after it.
@MainActor
final class SpotifyRemote: NSObject, SpotifyLink {
    static let redirectURL = URL(string: "lumen-spotify://callback")!
    let name = "Spotify"
    private let appRemote: SPTAppRemote
    private var token: (value: String, expires: Date)?
    private var waiting: [CommandAction] = []
    private(set) var status = "Inte kopplad"

    init(clientID: String) {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: Self.redirectURL)
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .error)
        super.init()
        appRemote.delegate = self
    }

    var isAvailable: Bool {
        guard let token else { return false }
        return token.expires > Date()
    }

    func link() {
        status = "Öppnar Spotify …"
        appRemote.authorizeAndPlayURI("", completionHandler: nil)
    }

    func handle(_ url: URL) -> Bool {
        guard url.scheme == Self.redirectURL.scheme else { return false }
        let parameters = appRemote.authorizationParameters(from: url)
        if let value = parameters?[SPTAppRemoteAccessTokenKey] {
            token = (value, Date().addingTimeInterval(55 * 60))
            appRemote.connectionParameters.accessToken = value
            status = "Kopplad (i cirka en timme)"
        } else {
            status = "Kopplingen misslyckades: " + (parameters?[SPTAppRemoteErrorDescriptionKey] ?? "okänt fel")
        }
        return true
    }

    func perform(_ action: CommandAction) {
        if appRemote.isConnected, let api = appRemote.playerAPI {
            send(action, to: api)
            return
        }
        waiting.append(action)
        appRemote.connect()
    }

    /// By selector: the Objective-C names (`skipToNext:`) are the stable part of the SDK, not their Swift spelling.
    private func send(_ action: CommandAction, to api: any SPTAppRemotePlayerAPI) {
        let selector: String
        switch action {
        case .nextTrack: selector = "skipToNext:"
        case .previousTrack: selector = "skipToPrevious:"
        case .pauseMusic: selector = "pause:"
        case .musicHandOff: selector = "resume:"
        default: return
        }
        _ = (api as AnyObject).perform(NSSelectorFromString(selector), with: nil)
    }
}

extension SpotifyRemote: @preconcurrency SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        status = "Kopplad"
        if let api = appRemote.playerAPI {
            for action in waiting { send(action, to: api) }
        }
        waiting.removeAll()
        // Spotify's guideline: no connection kept in the background. A moment first, so the command arrives.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.appRemote.disconnect()
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: (any Error)?) {
        waiting.removeAll()
        status = "Spotify svarar inte. Spelar musiken?"
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: (any Error)?) {
        if error != nil { status = "Frånkopplad" }
    }
}
#else
@MainActor
private func makeSpotifyLink(clientID: String) -> (any SpotifyLink)? { nil }
#endif
