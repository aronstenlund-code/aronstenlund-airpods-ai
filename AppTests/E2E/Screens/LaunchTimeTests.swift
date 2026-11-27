// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import XCTest

/// T62 (Toby (moln), Deangelo 2026-11-27 05:19): the app's start time in the Simulator, before and after Angela
/// Schrute's fast start. The same test runs on both apps (`scripts/apptest/t62.sh`): from `launch()` to the first
/// screen a user can use, six times each, after one warm-up launch that is not counted. (1) A new installation: to
/// "Välkommen till EarMind" (nothing is tapped, so every launch is a first start). (2) After the first start (Fortsätt
/// → Senare): to Start ("Nytt prov" hittable). The app is terminated between launches (cold for the process; the
/// Simulator's own caches stay warm). Simulator times are not a phone's: only the difference between the two apps
/// on the same runner says anything. Output: `<LUMEN_T62_OUT>/launch-<label>.json`.
@MainActor
final class LaunchTimeTests: XCTestCase {
    func testLaunchTime() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["LUMEN_T62_OUT"] else { throw XCTSkip("T62 runs from scripts/apptest/t62.sh") }
        let label = env["LUMEN_T62_LABEL"] ?? "app"
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
        app.launchEnvironment["LUMEN_TEST_HEADER"] = "1"

        func timed(until labels: [String], hittable: Bool = false) -> Double? {
            app.terminate()
            let t0 = Date()
            app.launch()
            let deadline = t0.addingTimeInterval(60)
            while Date() < deadline {
                for label in labels {
                    let element = app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
                    if element.exists, !hittable || element.isHittable { return Date().timeIntervalSince(t0) }
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            return nil
        }

        _ = timed(until: ["Välkommen till EarMind"]) // warm-up, not counted
        let welcome = (0..<6).compactMap { _ in timed(until: ["Välkommen till EarMind"]) }
        // The first start once (Fortsätt → the consent's Senare), then Start is the first screen.
        for label in ["Fortsätt", "Senare"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 10) { button.tap() }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        let start = (0..<6).compactMap { _ in timed(until: ["Nytt prov"], hittable: true) }
        app.terminate()

        func stats(_ values: [Double]) -> [String: Double] {
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return [:] }
            return ["median": sorted[sorted.count / 2], "min": sorted.first!, "max": sorted.last!,
                    "mean": sorted.reduce(0, +) / Double(sorted.count)]
        }
        let result: [String: Any] = ["label": label, "welcome": welcome, "start": start,
                                     "welcomeStats": stats(welcome), "startStats": stats(start)]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: folder).appending(path: "launch-\(label).json"))
        print("T62 \(label): welcome \(welcome.map { String(format: "%.2f", $0) }) start \(start.map { String(format: "%.2f", $0) })")
        XCTAssertEqual(welcome.count, 6, "Välkommen did not come on every launch")
        XCTAssertEqual(start.count, 6, "Start did not come on every launch")
    }
}
#endif
