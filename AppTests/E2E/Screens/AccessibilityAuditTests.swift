// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import XCTest

/// For Angela Fable's A95 (VoiceOver and accessibility in the repetition mode): XCTest's accessibility audit (the
/// same checks as Accessibility Inspector) on each Debug scene of `ScreenshotStage` (`-LumenScreenshot <scene>`, as
/// `.github/workflows/screenshots.yml`). Per scene two attachments: `a11y-<scene>.audit` (every issue with its type,
/// descriptions and the element's label, identifier and frame) and `a11y-<scene>.tree` (`debugDescription`, the
/// accessibility tree in reading order). Findings never fail the test: Angela reads the files and fixes the views.
///
/// `LUMEN_A11Y_SCENES` (space separated) comes from `scripts/apptest/a11y.sh`; without it the test is skipped, so the
/// T3 screen tour that runs this target is unchanged. Simulator only: never a verification on a device.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    func testAuditEveryScene() throws {
        continueAfterFailure = true
        guard let list = ProcessInfo.processInfo.environment["LUMEN_A11Y_SCENES"], !list.isEmpty else {
            throw XCTSkip("runs from scripts/apptest/a11y.sh")
        }
        let scenes = list.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        var summary: [String] = []
        for scene in scenes {
            let app = XCUIApplication()
            app.launchArguments = ["-LumenScreenshot", scene, "-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
            app.launch()
            RunLoop.current.run(until: Date().addingTimeInterval(2))

            var issues: [String] = []
            var types: [String: Int] = [:]
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
            let head = "\(scene): \(issues.count) issues" + (types.isEmpty ? "" : " (" + types.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ") + ")")
            summary.append(head)
            attach("a11y-\(scene).audit", ([head, ""] + issues).joined(separator: "\n\n") + "\n")
            attach("a11y-\(scene).tree", app.debugDescription)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "a11y-\(scene)"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
        attach("a11y-summary", summary.joined(separator: "\n") + "\n")
    }

    private func attach(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
