import Darwin
import Foundation
import UIKit

/// D81: battery and CPU per 10 minutes of listening, with the voice work in the same line, so the cost of the
/// speaker labels can be read off a real session (Settings → Diagnostics log).
struct ResourceSample: Equatable, Sendable {
    var at: Date
    /// User + system CPU time of the whole app, seconds.
    var cpuSeconds: Double
    /// 0–1, or nil when iOS does not say (Simulator).
    var battery: Double?

    @MainActor static func now() -> ResourceSample {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        let level = UIDevice.current.batteryLevel
        return ResourceSample(at: Date(), cpuSeconds: cpu, battery: level >= 0 ? Double(level) : nil)
    }

    /// "CPU 6.4 % · battery −3 % · 10 min"
    static func line(from start: ResourceSample, to end: ResourceSample) -> String {
        let wall = max(1, end.at.timeIntervalSince(start.at))
        let cpu = (end.cpuSeconds - start.cpuSeconds) / wall * 100
        var parts = [String(format: "CPU %.1f %%", cpu)]
        if let a = start.battery, let b = end.battery {
            parts.append(String(format: "battery %+.0f %%", (b - a) * 100))
        } else {
            parts.append("battery n/a")
        }
        parts.append(String(format: "%.0f min", wall / 60))
        return parts.joined(separator: " · ")
    }
}

@MainActor
final class ResourceMeter {
    static let interval: TimeInterval = 600
    private var task: Task<Void, Never>?
    private var since: ResourceSample?

    /// Starts measuring; `report` gets one line every 10 minutes until `stop`.
    func start(report: @escaping @MainActor @Sendable (ResourceSample, ResourceSample) -> Void) {
        guard task == nil else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        since = .now()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.interval))
                guard let self, !Task.isCancelled, let from = self.since else { return }
                let to = ResourceSample.now()
                report(from, to)
                self.since = to
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        since = nil
    }
}
