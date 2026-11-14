// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T21 (Toby 2): a new user in A94's first start (Kelly Ke55, `docs/design/forsta-starten.md`), from a fresh install
/// (the script erases the Simulator) to the first question of the first exam. Only what is on the screen, the obvious
/// button. Every screen is photographed with its texts and buttons, every tap counted and timed.
///
/// Krav (T21): at most 3 screens before the camera, and no BETA text in the first start.
///
/// The Simulator has no document camera: Fota sidor is tapped and what appears is recorded (that is where the camera
/// would be), then the test goes on with **Skriv text**, the same Nytt prov. Taps a real user would not make are
/// counted apart as test taps: the question count down to 3 (D120, about 0.15 USD of voice instead of 0.5), the three
/// "Hoppa över" on Styr med dina AirPods (no AirPods in the Simulator). Live backend: drill and drill audio.
///
/// `LUMEN_T21` must be set (from `scripts/apptest/newuser.sh`); the T3 screen tour runs this target too.
/// Simulator only: never a verification on a device. Whether the question is heard is not visible to a UI test.
@MainActor
final class NewUserRepetitionTests: XCTestCase {
    private var app: XCUIApplication!
    private var springboard: XCUIApplication!
    private var started = Date()
    private var taps = 0
    private var testTaps = 0
    private var screens = 0
    private var log: [String] = []
    private var milestones: [String] = []
    private var unclear: [String] = []
    private var betaSeen: [String] = []
    private var betaAfter: Set<String> = []
    private var inFirstStart = true
    private var screensBeforeCamera: Int?

    private let material = "Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial."

    func testNewUserToFirstQuestion() throws {
        continueAfterFailure = true
        guard ProcessInfo.processInfo.environment["LUMEN_T21"] != nil else {
            throw XCTSkip("T21 runs from scripts/apptest/newuser.sh (live, paid)")
        }
        app = XCUIApplication()
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
        started = Date()
        app.launch()
        milestone("app opened")
        // In teardown, so the log is written also when XCTest stops the test early (run 43583904414 had none).
        addTeardownBlock { @MainActor [weak self] in self?.finish() }

        // 1. Välkommen
        guard wait(["Välkommen till Earmind"], 15) != nil else {
            screen("forsta-skarmen", "First screen is not Välkommen")
            fail("Välkommen till Earmind not shown at the first start")
            return
        }
        screen("valkommen", "Skärm 1: Välkommen")
        if tap(["Läs mer"], "Läs mer (data och integritet)", counted: false) {
            screen("las-mer", "Läs mer: Data och integritet (looked at, not counted as a screen of the path)", counts: false)
            tap(["Klar"], "Klar on Läs mer", counted: false)
        }
        guard tap(["Fortsätt"], "Fortsätt on Välkommen") else { return }

        // 2. Nytt prov (first time)
        guard wait(["Fota sidor"], 10) != nil else {
            screen("efter-fortsatt", "After Fortsätt: no Fota sidor")
            fail("Nytt prov with Fota sidor not shown after Fortsätt")
            return
        }
        screen("nytt-prov", "Skärm 2: Nytt prov")
        if find(["Börja med materialet till ditt nästa prov."]) == nil {
            note("Nytt prov: the line 'Börja med materialet till ditt nästa prov.' is missing")
        }

        // 3. The camera is the next step: the screens before it are counted here (krav högst 3).
        screensBeforeCamera = screens
        milestone("camera reached (Fota sidor on the screen)")
        // LUMEN_T21_ORDER: camera-first (a new user's order) or text-first. Runs 43585273570 and 43586474124: after the
        // photo library sheet (Fota sidor in the Simulator) the text field under Skriv text never got focus; the
        // script runs both orders to see whether the sheet before it is the cause.
        // Run 43587898100: Skriv text got no focus in either order (a blank sheet, no keyboard), so the default path
        // is photo: Fota sidor (what the Simulator shows instead of the camera), then Välj bilder with a picture of
        // the material that the script put in the photo library.
        let order = ProcessInfo.processInfo.environment["LUMEN_T21_ORDER"] ?? "photo"
        log.append("order: \(order)")
        switch order {
        case "text-first":
            guard textStep() else { return }
            cameraStep()
        case "camera-first":
            cameraStep()
            guard textStep() else { return }
        default:
            cameraStep()
            guard photoStep() else { return }
        }
        screen("nytt-prov-material", "Nytt prov with the material")
        lowerQuestionsToThree()

        guard tap(["Skapa frågor"], "Skapa frågor") else { return }
        milestone("Skapa frågor")
        guard wait(["Ser rätt ut", "Stämmer det här?"], 180) != nil else {
            screen("skapa-fragor", "No Stämmer det här? within 180 s")
            fail("Stämmer det här? not shown within 180 s of Skapa frågor")
            return
        }
        milestone("Stämmer det här?")
        screen("stammer", "Stämmer det här?")
        guard waitEnabled(["Ser rätt ut"], 120), tap(["Ser rätt ut"], "Ser rätt ut") else {
            fail("Ser rätt ut not tappable within 120 s")
            return
        }
        inFirstStart = false // A94's first start ends here; Start follows

        // The question list: Starta prov when the sound is made ("Gör ljud …" before)
        guard wait(["Starta prov", "Gör ljud …"], 30) != nil else {
            screen("fragelistan", "No question list after Ser rätt ut")
            fail("question list not shown after Ser rätt ut")
            return
        }
        screen("fragelistan", "Frågelistan")
        milestone("question list")
        guard waitEnabled(["Starta prov"], 300) else {
            screen("gor-ljud", "Still no Starta prov after 300 s")
            fail("Starta prov not enabled within 300 s (sound)")
            return
        }
        milestone("sound ready")
        tap(["Starta prov"], "Starta prov in the question list")

        // Styr med dina AirPods (first time): no AirPods in the Simulator, so the three steps are skipped
        if wait(["Styr med dina AirPods", "Medan frågan spelas:"], 10) != nil {
            screen("styr", "Styr med dina AirPods")
            for n in 1...3 {
                guard let skip = wait(["Hoppa över"], 15) else { break }
                tapElement(skip, "Hoppa över \(n) (Simulator: no AirPods)", counted: false)
                pause(0.5)
            }
            screen("styr-klar", "Styr med dina AirPods after the skips")
            guard tap(["Starta ändå", "Starta prov"], "Starta on Styr med dina AirPods") else { return }
        } else {
            note("Styr med dina AirPods did not show before the first question")
        }

        // The first question
        if wait(["Tryck på AirPods för svaret", "Tänk", "Avsluta", "Gör ljud …"], 20) != nil {
            milestone("first question")
            screen("forsta-fragan", "The first question plays")
        } else {
            screen("ingen-fraga", "No player after Starta")
            fail("the player did not show after Starta")
        }
        if let end = find(["Avsluta"]) { tapElement(end, "Avsluta (end of the test)", counted: false) }

        XCTAssertLessThanOrEqual(screensBeforeCamera ?? 99, 3, "screens before the camera")
        XCTAssertTrue(betaSeen.isEmpty, "BETA in the first start: \(betaSeen)")
    }

