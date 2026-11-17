// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T36 (Toby (moln), Deangelo 2026-11-16 23:00), part 1: Angela Fable's A115 "Säg i AirPods" (D203). On Start: the
/// field "Säg i AirPods", Hur länge (En gång / Upprepa 5, 10, 20 min), the tempo and Spela (grey without text), the line
/// "Räknas som 1 fråga. Upprepningar kostar inget." Spela saves the text as a reading and opens the reading player:
/// "Spelar i AirPods", with repetition "Varv 1 · … kvar av 5 min". Pause and skip with the press hook. Fake audio only
/// (LUMEN_TEST_HEADER, D180: 0 ElevenLabs). Material (PDF, picture, link) and the credit label (A116, A117) come when
/// they are on main. One Simulator (`scripts/apptest/t36.sh`). Never a device test.
@MainActor
final class SayFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var springboard: XCUIApplication!
    private var header = "1"
    private var started = Date()
    private var taps = 0
    private var testTaps = 0
    private var shots = 0
    private var log: [String] = []
    private var sections: [String] = []
    private var unclear: [String] = []
    private var out: URL!

    static let text = "Klorofyllet i bladen fångar ljuset. Växten gör socker av vatten och koldioxid."

    func testSay() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard env["LUMEN_T36_OUT"] != nil else { throw XCTSkip("T36 runs from scripts/apptest/t36.sh") }
        header = env["LUMEN_T36_HEADER"] ?? "1"
        out = URL(fileURLWithPath: env["LUMEN_T36_OUT"]!)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock { @MainActor [weak self] in
            self?.finish()
        }
        launch(header)
        guard section("Första starten till Start", { firstStart() }) else { return }
        guard section("Säg i AirPods: skriv en text", { writeText() }) else { return }
        section("Spela en gång", { playOnce() })
        section("Upprepa 5 min: varv 2", { repeatFive() })
        section("Pausa och hoppa (1 och 2 tryck)", { pauseAndSkip() })
        section("Ta bort uppläsningen", { cleanUp() })
    }

    // MARK: Steps

    private func firstStart() -> Bool {
        guard wait(["Välkommen till EarMind"], 20) != nil else { return miss("Välkommen not shown") }
        guard tap(["Fortsätt"], "Fortsätt") else { return false }
        if wait(["Senare"], 8) != nil { tap(["Senare"], "Senare") }
        pause(2)
        systemAlerts()
        goToStart()
        screen("start", "Start with Säg i AirPods")
        return atStart() || miss("Start not shown")
    }

    private var field: XCUIElement {
        let byLabel = app.textFields.matching(NSPredicate(format: "label BEGINSWITH[c] 'Säg i AirPods'")).firstMatch
        if byLabel.exists { return byLabel }
        return app.textViews.matching(NSPredicate(format: "label BEGINSWITH[c] 'Säg i AirPods'")).firstMatch
    }

    private func writeText() -> Bool {
        guard field.waitForExistence(timeout: 10) else { return miss("no field 'Säg i AirPods' on Start") }
        if let play = find(["Spela"]), play.isEnabled { note("Spela is tappable before any text (A115: grey without text)") }
        tapElement(field, "Säg i AirPods (the field)")
        pause(1)
        field.typeText(Self.text)
        pause(1)
        let value = (field.value as? String) ?? ""
        log.append("T36 field value: \(value)")
        if !value.contains("Klorofyllet") { return miss("the text did not get into the field (value '\(value)')") }
        if find(["Räknas som 1 fråga*"]) == nil { note("no line 'Räknas som 1 fråga. Upprepningar kostar inget.' under the text") }
        log.append("T36 Hur länge: \(find(["Hur länge*"])?.label ?? "-"), tempo: \(find(["Tempo*"])?.label ?? "-")")
        screen("text", "Säg i AirPods with a text")
        return waitEnabled(["Spela"], 5) || miss("Spela not tappable with a text")
    }

    private func openPlayer() -> Bool {
        guard tap(["Spela"], "Spela") else { return false }
        if wait(["Styr med dina AirPods"], 5) != nil {
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov", "Spela"], "Start on the control check", quiet: true)
        }
        // Run 44006955559: with fake audio a short text can be read through before this looks ("Klart · Slut på texten").
        if wait(["Spelar i AirPods*", "Klart*", "Slut på texten"], 30) != nil {
            if find(["Spelar i AirPods*"]) == nil { log.append("T36 the player was already at the end: \(text(starting: "Klart") ?? "-")") }
            return true
        }
        screen("ingen-spelare", "Spela did not open 'Spelar i AirPods'")
        return miss("no 'Spelar i AirPods' in the player")
    }

    private func playOnce() -> Bool {
        guard openPlayer() else { return false }
        screen("spelar", "Spelar i AirPods (En gång)")
        // Once: the text ends by itself (fake audio, a few seconds); then 1 press is Börja om (D188) or it closes.
        let end = Date().addingTimeInterval(60)
        var ended = false
        while Date() < end, !ended {
            let texts = Self.labels(in: app.debugDescription, kind: "StaticText")
            ended = texts.contains { $0.hasPrefix("Mening 2 av 2") || $0 == "Slut på texten" } || find(["Spelar i AirPods*"]) == nil
            pause(2)
        }
        log.append("T36 once: reached the end or closed: \(ended)")
        if find(["Varv 2*"]) != nil { note("En gång shows 'Varv 2'") }
        tap(["Avsluta"], "Avsluta", quiet: true)
        pause(2)
        goToStart()
        return true
    }

    private func repeatFive() -> Bool {
        // Run 43996745785: the field is empty after a played text, and an empty field's value is its placeholder.
        if field.exists, !((field.value as? String) ?? "").contains("Klorofyllet") {
            tapElement(field, "Säg i AirPods (again)")
            pause(1)
            field.typeText(Self.text)
            pause(1)
            log.append("T36 the field was empty after the first play; typed again")
        }
        // SayViews: the menu's label is "Hur länge, En gång" (A115).
        guard tap(["Hur länge*", "En gång"], "Hur länge") else { return false }
        guard tap(["Upprepa 5 min", "5 min"], "Upprepa 5 min") else { return false }
        pause(1)
        guard openPlayer() else { return false }
        guard waitText(starting: "Varv 1", 20) else { screen("utan-varv", "No Varv 1 line"); return miss("no 'Varv 1 · … kvar av 5 min' line") }
        log.append("T36 repeat: \(text(starting: "Varv 1") ?? "-")")
        screen("varv-1", "Upprepa 5 min, Varv 1")
        // The text is short and the fake audio has no length, so lap 2 should come long before the 5 minutes.
        // Run 43998813563: the lap line ticks every second ("4:59 kvar"), so an element found by it can be gone when its
        // label is read (XCTest stops the test). Read the text from the tree instead.
        let end = Date().addingTimeInterval(150)
        var lap2: String?
        while lap2 == nil, Date() < end { lap2 = text(starting: "Varv 2"); if lap2 == nil { pause(2) } }
        guard let lap2 else { return miss("no 'Varv 2' in 150 s (the text did not start again)") }
        log.append("T36 repeat: \(lap2)")
        screen("varv-2", "Upprepa 5 min, Varv 2")
        return true
    }

    /// Still in the repeating player: 1 press pauses and goes on, 2 presses skip to the next sentence.
    private func pauseAndSkip() -> Bool {
        if find(["Spelar i AirPods*"]) == nil {
            if field.exists, !((field.value as? String) ?? "").contains("Klorofyllet") { tapElement(field, "Säg i AirPods (again)"); pause(1); field.typeText(Self.text); pause(1) }
            if !openPlayer() { return false }
        }
        let pausedBefore = paused()
        Self.press(1); pause(3)
        let first = paused()
        Self.press(1); pause(3)
        let second = paused()
        log.append("T36 press 1: paused \(pausedBefore) → \(first) → \(second)")
        let place0 = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Mening ") }
        Self.press(2); pause(3)
        let place1 = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Mening ") }
        log.append("T36 press 2: \(place0 ?? "-") → \(place1 ?? "-")")
        if place0 == place1 { note("2 presses did not move the place (\(place0 ?? "-"))") }
        screen("efter-tryck", "After 1, 1 and 2 presses")
        tap(["Avsluta"], "Avsluta", quiet: true)
        pause(2)
        return first != second || miss("two 1 presses did not toggle pause")
    }

    /// A text on screen that starts with `prefix`, read from the tree (labels that change every second are not queried).
    private func text(starting prefix: String) -> String? {
        Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix(prefix) }
    }

    private func waitText(starting prefix: String, _ timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat { if text(starting: prefix) != nil { return true }; pause(1) } while Date() < end
        return false
    }

    private func paused() -> Bool {
        !app.buttons.matching(NSPredicate(format: "label ==[c] 'Pausa'")).firstMatch.exists
    }

    private func cleanUp() -> Bool {
        goToStart()
        // The text is saved as a reading (A115); its row on Start opens it like any reading (T28).
        guard tap(["Texten", "Frågor och svar"], "Texten", quiet: true) else { note("the saved reading was not found on Start"); return true }
        guard tap(["Mer"], "Mer") else { return false }
        guard tap(["Ta bort texten", "Ta bort provet"], "Ta bort texten") else { return false }
        pause(1)
        if !confirmDestructive("Ta bort texten"), !confirmDestructive("Ta bort provet") { note("no confirmation button to tap") }
        pause(3)
        screen("borta", "After Ta bort texten")
        return true
    }

    private static func press(_ n: Int) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("earmind.test.press.\(n)" as CFString), nil, nil, true)
    }

    /// A line in the test log with the time, so the script can cut the app log at it.
    private func mark(_ what: String) {
        log.append(String(format: "MARK %@ at %@", what, ISO8601DateFormatter().string(from: Date())))
        writeLog()
    }

    private func gone(_ labels: [String], _ timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if find(labels)?.isHittable != true { return true }
            pause(0.5)
        } while Date() < end
        return false
    }

    private func atStart() -> Bool {
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Inställningar'")).firstMatch.isHittable
            && find(["Avsluta"])?.isHittable != true
    }

    private func goToStart() {
        for _ in 0..<6 {
            // A109: "Vill du ha en påminnelse?" after the first finished exam or reading (run 43990919797).
            if find(["Vill du ha en påminnelse?"]) != nil, let notNow = find(["Inte nu"]), notNow.isHittable {
                tapElement(notNow, "Inte nu (reminder question)", counted: false)
                pause(1)
                continue
            }
            if atStart() { return }
            if app.alerts.firstMatch.exists {
                let alert = app.alerts.firstMatch
                log.append("ALERT: \(alert.label) — " + alert.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " / "))
                let ok = ["Okej", "OK", "Ok", "Stäng"].lazy.map { alert.buttons[$0] }.first { $0.exists }
                (ok ?? alert.buttons.element(boundBy: 0)).tap(); testTaps += 1
                pause(1)
                continue
            }
            if let end = find(["Avsluta"]), end.isHittable { tapElement(end, "Avsluta (back to Start)", counted: false); pause(1); continue }
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists, back.isHittable, ["Prov", "Tillbaka", "Back"].contains(back.label) || back.label.isEmpty {
                back.tap(); testTaps += 1; pause(1); continue
            }
            if tap(["Avbryt", "Stäng", "Klar", "Cancel", "Done", "Prov"], "back to Start", counted: false, quiet: true) { pause(1); continue }
            app.swipeDown(velocity: .fast)
            pause(1)
        }
        if !atStart() { log.append("goToStart: Start not in front after 6 tries") }
    }

    /// A menu (Mer) closes with a tap outside it, never on one of its own buttons.
    private func closeMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.95)).tap()
        testTaps += 1
        pause(1)
    }

    private func confirmDestructive(_ label: String) -> Bool {
        let predicate = NSPredicate(format: "label ==[c] %@", label)
        let end = Date().addingTimeInterval(5)
        repeat {
            for container in [app.sheets.firstMatch, app.alerts.firstMatch] where container.exists {
                let button = container.buttons.matching(predicate).firstMatch
                if button.exists, button.isHittable { tapElement(button, "\(label) (confirm)"); return true }
            }
            let hittable = app.buttons.matching(predicate).allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if hittable.count > 1, let last = hittable.last { tapElement(last, "\(label) (confirm)"); return true }
            pause(0.5)
        } while Date() < end
        return false
    }

    // MARK: Shared steps

    private func pickPhoto() -> Bool {
        guard tap(["Välj bilder"], "Välj bilder") else { return false }
        systemAlerts()
        // Runs 43623858065, 43628656647: "Läser in …" after 15 s on a just-erased Simulator. Wait up to 60 s.
        let samples = ["2009", "2010", "2011", "2012"]
        var cells: [XCUIElement] = []
        let end = Date().addingTimeInterval(60)
        repeat {
            pause(1)
            cells = app.images.allElementsBoundByIndex.filter { image in
                image.exists && samples.contains { image.label.contains($0) } && image.frame.width < 250
            }
        } while cells.isEmpty && Date() < end
        screen("bildbiblioteket", "Välj bilder: the photo library", counts: false)
        guard let width = cells.map(\.frame.width).max(), let top = cells.map(\.frame.minY).min() else {
            return miss("no grid of pictures")
        }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: width / 2, dy: top + width / 2)).tap()
        taps += 1
        if let add = wait(["Lägg till", "Add", "Klar", "Done"], 3) { tapElement(add, "Lägg till in the photo library") }
        return wait(["1 foto*"], 20) != nil || waitEnabled(["Skapa frågor"], 10) || miss("the picture did not get in")
    }

    private func lowerQuestions(to target: Int) {
        let decrement = app.buttons["Decrement"]
        guard decrement.waitForExistence(timeout: 3) else { return }
        for _ in 0..<60 {
            if "\(decrement.value ?? "")" == "\(target)" { break }
            guard decrement.isEnabled else { break }
            decrement.tap(); testTaps += 1
        }
    }

    private func closeSheet() {
        if !tap(["Avbryt", "Cancel", "Stäng", "Close", "Klar", "Done"], "close the sheet", counted: false, quiet: true) {
            app.swipeDown(velocity: .fast)
        }
        pause(1)
    }

    // MARK: Helpers

    private func launch(_ value: String) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
        app.launchEnvironment["LUMEN_TEST_HEADER"] = value
        // Angela Schrute's hook (60d83ce, Debug only): 1, 2 and 3 presses as Darwin notifications.
        app.launchEnvironment["LUMEN_TEST_PRESSES"] = "1"
        app.launch()
        log.append("launched with LUMEN_TEST_HEADER=\(value)")
    }

    private func relaunchToStart(keepHeader: Bool = false) {
        if !keepHeader || app == nil { launch(header) } else {
            let value = app.launchEnvironment["LUMEN_TEST_HEADER"] ?? header
            launch(value)
        }
        _ = wait(["Nytt prov"], 15)
    }

    /// One section: timed, taps counted, a failure photographed; the next section starts from a relaunch.
    @discardableResult
    private func section(_ name: String, _ body: () -> Bool) -> Bool {
        let t0 = Date()
        let taps0 = taps
        log.append("=== \(name)")
        let ok = body()
        let line = String(format: "%@ %@: %.0f s, %d tryck", ok ? "OK " : "FEL", name, Date().timeIntervalSince(t0), taps - taps0)
        sections.append(line)
        log.append(line)
        writeLog() // after every section: a run stopped by the time limit keeps what it did (43632852744 lost it all)
        if !ok {
            screen("fel-\(sections.count)", "Section failed: \(name)", counts: false)
            XCTFail("[t36] \(name)")
        }
        return ok
    }

    @discardableResult
    private func miss(_ what: String) -> Bool {
        log.append("MISS: \(what)")
        return false
    }

    private func note(_ what: String) {
        unclear.append(what)
        log.append("UNCLEAR: \(what)")
    }

    private func find(_ labels: [String]) -> XCUIElement? {
        for label in labels {
            let predicate = label.hasSuffix("*")
                ? NSPredicate(format: "label BEGINSWITH[c] %@", String(label.dropLast()))
                : NSPredicate(format: "label ==[c] %@", label)
            let button = app.buttons.matching(predicate).firstMatch
            if button.exists { return button }
            let any = app.descendants(matching: .any).matching(predicate).firstMatch
            if any.exists { return any }
        }
        return nil
    }

    private func wait(_ labels: [String], _ timeout: TimeInterval) -> XCUIElement? {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if let element = find(labels) { return element }
            pause(0.25)
        } while Date() < end
        return nil
    }

    private func waitEnabled(_ labels: [String], _ timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if let element = find(labels), element.isEnabled { return true }
            pause(1)
        } while Date() < end
        return false
    }

    @discardableResult
    private func tap(_ labels: [String], _ step: String, counted: Bool = true, quiet: Bool = false) -> Bool {
        guard var element = wait(labels, quiet ? 1.5 : 6) else {
            if !quiet { log.append("MISS: \(step): '\(labels[0])' not found") }
            return false
        }
        var swipes = 0
        while !element.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
            if let again = find(labels) { element = again }
        }
        if swipes > 0 { note("\(step): '\(labels[0])' was below the screen (\(swipes) swipes)") }
        guard element.isHittable else { log.append("MISS: \(step): '\(labels[0])' not hittable"); return false }
        tapElement(element, step, counted: counted)
        return true
    }

    private func tapElement(_ element: XCUIElement, _ step: String, counted: Bool = true) {
        element.tap()
        if counted { taps += 1 } else { testTaps += 1 }
        log.append(String(format: "%@ at %6.1f s: %@", counted ? "TAP \(taps)" : "TEST TAP", Date().timeIntervalSince(started), step))
    }

    private func systemAlerts() {
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            log.append("SYSTEM ALERT: \(alert.label)")
            let allow = ["Tillåt", "Allow", "OK", "Tillåt när appen används", "Allow While Using App"]
            if let button = allow.lazy.map({ alert.buttons[$0] }).first(where: { $0.exists }) { button.tap() } else {
                alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            }
            taps += 1
        }
    }

    private func screen(_ name: String, _ note: String, counts: Bool = true) {
        if counts { shots += 1 }
        pause(1)
        let fileName = String(format: "t36-%02d-%@", shots, name)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
        let tree = app.debugDescription
        log.append(String(format: "SCREEN %@ at %6.1f s — %@", fileName, Date().timeIntervalSince(started), note))
        log.append("  texts: " + Self.labels(in: tree, kind: "StaticText").prefix(50).joined(separator: " | "))
        log.append("  buttons: " + Self.labels(in: tree, kind: "Button").prefix(40).joined(separator: " | "))
    }

    nonisolated static func labels(in tree: String, kind: String) -> [String] {
        tree.split(separator: "\n").compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(kind + ","), let start = trimmed.range(of: "label: '") else { return nil }
            let rest = trimmed[start.upperBound...]
            guard let end = rest.range(of: "'", options: .backwards), end.lowerBound > rest.startIndex else { return nil }
            let label = String(rest[..<end.lowerBound])
            return label.isEmpty ? nil : label
        }
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    @discardableResult
    private func writeLog() -> String {
        var lines = ["T36 (simulator, not a device), header x-earmind-test=\(header)",
                     "taps (a user's): \(taps), test taps: \(testTaps), screens: \(shots)", "", "Sections:"] + sections
        lines += ["", "Not obvious:"] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 }) + ["", "Log:"] + log + [""]
        let text = lines.joined(separator: "\n")
        try? text.write(to: out.appendingPathComponent("t36-log.txt"), atomically: true, encoding: .utf8)
        return text
    }

    private func finish() {
        let text = writeLog()
        let summary = XCTAttachment(string: text)
        summary.name = "t36-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
