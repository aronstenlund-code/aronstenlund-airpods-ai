// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import XCTest

/// T8 (Toby): the first-time user. From a fresh install (the script erases the Simulator) to the first answer in
/// Frågor and then in Provläge, the way a new user would go: only what is on the screen, the obvious button. Every
/// step is timed, every tap counted, every screen photographed and its texts and buttons written down, so the report
/// can say what is unclear or unnecessary.
///
/// The question is a WAV file through the app's own hook (`LUMEN_AUDIO_FILES`, looped with a long gap, so a session
/// started later also hears it). Live Scribe and /answer, the voice the app picks for a new user.
///
/// `LUMEN_T8_PATH` (from `scripts/apptest/firstuser.sh`):
/// - `skip`: "Hoppa över" at the exam step, then find Provläge from the start screen.
/// - `exam`: add an exam at the first start (the step offers it), then Provläge from its card.
///
/// A50 (D124, 2026-11-11): after the first start the user goes back to Start and presses the big **Starta Lumen**
/// (Aron on the phone: "man förstår inte hur man börjar ställa frågor"); the same question must be answered there.
/// Provläge is then chosen with the mode line under the button ("Standardläge · Byt") and started with Starta Lumen.
///
/// Simulator only: never a verification on a device. "Svar visat" is what the screen shows; whether it was spoken
/// is not visible to a UI test (the T5 test counts spoken answers).
@MainActor
final class FirstUserTests: XCTestCase {
    private var app: XCUIApplication!
    private var springboard: XCUIApplication!
    private var path = "skip"
    private var started = Date()
    private var taps = 0
    private var shots = 0
    private var log: [String] = []
    private var milestones: [String] = []

    /// The answer to the WAV file's question ("Vad är huvudstaden i Australien?").
    private let answerKey = "Canberra"
    private let questionKey = "Australien"

    func testFirstUser() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        // The T3 screen tour runs this target too: T8 is live and paid, so only from scripts/apptest/firstuser.sh.
        guard let chosen = env["LUMEN_T8_PATH"] else { throw XCTSkip("T8 runs from scripts/apptest/firstuser.sh") }
        path = chosen
        app = XCUIApplication()
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
        if let files = env["LUMEN_AUDIO_FILES"] {
            app.launchEnvironment["LUMEN_AUDIO_FILES"] = files
            app.launchEnvironment["LUMEN_AUDIO_GAP"] = env["LUMEN_AUDIO_GAP"] ?? "20"
            app.launchEnvironment["LUMEN_AUDIO_LOOP"] = "1"
        }
        started = Date()
        app.launch()
        milestone("app opened")

        // 1. Intro
        guard wait(["Testa nu"], 20) != nil else { return fail("intro: no 'Testa nu'") }
        screen("intro", "Intro: the first thing a new user sees")
        tap(["Testa nu"], "intro → Testa nu")
        systemAlerts()

        // 2. The first question in Frågor
        if wait(["Fråga vad som helst"], 10) != nil {
            screen("forsta-fragan", "First question, before speaking")
            milestone("first question screen")
            // T8 finding 1 / A25: "Startar …" must become "Lyssnar" within a few seconds of the microphone alert.
            if waitText(containing: "Lyssnar", 15) != nil {
                milestone("first question: Lyssnar")
            } else {
                screen("forsta-fragan-startar", "First question: no 'Lyssnar' within 15 s")
                fail("first question: no 'Lyssnar' within 15 s (A25)")
            }
            if let shown = waitText(containing: answerKey, 60) {
                milestone("Frågor: answer shown")
                log.append("answer shown: \(shown.prefix(200))")
                screen("forsta-svaret", "Frågor: the first answer on the screen")
            } else {
                screen("forsta-svaret-saknas", "Frågor: no answer within 60 s")
                fail("Frågor: no answer containing '\(answerKey)' within 60 s")
            }
            // A18: "Fortsätt" only after an answer, "Hoppa över" before it.
            tap(["Fortsätt", "Hoppa över"], "first question → Fortsätt/Hoppa över")
            pause(1.5)
            systemAlerts()
        } else {
            fail("no 'Fråga vad som helst' after Testa nu")
        }

        // 3. The exam step of the first start
        // A22: the exam step is "Har du prov snart?" with "Inte nu" (was "Hoppa över").
        if wait(["Inte nu", "Spara prov", "Hoppa över"], 8) != nil {
            screen("prov-steget", "First start: add an exam or skip")
            if path == "exam" {
                // A33: the form is behind "Skriv i stället" (Lumen asks aloud first; no voice in the Simulator).
                if find(["Skriv i stället"]) != nil { tap(["Skriv i stället"], "exam step → Skriv i stället") }
                tap(["NO"], "exam step → NO")
                screen("prov-steget-no", "Exam step, NO chosen")
                tap(["Spara prov"], "exam step → Spara prov")
            } else {
                tap(["Inte nu", "Hoppa över"], "exam step → Inte nu")
            }
        } else {
            log.append("note: no exam step")
        }
        if wait(["Dela inte", "Don't share"], 5) != nil {
            screen("dela-historik", "Share history prompt")
            tap(["Dela inte", "Don't share"], "share prompt → Dela inte")
        }
        pause(1)
        screen("start", "The start screen after the first start")
        milestone("start screen")
        if wait(["Tillbaka till start"], 1) != nil {
            log.append("note: a Frågor session is still on (Lyssnar) after the first start")
        }

