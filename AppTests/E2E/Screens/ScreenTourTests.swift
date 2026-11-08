import XCTest

/// T3 (Toby): walks every screen of the app in the Simulator and attaches a screenshot of each, so CI shows what the
/// app looks like in light, dark, large text and on a small iPhone. Navigation uses only what a user sees (labels),
/// no hooks inside the app. A screen that cannot be reached is recorded as a failure and the tour goes on.
///
/// Simulator only. A screenshot here is never a verification on a device.
///
/// Configuration comes from the runner script (`scripts/apptest/screens.sh`) through `TEST_RUNNER_` variables:
/// - `LUMEN_SHOT_PREFIX`: the config's name, put in front of every screenshot name (e.g. `pro-light`).
/// - `LUMEN_TOUR_MIC`: `denied` when the script revoked the microphone (the error screens are then expected).
@MainActor
final class ScreenTourTests: XCTestCase {
    // Created inside the test (main actor), not as default values: XCTestCase's initialiser is nonisolated.
    private var app: XCUIApplication!
    private var springboard: XCUIApplication!
    private var prefix = "shot"
    private var shotNumber = 0
    private var log: [String] = []
    private var unreachable: [String] = []

    func testScreenTour() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        prefix = env["LUMEN_SHOT_PREFIX"] ?? "shot"
        let micDenied = env["LUMEN_TOUR_MIC"] == "denied"

        app = XCUIApplication()
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Swedish UI, as the users see it. Apple's recogniser instead of Scribe: no paid realtime session from CI.
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE", "-stt.useCloud", "NO"]
        app.launch()

        firstStart(micDenied: micDenied)
        sharePrompt()
        shoot("start-utan-prov", note: "Start without an exam (sketch 7)")
        addExamFromHome()
        settingsTour()
        modesTour()
        provTour()

