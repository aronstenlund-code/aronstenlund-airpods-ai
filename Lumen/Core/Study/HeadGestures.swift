import CoreMotion
import Foundation

/// D83 (D60, owner said yes): a nod is "ja", a shake is "nej", only to answer Provläge's yes/no check questions.
/// Fed pitch (nod) and yaw (shake) in radians from the AirPods' head tracking. Pure; unit-tested.
struct HeadGestureDetector: Sendable {
    enum Gesture: Equatable, Sendable { case nod, shake }

    /// A swing must be at least this large, and come back, within `window`.
    static let amplitude = 0.18
    static let window: TimeInterval = 1.4

    private var samples: [(at: Date, pitch: Double, yaw: Double)] = []

    mutating func reset() {
        samples.removeAll()
    }

    /// A gesture once both directions of the swing were seen; then it starts over.
    mutating func add(pitch: Double, yaw: Double, at date: Date) -> Gesture? {
        samples.append((date, pitch, yaw))
        samples.removeAll { date.timeIntervalSince($0.at) > Self.window }
        guard let first = samples.first else { return nil }
        if Self.swung(samples.map { $0.pitch - first.pitch }) {
            samples.removeAll()
            return .nod
        }
        if Self.swung(samples.map { $0.yaw - first.yaw }) {
            samples.removeAll()
            return .shake
        }
        return nil
    }

    /// Went at least `amplitude` one way and then came back at least half of it: a nod or a shake, not just a turn
    /// of the head.
    private static func swung(_ offsets: [Double]) -> Bool {
        guard let peakIndex = offsets.indices.max(by: { abs(offsets[$0]) < abs(offsets[$1]) }) else { return false }
        let peak = offsets[peakIndex]
        guard abs(peak) >= amplitude else { return false }
        let after = offsets[peakIndex...]
        return after.contains { peak > 0 ? $0 <= peak / 2 : $0 >= peak / 2 }
    }
}

/// The AirPods' head tracking, only while a yes/no question waits for an answer (D83).
@MainActor
final class HeadMotionListener {
    private let manager = CMHeadphoneMotionManager()
    private var detector = HeadGestureDetector()
    private var onGesture: (@MainActor (HeadGestureDetector.Gesture) -> Void)?
    private var stopTask: Task<Void, Never>?

    /// False on AirPods without head tracking (and in the Simulator): answer with the voice instead.
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Listens for `seconds`, then stops by itself.
    func listen(for seconds: TimeInterval, onGesture: @escaping @MainActor (HeadGestureDetector.Gesture) -> Void) {
        guard isAvailable else { return }
        stop()
        detector.reset()
        self.onGesture = onGesture
        manager.startDeviceMotionUpdates(to: .main, withHandler: Self.handler { [weak self] pitch, yaw in
            self?.received(pitch: pitch, yaw: yaw)
        })
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        onGesture = nil
    }

    private func received(pitch: Double, yaw: Double) {
        guard let gesture = detector.add(pitch: pitch, yaw: yaw, at: Date()) else { return }
        let callback = onGesture
        stop()
        callback?(gesture)
    }

    /// Made outside the main actor (the crash of 2026-11-07): CoreMotion calls it on the queue we give, but a
    /// main-actor closure must not depend on that. It hops to the main actor itself.
    nonisolated static func handler(_ action: @escaping @MainActor @Sendable (Double, Double) -> Void) -> CMHeadphoneDeviceMotionHandler {
        { motion, _ in
            guard let motion else { return }
            let pitch = motion.attitude.pitch
            let yaw = motion.attitude.yaw
            Task { @MainActor in action(pitch, yaw) }
        }
    }
}
