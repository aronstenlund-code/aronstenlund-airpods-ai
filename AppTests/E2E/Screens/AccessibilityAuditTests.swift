// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import XCTest

/// For Angela Fable's A95 (VoiceOver and accessibility in the repetition mode): XCTest's accessibility audit (the
/// same checks as Accessibility Inspector) on each Debug scene of `ScreenshotStage` (`-LumenScreenshot <scene>`, as
/// `.github/workflows/screenshots.yml`). Per scene, written to `LUMEN_A11Y_OUT` as soon as the scene is done:
/// `a11y-<scene>.audit.txt` (every issue with its type, descriptions and the element's label, identifier and frame),
/// `a11y-<scene>.tree.txt` (`debugDescription`, the accessibility tree in reading order) and `a11y-<scene>.png`.
/// `a11y-<scene>.started` is written before the audit, so `scripts/apptest/a11y.sh` knows which scene got stuck when
/// it has to stop a run (run 43590746967: the SE with the largest text stopped inside an audit and lost every file).
/// Findings never fail the test: Angela reads the files and fixes the views.
///
/// `LUMEN_A11Y_SCENES` (space separated) comes from `scripts/apptest/a11y.sh`; without it the test is skipped, so the
/// T3 screen tour that runs this target is unchanged. Simulator only: never a verification on a device.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    func testAuditEveryScene() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard let list = env["LUMEN_A11Y_SCENES"], !list.isEmpty else {
            throw XCTSkip("runs from scripts/apptest/a11y.sh")
        }
        let out = URL(fileURLWithPath: env["LUMEN_A11Y_OUT"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let scenes = list.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        for scene in scenes {
            write(out, "a11y-\(scene).started", "\(Date())\n")
            let app = XCUIApplication()
            app.launchArguments = ["-LumenScreenshot", scene, "-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
            app.launch()
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            try? app.screenshot().pngRepresentation.write(to: out.appendingPathComponent("a11y-\(scene).png"))
            write(out, "a11y-\(scene).tree.txt", app.debugDescription)

            var issues: [String] = []
            var types: [String: Int] = [:]
            let started = Date()
            do {
                try app.performAccessibilityAudit(for: .all) { issue in
                    let type = Self.name(of: issue.auditType)
                    types[type, default: 0] += 1
                    var line = "ISSUE \(issues.count + 1) [\(type)] \(issue.compactDescription)\n  \(issue.detailedDescription)"
                    if let element = issue.element, element.exists {
                        line += "\n  element: \(element.elementType.rawValue) label='\(element.label)' identifier='\(element.identifier)' frame=\(NSCoder.string(for: element.frame))"
                    } else {
                        line += "\n  element: (none)"
                    }
                    issues.append(line)
                    return true // recorded, not a failure: go on
                }
            } catch {
                issues.append("AUDIT ERROR: \(error)")
            }
            let seconds = Int(Date().timeIntervalSince(started))
            let head = "\(scene): \(issues.count) issues" + (types.isEmpty ? "" : " (" + types.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ") + ")") + ", audit \(seconds) s"
            write(out, "a11y-\(scene).audit.txt", ([head, ""] + issues).joined(separator: "\n\n") + "\n")
            app.terminate()
        }
    }

    private func write(_ dir: URL, _ name: String, _ text: String) {
        try? text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    nonisolated private static func name(of type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"), (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"), (.trait, "trait"),
        ]
        return names.first { type.contains($0.0) }?.1 ?? "type \(type.rawValue)"
    }
}
#endif
