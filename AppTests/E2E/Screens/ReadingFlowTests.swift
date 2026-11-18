// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T28 (Toby (moln), Deangelo 2026-11-15 02:45; after Angela Schrute's A105 and Angela Fable's A106, D185/D188): the
/// reading mode in the app. Fake audio only (D180: `LUMEN_TEST_HEADER`), presses through Angela Schrute's Debug hook
/// (`LUMEN_TEST_PRESSES`, Darwin notifications `earmind.test.press.1/2/3`, 60d83ce), one Simulator
/// (`scripts/apptest/reading.sh`, the network switch of T27's `offline.sh`).
/// Steps: a text made with Nytt prov → Läs upp texten → Skriv text → Skapa uppläsning → Ser rätt ut; the player with
/// 1 press (pause and go on), 2 presses (next sentence), 3 presses (previous), a tap on a sentence; Avsluta and the
/// place on Start; then without a network: relaunch, Start still says the place, Fortsätt reads from it.
/// The app log's "Reading: …" lines (in the summary) say what the player did. D188: the test account's fake audio has
/// no sentence times, so a press moves the place but the sound starts the part again. Simulator only, never a device.
@MainActor
final class ReadingFlowTests: XCTestCase {
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
    private var savedPlace: String?
    private var atEnd = false

    static let material = """
    Fotosyntes
    Växter tillverkar socker av koldioxid och vatten. Det sker med hjälp av solljus. Klorofyllet i bladen fångar ljuset.
    Syre
    Syre bildas och släpps ut genom bladen. Sockret ger växten energi. Det används också som byggmaterial.
    """

