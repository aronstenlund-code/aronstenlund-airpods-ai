import Foundation

/// Minimal session state machine for Phase 1 (ARCHITECTURE §11: idle → listening → paused → error).
enum SessionState: Equatable, Sendable {
    case idle
    case listening
    case paused(PauseReason)
    case error(String)

    var isListening: Bool { self == .listening }

    var label: String {
        switch self {
        case .idle: "Idle"
        case .listening: "Listening"
        case .paused(let reason): "Paused — \(reason.label)"
        case .error(let message): "Error — \(message)"
        }
    }
}

enum PauseReason: Equatable, Sendable {
    /// The user paused, e.g. to play music (D33). The audio session is released; only the user resumes.
    case user
    /// Another app or the system took the audio (call, Siri, alarm, Spotify). May never end for a music app.
    case interruption
    /// Interruption ended, or a resume was refused → "tap to resume". We never take audio back by ourselves (D33).
    case awaitingUserResume
    /// AirPods / headphones were removed or disconnected.
    case outputDeviceLost
    /// Media services were reset; the audio engine was rebuilt and must be restarted by the user.
    case mediaServicesReset

    var label: String {
        switch self {
        case .user: "by you"
        case .interruption: "interrupted — tap to resume"
        case .awaitingUserResume: "tap to resume"
        case .outputDeviceLost: "AirPods disconnected — tap to resume"
        case .mediaServicesReset: "audio system reset — tap to resume"
        }
    }
}

/// Inputs to the reducer. UI actions and audio-session notifications both become events.
enum SessionEvent: Equatable, Sendable {
    case userStart
    case userStop
    case userResume
    case userPause
    /// A resume could not get the audio back (a call is running, background rules).
    case resumeFailed
    case captureStarted
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case outputDeviceLost
    case outputDeviceRestored
    case mediaServicesReset
    case failed(String)
}

/// Side effects the owner must perform after a transition.
enum SessionEffect: Equatable, Sendable {
    case startCapture
    case stopCapture
    case resumeCapture
    case pauseCapture
    case rebuildAudioGraph
}

/// Pure transition function — unit-tested without hardware (Phase 1 §7 "session state transitions").
enum SessionReducer {
    static func reduce(_ state: SessionState, _ event: SessionEvent) -> (SessionState, SessionEffect?) {
        switch (state, event) {
        case (.idle, .userStart), (.error, .userStart):
            return (.listening, .startCapture)
        case (.listening, .captureStarted):
            return (.listening, nil)
        case (.listening, .userStop), (.paused, .userStop), (.error, .userStop):
            return (.idle, .stopCapture)
        case (.idle, .userStop):
            return (.idle, nil)

        case (.listening, .interruptionBegan):
            return (.paused(.interruption), .pauseCapture)
        case (.paused(.interruption), .interruptionEnded):
            // Even with `shouldResume`: taking audio back could cut off what the user is listening to (D33).
            return (.paused(.awaitingUserResume), nil)
        case (.paused(let reason), .interruptionEnded):
            // We were already paused for another reason; stay there.
            return (.paused(reason), nil)
        case (.paused, .userResume):
            return (.listening, .resumeCapture)
        case (.listening, .userPause):
            // Same effect as stopping: engine off, session released so the other app resumes in full quality.
            return (.paused(.user), .stopCapture)
        case (.listening, .resumeFailed):
            return (.paused(.awaitingUserResume), .pauseCapture)

        case (.paused(.user), .outputDeviceLost):
            return (.paused(.user), nil)
        case (.listening, .outputDeviceLost), (.paused, .outputDeviceLost):
            return (.paused(.outputDeviceLost), .pauseCapture)
        case (.paused(.outputDeviceLost), .outputDeviceRestored):
            // Do not auto-resume capture when the AirPods come back; the user taps to resume.
            return (.paused(.awaitingUserResume), nil)

        case (.listening, .mediaServicesReset), (.paused, .mediaServicesReset):
            return (.paused(.mediaServicesReset), .rebuildAudioGraph)
        case (.idle, .mediaServicesReset), (.error, .mediaServicesReset):
            return (state, .rebuildAudioGraph)

        case (_, .failed(let message)):
            return (.error(message), .stopCapture)

        default:
            return (state, nil)
        }
    }
}
