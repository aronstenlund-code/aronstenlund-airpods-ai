// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T30 (Toby (moln), Deangelo 2026-11-15 16:55; Angela Schrute's A108 and Angela Fable's A109, D194/D195): the streak
/// and the reminder. In the Simulator: no notification question at the first start or before the first exam is played
/// through; after a whole lap and Avsluta the sheet "Vill du ha en påminnelse?" (Påminn mig / Inte nu); Påminn mig
/// gives iOS's question about notifications; Start says "1 dag i rad"; Settings has Påminnelse with "Påminn mig att
/// plugga" and Tid. The day boundary (midnight) and a missed day are Angela Schrute's unit tests: the Simulator's clock
/// cannot be set from a UI test. Fake audio (D180). One Simulator (`scripts/apptest/t30.sh`). Never a device test.
@MainActor
final class ReminderFlowTests: XCTestCase {
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
    private var offline = false
    private var notificationAsks: [String] = []

    static let answer = """
    Här är frågorna:

    Fråga 1: Vad behöver växter för fotosyntesen?
    Svar: Koldioxid, vatten och solljus.

    Fråga 2: Var i bladet sker fotosyntesen?
    Svar: I kloroplasterna.

    Fråga 3: Vad används sockret till?
    Svar: Som energi och byggmaterial.
    """

