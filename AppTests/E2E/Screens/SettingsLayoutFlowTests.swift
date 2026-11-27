// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import XCTest

/// T63 (Toby (moln), Deangelo 2026-11-27 05:19): Angela Schrute's short Inställningar. From a new installation:
/// (1) the most important at the top, on the first screen without scrolling: the app's language (`settings.appLanguage`),
/// the activation words, the voice and the credits (`settings.credits`); (2) what must always be found, with Avancerat
/// folded in: Historik, Integritet och samtycke, the account (Radera konto), Hjälp/Feedback, Om appen; (3) the rest only
/// after Avancerat (`settings.advanced`) is folded out: Röstkommandon, Minne, Anteckningar, Studiekort, Förberedelser,
/// Egna kommandon, Diagnostik, and folded in again with one more tap. Simulator only. `scripts/apptest/t62.sh` with
/// TEST=SettingsLayoutFlowTests.
@MainActor
final class SettingsLayoutFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var log: [String] = []

    func testSettingsLayout() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["LUMEN_T62_OUT"] else { throw XCTSkip("T63 runs from scripts/apptest/t62.sh") }
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE", "-settings.showsAdvanced", "NO"]
        app.launchEnvironment["LUMEN_TEST_HEADER"] = "1"
        app.launch()
        defer {
            try? log.joined(separator: "\n").write(to: URL(fileURLWithPath: folder).appending(path: "t63-log.txt"), atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(app.staticTexts["Välkommen till EarMind"].waitForExistence(timeout: 30), "Välkommen")
        for label in ["Fortsätt", "Senare"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 10) { button.tap() }
            pause(1)
        }
        let open = app.buttons["Inställningar"]
        XCTAssertTrue(open.waitForExistence(timeout: 15), "the Inställningar button on Start")
        open.tap()
        XCTAssertTrue(app.buttons["Klar"].waitForExistence(timeout: 10), "the settings sheet")
        pause(1.5)
        shoot("installningar-overst")

        // (1) The top, without scrolling.
        let top: [(String, XCUIElement)] = [
            ("language", element("settings.appLanguage")),
            ("activation words", any(["activation.words"], labels: ["Aktiveringsord*", "Eget aktiveringsord*"])),
            ("voice", any([], labels: ["Röst*", "Rösten*", "Röster*"])),
            ("credits", element("settings.credits")),
        ]
        for (name, item) in top {
            let seen = item.exists && item.isHittable
            log.append("top \(name): exists \(item.exists), on the first screen \(seen)\(item.exists ? " (\(item.label.prefix(60)))" : "")")
            XCTAssertTrue(seen, "\(name) is not on the first screen of Inställningar")
        }
        // (2) Always found with Avancerat folded in.
        let advancedRow = element("settings.voiceCommands")
        XCTAssertFalse(advancedRow.exists, "Röstkommandon shows before Avancerat is folded out")
        for (name, id) in [("Historik", "settings.history"), ("Integritet och samtycke", "settings.privacy"),
                           ("Radera konto", "settings.deleteAccount"), ("Feedback", "settings.feedback"), ("Om appen", "settings.about")] {
            let found = scroll(to: element(id))
            log.append("always \(name): \(found)")
            XCTAssertTrue(found, "\(name) is not found with Avancerat folded in")
        }
        shoot("installningar-alltid")
        // (3) Avancerat folds out, and in again.
        let advanced = element("settings.advanced")
        XCTAssertTrue(scroll(to: advanced), "no Avancerat row")
        advanced.tap()
        pause(1)
        shoot("installningar-avancerat")
        for (name, id) in [("Röstkommandon", "settings.voiceCommands"), ("Minne", "settings.memory"), ("Anteckningar", "settings.notes"),
                           ("Studiekort", "settings.studyCards"), ("Förberedelser", "settings.preparations"),
                           ("Egna kommandon", "settings.customCommands"), ("Diagnostik", "settings.diagnostics")] {
            let found = scroll(to: element(id))
            log.append("advanced \(name): \(found)")
            XCTAssertTrue(found, "\(name) is not under Avancerat")
        }
        XCTAssertTrue(scroll(to: advanced, up: true), "Avancerat not found again")
        advanced.tap()
        pause(1)
        log.append("after the second tap: Röstkommandon exists \(element("settings.voiceCommands").exists)")
        XCTAssertFalse(element("settings.voiceCommands").exists, "Avancerat did not fold in again")
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func any(_ ids: [String], labels: [String]) -> XCUIElement {
        for id in ids where element(id).exists { return element(id) }
        for label in labels {
            let predicate = label.hasSuffix("*") ? NSPredicate(format: "label BEGINSWITH[c] %@", String(label.dropLast()))
                : NSPredicate(format: "label ==[c] %@", label)
            let found = app.descendants(matching: .any).matching(predicate).firstMatch
            if found.exists { return found }
        }
        return element(ids.first ?? "-")
    }

    /// Held drags (no flick, as the screen tour), up to 20, until the element is hittable.
    private func scroll(to target: XCUIElement, up: Bool = false) -> Bool {
        for _ in 0..<20 {
            if target.exists && target.isHittable { return true }
            let (from, to) = up ? (0.3, 0.8) : (0.8, 0.3)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
            pause(0.4)
            if !app.buttons["Klar"].exists { log.append("the sheet closed while scrolling"); return false }
        }
        return target.exists && target.isHittable
    }

    private func pause(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    private func shoot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "t63-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