    // MARK: Steps

    /// Fota sidor and back. The Simulator has no document camera; what appears is photographed and closed.
    private func cameraStep() {
        tap(["Fota sidor"], "Fota sidor")
        systemAlerts()
        pause(2)
        screen("kamera", "Skärm 3: Fota sidor (the Simulator has no document camera)")
        if find(["Samlingar"]) != nil { log.append("Fota sidor opened the photo library in the Simulator (no document camera there)") }
        if app.state != .runningForeground {
            note("Fota sidor: the app left the foreground in the Simulator (state \(app.state.rawValue)), relaunched")
            app.activate()
            pause(2)
        }
        // Back from the camera sheet, whatever the Simulator shows.
        if find(["Fota sidor"]) == nil || !(find(["Fota sidor"])?.isHittable ?? false) {
            if !tap(["Avbryt", "Cancel", "Stäng", "Klar"], "close the camera", counted: false, quiet: true) {
                app.swipeDown(velocity: .fast)
            }
            pause(1)
        }
    }

    /// Välj bilder and the picture of the material (`scripts/apptest/newuser.sh` adds it with `simctl addmedia`; the
    /// Simulator's own sample photos are older, so the newest one is ours). False: no picture got in.
    private func photoStep() -> Bool {
        guard tap(["Välj bilder"], "Välj bilder") else { return false }
        systemAlerts()
        pause(3)
        screen("valj-bilder", "Välj bilder: the photo library")
        let images = app.images.allElementsBoundByIndex.filter { $0.exists && $0.frame.width > 40 }
        log.append("photo library: \(images.count) pictures: " + images.prefix(12).map(\.label).joined(separator: " | "))
        // Run 43589853220: the Simulator's five sample photos are labelled "Bild, <date 2009–2012>"; ours (from
        // simctl addmedia) had an empty label and came first. The last sample was not hittable.
        // Run 43591754488: ours is not an Image element at all (the unlabelled one was the sheet's background,
        // 702×1102); on the screenshot it is the first cell of the grid, top left, newest first. The grid is found
        // from the sample photos' frames and the first cell tapped by coordinate.
        let samples = ["2009", "2010", "2011", "2012"]
        let cells = images.filter { image in samples.contains { image.label.contains($0) } && image.frame.width < 250 }
        guard let width = cells.map(\.frame.width).max(), let top = cells.map(\.frame.minY).min() else {
            fail("Välj bilder: no grid of pictures in the photo library")
            return false
        }
        let point = CGVector(dx: width / 2, dy: top + width / 2)
        log.append("picked the first cell of the grid at (\(Int(point.dx)), \(Int(point.dy))), cell \(Int(width)) pt")
        app.coordinate(withNormalizedOffset: .zero).withOffset(point).tap()
        taps += 1
        log.append(String(format: "TAP %d at %6.1f s: the picture of the material", taps, Date().timeIntervalSince(started)))
        if let add = wait(["Lägg till", "Add", "Klar", "Done"], 3) { tapElement(add, "Lägg till in the photo library") }
        guard wait(["1 foto.", "1 foto"], 20) != nil || waitEnabled(["Skapa frågor"], 10) else {
            screen("efter-bild", "No picture in Nytt prov after Välj bilder")
            fail("Välj bilder: the picture did not get into Nytt prov")
            return false
        }
        return true
    }

