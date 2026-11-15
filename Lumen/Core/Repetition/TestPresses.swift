#if DEBUG
import CoreFoundation
import Foundation

/// Toby (moln) T27/T28: XCUITest cannot press AirPods, so a Debug UI test sends the presses as Darwin notifications.
/// Only in Debug builds and only with the launch environment `LUMEN_TEST_PRESSES=1`: the test runs
/// `xcrun simctl spawn booted notifyutil -p earmind.test.press.1` (or `.2`, `.3`), and the press goes to
/// `RepetitionSession.press`, the same path as the AirPods' remote commands. It reaches the questions' player and,
/// in the reading mode, `ReadingPlayer` (1 = pause/go on, 2 = next sentence, 3 = previous). No sound is made by the
/// hook itself; 0 ElevenLabs (D180).
@MainActor
final class TestPresses {
    nonisolated static let environmentKey = "LUMEN_TEST_PRESSES"
    nonisolated static let names = ["earmind.test.press.1", "earmind.test.press.2", "earmind.test.press.3"]

    private let session: RepetitionSession
    /// The presses received, newest last, for the tests.
    private(set) var received: [RepetitionEvent] = []

    /// Nil unless the UI test asked for the hook.
    init?(session: RepetitionSession, environment: [String: String] = ProcessInfo.processInfo.environment,
          listen: Bool = true) {
        guard environment[Self.environmentKey] == "1" else { return nil }
        self.session = session
        if listen { Self.register(Unmanaged.passUnretained(self).toOpaque()) }
        Log.repetition.info("Test presses: listening for \(Self.names.joined(separator: ", "), privacy: .public)")
    }

    /// 1, 2 or 3 presses, as the AirPods send them (D142).
    nonisolated static func event(for name: String) -> RepetitionEvent? {
        switch name {
        case "earmind.test.press.1": .long
        case "earmind.test.press.2": .short
        case "earmind.test.press.3": .pauseToggle
        default: nil
        }
    }

    /// A notification's press, on the main actor.
    func press(named name: String) {
        guard let event = Self.event(for: name) else { return }
        received.append(event)
        Log.repetition.info("Test press \(name, privacy: .public) → \(event.rawValue, privacy: .public)")
        session.press(event)
    }

    /// The observer lives as long as the app (the container keeps it), so it is never removed.
    nonisolated private static func register(_ observer: UnsafeMutableRawPointer) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        for name in names {
            CFNotificationCenterAddObserver(center, observer, { _, observer, name, _, _ in
                guard let observer, let name else { return }
                let raw = name.rawValue as String
                let address = UInt(bitPattern: observer)
                Task { @MainActor in
                    guard let pointer = UnsafeRawPointer(bitPattern: address) else { return }
                    Unmanaged<TestPresses>.fromOpaque(pointer).takeUnretainedValue().press(named: raw)
                }
            }, name as CFString, nil, .deliverImmediately)
        }
    }
}
#endif