    func testReading() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard env["LUMEN_T28_OUT"] != nil else { throw XCTSkip("T28 runs from scripts/apptest/reading.sh") }
        header = env["LUMEN_T28_HEADER"] ?? "1"
        out = URL(fileURLWithPath: env["LUMEN_T28_OUT"]!)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock { @MainActor [weak self] in
            if self?.offline == true { _ = self?.network(on: true) }
            self?.finish()
        }
        launch(header)
        guard section("En text med Läs upp texten", { makeText() }) else { return }
        section("Spelaren: 1, 2 och 3 tryck", { readingPresses() })
        section("Spelaren: tryck på en mening", { tapSentence() })
        section("Avsluta: platsen på Start", { endAndPlace() })
        guard section("Nätet av", { network(on: false) }) else { return }
        section("Utan nät: omstart, platsen kvar, Fortsätt", { relaunchAndResume() })
        section("Nätet på", { network(on: true) })
        section("Ta bort texten", { cleanUp() })
    }

    // MARK: Steps

    private func makeText() -> Bool {
        guard wait(["Välkommen till EarMind"], 20) != nil else { return miss("Välkommen not shown") }
        guard tap(["Fortsätt"], "Fortsätt") else { return false }
        guard tap(["Senare"], "Senare") else { return false }
        pause(2)
        // Runs up to 43749392418: the Simulator's photo picker gave a sample photo and Skriv text takes no text from
        // XCUITest. Angela Schrute's LUMEN_TEST_MATERIAL (dbedcd6) puts the material in Nytt prov: relaunch with it now
        // that the first start is over (the choice Läs upp texten is not in the first start's Nytt prov).
        launch(header, material: Self.material.replacingOccurrences(of: "\n", with: "\\n"))
        // The hook fills the material in when Nytt prov opens (NewDrillView); it does not open Nytt prov by itself.
        _ = wait(["Inställningar"], 20)
        if find(["Läs upp texten"]) == nil { tap(["Nytt prov"], "Nytt prov (with LUMEN_TEST_MATERIAL)") }
        guard wait(["Läs upp texten", "Skapa frågor", "Skapa uppläsning"], 20) != nil else {
            screen("ingen-krok", "No Nytt prov with the material after the relaunch")
            return miss("LUMEN_TEST_MATERIAL: Nytt prov did not open with the material")
        }
        pause(1)
        guard tap(["Läs upp texten"], "Gör: Läs upp texten") else { screen("ingen-las-upp", "No Läs upp texten"); return miss("no 'Läs upp texten' in Nytt prov") }
        screen("nytt-prov-text", "Nytt prov with the material and Läs upp texten")
        pause(1)
        guard waitEnabled(["Skapa uppläsning"], 15), tap(["Skapa uppläsning"], "Skapa uppläsning") else {
            screen("ingen-skapa-upplasning", "Skapa uppläsning not tappable")
            return miss("Skapa uppläsning not tappable")
        }
        guard wait(["Ser rätt ut"], 180) != nil else { screen("ingen-stammer", "No Stämmer det här?"); return miss("Stämmer det här? not shown in 180 s") }
        screen("stammer-text", "Stämmer det här? for a text")
        guard waitEnabled(["Ser rätt ut"], 120), tap(["Ser rätt ut"], "Ser rätt ut") else { return miss("Ser rätt ut not tappable") }
        pause(3)
        goToStart()
        guard waitEnabled(["Starta prov"], 240) else { screen("text-inget-ljud", "No Starta prov"); return miss("Starta prov not enabled in 240 s") }
        let end = Date().addingTimeInterval(180)
        var last: [String] = []
        repeat {
            pause(5)
            last = Self.labels(in: app.debugDescription, kind: "StaticText").filter {
                ($0.localizedCaseInsensitiveContains("ljud") || $0.localizedCaseInsensitiveContains("laddas"))
                    && !$0.localizedCaseInsensitiveContains("ljud klart")
            }
        } while !last.isEmpty && Date() < end
        log.append("sound lines on Start: \(last.isEmpty ? "(none)" : last.joined(separator: " | "))")
        screen("start-text", "Start with the text, sound ready")
        log.append("Start texts: " + Self.labels(in: app.debugDescription, kind: "StaticText").prefix(20).joined(separator: " | "))
        return true
    }

    /// The edit menu's paste item, only one that can be tapped.
    private func pasteItem(_ timeout: TimeInterval) -> XCUIElement? {
        let predicate = NSPredicate(format: "label ==[c] 'Klistra in' OR label ==[c] 'Paste'")
        let end = Date().addingTimeInterval(timeout)
        repeat {
            for query in [app.menuItems, app.buttons] {
                if let item = query.matching(predicate).allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) { return item }
            }
            pause(0.3)
        } while Date() < end
        return nil
    }

    /// "Mening n av m" in the player.
    private func place() -> String? {
        Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Mening ") && $0.contains(" av ") }
    }

    private func openPlayer(_ labels: [String]) -> Bool {
        goToStart()
        guard waitEnabled(labels, 20) else { return miss("no \(labels.joined(separator: "/")) on Start") }
        tap(labels, labels[0])
        if wait(["Styr med dina AirPods"], 8) != nil {
            screen("styr-text", "Styr med dina AirPods for a text")
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov", "Fortsätt"], "Starta on the control check", quiet: true)
        }
        guard wait(["Mening *"], 20) != nil else { screen("ingen-spelare", "No reading player"); return miss("no 'Mening n av m' in the player") }
        return true
    }

    private func readingPresses() -> Bool {
        mark("READING-START")
        guard openPlayer(["Starta prov"]) else { return false }
        pause(3)
        let p0 = place()
        screen("spelaren", "The reading player")
        log.append("READ place at start: \(p0 ?? "-")")
        var ok = true
        Self.press(2)
        pause(3)
        let p2 = place()
        log.append("READ press 2: \(p0 ?? "-") → \(p2 ?? "-")")
        if p2 == p0 { note("press 2 did not move the place on the screen (\(p0 ?? "-"))") }
        Self.press(2)
        pause(3)
        let p22 = place()
        log.append("READ press 2 again: \(p2 ?? "-") → \(p22 ?? "-")")
        Self.press(3)
        pause(3)
        let p3 = place()
        log.append("READ press 3: \(p22 ?? "-") → \(p3 ?? "-")")
        if p3 == p22 { note("press 3 did not move the place back (\(p22 ?? "-"))") }
        screen("efter-2-och-3", "After 2, 2 and 3 presses")
        // Nightly 43791360412: the fake audio has no sentence times and can reach the last sentence before these presses;
        // there 1 press is Börja om (D188), and Start's card also has a "Fortsätt". So only check that 1 press toggles.
        let before = readingPaused()
        Self.press(1)
        pause(3)
        let first = readingPaused()
        log.append("READ press 1: paused \(before) → \(first)")
        screen("pausad", "After 1 press")
        Self.press(1)
        pause(3)
        let second = readingPaused()
        log.append("READ press 1 again: paused \(first) → \(second)")
        if first == second { ok = false; log.append("MISS: two 1 presses did not toggle pause (\(first) both times)") }
        mark("READING-PRESSES-END")
        return ok
    }

    /// The player is paused when its own "Pausa" button is gone (Start's card under it has a "Fortsätt" of its own).
    private func readingPaused() -> Bool {
        !app.buttons.matching(NSPredicate(format: "label ==[c] 'Pausa'")).firstMatch.exists
    }

    /// Ke63: a tap on a sentence reads from there. The text is one UITextView; tap low in it, then high.
    private func tapSentence() -> Bool {
        // Run 43740301853: no UITextView in the tree; the text carries the current sentence as its label (A106).
        var text = app.textViews.firstMatch
        if !text.exists {
            // Run 43754170486: the first long label was Start's card under the player. The sentence is the text after
            // "Mening n av m" and the heading: a sentence ending in "." that is not a status line.
            let texts = Self.labels(in: app.debugDescription, kind: "StaticText")
            let afterPlace = texts.drop { !$0.hasPrefix("Mening ") }
            let current = afterPlace.first { $0.hasSuffix(".") && !$0.hasPrefix("Pausad") && !$0.hasPrefix("Mening ") } ?? ""
            let byLabel = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", current)).allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
            log.append("READ text element by its sentence: \(byLabel.count) (\(current.prefix(40)))")
            guard let element = byLabel.max(by: { $0.frame.height < $1.frame.height }) else { return miss("the reading text is not in the tree (\(current))") }
            log.append("READ text element frame: \(Int(element.frame.minY))–\(Int(element.frame.maxY))")
            text = element
        }
        // Run 43756705421: after the first tap the current sentence changed, so the element (found by that sentence's
        // label) was gone and the second tap stopped the test. Keep the frame and tap screen coordinates.
        let frame = text.frame
        func tapAt(_ y: CGFloat) {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.minX + frame.width * 0.3, dy: frame.minY + frame.height * y)).tap()
            taps += 1
        }
        let before = place()
        tapAt(0.85)
        pause(3)
        let low = place()
        log.append("READ tap low in the text: \(before ?? "-") → \(low ?? "-")")
        tapAt(0.08)
        pause(3)
        let high = place()
        log.append("READ tap high in the text: \(low ?? "-") → \(high ?? "-")")
        screen("tryck-pa-mening", "After a tap on a sentence")
        if before == low, low == high { note("a tap on a sentence did not move the place (\(before ?? "-"))") }
        // Leave it at a later sentence, so the place after Avsluta is not the first one.
        Self.press(2)
        pause(3)
        return true
    }

    private func endAndPlace() -> Bool {
        let inPlayer = place()
        log.append("READ place before Avsluta: \(inPlayer ?? "-")")
        tap(["Avsluta"], "Avsluta")
        pause(2)
        goToStart()
        pause(2)
        savedPlace = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Du var på mening") }
        screen("start-platsen", "Start after Avsluta")
        log.append("READ Start after Avsluta: \(savedPlace ?? "(no 'Du var på mening')")")
        // D188: at the end of the text the saved place becomes 0, so Start says nothing (run 43758889302). The fake sound
        // has no sentence times and plays fast, so where the test stands at Avsluta varies between runs.
        if let p = inPlayer, let m = p.range(of: #"Mening (\d+) av (\d+)"#, options: .regularExpression) {
            let nums = p[m].split(separator: " ").compactMap { Int($0) }
            if nums.count == 2, nums[0] == nums[1] {
                atEnd = true
                log.append("READ Avsluta at the last sentence: no saved place is D188 (the place becomes 0 at the end)")
                return savedPlace == nil || miss("at the end Start still says '\(savedPlace!)' (D188: the place becomes 0)")
            }
        }
        return savedPlace != nil || miss("Start does not say 'Du var på mening n av m' after Avsluta")
    }

    private func relaunchAndResume() -> Bool {
        launch(header)
        guard wait(["Inställningar"], 30) != nil else { return miss("Start not shown after relaunch offline") }
        pause(6)
        let again = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Du var på mening") }
        screen("utan-nat-omstart", "Start after relaunch without a network")
        log.append("READ Start after relaunch offline: \(again ?? "(none)") (before: \(savedPlace ?? "-"))")
        var ok = true
        if again == nil, !atEnd { ok = false; log.append("MISS: the place is gone after the relaunch") }
        guard openPlayer(["Fortsätt", "Starta prov"]) else { return false }
        pause(4)
        let resumed = place()
        log.append("READ player after Fortsätt offline: \(resumed ?? "-")")
        screen("utan-nat-fortsatt", "The reading player without a network after Fortsätt")
        Self.press(2)
        pause(3)
        log.append("READ press 2 offline: \(resumed ?? "-") → \(place() ?? "-")")
        if find(["Ingen internetanslutning*"]) != nil { note("offline: the player says there is no connection") }
        tap(["Avsluta"], "Avsluta")
        pause(2)
        return ok
    }

    /// One AirPods press through the app's Debug hook: a Darwin notification inside the Simulator.
    private static func press(_ n: Int) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("earmind.test.press.\(n)" as CFString), nil, nil, true)
    }

    private func cleanUp() -> Bool {
        goToStart()
        // Kelly L2: a text's row is "Texten", not "Frågor och svar".
        guard tap(["Texten", "Frågor och svar"], "Texten") else { return false }
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
        let name = on ? "t28-net-on" : "t28-net-off"
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
            // A109: "Vill du ha en påminnelse?" after the first finished exam (T30 tests the question itself).
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
        if cells.isEmpty {
            // No sample pictures by name: any small image in the grid (our picture is the newest, top left).
            cells = app.images.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 40 && $0.frame.width < 250 && $0.frame.minY > 80 }
            log.append("READ photo grid without sample names: \(cells.count) images")
        }
        guard let width = cells.map(\.frame.width).max(), let top = cells.map(\.frame.minY).min() else {
            return miss("no grid of pictures")
        }
        // Run 43746140315 (and every T28 run: 527899 bytes each time): top left was one of iOS's samples (a waterfall),
        // not our picture. Our picture is not an Image element (T24 handover), so it is the grid slot that no sample
        // covers: find the columns and rows of the samples and tap the first slot without one.
        let xs = Array(Set(cells.map { Int($0.frame.minX.rounded()) })).sorted()
        let ys = Array(Set(cells.map { Int($0.frame.minY.rounded()) })).sorted()
        let step = ys.count > 1 ? ys[1] - ys[0] : Int(width) + 2
        var slot: CGPoint?
        search: for y in ys + [(ys.last ?? Int(top)) + step] {
            for x in xs where !cells.contains(where: { abs(Int($0.frame.minX) - x) < 6 && abs(Int($0.frame.minY) - y) < 6 }) {
                slot = CGPoint(x: CGFloat(x) + width / 2, y: CGFloat(y) + width / 2)
                break search
            }
        }
        log.append("READ photo grid: \(xs.count) columns, \(ys.count) rows, samples \(cells.count), free slot \(slot.map { "\(Int($0.x)),\(Int($0.y))" } ?? "none")")
        let point = slot ?? CGPoint(x: width / 2, y: top + width / 2)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        taps += 1
        if let add = wait(["Lägg till", "Add", "Klar", "Done"], 3) { tapElement(add, "Lägg till in the photo library") }
        return wait(["1 foto*"], 20) != nil || waitEnabled(["Skapa uppläsning", "Skapa frågor"], 10) || miss("the picture did not get in")
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

    private func launch(_ value: String, material: String? = nil) {
        app?.terminate()
        app = XCUIApplication()
        // Angela Schrute's hook (dbedcd6, Debug only): Nytt prov opens with this text as its material.
        if let material { app.launchEnvironment["LUMEN_TEST_MATERIAL"] = material }
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
            XCTFail("[t28] \(name)")
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

    private func hittableTwin(_ labels: [String]) -> XCUIElement? {
        for label in labels {
            let predicate = label.hasSuffix("*")
                ? NSPredicate(format: "label BEGINSWITH[c] %@", String(label.dropLast()))
                : NSPredicate(format: "label ==[c] %@", label)
            if let hit = app.buttons.matching(predicate).allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) { return hit }
        }
        return nil
    }

    @discardableResult
    private func tap(_ labels: [String], _ step: String, counted: Bool = true, quiet: Bool = false) -> Bool {
        guard var element = wait(labels, quiet ? 1.5 : 6) else {
            if !quiet { log.append("MISS: \(step): '\(labels[0])' not found") }
            return false
        }
        // A132 (run 44163428569): Start's own "Klistra in" (empty field, text on the clipboard) stands behind a sheet
        // with the same label, and the first match was that one. Take a hittable button with the same label first.
        if !element.isHittable, let twin = hittableTwin(labels) { element = twin }
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
        let fileName = String(format: "t28-%02d-%@", shots, name)
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
        var lines = ["T28 (simulator, not a device), header x-earmind-test=\(header)",
                     "taps (a user's): \(taps), test taps: \(testTaps), screens: \(shots)", "", "Sections:"] + sections
        lines += ["", "Not obvious:"] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 }) + ["", "Log:"] + log + [""]
        let text = lines.joined(separator: "\n")
        try? text.write(to: out.appendingPathComponent("t28-log.txt"), atomically: true, encoding: .utf8)
        return text
    }

    private func finish() {
        let text = writeLog()
        let summary = XCTAttachment(string: text)
        summary.name = "t28-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
