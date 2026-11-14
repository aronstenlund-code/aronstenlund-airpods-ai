// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import XCTest

/// T23 (Toby 2): the states of A99 and A100 that a test account cannot reach for real, through Angela's Debug scenes
/// (`-LumenScreenshot <scene>`, `RepetitionScreenshots.swift`). No server, no ElevenLabs (D180).
/// - (1) A100: `repHomeNew` has no Fler lägen and no BETA line; `repHomeStarted` has both.
/// - (2) D175: `repQuotaUsedUp` says before Skapa frågor that the month's questions are used up.
/// - (3) D176: `repLength` shows "Lite längre än vanligt" and "Mycket lång" on the question rows, `repLengthEdit` the
///   note in the editor. Generated questions are nearly always normal (Oscar O60: 57/58), so a real one is rare.
/// - (4) K62/A100: `repSoundProblem` and `repHomeSoundProblem` show "Ljudet kan inte göras just nu" and no frozen
///   "Ljud: x av y klara". Test accounts get fake audio (K62b), so the real error cannot be caused from a test.
/// These are staged states: they show what the views do with the value, not that the server sends it.
/// `LUMEN_T23_STATES` must be set (from `scripts/apptest/states.sh`). Simulator only, never a device.
@MainActor
final class RepetitionStatesTests: XCTestCase {
    private var lines: [String] = []

    func testStates() throws {
        continueAfterFailure = true
        guard ProcessInfo.processInfo.environment["LUMEN_T23_STATES"] != nil else {
            throw XCTSkip("runs from scripts/apptest/states.sh")
        }
        check("repHomeNew", "(1) new user's Start", has: [], hasNot: ["Fler lägen", "Beta · använder mikrofonen"])
        check("repHomeStarted", "(1) Start after the first exam", has: ["Fler lägen", "Beta · använder mikrofonen"], hasNot: [])
        check("repQuotaUsedUp", "(2) Nytt prov with no questions left", has: ["Du har inga frågor kvar den här månaden*"], hasNot: [])
        check("repLength", "(3) question list with length classes", has: ["Lite längre än vanligt", "Mycket lång"], hasNot: [])
        check("repLengthEdit", "(3) editor of a very long question", has: ["Frågan och svaret är mycket långa*"], hasNot: [])
        check("repSoundProblem", "(4) question list when the sound cannot be made", has: ["*Ljudet kan inte göras just nu*"], hasNot: ["Ljud: * av * klara"])
        check("repHomeSoundProblem", "(4) Start when the sound cannot be made", has: ["*Ljudet kan inte göras just nu*"], hasNot: ["Ljud: * av * klara"])
        let summary = XCTAttachment(string: (["T23 states (Debug scenes, simulator, not a device)", ""] + lines).joined(separator: "\n") + "\n")
        summary.name = "t23-states-log"
        summary.lifetime = .keepAlways
        add(summary)
    }

    /// Launches a scene and looks for texts. A pattern with * matches any text (as in a shell glob).
    private func check(_ scene: String, _ what: String, has: [String], hasNot: [String]) {
        let app = XCUIApplication()
        app.launchArguments = ["-LumenScreenshot", scene, "-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
        app.launch()
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
        let tree = app.debugDescription
        let texts = Self.labels(in: tree)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "t23-\(scene)"
        shot.lifetime = .keepAlways
        add(shot)
        var problems: [String] = []
        for pattern in has where !texts.contains(where: { Self.matches($0, pattern) }) { problems.append("missing '\(pattern)'") }
        for pattern in hasNot {
            if let found = texts.first(where: { Self.matches($0, pattern) }) { problems.append("has '\(found)'") }
        }
        lines.append("\(problems.isEmpty ? "OK " : "FEL") \(scene): \(what)" + (problems.isEmpty ? "" : " — " + problems.joined(separator: "; ")))
        lines.append("    texts: " + texts.prefix(40).joined(separator: " | "))
        for problem in problems { XCTFail("[t23] \(scene): \(problem)") }
        app.terminate()
    }

    nonisolated static func matches(_ text: String, _ pattern: String) -> Bool {
        NSPredicate(format: "SELF LIKE %@", pattern).evaluate(with: text)
    }

    /// Every label in a `debugDescription` tree ("…, label: 'Fler lägen'").
    nonisolated static func labels(in tree: String) -> [String] {
        tree.split(separator: "\n").compactMap { line -> String? in
            guard let start = line.range(of: "label: '") else { return nil }
            let rest = line[start.upperBound...]
            guard let end = rest.range(of: "'", options: .backwards), end.lowerBound > rest.startIndex else { return nil }
            return String(rest[..<end.lowerBound])
        }
    }
}
#endif