        // 4. A50: Starta Lumen, the obvious way to ask a question from Start
        startButton()

        // 5. Provläge, the obvious way from here
        startProv()
        systemAlerts()
        if wait(["Hoppa över allt"], 6) != nil {
            screen("provlage-introfragor", "Provläge's own first-start questions")
            // A new user answers what is asked; Hoppa över is the quickest honest choice, step by step.
            var steps = 0
            while wait(["Hoppa över allt"], 2) != nil, steps < 6 {
                tap(["Hoppa över"], "Provläge questions → Hoppa över")
                steps += 1
                pause(1)
                if wait(["Hoppa över allt"], 1) != nil { screen("provlage-introfragor-\(steps + 1)", "Provläge question \(steps + 1)") }
            }
        }
        systemAlerts()
        if wait(["Tillbaka till start"], 10) != nil {
            if waitText(containing: "Prov", 2) == nil { fail("the Lyssnar screen is not Provläge") }
            screen("provlage-lyssnar", "Lyssnar in Provläge, before the question")
            milestone("Provläge: listening")
            let before = Date()
            if let shown = waitText(containing: answerKey, 90, after: before) {
                milestone("Provläge: answer shown")
                log.append("Provläge answer shown: \(shown.prefix(200))")
                screen("provlage-svaret", "Provläge: the first answer on the screen")
            } else {
                screen("provlage-svaret-saknas", "Provläge: no answer within 90 s")
                fail("Provläge: no answer containing '\(answerKey)' within 90 s")
            }
        } else {
            screen("provlage-startade-inte", "Provläge did not open Lyssnar")
            fail("Provläge: no Lyssnar screen")
        }
        finish()
    }

    // MARK: A50 Starta Lumen

    /// The big button at the top of Start: one tap, Lyssnar within 15 s, and the looped question answered.
    private func startButton() {
        endRunningSession()
        guard wait(["Starta Lumen"], 3) != nil else {
            log.append("note: no 'Starta Lumen' on Start (a build before A50)")
            return
        }
        if find(["Starta Lumen"])?.isHittable != true { log.append("A50: Starta Lumen is not on screen without scrolling") }
        let mode = find(["Läge:*"])?.label ?? "(no mode line)"
        log.append("A50: mode line = \(mode)")
        if find(["Lumen kan allt*"]) == nil { fail("A50: no 'Lumen kan allt' on Start") }
        screen("start-starta-lumen", "A50: Start before pressing Starta Lumen")
        milestone("Start: Starta Lumen visible")
        tap(["Starta Lumen"], "start → Starta Lumen")
        systemAlerts()
        guard wait(["Tillbaka till start"], 10) != nil else {
            screen("starta-lumen-startade-inte", "Starta Lumen did not open Lyssnar")
            return fail("Starta Lumen: no Lyssnar screen within 10 s")
        }
        let baseline = count(containing: answerKey)
        if waitText(containing: "Lyssnar", 15) != nil {
            milestone("Starta Lumen: Lyssnar")
        } else {
            screen("starta-lumen-startar", "Starta Lumen: no 'Lyssnar' within 15 s")
            fail("Starta Lumen: no 'Lyssnar' within 15 s")
        }
        screen("starta-lumen-lyssnar", "A50: Lyssnar after Starta Lumen, before the answer")
        if waitNew(containing: answerKey, more: baseline, 60) {
            milestone("Starta Lumen: answer shown")
            screen("starta-lumen-svaret", "A50: the answer after Starta Lumen")
        } else {
            screen("starta-lumen-svaret-saknas", "Starta Lumen: no answer within 60 s")
            fail("Starta Lumen: no new answer containing '\(answerKey)' within 60 s")
        }
        endRunningSession()
    }

    /// End a session that is still on, as a user would before choosing something else.
    private func endRunningSession() {
        guard wait(["Avsluta"], 1) != nil, wait(["Tillbaka till start"], 1) != nil else { return }
        tap(["Avsluta"], "Lyssnar → Avsluta")
        pause(2)
        if wait(["Starta Lumen", "Lägg till prov", "Få A-svar till provet", "Fler lägen"], 3) == nil {
            screen("efter-avsluta", "After Avsluta")
            for label in ["Klar", "Stäng"] where app.buttons[label].exists { tapElement(app.buttons[label], "after Avsluta → \(label)"); break }
        }
    }

    private func count(containing key: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", key)).count
    }

    /// True when more texts than `more` contain `key` (a new answer, not one already on the screen).
    private func waitNew(containing key: String, more: Int, _ timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if count(containing: key) > more {
                if let label = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", key)).allElementsBoundByIndex.last?.label {
                    log.append("answer shown: \(label.prefix(200))")
                }
                return true
            }
            pause(0.5)
        } while Date() < end
        return false
    }

    // MARK: Provläge from the start screen

    private func startProv() {
        endRunningSession()
        // A50: choose Provläge with the mode line ("Standardläge · Byt"), then the one Start button.
        if find(["Läge:*"]) != nil {
            tap(["Läge:*"], "start → Byt (mode line)")
            pause(1)
            screen("byt-lage", "A50: Byt from Start")
            guard tap(["Provläge*"], "Byt → Provläge") else { return }
            pause(1)
            log.append("A50: mode line after choosing = \(find(["Läge:*"])?.label ?? "(none)")")
            tap(["Starta Lumen"], "start → Starta Lumen (Provläge)")
            return
        }
        if find(["Få A-svar till provet"]) != nil {
            tap(["Få A-svar till provet"], "start → Få A-svar till provet")
            return
        }
        // No exam: Provläge is under the other modes.
        if tap(["Fler lägen"], "start → Fler lägen") {
            pause(1)
            screen("fler-lagen", "Fler lägen")
            if !tap(["Provläge*", "Prov*"], "Fler lägen → Provläge") { fail("no Provläge under Fler lägen") }
            pause(1)
            if wait(["Tillbaka till start", "Hoppa över allt"], 2) == nil {
                screen("provlage-val", "After choosing Provläge")
                for label in ["Starta*", "Start*", "Börja*", "Fortsätt", "Lägg till prov"] where find([label]) != nil {
                    tap([label], "Provläge → \(label)")
                    break
                }
            }
        } else {
            fail("no way to Provläge on the start screen")
        }
    }

    // MARK: Helpers

    private func milestone(_ what: String) {
        let line = String(format: "%6.1f s, %2d taps, %2d screens: %@", Date().timeIntervalSince(started), taps, shots, what)
        milestones.append(line)
        log.append("MILESTONE " + line)
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

    /// A static text containing `key` (the answer), polled.
    private func waitText(containing key: String, _ timeout: TimeInterval, after: Date? = nil) -> String? {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", key)
        let end = Date().addingTimeInterval(timeout)
        repeat {
            let match = app.staticTexts.matching(predicate).firstMatch
            if match.exists { return match.label }
            pause(0.5)
        } while Date() < end
        return nil
    }

    @discardableResult
    private func tap(_ labels: [String], _ step: String) -> Bool {
        guard var element = wait(labels, 5) else {
            fail("\(step): '\(labels[0])' not found")
            screen("saknas-\(labels[0].replacingOccurrences(of: "*", with: ""))", "Missing: \(labels[0])")
            return false
        }
        var swipes = 0
        while !element.isHittable, swipes < 8 {
            app.swipeUp()
            swipes += 1
            if let again = find(labels) { element = again }
        }
        if swipes > 0 { log.append("scrolled \(swipes)× to reach '\(labels[0])'") }
        tapElement(element, step)
        return true
    }

    private func tapElement(_ element: XCUIElement, _ step: String) {
        element.tap()
        taps += 1
        log.append(String(format: "TAP %2d at %6.1f s: %@", taps, Date().timeIntervalSince(started), step))
    }

    private func systemAlerts() {
        for _ in 0..<3 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            let text = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " / ")
            log.append("SYSTEM ALERT: \(alert.label) — \(text)")
            shots += 1
            attachShot(String(format: "t8-%@-%02d-systemfraga", path, shots), "System alert: \(alert.label)")
            let allow = ["Tillåt", "Allow", "Tillåt när appen används", "Allow While Using App", "OK"]
            if let button = allow.lazy.map({ alert.buttons[$0] }).first(where: { $0.exists }) {
                button.tap()
            } else {
                alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            }
            taps += 1
            log.append(String(format: "TAP %2d at %6.1f s: system alert → allow", taps, Date().timeIntervalSince(started)))
        }
    }

    /// Screenshot, and every text and button on the screen written down (the report's "unclear or unnecessary").
    private func screen(_ name: String, _ note: String) {
        shots += 1
        pause(1) // let the transition finish: reading labels mid-animation failed the test once
        let fileName = String(format: "t8-%@-%02d-%@", path, shots, name)
        attachShot(fileName, note)
        let texts = app.staticTexts.allElementsBoundByIndex.prefix(60).map(\.label).filter { !$0.isEmpty }
        let buttons = app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).filter { !$0.isEmpty }
        log.append("SCREEN \(fileName) — \(note)")
        log.append("  texts (\(texts.count)): " + texts.joined(separator: " | "))
        log.append("  buttons (\(buttons.count)): " + buttons.joined(separator: " | "))
    }

    private func attachShot(_ fileName: String, _ note: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)
        log.append(String(format: "shot at %6.1f s: %@ — %@", Date().timeIntervalSince(started), fileName, note))
    }

    private func fail(_ what: String) {
        log.append("MISS: \(what)")
        XCTFail("[t8-\(path)] \(what)")
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func finish() {
        milestone("done")
        var lines = ["path: \(path)", "taps: \(taps)", "screens: \(shots)", "", "Milestones:"] + milestones + ["", "Log:"] + log
        lines.append("")
        let summary = XCTAttachment(string: lines.joined(separator: "\n"))
        summary.name = "t8-\(path)-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
