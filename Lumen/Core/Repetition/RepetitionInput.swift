import Foundation

/// D142: everything the repetition player can be told. The meaning never depends on what iOS thinks is playing.
enum RepetitionEvent: String, Equatable, Sendable, CaseIterable {
    /// 1 press: the long A+ answer.
    case long
    /// 2 presses: the short answer.
    case short
    /// 3 presses: pause, and 3 again: go on.
    case pauseToggle
}

/// D142: a source of `RepetitionEvent`s. AirPods (through the remote commands) are the first; a Bluetooth button or a
/// pen for 75 kr becomes one more source without the player changing.
@MainActor
protocol RepetitionInput: AnyObject {
    var onEvent: (@MainActor (RepetitionEvent) -> Void)? { get set }
    func begin()
    func end()
}

/// What reaches the app from AirPods, the Lock Screen and Control Center.
enum RemoteCommand: String, Equatable, Sendable {
    case play, pause, toggle, next, previous

    /// D142 §3: play, pause and toggle are all "1 press"; next track = 2 presses; previous track = 3 presses.
    var repetitionEvent: RepetitionEvent {
        switch self {
        case .play, .pause, .toggle: .long
        case .next: .short
        case .previous: .pauseToggle
        }
    }
}

/// AirPods as a `RepetitionInput`: takes over the shared `RemoteCommandHub` while the repetition runs.
@MainActor
final class AirPodsRepetitionInput: RepetitionInput {
    var onEvent: (@MainActor (RepetitionEvent) -> Void)?
    private let hub: RemoteCommandHub

    init(hub: RemoteCommandHub) {
        self.hub = hub
    }

    func begin() {
        hub.takeOver { [weak self] command in
            Log.repetition.info("Remote command \(command.rawValue, privacy: .public) → \(command.repetitionEvent.rawValue, privacy: .public)")
            self?.onEvent?(command.repetitionEvent)
        }
    }

    func end() {
        hub.release()
    }
}