    /// Skriv text with the material, Klar, and any question after it. False: the material did not get in.
    private func textStep() -> Bool {
        guard tap(["Skriv text"], "Skriv text") else { return false }
        let editor = app.textViews.firstMatch
        guard editor.waitForExistence(timeout: 5) else {
            fail("Skriv text: no text field")
            screen("skriv-text", "Skriv text without a text field")
            return false
        }
        pause(1) // the sheet settles first
        editor.tap()
        taps += 1
        // Runs 43583904414, 43585273570 and 43586474124: after the photo library sheet a tap gave no focus. Then, in
        // order: a tap at the top of the text, a long press and Klistra in.
        if !app.keyboards.firstMatch.waitForExistence(timeout: 4) {
            note("Skriv text: the first tap on the text field gave no keyboard (Simulator)")
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.04)).tap()
            testTaps += 1
        }
        if app.keyboards.firstMatch.waitForExistence(timeout: 4) {
            editor.typeText(material)
            log.append("typed the material (\(material.count) characters)")
        } else {
            log.append("still no keyboard: long press and Klistra in")
            screen("skriv-text-utan-tangentbord", "Skriv text without a keyboard", counts: false)
            UIPasteboard.general.string = material
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.04)).press(forDuration: 1.2)
            testTaps += 1
            guard let paste = wait(["Klistra in", "Paste"], 4) else {
                fail("Skriv text: no focus, no keyboard and no Klistra in")
                return false
            }
            paste.tap()
            testTaps += 1
            if let allow = wait(["Tillåt klistra in", "Allow Paste"], 3) { allow.tap(); testTaps += 1 }
            log.append("pasted the material")
        }
        pause(1)
        let value = "\(editor.value ?? "")"
        log.append("text field holds \(value.count) characters")
        guard value.count >= 50 else {
            fail("Skriv text: the material did not get into the text field")
            return false
        }
        screen("skriv-text", "Skriv text with the material")
        tap(["Klar"], "Klar on Skriv text")
        pause(1)
        systemAlerts()
        // A93: a pasted text may be offered as an import; a new user answers the obvious way and keeps the text.
        if app.alerts.firstMatch.exists {
            let alert = app.alerts.firstMatch
            log.append("ALERT after Skriv text: \(alert.label) — " + alert.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " / "))
            screen("efter-text", "Alert after Skriv text")
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            taps += 1
        }
        return true
    }

    /// D120: three questions, not the default; counted as test taps.
    private func lowerQuestionsToThree() {
        // The stepper's buttons: identifier Decrement, label "Antal frågor, 20, Minskning", value 20 (first run).
        let decrement = app.buttons["Decrement"]
        guard decrement.waitForExistence(timeout: 3) else { note("Antal frågor: no stepper"); return }
        let first = "\(decrement.value ?? "?")"
        for _ in 0..<60 {
            if "\(decrement.value ?? "")" == "3" { break }
            guard decrement.isEnabled else { break }
            decrement.tap()
            testTaps += 1
        }
        log.append("Antal frågor \(first) → \(decrement.value ?? "?") (\(testTaps) test taps so far)")
    }

    // MARK: Helpers (as T8's FirstUserTests)

    private func milestone(_ what: String) {
        let line = String(format: "%6.1f s, %2d tryck, %2d skärmar: %@", Date().timeIntervalSince(started), taps, screens, what)
        milestones.append(line)
        log.append("MILESTONE " + line)
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

    /// Taps the first label found within 5 s. Not found: a miss, with a screenshot (the "next step is not obvious").
    @discardableResult
    private func tap(_ labels: [String], _ step: String, counted: Bool = true, quiet: Bool = false) -> Bool {
        guard var element = wait(labels, quiet ? 1 : 5) else {
            if !quiet {
                fail("\(step): '\(labels[0])' not found")
                screen("saknas-\(labels[0])", "Missing: \(labels[0])", counts: false)
            }
            return false
        }
        var swipes = 0
        while !element.isHittable, swipes < 8 {
            app.swipeUp()
            swipes += 1
            if let again = find(labels) { element = again }
        }
        if swipes > 0 { note("\(step): '\(labels[0])' was below the screen (\(swipes) swipes)") }
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
            let text = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " / ")
            log.append("SYSTEM ALERT: \(alert.label) — \(text)")
            screen("systemfraga", "System alert: \(alert.label)", counts: false, fromSpringboard: true)
            let allow = ["Tillåt", "Allow", "OK"]
            if let button = allow.lazy.map({ alert.buttons[$0] }).first(where: { $0.exists }) {
                button.tap()
            } else {
                alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            }
            taps += 1
            log.append(String(format: "TAP %d at %6.1f s: system alert → allow", taps, Date().timeIntervalSince(started)))
        }
    }

    /// Screenshot, every text and button written down, and BETA looked for (first start only: up to the question list).
    private func screen(_ name: String, _ note: String, counts: Bool = true, fromSpringboard: Bool = false) {
        if counts { screens += 1 }
        pause(1)
        let fileName = String(format: "t21-%02d-%@", screens, name)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
        let source: XCUIApplication = fromSpringboard ? springboard : app
        // One snapshot (debugDescription), not element by element: a sheet animating in removed element 15 between
        // the count and the read and failed the first run (43583021882).
        let tree = source.debugDescription
        let texts = Self.labels(in: tree, kind: "StaticText")
        let buttons = Self.labels(in: tree, kind: "Button")
        log.append(String(format: "SCREEN %@ at %6.1f s — %@", fileName, Date().timeIntervalSince(started), note))
        log.append("  texts (\(texts.count)): " + texts.joined(separator: " | "))
        log.append("  buttons (\(buttons.count)): " + buttons.joined(separator: " | "))
        if !fromSpringboard {
            // The krav is about the first start itself (A94: Välkommen, Nytt prov, Stämmer det här?). After Ser rätt
            // ut the app is on Start, where Fler lägen says "Beta · använder mikrofonen" by design (Ke55: BETA is
            // reached through Fler lägen); that is logged apart, and the later screens have Start underneath them
            // (run 43594095637), so their tree holds the same row without it being visible.
            for label in texts + buttons where label.range(of: "beta", options: .caseInsensitive) != nil {
                if inFirstStart { betaSeen.append("\(fileName): \(label)") } else { betaAfter.insert(label) }
            }
        }
    }

    /// The labels of one element kind in a `debugDescription` tree ("Button, 0x…, label: 'Fortsätt'").
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

    private func fail(_ what: String) {
        log.append("MISS: \(what)")
        XCTFail("[t21] \(what)")
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func finish() {
        milestone("done")
        var lines = [
            "T21 ny användare (simulator, inte enhet)",
            "screens before the camera: \(screensBeforeCamera.map(String.init) ?? "not reached") (krav högst 3)",
            "BETA in the first start: \(betaSeen.isEmpty ? "none" : betaSeen.joined(separator: "; "))",
            "BETA after it (Start, before the first question): \(betaAfter.isEmpty ? "none" : betaAfter.sorted().joined(separator: "; "))",
            "taps (a user's): \(taps), test taps (not a user's): \(testTaps), screens: \(screens)",
            "", "Not obvious:",
        ] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 })
        lines += ["", "Milestones:"] + milestones + ["", "Log:"] + log + [""]
        let summary = XCTAttachment(string: lines.joined(separator: "\n"))
        summary.name = "t21-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
