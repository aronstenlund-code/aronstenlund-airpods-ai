import Foundation
import MediaPlayer

/// The AirPods press (D74): play/pause remote commands reach the app that is "Now Playing". One press pauses Lumen
/// and lets go of the microphone so music can play, the next press listens again in the same mode.
///
/// What iOS does with the press is decided by the system, not by us. Lumen only gets it while it is the Now Playing
/// app: once Spotify plays after Lumen paused, the press goes to Spotify. The Siri phrase "Starta Lumen", the
/// Control and the Lock Screen button are the way back then (D58). **Untested on device.**
@MainActor
final class RemoteCommandHub {
    /// Play, pause and toggle all land here; `ListeningModel.togglePause` decides.
    var onToggle: (@MainActor () async -> Void)?
    var onPlay: (@MainActor () async -> Void)?
    var onPause: (@MainActor () async -> Void)?
    private var targets: [(MPRemoteCommand, Any)] = []

    /// Registers the commands once and says what is playing.
    func show(listening: Bool, mode: String) {
        if targets.isEmpty { register() }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: listening ? "Lumen lyssnar" : "Lumen är pausad",
            MPMediaItemPropertyArtist: mode,
            MPNowPlayingInfoPropertyPlaybackRate: listening ? 1.0 : 0.0,
        ]
    }

    /// The session ended: nothing is playing any more.
    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func register() {
        let center = MPRemoteCommandCenter.shared()
        let commands: [(MPRemoteCommand, @Sendable () -> Void)] = [
            (center.togglePlayPauseCommand, { [weak self] in Task { @MainActor in await self?.onToggle?() } }),
            (center.playCommand, { [weak self] in Task { @MainActor in await self?.onPlay?() } }),
            (center.pauseCommand, { [weak self] in Task { @MainActor in await self?.onPause?() } }),
        ]
        for (command, action) in commands {
            command.isEnabled = true
            targets.append((command, command.addTarget(handler: Self.handler(action))))
        }
    }

    /// Made outside the main actor: iOS calls remote command handlers on a queue of its choosing, and a main-actor
    /// closure would trap there (the crash of 2026-11-07).
    nonisolated static func handler(_ action: @escaping @Sendable () -> Void) -> @Sendable (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        { _ in run(action) }
    }

    /// The body of every handler, separate so a test can call it from another queue.
    nonisolated static func run(_ action: @Sendable () -> Void) -> MPRemoteCommandHandlerStatus {
        action()
        return .success
    }
}