        finish()
    }

    // MARK: First start (sketches 1-3)

    private func firstStart(micDenied: Bool) {
        if waitFor(["Testa nu"], timeout: 20) != nil {
            shoot("intro", note: "Intro (sketch 1)")
            tap(["Testa nu"], step: "intro → Testa nu")
        } else {
            miss("intro: 'Testa nu' not found (first start not shown?)")
        }

        if waitFor(["Jag förstår — börja använda Lumen", "I understand — start using Lumen"], timeout: 8) != nil {
            shoot("samtycke", note: "Consent, top")
            app.swipeUp()
            shoot("samtycke-slut", note: "Consent, scrolled")
            tap(["Jag förstår — börja använda Lumen", "I understand — start using Lumen"], step: "consent → accept")
        } else {
            miss("consent screen not shown")
        }

        dismissSystemAlerts()
        if waitFor(["Fråga vad som helst"], timeout: 10) != nil {
            pause(3) // let "Startar …" become "Lyssnar" (or the microphone error card)
            dismissSystemAlerts()
            shoot(micDenied ? "forsta-fragan-mikrofon-nekad" : "forsta-fragan", note: "First question (sketch 2)")
            tap(["Fortsätt"], step: "first question → Fortsätt")
        } else {
            miss("'Fråga vad som helst' not shown")
        }

        if waitFor(["Hoppa över"], timeout: 8) != nil {
            shoot("lagg-till-prov-forsta", note: "Add exam at first start (sketch 3)")
            app.swipeUp()
            shoot("lagg-till-prov-forsta-slut", note: "Add exam at first start, scrolled")
            tap(["Hoppa över"], step: "add exam → Hoppa över")
        } else {
            miss("add-exam step of the first start not shown")
        }
    }

    private func sharePrompt() {
        let dontShare = ["Dela inte", "Don't share"]
        if waitFor(dontShare, timeout: 5) != nil {
            shoot("dela-historik", note: "Share history prompt")
            tap(dontShare, step: "share prompt → Dela inte")
        } else {
            log.append("note: no share-history prompt")
        }
    }

    // MARK: Start with an exam (sketch 4)

    private func addExamFromHome() {
        guard tap(["Lägg till prov"], step: "start → Lägg till prov") else { return }
        if waitFor(["Spara prov"], timeout: 5) != nil {
            shoot("lagg-till-prov", note: "Add exam sheet")
            tap(["NO"], step: "add exam → NO")
            pause(0.5)
            shoot("lagg-till-prov-no", note: "Add exam, NO chosen")
            tap(["Spara prov"], step: "add exam → Spara prov")
            pause(1)
            if waitFor(["Få A-svar till provet"], timeout: 5) != nil {
                shoot("start-med-prov", note: "Start with an exam (sketch 4)")
                app.swipeUp()
                shoot("start-med-prov-slut", note: "Start with an exam, scrolled")
                app.swipeDown()
            } else {
                miss("exam card not shown after Spara prov")
            }
        } else {
            miss("add-exam sheet not shown")
        }
    }

    // MARK: Settings and everything under it

    private func settingsTour() {
        guard tap(["Inställningar"], step: "start → Inställningar") else { return }
        guard waitFor(["Klar"], timeout: 5) != nil else { miss("settings sheet not shown"); return }
        pause(1)
        shoot("installningar-1", note: "Settings, top")
        for page in 2...6 {
            app.swipeUp()
            shoot("installningar-\(page)", note: "Settings, scrolled \(page - 1)")
        }

        let pages: [(name: String, labels: [String])] = [
            ("anteckningar", ["Anteckningar", "Notes"]),
            ("forberedelser", ["Förberedelser"]),
            ("egna-kommandon", ["Egna kommandon"]),
            ("integritet", ["Integritet och samtycke", "Privacy & consent"]),
            ("ra-transkription", ["Rå transkription och svar"]),
            ("diagnostik", ["Diagnostik", "Diagnostics"]),
            ("historik", ["Historik", "History"]),
            ("minne", ["Minne"]),
            ("studiekort", ["Studiekort"]),
            ("feedback", ["Feedback & förslag", "Feedback & suggestions"]),
        ]
        for page in pages {
            openFromSettings(page.labels, name: page.name)
        }
        tap(["Klar"], step: "settings → Klar")
        pause(1)
    }

    /// Scrolls the settings list up or down until the row is there, opens it, shoots it and goes back.
    private func openFromSettings(_ labels: [String], name: String) {
        guard let row = scrollTo(labels) else {
            miss("settings row \(labels[0]) not found")
            return
        }
        row.tap()
        pause(1.5)
        shoot("installningar-\(name)", note: "Settings › \(labels[0])")
        app.swipeUp()
        shoot("installningar-\(name)-slut", note: "Settings › \(labels[0]), scrolled")
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 3) {
            back.tap()
            pause(1)
        } else {
            miss("no back button on \(labels[0])")
        }
    }

    // MARK: Modes (sketches 5 and 8)

    private func modesTour() {
        if tap(["Frågor"], step: "start → Frågor") {
            dismissSystemAlerts()
            if waitFor(["Byt läge"], timeout: 10) != nil {
                pause(2)
                dismissSystemAlerts()
                shoot("lyssnar-fragor", note: "Lyssnar in Frågor (sketch 5)")
                tap(["Byt läge"], step: "lyssnar → Byt läge")
                if waitFor(["Klar"], timeout: 5) != nil {
                    pause(1)
                    shoot("byt-lage", note: "Byt läge (sketch 8)")
                    tap(["Klar"], step: "byt läge → Klar")
                }
                tap(["Tillbaka till start"], step: "lyssnar → Tillbaka till start")
                pause(1)
                shoot("start-medan-lyssnar", note: "Start with the indicator line while listening")
                if let bar = waitFor(["Lyssnar", "Pausad"], timeout: 3) { bar.tap(); pause(1) }
                endSession()
            } else {
                shoot("fragor-startade-inte", note: "Frågor did not open Lyssnar")
                miss("Lyssnar did not open for Frågor")
            }
        }

        sheetFromMode(["Intervju"], name: "intervju-setup", close: ["Avbryt", "Cancel"])
        sheetFromMode(["Socialt"], name: "socialt-start", close: ["Avbryt", "Cancel"])
        sheetFromMode(["Rizz 18+"], name: "rizz-aldersgrans", close: ["Avbryt", "Cancel"])
    }

    private func sheetFromMode(_ labels: [String], name: String, close: [String]) {
        guard tap(labels, step: "start → \(labels[0])") else { return }
        pause(2)
        dismissSystemAlerts()
        shoot(name, note: "\(labels[0]) first screen")
        if waitFor(close, timeout: 2) != nil {
            tap(close, step: "\(name) → close")
        } else if waitFor(["Byt läge"], timeout: 1) != nil {
            // It went straight to Lyssnar.
            endSession()
        } else {
            app.swipeDown(velocity: .fast) // pull the sheet down
        }
        pause(1)
        if waitFor(["Byt läge"], timeout: 1) != nil { endSession() }
    }

    // MARK: Provläge

    private func provTour() {
        guard tap(["Få A-svar till provet"], step: "start → Få A-svar till provet") else { return }
        pause(2)
        dismissSystemAlerts()
        if waitFor(["Hoppa över allt"], timeout: 5) != nil {
            shoot("provlage-fragor-1", note: "Provläge first start, question 1")
            tap(["Hoppa över"], step: "prov onboarding → Hoppa över")
            pause(1)
            shoot("provlage-fragor-2", note: "Provläge first start, question 2")
            tap(["Hoppa över allt"], step: "prov onboarding → Hoppa över allt")
            pause(2)
        }
        dismissSystemAlerts()
        if waitFor(["Byt läge"], timeout: 8) != nil {
            pause(1)
            shoot("lyssnar-provlage", note: "Lyssnar in Provläge (sketch 5)")
            endSession()
        } else {
            shoot("provlage-startade-inte", note: "Provläge did not open Lyssnar")
            miss("Lyssnar did not open for Provläge")
        }
    }

    private func endSession() {
        tap(["Avsluta"], step: "lyssnar → Avsluta")
        pause(2)
        dismissSystemAlerts()
        // Whatever follows the session (a summary, study cards) is a screen too.
        if waitFor(["Lägg till prov", "Få A-svar till provet"], timeout: 3) == nil {
            shoot("efter-avsluta-\(shotNumber)", note: "After Avsluta")
            for label in ["Klar", "Stäng", "Done", "Close"] where app.buttons[label].exists {
                app.buttons[label].tap()
                pause(1)
                break
            }
        }
    }

    // MARK: Helpers

    /// The first element (button first, then any) whose label is one of `labels`, waiting up to `timeout`.
    @discardableResult
    private func waitFor(_ labels: [String], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let found = find(labels) { return found }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return nil
    }

    private func find(_ labels: [String]) -> XCUIElement? {
        for label in labels {
            let predicate = NSPredicate(format: "label ==[c] %@", label)
            let button = app.buttons.matching(predicate).firstMatch
            if button.exists { return button }
            let any = app.descendants(matching: .any).matching(predicate).firstMatch
            if any.exists { return any }
        }
        return nil
    }

    @discardableResult
    private func tap(_ labels: [String], step: String) -> Bool {
        guard let element = waitFor(labels, timeout: 5) else {
            miss("\(step): '\(labels[0])' not found")
            shoot("saknas-\(labels[0])", note: "Missing: \(labels[0])")
            return false
        }
        if !element.isHittable, let scrolled = scrollTo(labels) {
            scrolled.tap()
        } else {
            element.tap()
        }
        log.append("tap: \(step)")
        return true
    }

    /// Swipes up (then back down) until an element with one of the labels is hittable.
    private func scrollTo(_ labels: [String]) -> XCUIElement? {
        for direction in [true, false] {
            for _ in 0..<10 {
                if let element = find(labels), element.isHittable { return element }
                if direction { app.swipeUp() } else { app.swipeDown() }
            }
        }
        return nil
    }

    private func dismissSystemAlerts() {
        for _ in 0..<3 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 1) else { return }
            log.append("system alert: \(alert.label)")
            let allow = ["Tillåt", "Allow", "Tillåt när appen används", "Allow While Using App", "OK"]
            guard let button = allow.lazy.map({ alert.buttons[$0] }).first(where: { $0.exists }) else {
                alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
                continue
            }
            button.tap()
        }
    }

    private func shoot(_ name: String, note: String) {
        shotNumber += 1
        let fileName = String(format: "%@-%02d-%@", prefix, shotNumber, name)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
        log.append("shot: \(fileName) — \(note)")
    }

    private func miss(_ what: String) {
        unreachable.append(what)
        log.append("MISS: \(what)")
        XCTFail("[\(prefix)] \(what)")
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func finish() {
        var lines = ["config: \(prefix)", "screenshots: \(shotNumber)", "unreachable: \(unreachable.count)", ""]
        lines += log
        let summary = XCTAttachment(string: lines.joined(separator: "\n"))
        summary.name = "\(prefix)-tour-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
