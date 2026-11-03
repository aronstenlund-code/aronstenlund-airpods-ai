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
    /// System interruption in progress (call, Siri, alarm).
    case interruption
    /// Interruption ended but the system did not ask us to resume → "tap to resume".
    case awaitingUserResume
    /// AirPods / headphones were removed or disconnected.
    case outputDeviceLost
    /// Media services were reset; the audio engine was rebuilt and must be restarted by the user.
    case mediaServicesReset

    var label: String {
        switch self {
        case .interruption: "interrupted"
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
        case (.paused(.interruption), .interruptionEnded(let shouldResume)):
            return shouldResume ? (.listening, .resumeCapture) : (.paused(.awaitingUserResume), nil)
        case (.paused(let reason), .interruptionEnded):
            // We were already paused for another reason; stay there.
            return (.paused(reason), nil)
        case (.paused, .userResume):
            return (.listening, .resumeCapture)

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
