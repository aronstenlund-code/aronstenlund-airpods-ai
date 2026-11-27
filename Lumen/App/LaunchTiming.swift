import Darwin
import Foundation
import os

/// Deangelo 2026-11-27 04:10: the time from launch to the first screen, measured at every launch. From the process's own
/// start (the kernel's clock) to the first screen's first frame; logged in Diagnostik ("Launch: …") and as a signpost.
@MainActor
enum LaunchTiming {
    /// When the process began; when the kernel does not say, when this code first ran (later, so it measures less).
    static let processStart: Date = processStartTime() ?? Date()
    /// The first screen's first frame, once per launch.
    private(set) static var firstScreenAt: Date?
    /// The milliseconds to the first screen, once it has been shown.
    static var firstScreenMs: Int? { firstScreenAt.map { milliseconds(from: processStart, to: $0) } }

    nonisolated static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int((end.timeIntervalSince(start) * 1000).rounded()))
    }

    nonisolated static func line(_ ms: Int) -> String { "Launch: first screen after \(ms) ms" }

    /// Called from the first screen's first frame. True the first time (the line is logged once).
    @discardableResult
    static func firstScreenShown(at date: Date = Date()) -> Bool {
        guard firstScreenAt == nil else { return false }
        firstScreenAt = date
        let ms = milliseconds(from: processStart, to: date)
        Log.signposter.emitEvent("launch.firstScreen", "\(ms, privacy: .public) ms")
        Log.app.info("\(line(ms), privacy: .public)")
        return true
    }

    /// The process's start time from the kernel (`kinfo_proc.kp_proc.p_starttime`).
    nonisolated static func processStartTime() -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let started = info.kp_proc.p_un.__p_starttime
        guard started.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(started.tv_sec) + Double(started.tv_usec) / 1_000_000)
    }
}
