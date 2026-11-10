import Foundation
import Observation
import UIKit

/// A49 (D123): "Sov" starts a night, "Vakna" ends it and opens the morning report. Lumen's normal listening is ended
/// first (one microphone user at a time). The screen may lock; the background audio mode keeps the microphone on,
/// and iOS shows its indicator all night.
@MainActor
@Observable
final class SleepController {
    let store: SleepStore
    private(set) var night: SleepNight?
    private(set) var problem: String?
    /// The night that has just ended, for the morning report.
    var report: SleepNight?
    @ObservationIgnored private var recorder: SleepRecorder?
    @ObservationIgnored private var startBattery: Double?

    var isSleeping: Bool { night != nil }

    init(store: SleepStore = SleepStore()) {
        self.store = store
        store.removeOld()
    }

    func start() {
        guard night == nil else { return }
        let new = SleepNight(start: Date())
        let folder = store.folder(for: new)
        let recorder = SleepRecorder(folder: folder) { [weak self] event in
            Task { @MainActor in self?.record(event) }
        }
        do {
            try recorder.start()
        } catch {
            problem = "Sömnläget kunde inte starta mikrofonen."
            return
        }
        problem = nil
        UIDevice.current.isBatteryMonitoringEnabled = true
        startBattery = Self.battery()
        self.recorder = recorder
        night = new
        store.save(new)
        UIApplication.shared.isIdleTimerDisabled = false // the screen may sleep; the microphone goes on
    }

    func stop() {
        guard var finished = night else { return }
        recorder?.stop()
        recorder = nil
        finished.end = Date()
        if let start = startBattery, let end = Self.battery() { finished.batteryUsed = max(0, (start - end) * 100) }
        night = nil
        store.save(finished)
        report = finished
        transcribe(finished)
    }

    private func record(_ event: SleepRecorder.Event) {
        guard var current = night else { return }
        switch event {
        case .talk(let at, let seconds, let file):
            current.talks.append(SleepTalk(at: at, seconds: seconds, text: nil, clip: file.lastPathComponent))
        case .snore(let at, let seconds):
            current.snoreSeconds += seconds
            // One mark per 5 s is enough for the timeline and keeps a night's file small.
            if current.snores.last.map({ at.timeIntervalSince($0) >= 5 }) ?? true { current.snores.append(at) }
        case .noise(let at):
            current.noises.append(at)
        }
        night = current
        if case .talk = event { store.save(current) } // the counts are saved at the end; a clip at once
    }

    /// The words of each clip, on the phone, after the night (no work for the phone while it lies still).
    private func transcribe(_ finished: SleepNight) {
        Task { [weak self] in
            guard let self else { return }
            var updated = finished
            for (index, talk) in finished.talks.enumerated() where talk.text == nil {
                let url = self.store.clipURL(talk, in: finished)
                updated.talks[index].text = await SleepRecorder.transcribe(url)
            }
            self.store.save(updated)
            if self.report?.id == updated.id { self.report = updated }
        }
    }

    private static func battery() -> Double? {
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? Double(level) : nil
    }
}
