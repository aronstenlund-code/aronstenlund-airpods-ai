// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T58 part 2 (Toby (moln), Deangelo 2026-11-26 22:41, D263): "Spela in själv – helt gratis" through Angela Fable's
/// views (A165) on Angela Schrute's core (A164). From a new installation: Start → "Spela in själv – helt gratis"
/// (`home.ownDecks`) → the deck's screen (`ownDeck.name`, `ownCard.question`/`.answer`) → Spela in and Stoppa for the
/// question and the answer (`-FakeOwnRecorder 1`: two seconds of silence, the Simulator in CI has no microphone) →
/// Lägg till fråga, a second card with text only (the phone's own voice reads it) → Öva (`ownDeck.practise`) → the
/// exam player ("Fråga 1 av 2") → Avsluta → the deck's row on Start (`home.ownDeck`). The network is turned off on
/// the runner from the deck's screen until the player has played (`scripts/apptest/t58ui.sh`), and the credit capsule
/// must say the same before and after. Fake audio only (LUMEN_TEST_HEADER, D180: 0 ElevenLabs). Never a device test.
/// The sheet on 402 and `provider_*` is in the in-process test (OwnDeckE2ETests, part 2b): the UI cannot make the
/// server say no on demand, and a new account cannot ask for an exam (1,5k credits, 3 questions cost about 2,0k).
@MainActor
final class OwnDeckFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var springboard: XCUIApplication!
    private var out: URL!
    private var log: [String] = []
    private var sections: [String] = []
    private var started = Date()
    private var shots = 0

    func testOwnDeck() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["LUMEN_T58_OUT"] else { throw XCTSkip("T58 runs from scripts/apptest/t58ui.sh") }
        out = URL(fileURLWithPath: folder)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock { @MainActor [weak self] in self?.writeLog() }
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE", "-FakeOwnRecorder", "1"]
        app.launchEnvironment["LUMEN_TEST_HEADER"] = "1"
        app.launch()

        guard section("Första starten till Start", { firstStart() }) else { return }
        let before = credits()
        log.append("credits before: \(before ?? "-")")
        guard section("Ingången: Spela in själv – helt gratis", { openEntry() }) else { return }
        network(on: false)
        guard section("Namn, fråga och svar", { writeFirstCard() }) else { network(on: true); return }
        section("Spela in frågan och svaret (låtsasmikrofon)", { recordBoth() })
        section("Lägg till fråga: ett kort med bara text", { addTextCard() })
        section("Öva: provspelaren spelar samlingen utan nät", { practise() })
        network(on: true)
        section("Samlingen på Start, krediterna oförändrade", { onStart(before: before) })
    }

    // MARK: Sections

    private func firstStart() -> Bool {
        guard wait(["Välkommen till EarMind"], 30) != nil else { return miss("Välkommen not shown") }
        tap(["Fortsätt"])
        if wait(["Senare"], 10) != nil { tap(["Senare"]) }
        pause(2)
        systemAlerts()
        guard wait(["Nytt prov"], 20) != nil else { return miss("Start not shown") }
        shoot("start")
        return true
    }

    private func openEntry() -> Bool {
        let entry = app.buttons["home.ownDecks"]
        for _ in 0..<6 where !(entry.exists && entry.isHittable) { app.swipeUp(); pause(0.5) }
        guard entry.exists else { return miss("no home.ownDecks on Start") }
        log.append("entry: \(entry.label)")
        if !entry.label.contains("gratis") { note("the entry does not say it is free: \(entry.label)") }
        entry.tap()
        guard element("ownDeck.name").waitForExistence(timeout: 10) else { return miss("the deck's screen did not open") }
        pause(1)
        shoot("samling-ny")
        return true
    }

    private func writeFirstCard() -> Bool {
        guard type("T58 Biologi", into: element("ownDeck.name")) else { return miss("no name field") }
        guard type("Vad är en cell?", into: element("ownCard.question", 0)) else { return miss("no question field") }
        guard type("Livets minsta del.", into: element("ownCard.answer", 0)) else { return miss("no answer field") }
        keyboardDown()
        shoot("samling-text")
        return true
    }

    private func recordBoth() -> Bool {
        var ok = true
        for (id, name) in [("ownCard.recordQuestion", "frågan"), ("ownCard.recordAnswer", "svaret")] {
            let record = element(id, 0)
            guard record.waitForExistence(timeout: 5) else { ok = miss("no \(id)"); continue }
            record.tap()
            systemAlerts()
            let stop = element(id + ".stop", 0)
            guard stop.waitForExistence(timeout: 5) else {
                ok = miss("\(name): no Stoppa after Spela in (\(texts().prefix(300)))")
                continue
            }
            shoot("spelar-in-\(name)")
            pause(1)
            stop.tap()
            let play = element(id + ".play", 0)
            if play.waitForExistence(timeout: 5) {
                log.append("\(name) recorded: \(play.label)")
            } else {
                ok = miss("\(name): no ▶ after Stoppa")
            }
        }
        shoot("inspelad")
        return ok
    }

    private func addTextCard() -> Bool {
        let add = element("ownDeck.addCard")
        for _ in 0..<4 where !(add.exists && add.isHittable) { app.swipeUp(); pause(0.5) }
        guard add.exists else { return miss("no Lägg till fråga") }
        add.tap()
        pause(1)
        guard type("Vad gör mitokondrien?", into: element("ownCard.question", 1)) else { return miss("no second question field") }
        guard type("Den gör energi åt cellen.", into: element("ownCard.answer", 1)) else { return miss("no second answer field") }
        keyboardDown()
        shoot("tva-kort")
        return true
    }

    private func practise() -> Bool {
        let practise = element("ownDeck.practise")
        guard practise.waitForExistence(timeout: 5) else { return miss("no Öva") }
        let button = practise.buttons.firstMatch.exists ? practise.buttons.firstMatch : practise
        guard button.isEnabled else { return miss("Öva is grey with two cards") }
        button.tap()
        guard wait(["Fråga 1 av 2*"], 15) != nil else { return miss("the player did not open (\(texts().prefix(300)))") }
        shoot("spelaren")
        // Question 1 (own recording), thinking time, question 2 (the phone's voice).
        let second = wait(["Fråga 2 av 2*"], 40) != nil
        log.append("the player reached question 2: \(second)")
        shoot("spelaren-2")
        guard second else { return miss("the player never reached question 2 without network") }
        if let end = find(["Avsluta"]) { end.tap() } else { return miss("no Avsluta") }
        pause(2)
        return true
    }

    private func onStart(before: String?) -> Bool {
        if let notNow = find(["Inte nu"]), notNow.isHittable { notNow.tap(); pause(1) } // a reminder question (A109)
        guard wait(["Nytt prov"], 15) != nil else { return miss("not back on Start") }
        let row = app.descendants(matching: .any)["home.ownDeck"]
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp(); pause(0.5) }
        log.append("deck row on Start: \(row.exists ? row.label : "-")")
        shoot("start-med-samling")
        for _ in 0..<6 { app.swipeDown(); pause(0.3) }
        pause(3) // the capsule reads the balance again with the network back
        let after = credits()
        log.append("credits after: \(after ?? "-")")
        var ok = row.exists || miss("no home.ownDeck row on Start")
        if before == nil || before != after { ok = miss("credits \(before ?? "-") → \(after ?? "-")") }
        return ok
    }

    // MARK: Helpers

    private func element(_ id: String, _ index: Int = 0) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).element(boundBy: index)
    }

    private func type(_ text: String, into field: XCUIElement) -> Bool {
        guard field.waitForExistence(timeout: 5) else { return false }
        field.tap()
        pause(0.5)
        field.typeText(text)
        log.append("typed '\(text)' into \(field.identifier)")
        return true
    }

    private func keyboardDown() {
        if let done = find(["Klar", "Done", "Return", "retur"]), app.keyboards.count > 0, done.isHittable, done.identifier != "ownDeck.done" {
            done.tap()
        } else if app.keyboards.count > 0 {
            app.swipeDown()
        }
        pause(0.5)
    }

    private func credits() -> String? {
        let capsule = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'krediter kvar' OR label CONTAINS[c] 'kredit kvar'")).firstMatch
        return capsule.waitForExistence(timeout: 20) ? capsule.label : nil
    }

    /// The runner's network, through the script's request files (as T36).
    private func network(on: Bool) {
        let name = on ? "t58-net-on" : "t58-net-off"
        let request = out.appending(path: "\(name).request")
        let done = out.appending(path: "\(name).done")
        try? FileManager.default.removeItem(at: done)
        FileManager.default.createFile(atPath: request.path, contents: Data())
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, !FileManager.default.fileExists(atPath: done.path) { pause(1) }
        log.append("network \(on ? "on" : "off"): \(FileManager.default.fileExists(atPath: done.path) ? "done" : "no answer from the script")")
    }

    private func find(_ labels: [String]) -> XCUIElement? {
        for label in labels {
            let predicate = label.hasSuffix("*") ? NSPredicate(format: "label BEGINSWITH[c] %@", String(label.dropLast()))
                : NSPredicate(format: "label ==[c] %@", label)
            let button = app.buttons.matching(predicate).firstMatch
            if button.exists { return button }
            let any = app.descendants(matching: .any).matching(predicate).firstMatch
            if any.exists { return any }
        }
        return nil
    }

    private func wait(_ labels: [String], _ seconds: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if let found = find(labels) { return found }
            pause(0.3)
        } while Date() < deadline
        return nil
    }

    private func tap(_ labels: [String]) {
        guard let element = wait(labels, 8) else { log.append("MISS: no \(labels[0]) to tap"); return }
        element.tap()
        log.append("TAP \(labels[0])")
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
        }
    }

    private func texts() -> String {
        app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }.joined(separator: " | ")
    }

    private func pause(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    private func shoot(_ name: String) {
        shots += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "t58-%02d-%@", shots, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        log.append(String(format: "shot %@ at %.0f s", attachment.name ?? name, Date().timeIntervalSince(started)))
    }

    private func note(_ what: String) { log.append("UNCLEAR: \(what)") }

    @discardableResult
    private func miss(_ what: String) -> Bool {
        log.append("MISS: \(what)")
        return false
    }

    @discardableResult
    private func section(_ name: String, _ body: () -> Bool) -> Bool {
        let t0 = Date()
        log.append("=== \(name)")
        let ok = body()
        let line = String(format: "%@ %@: %.0f s", ok ? "OK " : "FEL", name, Date().timeIntervalSince(t0))
        sections.append(line)
        log.append(line)
        writeLog()
        if !ok {
            shoot("fel-\(sections.count)")
            XCTFail("[t58] \(name)")
        }
        return ok
    }

    private func writeLog() {
        let text = (["T58 views (simulator, not a device)", "", "Sections:"] + sections + ["", "Log:"] + log).joined(separator: "\n")
        try? text.write(to: out.appending(path: "t58-log.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
