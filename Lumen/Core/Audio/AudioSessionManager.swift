import AVFAudio
import Foundation
import Observation

/// Events published by the session manager (all values are Sendable snapshots, never AVFoundation objects).
enum AudioSessionEvent: Sendable, Equatable {
    case activated(SessionSnapshot)
    /// Route re-read 1 s after activation — routes can change after `setActive` (Phase 1 §3.11).
    case routeSettled(SessionSnapshot)
    case interruptionBegan(reason: String)
    case interruptionEnded(shouldResume: Bool)
    case routeChanged(reason: String, outputLost: Bool, snapshot: SessionSnapshot)
    case mediaServicesReset
    case warning(String)
}

@MainActor
protocol AudioSessionManaging: AnyObject {
    var snapshot: SessionSnapshot? { get }
    var activeConfig: CaptureConfig? { get }
    var eventHandler: (@MainActor (AudioSessionEvent) -> Void)? { get set }

    func requestMicrophonePermission() async -> Bool
    /// Configures and activates the session for `config`, applies the preferred input, returns the snapshot.
    func activate(_ config: CaptureConfig) async throws(AudioError) -> SessionSnapshot
    /// Re-activates after an interruption (category/mode/options unchanged).
    func reactivate() throws(AudioError)
    func deactivate()
    func refreshSnapshot(engineInputFormat: String?) -> SessionSnapshot
}

@MainActor
@Observable
final class AudioSessionManager: AudioSessionManaging {
    private(set) var snapshot: SessionSnapshot?
    private(set) var activeConfig: CaptureConfig?
    var eventHandler: (@MainActor (AudioSessionEvent) -> Void)?

    private var lastPreferredInputResult: Bool?
    private var observers: [NSObjectProtocol] = []
    private var settleTask: Task<Void, Never>?

    init() {
        installObservers()
    }

    // MARK: - Permission

