// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T27 (Toby (moln), Deangelo 2026-11-15 02:40, after Angela Schrute's A103 / D186): an exam played without a network.
/// Fake audio only (D180: `LUMEN_TEST_HEADER` sends x-earmind-test, and the Simulator in Actions is a `ci` test).
///
/// One Simulator (`scripts/apptest/offline.sh`). The test makes an exam online (Fota sidor → Välj bilder → Skapa
/// frågor → Ser rätt ut) and waits until its sound is on the phone. Then it asks the runner to take the Mac's network
/// away (file `t27-net-off.request`; the script turns every network service off and writes `t27-net-off.done`, with a
/// watchdog that turns them on again after 9 minutes whatever happens). Without a network it checks:
/// - Start, Nytt prov (said in advance, Skapa frågor grey), the exam's screen (Dela and Publicera grey, one line),
///   Prov från din skola (says there is no connection);
/// - Starta prov plays question after question from the files (the app log's "Repetition:" lines are read by the
///   script), and a tap on a paused screen goes on;
/// - the same after the app is relaunched (in the Simulator a relaunch is a new anonymous account, D183).
/// Then the network comes back (`t27-net-on.request` / `.done`) and the exam is removed.
/// AirPods presses (1, 2, 3) cannot be sent from a UI test (no hook in the app; asked of Angela Schrute in the report).
/// The press logic itself is T18 (`RepetitionE2ETests`). Simulator only: never a verification on a device.
@MainActor
final class OfflineFlowTests: XCTestCase {
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

