import Foundation
import Observation

/// Runs the Provläge machine on the live capture: one level reading per 40 ms chunk (silence included), the
/// transcript from the recogniser, and the answer/speech lifecycle from `ListeningModel`.
@MainActor
@Observable
final class StudySessionController {
    let settings: StudySettings
    private(set) var machine: StudyMachine
    /// Why the last session ended, for the notice line.
    private(set) var endedBySilence = false
    var onEvent: (@MainActor (StudyEvent) -> Void)?

    /// Set before `start` for a mode that reacts to silence (Rizzläge).
    var stallSilence: TimeInterval?
    private let session: SessionController
    private var levelSubscription: UUID?
    private var levelTask: Task<Void, Never>?

    init(settings: StudySettings, session: SessionController) {
        self.settings = settings
        self.session = session
        self.machine = StudyMachine(tuning: settings.tuning)
    }

    var phase: StudyPhase { machine.phase }
    var isActive: Bool { machine.phase != .off }
    var isUserSpeaking: Bool { machine.isUserSpeaking }
    var noiseFloorDBFS: Double? { machine.noiseFloorDBFS }
    var lastTurnLevelDBFS: Double? { machine.lastTurnLevelDBFS }

    func someoneIsTalking(at now: Date = Date()) -> Bool { machine.someoneIsTalking(at: now) }

    func start(at now: Date = Date()) {
        machine.tuning = settings.tuning
        machine.tuning.stallSilence = stallSilence
        endedBySilence = false
        machine.start(at: now)
        subscribeToLevels()
        Log.session.info("Provläge started · endpoint \(self.machine.tuning.endpointSilence, privacy: .public) s · auto-end \(self.machine.tuning.autoEndSilence.map { "\(Int($0)) s" } ?? "never", privacy: .public)")
    }

    func stop() {
        machine.stop()
        unsubscribeFromLevels()
        Log.session.info("Provläge ended")
    }

    // MARK: Inputs

    func level(_ rmsDBFS: Double, at now: Date = Date()) {
        guard let event = machine.level(rmsDBFS, at: now) else { return }
        if event == .autoEnded {
            endedBySilence = true
            unsubscribeFromLevels()
        }
        onEvent?(event)
    }

    func transcriptPartial(_ text: String) {
        machine.transcriptPartial(text)
    }

    func transcriptFinal(_ text: String, at now: Date = Date()) {
        if let event = machine.transcriptFinal(text, at: now) {
            onEvent?(event)
        }
    }

    func answerStarted() { machine.answerStarted() }
    func speechStarted() { machine.speechStarted() }
    func resumeListening(at now: Date = Date()) { machine.resumeListening(at: now) }

    // MARK: Levels from the capture fan-out

    private func subscribeToLevels() {
        unsubscribeFromLevels()
        let subscription = session.subscribeToChunks()
        levelSubscription = subscription.id
        levelTask = Task { [weak self] in
            for await chunk in subscription.stream {
                guard let self else { return }
                self.level(AudioLevel.reading(chunk.samples).rmsDBFS, at: Date())
            }
        }
    }

    private func unsubscribeFromLevels() {
        levelTask?.cancel()
        levelTask = nil
        if let id = levelSubscription {
            session.unsubscribeFromChunks(id)
            levelSubscription = nil
        }
    }
}