    func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            Log.session.error("Microphone permission denied (Settings)")
            return false
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            Log.session.info("Microphone permission request → \(granted ? "granted" : "denied", privacy: .public)")
            return granted
        @unknown default:
            return false
        }
    }

    // MARK: - Activation

    func activate(_ config: CaptureConfig) async throws(AudioError) -> SessionSnapshot {
        let session = AVAudioSession.sharedInstance()
        Log.session.info("Activating \(config.rawValue, privacy: .public): mode=\(config.modeName, privacy: .public) options=\(config.optionNames.joined(separator: ","), privacy: .public)")

        do {
            try session.setCategory(config.category, mode: config.mode, options: config.options)
        } catch {
            Log.session.error("setCategory failed: \(error.localizedDescription, privacy: .public)")
            throw AudioError.sessionConfiguration(config: config.rawValue, detail: error.localizedDescription)
        }

        do {
            try session.setPreferredIOBufferDuration(0.020)
        } catch {
            emit(.warning("setPreferredIOBufferDuration(20 ms) failed: \(error.localizedDescription)"))
        }

        do {
            try session.setActive(true, options: [])
        } catch {
            Log.session.error("setActive failed: \(error.localizedDescription, privacy: .public)")
            throw AudioError.sessionActivation(detail: error.localizedDescription)
        }

        lastPreferredInputResult = applyPreferredInput(for: config, on: session)
        activeConfig = config

        let snapshot = refreshSnapshot(engineInputFormat: nil)
        Log.session.info("Active: \(snapshot.banner, privacy: .public)")
        emit(.activated(snapshot))

        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled else { return }
            let settled = self.refreshSnapshot(engineInputFormat: self.snapshot?.engineInputFormat)
            Log.session.info("Route 1 s after activation: \(settled.banner, privacy: .public)")
            self.emit(.routeSettled(settled))
        }
        return snapshot
    }

    /// Returns true/false for the `setPreferredInput` call, nil when no matching input exists.
    private func applyPreferredInput(for config: CaptureConfig, on session: AVAudioSession) -> Bool? {
        guard let inputs = session.availableInputs, !inputs.isEmpty else {
            emit(.warning("availableInputs is empty — no microphone to prefer"))
            return nil
        }
        let wantBluetooth = config.inputPreference == .bluetooth
        let match = inputs.first { port in
            if wantBluetooth {
                return port.portType == .bluetoothHFP || port.portType == .bluetoothLE
            }
            return port.portType == .builtInMic
        }
        guard let match else {
            let names = inputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
            emit(.warning("No \(wantBluetooth ? "Bluetooth" : "built-in") input available. Inputs: \(names)"))
            return nil
        }
        do {
            try session.setPreferredInput(match)
            Log.session.info("setPreferredInput(\(match.portName, privacy: .public)) succeeded")
            return true
        } catch {
            emit(.warning("setPreferredInput(\(match.portName)) failed: \(error.localizedDescription)"))
            return false
        }
    }

    func reactivate() throws(AudioError) {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            throw AudioError.sessionActivation(detail: error.localizedDescription)
        }
        let snapshot = refreshSnapshot(engineInputFormat: self.snapshot?.engineInputFormat)
        Log.session.info("Reactivated: \(snapshot.banner, privacy: .public)")
    }

    func deactivate() {
        settleTask?.cancel()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            Log.session.info("Session deactivated")
        } catch {
            // Deactivation failures are common while IO is still running; surface, do not swallow.
            emit(.warning("setActive(false) failed: \(error.localizedDescription)"))
        }
        activeConfig = nil
    }

    @discardableResult
    func refreshSnapshot(engineInputFormat: String?) -> SessionSnapshot {
        let snapshot = SessionSnapshot.read(from: AVAudioSession.sharedInstance(),
                                            config: activeConfig,
                                            preferredInputSucceeded: lastPreferredInputResult,
                                            engineInputFormat: engineInputFormat)
        self.snapshot = snapshot
        return snapshot
    }

    // MARK: - Notifications

    private func installObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let info = note.userInfo
            let typeRaw = info?[AVAudioSessionInterruptionTypeKey] as? UInt ?? UInt.max
            let optionsRaw = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let reasonRaw = info?[AVAudioSessionInterruptionReasonKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw, reasonRaw: reasonRaw)
            }
        })

        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
            let info = note.userInfo
            let reasonRaw = info?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? UInt.max
            let previous = info?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
            let previousOutputs = previous?.outputs.map { PortInfo(port: $0) } ?? []
            MainActor.assumeIsolated {
                self?.handleRouteChange(reasonRaw: reasonRaw, previousOutputs: previousOutputs)
            }
        })

        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.session.error("Media services were reset")
                self?.emit(.mediaServicesReset)
            }
        })
    }

    private func handleInterruption(typeRaw: UInt, optionsRaw: UInt, reasonRaw: UInt?) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            var reason = "unknown"
            if let reasonRaw {
                if reasonRaw == AVAudioSession.InterruptionReason.default.rawValue { reason = "default" }
                else if reasonRaw == AVAudioSession.InterruptionReason.builtInMicMuted.rawValue { reason = "builtInMicMuted" }
                else if reasonRaw == AVAudioSession.InterruptionReason.routeDisconnected.rawValue { reason = "routeDisconnected" }
                else { reason = "raw=\(reasonRaw)" }
            }
            Log.session.warning("Interruption began (\(reason, privacy: .public))")
            emit(.interruptionBegan(reason: reason))
        case .ended:
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            Log.session.info("Interruption ended, shouldResume=\(shouldResume)")
            emit(.interruptionEnded(shouldResume: shouldResume))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt, previousOutputs: [PortInfo]) {
        let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw)
        let reasonName: String
        switch reason {
        case .unknown: reasonName = "unknown"
        case .newDeviceAvailable: reasonName = "newDeviceAvailable"
        case .oldDeviceUnavailable: reasonName = "oldDeviceUnavailable"
        case .categoryChange: reasonName = "categoryChange"
        case .override: reasonName = "override"
        case .wakeFromSleep: reasonName = "wakeFromSleep"
        case .noSuitableRouteForCategory: reasonName = "noSuitableRouteForCategory"
        case .routeConfigurationChange: reasonName = "routeConfigurationChange"
        case .none: reasonName = "raw=\(reasonRaw)"
        @unknown default: reasonName = "raw=\(reasonRaw)"
        }
        let outputLost = reason == .oldDeviceUnavailable && previousOutputs.contains(where: \.isExternalOutput)
        let snapshot = refreshSnapshot(engineInputFormat: self.snapshot?.engineInputFormat)
        Log.session.info("Route change \(reasonName, privacy: .public) outputLost=\(outputLost) → \(snapshot.banner, privacy: .public)")
        emit(.routeChanged(reason: reasonName, outputLost: outputLost, snapshot: snapshot))
    }

    private func emit(_ event: AudioSessionEvent) {
        if case .warning(let text) = event {
            Log.session.warning("\(text, privacy: .public)")
        }
        eventHandler?(event)
    }
}