    func testOffline() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard env["LUMEN_T27_OUT"] != nil else { throw XCTSkip("T27 runs from scripts/apptest/offline.sh") }
        header = env["LUMEN_T27_HEADER"] ?? "1"
        out = URL(fileURLWithPath: env["LUMEN_T27_OUT"]!)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock { @MainActor [weak self] in
            // Never leave the runner without a network (the script's watchdog is the second guard).
            if self?.offline == true { _ = self?.network(on: true) }
            self?.finish()
        }
        launch(header)
        guard section("Online: ett prov med ljud på telefonen", { makeExam() }) else { return }
        guard section("Nätet av", { network(on: false) }) else { return }
        section("Utan nät: Start och Nytt prov", { startAndNewExamOffline() })
        section("Utan nät: provets skärm (Dela, Publicera)", { examScreenOffline() })
        section("Utan nät: Prov från din skola", { schoolOffline() })
        section("Utan nät: Starta prov", { play("spela-1", seconds: 35) })
        // Run 43672420846: GitHub cancelled the job when the runner had been offline about 4.5 min, so the network
        // comes back between the two windows (each about 2 min). The relaunch is inside the second one.
        guard section("Nätet på (mellan fönstren)", { network(on: true) }) else { return }
        guard section("Nätet av igen", { network(on: false) }) else { return }
        section("Utan nät: omstart och Starta prov igen", { relaunchAndPlay() })
        section("Nätet på", { network(on: true) })
        section("Online igen: Dela går att trycka", { backOnline() })
        section("Ta bort provet", { cleanUp() })
    }

    // MARK: Steps

    private func makeExam() -> Bool {
        guard wait(["Välkommen till EarMind"], 20) != nil else { return miss("Välkommen not shown") }
        guard tap(["Fortsätt"], "Fortsätt") else { return false }
        guard tap(["Fota sidor"], "Fota sidor") else { return false }
        systemAlerts()
        pause(2)
        closeSheet()
        guard pickPhoto() else { return false }
        lowerQuestions(to: 4)
        guard tap(["Skapa frågor"], "Skapa frågor") else { return false }
        guard wait(["Ser rätt ut"], 180) != nil else { return miss("Stämmer det här? not shown in 180 s") }
        guard waitEnabled(["Ser rätt ut"], 120), tap(["Ser rätt ut"], "Ser rätt ut") else { return miss("Ser rätt ut not tappable") }
        guard waitEnabled(["Starta prov"], 240) else { screen("inget-ljud", "No Starta prov"); return miss("Starta prov not enabled in 240 s") }
        // Starta prov opens with the first question's sound (K46); the rest is still downloading. Wait until Start has no
        // line about the sound being made or downloaded, at most 180 s, so "downloaded" means the whole exam.
        let end = Date().addingTimeInterval(180)
        var last: [String] = []
        repeat {
            pause(5)
            last = Self.labels(in: app.debugDescription, kind: "StaticText").filter {
                $0.localizedCaseInsensitiveContains("ljud") || $0.localizedCaseInsensitiveContains("laddas")
            }
        } while !last.isEmpty && Date() < end
        log.append("sound lines on Start before the network goes: \(last.isEmpty ? "(none)" : last.joined(separator: " | "))")
        if !last.isEmpty { note("Start still says '\(last[0])' 180 s after Starta prov became tappable") }
        pause(20) // the last files
        screen("online-start", "Start online, the exam ready")
        return true
    }

    private func startAndNewExamOffline() -> Bool {
        pause(5)
        screen("utan-nat-start", "Start without a network")
        let texts = Self.labels(in: app.debugDescription, kind: "StaticText")
        log.append("Start offline texts: \(texts.prefix(30).joined(separator: " | "))")
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        pause(2)
        screen("utan-nat-nytt-prov", "Nytt prov without a network")
        let said = find(["Ingen internetanslutning*"]) != nil
        if !said { note("Nytt prov offline: no 'Ingen internetanslutning …' line") }
        if let create = find(["Skapa frågor"]), create.isEnabled { note("Nytt prov offline: Skapa frågor is tappable") }
        closeSheet()
        if !atStart() { goToStart() }
        return said
    }

    private func examScreenOffline() -> Bool {
        goToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        pause(2)
        screen("utan-nat-provet", "The exam's screen without a network")
        let said = find(["Ingen internetanslutning. Dela och Publicera*"]) != nil
        if !said { note("exam screen offline: no line about Dela and Publicera") }
        if let share = find(["Dela"]), share.isEnabled { note("exam screen offline: Dela is tappable") }
        if tap(["Mer"], "Mer") {
            pause(1)
            screen("utan-nat-mer", "Mer without a network")
            if let publish = find(["Publicera prov"]), publish.isEnabled { note("Mer offline: Publicera prov is tappable") }
            closeMenu()
        }
        goToStart()
        return said
    }

    private func schoolOffline() -> Bool {
        goToStart()
        // On Start (RepetitionHomeSection) and, in some states, in Nytt prov.
        var opened = tap(["Hitta prov från din skola", "Prov från din skola*"], "Hitta prov från din skola", quiet: true)
        if !opened, tap(["Nytt prov"], "Nytt prov", quiet: true) {
            opened = tap(["Hitta prov från din skola", "Prov från din skola*"], "Hitta prov från din skola", quiet: true)
        }
        guard opened else {
            note("offline: no 'Hitta prov från din skola' on Start or in Nytt prov (with one exam)")
            closeSheet(); goToStart()
            return true
        }
        pause(4)
        screen("utan-nat-skolan", "Prov från din skola without a network")
        let said = find(["Ingen internetanslutning*"]) != nil
        if !said { note("Prov från din skola offline: does not say there is no connection") }
        closeSheet(); goToStart()
        return said
    }

    /// Starta prov → (control check: Hoppa över ×3) → the player for `seconds`; samples the screen every 3 s.
    private func play(_ name: String, seconds: TimeInterval) -> Bool {
        goToStart()
        mark("PLAY-START \(name)")
        guard waitEnabled(["Starta prov"], 30) else {
            screen("\(name)-gra", "Starta prov grey")
            log.append("GREY texts: " + Self.labels(in: app.debugDescription, kind: "StaticText").prefix(40).joined(separator: " | "))
            log.append("GREY buttons: " + Self.labels(in: app.debugDescription, kind: "Button").prefix(30).joined(separator: " | "))
            // The exam's own screen says why (status line), as a user would look.
            if tap(["Frågor och svar"], "Frågor och svar (why grey)", quiet: true) {
                pause(2)
                screen("\(name)-gra-provet", "The exam's screen while Starta prov is grey")
                log.append("GREY exam texts: " + Self.labels(in: app.debugDescription, kind: "StaticText").prefix(40).joined(separator: " | "))
                goToStart()
            }
            return miss("Starta prov not tappable offline (30 s)")
        }
        tap(["Starta prov"], "Starta prov")
        if wait(["Styr med dina AirPods"], 8) != nil {
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov"], "Starta on the control check", quiet: true)
        }
        guard wait(["Tryck på AirPods för svaret", "Tänk", "Avsluta"], 20) != nil else { return miss("no player") }
        screen("\(name)-fraga", "The player without a network")
        var questions: [String] = []
        var waiting = 0
        var problems: [String] = []
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            let texts = Self.labels(in: app.debugDescription, kind: "StaticText")
            for q in texts where q.hasSuffix("?") && !questions.contains(q) { questions.append(q) }
            if texts.contains(where: { $0.hasPrefix("Gör ljud") || $0.hasPrefix("Hämtar") || $0.hasPrefix("Väntar på ljudet") }) { waiting += 1 }
            for t in texts where (t.contains("kan inte") || t.contains("internet")) && !problems.contains(t) { problems.append(t) }
            pause(3)
        }
        screen("\(name)-efter", "The player after \(Int(seconds)) s without a network")
        log.append("\(name): questions seen \(questions.count): \(questions.joined(separator: " | ")); samples waiting for sound \(waiting); problem lines: \(problems.joined(separator: " | "))")
        tap(["Avsluta"], "Avsluta")
        if !gone(["Avsluta"], 6) { tap(["Avsluta"], "Avsluta again", quiet: true) }
        mark("PLAY-END \(name)")
        if waiting > 0 { note("\(name): the player waited for sound in \(waiting) samples without a network") }
        if !problems.isEmpty { note("\(name): the player said: \(problems[0])") }
        return questions.count >= 2 && waiting == 0 || miss("\(name): \(questions.count) questions, \(waiting) samples waiting for sound")
    }

    private func relaunchAndPlay() -> Bool {
        launch(header)
        guard wait(["Inställningar"], 30) != nil else { screen("omstart-ingen-start", "No Start after relaunch"); return miss("Start not shown after relaunch offline") }
        pause(8)
        screen("utan-nat-omstart", "Start after relaunch without a network")
        if find(["Kom förberedd till provet"]) != nil { return miss("relaunch offline: Start is empty, the exam is gone") }
        return play("spela-2", seconds: 25)
    }

    private func backOnline() -> Bool {
        pause(15)
        goToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        pause(3)
        screen("online-igen", "The exam's screen with the network back")
        let line = find(["Ingen internetanslutning. Dela och Publicera*"]) != nil
        if line { note("network back: the offline line is still there after 15 s") }
        let share = find(["Dela"])?.isEnabled == true
        if !share { note("network back: Dela still grey") }
        goToStart()
        return !line && share
    }

    private func cleanUp() -> Bool {
        goToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        guard tap(["Mer"], "Mer") else { return false }
        guard tap(["Ta bort provet"], "Ta bort provet") else { return false }
        pause(1)
        if !confirmDestructive("Ta bort provet") { note("Ta bort provet: no confirmation button to tap") }
        pause(3)
        screen("provet-borta", "After Ta bort provet")
        return true
    }

    /// Asks the script on the runner to turn the Mac's network off or on, and waits for it (and for the app to see it).
    private func network(on: Bool) -> Bool {
        let name = on ? "t27-net-on" : "t27-net-off"
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
            XCTFail("[t27] \(name)")
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
        let fileName = String(format: "t27-%02d-%@", shots, name)
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
        var lines = ["T27 (simulator, not a device), header x-earmind-test=\(header)",
                     "taps (a user's): \(taps), test taps: \(testTaps), screens: \(shots)", "", "Sections:"] + sections
        lines += ["", "Not obvious:"] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 }) + ["", "Log:"] + log + [""]
        let text = lines.joined(separator: "\n")
        try? text.write(to: out.appendingPathComponent("t27-log.txt"), atomically: true, encoding: .utf8)
        return text
    }

    private func finish() {
        let text = writeLog()
        let summary = XCTAttachment(string: text)
        summary.name = "t27-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
