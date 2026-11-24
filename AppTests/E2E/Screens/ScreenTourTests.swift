// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag). Angela's LumenE2ETests
// unit-test bundle compiles all of AppTests/E2E, and a UI test cannot run there.
#if LUMEN_SCREEN_TOUR
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
    private var micDenied = false
    private var shotNumber = 0
    private var log: [String] = []
    private var unreachable: [String] = []
    private var started = Date()


    func testScreenTour() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        prefix = env["LUMEN_SHOT_PREFIX"] ?? "shot"
        micDenied = env["LUMEN_TOUR_MIC"] == "denied"

        app = XCUIApplication()
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Swedish UI, as the users see it. Apple's recogniser instead of Scribe: no paid realtime session from CI.
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE", "-stt.useCloud", "NO"]
        // D180: every request is test traffic with fake audio (x-earmind-test); the tour never plays anything.
        app.launchEnvironment["LUMEN_TEST_HEADER"] = "1"
        started = Date()
        app.launch()

        // Deangelo 2026-11-20 (T3 red on main since A94, 2026-11-14): the tour follows today's app. Välkommen →
        // Nytt prov (A94) → Start with Säg i AirPods (A115, A153) → Krediter (A117, A134) → Nytt prov's form (A154) →
        // Inställningar with Radera konto (A145) → Fler lägen · Beta when Start shows it. Nothing listens and nothing
        // is played or bought; the listening modes are only opened as pages.
        welcome()
        shoot("start", note: "Start, a new account (A115)")
        sayText()
        credits()
        newExamForm()
        startRows()
        settingsTour()
        deleteAccountQuestion()
        moreModes()
        if micDenied { record("note: microphone denied; nothing in the tour listens, so no error screen is expected") }

        finish()
    }

    // MARK: First start (A94, Kelly Ke55)

    private func welcome() {
        guard waitFor(["Välkommen till EarMind"], timeout: 25) != nil else {
            miss("Välkommen not shown on a new installation")
            return
        }
        shoot("valkommen", note: "Välkommen (A94)")
        app.swipeUp()
        shoot("valkommen-slut", note: "Välkommen, scrolled")
        guard tap(["Fortsätt"], step: "Välkommen → Fortsätt") else { return }
        dismissSystemAlerts()
        if waitFor(["Senare"], timeout: 10) != nil {
            shoot("forsta-nytt-prov", note: "Nytt prov right after Välkommen (A94)")
            app.swipeUp()
            shoot("forsta-nytt-prov-slut", note: "Nytt prov after Välkommen, scrolled")
            tap(["Senare"], step: "first Nytt prov → Senare")
            pause(1)
        } else {
            miss("Nytt prov did not open after Fortsätt (A94)")
        }
        dismissSystemAlerts()
        if waitFor(["Inställningar"], timeout: 15) == nil { miss("Start not shown after the first start") }
    }

    // MARK: Start (A115, A153)

    /// Säg i AirPods with a text: the cost and, with the keyboard up, Spela above it (A153). Nothing is played.
    private func sayText() {
        // SayFlowTests' field: "Säg i AirPods" as a text field, or a text view when it has grown.
        let predicate = NSPredicate(format: "label BEGINSWITH[c] 'Säg i AirPods'")
        let asField = app.textFields.matching(predicate).firstMatch
        let field = asField.waitForExistence(timeout: 5) ? asField : app.textViews.matching(predicate).firstMatch
        guard field.exists else { miss("Säg i AirPods: no field on Start"); return }
        field.tap()
        pause(1)
        guard app.keyboards.count > 0 || app.buttons["retur"].exists || app.buttons["return"].exists else {
            miss("Säg i AirPods: the field got no keyboard")
            return
        }
        field.typeText("Klorofyllet i bladen fångar ljuset.")
        pause(2) // the cost comes about 0,7 s after the last key
        shoot("sag-text-tangentbord", note: "Säg i AirPods with a text, keyboard up (A153)")
        if find(["Klar"], buttonsOnly: true) != nil {
            tap(["Klar"], step: "Säg i AirPods → Klar above the keyboard (A153)")
            pause(1)
        } else {
            record("note: no Klar above the keyboard; swiping down")
            app.swipeDown()
            pause(1)
        }
        shoot("sag-text", note: "Säg i AirPods with a text, the cost and Spela (A115)")
        // Leave Start as it was: the field emptied again, so later screens show Start without a text.
        field.tap()
        pause(0.5)
        if let value = field.value as? String, !value.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 2))
        }
        if find(["Klar"], buttonsOnly: true) != nil { tap(["Klar"], step: "emptied field → Klar") } else { app.swipeDown() }
        pause(1)
    }

    /// The credit capsule opens Krediter (A117, A134): the packs (none in the Simulator), Bjud in, Så räknas det.
    private func credits() {
        let capsule = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'krediter kvar' OR label CONTAINS[c] 'kredit kvar'")).firstMatch
        guard capsule.waitForExistence(timeout: 10) else { miss("Start: no credit capsule"); return }
        capsule.tap()
        record("tap: Start → the credit capsule")
        guard waitFor(["Så räknas det", "Bjud in"], timeout: 15) != nil else { miss("Krediter did not open"); return }
        pause(2)
        shoot("krediter", note: "Krediter (A134)")
        app.swipeUp()
        shoot("krediter-slut", note: "Krediter, scrolled: Villkor, Integritet, Återställ köp")
        closeSheet()
    }

    /// Nytt prov's form (A79, A154): Gör, Material, the count, Skapa frågor. Nothing is made.
    private func newExamForm() {
        guard tap(["Nytt prov"], step: "Start → Nytt prov") else { return }
        guard waitFor(["Skapa frågor", "Fota sidor"], timeout: 10) != nil else { miss("Nytt prov's form not shown"); return }
        pause(1)
        shoot("nytt-prov", note: "Nytt prov (A154)")
        app.swipeUp()
        shoot("nytt-prov-slut", note: "Nytt prov, scrolled")
        closeSheet()
        if waitFor(["Inställningar"], timeout: 5) == nil { closeSheet() }
    }

    /// The other rows of Start: Hitta prov från din skola and Klistra in en länk (A116), each opened and closed.
    private func startRows() {
        for (labels, name) in [(["Hitta prov från din skola"], "hitta-prov"), (["Klistra in en länk", "Öppna länk"], "klistra-in-lank")] {
            guard tap(labels, step: "Start → \(labels[0])") else { continue }
            pause(2)
            shoot(name, note: labels[0])
            backToStart()
        }
    }

    /// Back to Start from a pushed page (Hitta prov från din skola is a navigationDestination, run 44761053846) or a
    /// sheet: the navigation bar's back button first, then the sheet's own close button.
    private func backToStart() {
        for _ in 0..<3 {
            if find(["Inställningar"], buttonsOnly: true)?.isHittable == true { return }
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists, back.isHittable, !["Klar", "Inställningar"].contains(back.label) {
                record("back: '\(back.label)'")
                back.tap()
            } else {
                closeSheet()
            }
            pause(1)
        }
        if find(["Inställningar"], buttonsOnly: true) == nil { miss("could not get back to Start") }
    }

    // MARK: Radera konto (A145): the question only; Avbryt, nothing is deleted

    private func deleteAccountQuestion() {
        guard tap(["Inställningar"], step: "start → Inställningar (Konto)") else { return }
        guard waitFor(["Klar"], timeout: 5) != nil else { miss("settings sheet not shown (Konto)"); return }
        guard let found = scrollTo(["Radera konto", "Delete account"], buttonsOnly: true) else {
            miss("settings row Radera konto not found")
            closeSheet()
            return
        }
        let row = centered(found, labels: ["Radera konto", "Delete account"])
        shoot("installningar-konto", note: "Settings › Konto (A145)")
        row.tap()
        let alert = app.alerts.firstMatch
        // Run 44809087832 (pro-dark): one tap asked nothing. Tap the row once more before calling it a miss.
        if !alert.waitForExistence(timeout: 5), waitFor(["Avbryt"], timeout: 1) == nil,
           let again = find(["Radera konto", "Delete account"], buttonsOnly: true), again.isHittable {
            record("note: Radera konto tap asked nothing, retry")
            again.tap()
        }
        if alert.waitForExistence(timeout: 5) {
            shoot("radera-kontot-fragan", note: "Radera kontot? (A145)")
            let cancel = alert.buttons["Avbryt"]
            if cancel.exists { cancel.tap() } else { miss("Radera kontot? has no Avbryt") }
        } else if waitFor(["Avbryt"], timeout: 3) != nil {
            shoot("radera-kontot-fragan", note: "Radera kontot? (A145, as a sheet)")
            tap(["Avbryt"], step: "Radera kontot? → Avbryt")
        } else {
            // Run 44835830516 (pro-dark, twice in a row): no question. Write what is on screen into the log.
            record("note: Radera konto row \(row.frame), hittable \(row.isHittable), alerts \(app.alerts.count), sheets \(app.sheets.count)")
            for line in app.debugDescription.split(separator: "\n")
                where line.contains("Radera") || line.contains("Alert") || line.contains("Sheet") || line.contains("Avbryt") {
                record("note: tree: \(line.trimmingCharacters(in: .whitespaces).prefix(160))")
            }
            miss("Radera konto asked nothing")
        }
        pause(1)
        tap(["Klar"], step: "settings → Klar (Konto)")
        pause(1)
    }

    // MARK: Fler lägen · Beta (the listening modes, only opened as pages)

    private func moreModes() {
        // RepetitionHomeSection: "Fler lägen · Beta" (label "Fler lägen") at the bottom of Start in some states only.
        guard let row = find(["Fler lägen"], buttonsOnly: true) ?? scrollTo(["Fler lägen"], buttonsOnly: true) else {
            record("note: no Fler lägen on Start in this state (A115 Start); the listening modes are not in the tour")
            return
        }
        row.tap()
        pause(2)
        shoot("fler-lagen", note: "Fler lägen · Beta")
        app.swipeUp()
        shoot("fler-lagen-slut", note: "Fler lägen, scrolled")
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap() } else { closeSheet() }
        pause(1)
    }

    private func closeSheet() {
        for label in ["Klar", "Stäng", "Avbryt", "Done", "Close", "Cancel"] where app.buttons[label].exists {
            app.buttons[label].tap()
            pause(1)
            return
        }
        app.swipeDown(velocity: .fast)
        pause(1)
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

        // Back to the top of the list before the pages: the language choice (A157, `settings.appLanguage`, the one
        // row with an identifier) is the first row.
        let top = app.descendants(matching: .any)["settings.appLanguage"]
        for _ in 0..<30 where !(top.exists && top.isHittable) { drag(towardsEnd: false) }
        if !(top.exists && top.isHittable) { record("note: the top of Settings (settings.appLanguage) not seen") }
        // Run 45396745804: in the order they stand on the screen where it is known (tree of run 44862440315:
        // Integritet, Anteckningar, Historik, Studiekort, Förberedelser), so the search mostly goes forward.
        let pages: [(name: String, labels: [String])] = [
            ("integritet", ["Integritet och samtycke", "Privacy and consent", "Privacy & consent"]),
            ("anteckningar", ["Anteckningar", "Notes"]),
            ("historik", ["Historik", "History"]),
            ("studiekort", ["Studiekort", "Study cards"]),
            ("forberedelser", ["Förberedelser", "Preparations"]),
            ("egna-kommandon", ["Egna kommandon", "Your own commands"]),
            ("minne", ["Minne", "Memory"]),
            ("feedback", ["Feedback och förslag", "Feedback and suggestions", "Feedback & förslag", "Feedback & suggestions"]),
            ("rostkommandon", ["Röstkommandon", "Voice commands"]),
            ("om-appen", ["Om appen", "About the app"]),
        ]
        for page in pages {
            openFromSettings(page.labels, name: page.name)
        }
        // A13: "Avancerat" folds out its sections in place (not a page); the diagnostics rows are inside it.
        expandAdvanced()
        openFromSettings(["Rå transkription och svar", "Raw transcription and answers"], name: "ra-transkription", advanced: true)
        openFromSettings(["Diagnostik", "Diagnostics"], name: "diagnostik", advanced: true)
        tap(["Klar"], step: "settings → Klar")
        pause(1)
    }

    /// Folds out "Avancerat" in Settings (once per sheet) and shoots the first screen of it.
    private func expandAdvanced() {
        guard let row = scrollTo(["Avancerat*", "Advanced*"], buttonsOnly: true) else {
            miss("settings row Avancerat not found")
            return
        }
        row.tap()
        pause(1)
        app.swipeUp()
        shoot("installningar-avancerat", note: "Settings › Avancerat folded out")
        app.swipeUp()
        shoot("installningar-avancerat-2", note: "Settings › Avancerat, scrolled")
    }

    /// Scrolls the settings list up or down until the row is there, opens it, shoots it and goes back.
    private func openFromSettings(_ labels: [String], name: String, advanced: Bool = false) {
        // If going back from the previous page closed the whole sheet (seen after Förberedelser), open Settings again.
        // Run 44787390248: in iOS 26 the sheet's Klar (a toolbar item) is not a child of the navigation bar, so the
        // old check reopened Settings before every row and every other row was lost. Look for Klar anywhere, or the
        // page's title.
        if !app.buttons["Klar"].waitForExistence(timeout: 2) {
            record("note: Settings sheet closed before \(labels[0]), opening it again")
            tap(["Inställningar"], step: "start → Inställningar (again)")
            pause(1)
            if advanced { expandAdvanced() }
        }
        // Buttons only: a section header with the same words ("Diagnostik") is not the row.
        guard let found = scrollTo(labels, buttonsOnly: true) else {
            miss("settings row \(labels[0]) not found")
            return
        }
        found.tap()
        pause(1.5)
        // The last rows sit at the sheet's bottom edge, where a tap can miss (seen at the largest text size):
        // look the row up again each time and tap it only when it is hittable, never a stale element.
        var attempt = 0
        // The page is open when the sheet's Klar is gone (it belongs to the settings root only).
        while app.buttons["Klar"].exists, attempt < 3 {
            attempt += 1
            record("note: \(labels[0]) tap missed, retry \(attempt)")
            if let again = scrollTo(labels, buttonsOnly: true), again.isHittable {
                centered(again, labels: labels).tap()
            } else {
                app.swipeDown()
            }
            pause(1.5)
        }
        shoot("installningar-\(name)", note: "Settings › \(labels[0])")
        app.swipeUp()
        shoot("installningar-\(name)-slut", note: "Settings › \(labels[0]), scrolled")
        if !popSettingsPage() { miss("could not go back from \(labels[0])") }
    }

    /// Back from a page pushed inside Settings. Run 44795539606: a back button by its label could be Start's own
    /// "Inställningar" (gear, top right, behind the sheet). Take a navigation-bar button at the left edge, else swipe
    /// from the left edge; back when the sheet's Klar is there again.
    @discardableResult
    private func popSettingsPage() -> Bool {
        let width = app.windows.firstMatch.frame.width
        let candidates = app.navigationBars.buttons.allElementsBoundByIndex.filter {
            $0.exists && $0.isHittable && $0.frame.minX < width * 0.3 && $0.label != "Klar"
        }
        if let back = candidates.first {
            record("back: '\(back.label)'")
            back.tap()
        } else {
            record("back: edge swipe")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        }
        pause(1.5)
        return app.buttons["Klar"].waitForExistence(timeout: 3)
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

    private func find(_ labels: [String], buttonsOnly: Bool = false) -> XCUIElement? {
        for label in labels {
            // "Jag förstår*" = starts with (the app's dashes and ellipses vary; don't depend on them).
            let predicate = label.hasSuffix("*")
                ? NSPredicate(format: "label BEGINSWITH[c] %@", String(label.dropLast()))
                : NSPredicate(format: "label ==[c] %@", label)
            let button = app.buttons.matching(predicate).firstMatch
            if button.exists { return button }
            if buttonsOnly { continue }
            let any = app.descendants(matching: .any).matching(predicate).firstMatch
            if any.exists { return any }
        }
        return nil
    }

    @discardableResult
    private func tap(_ labels: [String], step: String) -> Bool {
        // Below the fold (largest text) the element may not exist until it is scrolled to.
        guard let element = waitFor(labels, timeout: 5) ?? scrollTo(labels) else {
            miss("\(step): '\(labels[0])' not found")
            shoot("saknas-\(labels[0])", note: "Missing: \(labels[0])")
            return false
        }
        if !element.isHittable, let scrolled = scrollTo(labels) {
            scrolled.tap()
        } else {
            element.tap()
        }
        record("tap: \(step)")
        return true
    }

    /// Swipes up (then back down) until an element with one of the labels is hittable.
    private func scrollTo(_ labels: [String], buttonsOnly: Bool = false) -> XCUIElement? {
        // Run 44809087832 (iPhone SE): swipeDown at the top of a sheet closed Inställningar, and the search went on
        // over Start. When that happens Settings is opened again and searched from the top.
        // Run 45396745804 (liten-light, A157 added rows at the top of Settings): a swipe carries on by itself and
        // moves the list more than a screen on the iPhone SE, so a row could pass between two looks every time
        // ("Integritet och samtycke not found"). Now the list is dragged and held, about 40 % of the screen a step,
        // so every row is in view at least once: a few steps back first (the next row is often just above), then
        // towards the end, then towards the top.
        let inSheet = app.buttons["Klar"].exists
        if let element = find(labels, buttonsOnly: buttonsOnly), element.isHittable { return element }
        for (towardsEnd, steps) in [(false, 3), (true, 80), (false, 80)] {
            for _ in 0..<steps {
                drag(towardsEnd: towardsEnd)
                if let element = find(labels, buttonsOnly: buttonsOnly), element.isHittable { return element }
                if inSheet, !app.buttons["Klar"].exists {
                    record("note: the sheet closed while looking for \(labels[0]); Settings opened again")
                    pause(1)
                    tap(["Inställningar"], step: "start → Inställningar (sheet closed)")
                    guard app.buttons["Klar"].waitForExistence(timeout: 5) else { return nil }
                    pause(1)
                    for _ in 0..<80 {
                        if let element = find(labels, buttonsOnly: buttonsOnly), element.isHittable { return element }
                        drag(towardsEnd: true)
                    }
                    record("note: scroll \(labels[0]) gave up")
                    dumpButtons()
                    return nil
                }
            }
        }
        record("note: scroll \(labels[0]) gave up")
        dumpButtons()
        return nil
    }

    /// One step of the list without a flick: press, drag about 40 % of the screen slowly, hold, let go.
    private func drag(towardsEnd: Bool) {
        let (from, to) = towardsEnd ? (0.72, 0.32) : (0.32, 0.72)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)),
                   withVelocity: .slow, thenHoldForDuration: 0.15)
    }

    /// The buttons in the tree right now, into the tour log (T3 diagnostics, run 44846862625).
    private func dumpButtons() {
        let lines = app.debugDescription.split(separator: "\n").filter { $0.contains("Button,") || $0.contains("CollectionView,") }
        for line in lines.prefix(45) { record("note: tree: \(line.trimmingCharacters(in: .whitespaces).prefix(150))") }
    }

    /// Run 44809087832 (iPhone SE): a row at the sheet's lower edge is "hittable" but the tap opens nothing. Drag it
    /// up to the middle of the screen first and look it up again.
    private func centered(_ element: XCUIElement, labels: [String], buttonsOnly: Bool = true) -> XCUIElement {
        let height = app.windows.firstMatch.frame.height
        guard height > 0, element.frame.midY > height * 0.7 else { return element }
        record("note: centring \(labels[0]) from y \(Int(element.frame.midY)) of \(Int(height))")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)),
                   withVelocity: .slow, thenHoldForDuration: 0.2)
        pause(0.5)
        if let again = find(labels, buttonsOnly: buttonsOnly), again.isHittable { return again }
        return element
    }

    private func dismissSystemAlerts() {
        for _ in 0..<3 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 1) else { return }
            record("system alert: \(alert.label)")
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
        record("shot: \(fileName) — \(note)")
    }

    /// A tour-log line with the seconds since launch, so a slow step shows in the job log (run 44809087832).
    private func record(_ line: String) {
        log.append("\(line) [+\(Int(Date().timeIntervalSince(started)))s]")
    }

    private func miss(_ what: String) {
        unreachable.append(what)
        record("MISS: \(what)")
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
#endif