    func testReminder() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard env["LUMEN_T30_OUT"] != nil else { throw XCTSkip("T30 runs from scripts/apptest/t30.sh") }
        header = env["LUMEN_T30_HEADER"] ?? "1"
        out = URL(fileURLWithPath: env["LUMEN_T30_OUT"]!)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock { @MainActor [weak self] in
            if self?.offline == true { _ = self?.network(on: true) }
            self?.finish()
        }
        launch(header)
        guard section("Första starten och ett prov, ingen fråga om notiser", { firstStartAndExam() }) else { return }
        section("Ett helt varv, Avsluta: frågan om påminnelse", { lapAndQuestion() })
        section("Start: dagar i rad", { streakOnStart() })
        section("Inställningar: Påminnelse", { settings() })
        section("Ta bort provet", { cleanUp() })
    }

    // MARK: Steps

    /// iOS's notification question, if it is up: recorded (when it came) and answered with Tillåt.
    private func notificationAlert(_ when: String) -> Bool {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 1) else { return false }
        let label = alert.label
        let isNotifications = label.localizedCaseInsensitiveContains("notification") || label.localizedCaseInsensitiveContains("notis")
            || label.localizedCaseInsensitiveContains("meddelande")
        log.append("SYSTEM ALERT (\(when)): \(label)")
        if isNotifications { notificationAsks.append(when) }
        let allow = ["Tillåt", "Allow", "OK"]
        if let button = allow.lazy.map({ alert.buttons[$0] }).first(where: { $0.exists }) { button.tap() } else {
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
        }
        testTaps += 1
        return isNotifications
    }

    private func firstStartAndExam() -> Bool {
        guard wait(["Välkommen till EarMind"], 20) != nil else { return miss("Välkommen not shown") }
        _ = notificationAlert("Välkommen")
        guard tap(["Fortsätt"], "Fortsätt") else { return false }
        guard tap(["Senare"], "Senare") else { return false }
        pause(2)
        _ = notificationAlert("Start after the first start")
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        if wait(["Gör med ChatGPT*"], 8) == nil { closeSheet(); goToStart(); tap(["Nytt prov"], "Nytt prov (again)") }
        guard tap(["Gör med ChatGPT*"], "Gör med ChatGPT") else { return false }
        tap(["Kopiera prompten"], "Kopiera prompten", quiet: true)
        UIPasteboard.general.string = Self.answer // never read the pasteboard in the test
        guard tap(["Klistra in", "Paste"], "Klistra in") else { return false }
        if let allow = wait(["Tillåt klistra in", "Allow Paste"], 3) { tapElement(allow, "Tillåt klistra in") }
        guard wait(["Hittade*"], 15) != nil else { return miss("Hittade n frågor not shown") }
        guard tap(["Spara frågorna"], "Spara frågorna") else { return false }
        pause(4)
        goToStart()
        _ = notificationAlert("Start with the exam, before playing")
        screen("start-med-prov", "Start with the exam, not played")
        if Self.labels(in: app.debugDescription, kind: "StaticText").contains(where: { $0.contains("i rad") }) {
            note("Start shows a streak before anything was played")
        }
        let early = notificationAsks
        log.append("T30 notification questions before the first exam: \(early.isEmpty ? "none" : early.joined(separator: ", "))")
        return early.isEmpty || miss("iOS asked about notifications before the first exam was played (\(early.joined(separator: ", ")))")
    }

    private func lapAndQuestion() -> Bool {
        guard waitEnabled(["Starta prov"], 30) else { return miss("Starta prov not tappable") }
        tap(["Starta prov"], "Starta prov")
        if wait(["Styr med dina AirPods"], 8) != nil {
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov"], "Starta on the control check", quiet: true)
        }
        // A whole lap: all three questions, then question 1 again (the player goes on by itself, about 7 s each).
        var order: [String] = []
        let end = Date().addingTimeInterval(150)
        var lapped = false
        while Date() < end, !lapped {
            if let q = Self.labels(in: app.debugDescription, kind: "StaticText").first(where: { $0.hasSuffix("?") && $0.contains("fotosyntes") || $0.hasSuffix("sockret till?") }) {
                if order.last != q { order.append(q) }
                if Set(order).count == 3, order.count > 3, q == order.first { lapped = true }
            }
            if order.count > 3 && Set(order).count == 3 { lapped = true }
            pause(1.5)
        }
        log.append("T30 lap: \(order.count) question changes, \(Set(order).count) different, whole lap \(lapped)")
        if !lapped { note("no whole lap seen in 150 s (\(Set(order).count) questions)") }
        _ = notificationAlert("during the lap")
        tap(["Avsluta"], "Avsluta")
        mark("ENDED")
        guard let sheet = wait(["Vill du ha en påminnelse?"], 6) else {
            screen("ingen-fraga", "No reminder question after Avsluta")
            return miss("no 'Vill du ha en påminnelse?' within 6 s of Avsluta")
        }
        log.append("T30 reminder question shown: \(sheet.label)")
        screen("paminnelse-fragan", "Vill du ha en påminnelse?")
        log.append("T30 sheet texts: " + Self.labels(in: app.debugDescription, kind: "StaticText").prefix(10).joined(separator: " | "))
        guard tap(["Påminn mig"], "Påminn mig") else { return false }
        pause(1)
        let asked = notificationAlert("after Påminn mig")
        log.append("T30 iOS asked about notifications after Påminn mig: \(asked)")
        if !asked { note("Påminn mig: no iOS notification question seen") }
        pause(2)
        return true
    }

    private func streakOnStart() -> Bool {
        goToStart()
        pause(2)
        let line = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.contains("i rad") }
        screen("start-streak", "Start after the first exam")
        log.append("T30 streak on Start: \(line ?? "(none)")")
        return line?.contains("1 dag i rad") == true || miss("Start does not say '1 dag i rad' after a whole lap")
    }

    private func settings() -> Bool {
        goToStart()
        guard tap(["Inställningar"], "Inställningar") else { return false }
        pause(1.5)
        var toggle: XCUIElement?
        for _ in 0..<12 {
            let t = app.switches.matching(NSPredicate(format: "label BEGINSWITH[c] 'Påminn mig att plugga'")).firstMatch
            if t.exists, t.isHittable { toggle = t; break }
            app.swipeUp()
        }
        screen("installningar-paminnelse", "Settings, Påminnelse")
        guard let toggle else { return miss("Settings: no 'Påminn mig att plugga'") }
        let value = String(describing: toggle.value ?? "")
        log.append("T30 settings toggle 'Påminn mig att plugga': \(value)")
        let time = find(["Tid"]) != nil
        log.append("T30 settings row Tid: \(time)")
        if value != "1" { note("Påminn mig att plugga is off after Påminn mig") }
        if !time { note("Settings: no Tid row under Påminnelse") }
        tap(["Klar", "Stäng", "Done"], "Klar (Settings)", quiet: true)
        pause(1)
        return value == "1"
    }

    /// One AirPods press through the app's Debug hook: a Darwin notification inside the Simulator.
    private static func press(_ n: Int) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("earmind.test.press.\(n)" as CFString), nil, nil, true)
    }

    private func cleanUp() -> Bool {
        goToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        guard tap(["Mer"], "Mer") else { return false }
        guard tap(["Ta bort provet", "Ta bort texten"], "Ta bort provet") else { return false }
        pause(1)
        if !confirmDestructive("Ta bort provet") { note("Ta bort provet: no confirmation button to tap") }
        pause(3)
        screen("provet-borta", "After Ta bort provet")
        return true
    }

    /// Asks the script on the runner to turn the Mac's network off or on, and waits for it (and for the app to see it).
    private func network(on: Bool) -> Bool {
        let name = on ? "t30-net-on" : "t30-net-off"
        let done = out.appendingPathComponent(name + ".done")
        try? FileManager.default.removeItem(at: done)
        try? "\(Date())\n".write(to: out.appendingPathComponent(name + ".request"), atomically: true, encoding: .utf8)
        mark(on ? "NET-ON request" : "NET-OFF request")
        let end = Date().addingTimeInterval(90)
        while Date() < end {
            if FileManager.default.fileExists(atPath: done.path) {
                offline = !on
                mark(on ? "NET-ON done" : "NET-OFF done")
                pause(on ? 20 : 6) // NWPathMonitor and DHCP
                return true
            }
            pause(2)
        }
        return miss("\(name): the runner did not answer in 90 s")
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
            XCTFail("[t30] \(name)")
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
        let fileName = String(format: "t30-%02d-%@", shots, name)
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
        var lines = ["T30 (simulator, not a device), header x-earmind-test=\(header)",
                     "taps (a user's): \(taps), test taps: \(testTaps), screens: \(shots)", "", "Sections:"] + sections
        lines += ["", "Not obvious:"] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 }) + ["", "Log:"] + log + [""]
        let text = lines.joined(separator: "\n")
        try? text.write(to: out.appendingPathComponent("t30-log.txt"), atomically: true, encoding: .utf8)
        return text
    }

    private func finish() {
        let text = writeLog()
        let summary = XCTAttachment(string: text)
        summary.name = "t30-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
