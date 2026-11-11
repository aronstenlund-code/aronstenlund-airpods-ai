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

    func testScreenTour() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        prefix = env["LUMEN_SHOT_PREFIX"] ?? "shot"
        micDenied = env["LUMEN_TOUR_MIC"] == "denied"

        app = XCUIApplication()
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Swedish UI, as the users see it. Apple's recogniser instead of Scribe: no paid realtime session from CI.
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE", "-stt.useCloud", "NO"]
        app.launch()

        firstStart(micDenied: micDenied)
        sharePrompt()
        // With the microphone on, the first start's Frågor session goes on and Lyssnar is shown.
        if waitFor(["Tillbaka till start"], timeout: 2) != nil {
            shoot("lyssnar-efter-forsta-start", note: "Lyssnar right after the first start")
            endSession()
        }
        shoot("start-utan-prov", note: "Start without an exam (sketch 7)")
        a50Start()
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
            app.swipeUp()
            shoot("intro-slut", note: "Intro, scrolled (the consent card)")
            // A2: the short consent card in the intro has "Läs mer" with the full text.
            if waitFor(["Läs mer"], timeout: 2) != nil {
                tap(["Läs mer"], step: "intro → Läs mer")
                if waitFor(["Klar"], timeout: 3) == nil {
                    log.append("note: Läs mer did not open within 3 s, tapping again")
                    tap(["Läs mer"], step: "intro → Läs mer (again)")
                }
                pause(1)
                shoot("las-mer", note: "Läs mer (full consent)")
                app.swipeUp()
                shoot("las-mer-slut", note: "Läs mer, scrolled")
                tap(["Klar"], step: "Läs mer → Klar")
                pause(1)
            } else {
                log.append("note: no 'Läs mer' in the intro")
            }
            tap(["Testa nu"], step: "intro → Testa nu")
        } else {
            miss("intro: 'Testa nu' not found (first start not shown?)")
        }

        // Before A2 a separate consent screen came after the intro; since A2, "Testa nu" is the consent.
        if waitFor(["Jag förstår*", "I understand*"], timeout: 4) != nil {
            shoot("samtycke", note: "Consent, top")
            app.swipeUp()
            shoot("samtycke-slut", note: "Consent, scrolled")
            tap(["Jag förstår*", "I understand*"], step: "consent → accept")
        } else {
            log.append("note: no separate consent screen (A2: Testa nu is the consent)")
        }

        dismissSystemAlerts()
        // A18: with the microphone denied the whole screen is "Lumen hör dig inte" (Ke10), and before the first
        // answer the button is "Hoppa över" (Fortsätt only after an answer, Ke9).
        if waitFor(["Fråga vad som helst", "Lumen hör dig inte"], timeout: 10) != nil {
            pause(3) // let "Startar …" become "Lyssnar" (or the microphone error card)
            dismissSystemAlerts()
            shoot(micDenied ? "forsta-fragan-mikrofon-nekad" : "forsta-fragan", note: "First question (sketch 2)")
            if micDenied, waitFor(["Lumen hör dig inte"], timeout: 1) == nil {
                miss("APP: microphone denied, the first question does not show 'Lumen hör dig inte'")
            }
            tap(["Fortsätt", "Hoppa över"], step: "first question → Fortsätt/Hoppa över")
            pause(1.5)
        } else {
            miss("'Fråga vad som helst' not shown")
        }

        // A22: the first start's exam step is "Har du prov snart?" with "Inte nu" (was "Hoppa över").
        if waitFor(["Inte nu", "Hoppa över"], timeout: 8) != nil {
            shoot("lagg-till-prov-forsta", note: "Add exam at first start (sketch 3)")
            app.swipeUp()
            shoot("lagg-till-prov-forsta-slut", note: "Add exam at first start, scrolled")
            // A33: the form is behind "Skriv i stället" (Lumen asks aloud first).
            if let write = find(["Skriv i stället"]) {
                write.tap()
                pause(1)
                shoot("lagg-till-prov-forsta-formular", note: "Add exam at first start, the form (A33)")
                app.swipeUp()
                shoot("lagg-till-prov-forsta-formular-slut", note: "Add exam at first start, the form, scrolled")
            }
            tap(["Inte nu", "Hoppa över"], step: "add exam → Inte nu")
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
            // A50: the exam card has "Förhör mig"; "Få A-svar till provet" left Start.
            if waitFor(["Förhör mig", "Få A-svar till provet"], timeout: 5) != nil {
                shoot("start-med-prov", note: "Start with an exam (sketch 4)")
                app.swipeUp()
                shoot("start-med-prov-slut", note: "Start with an exam, scrolled")
                app.swipeDown()
                myAnswers()
            } else {
                miss("exam card not shown after Spara prov")
            }
        } else {
            miss("add-exam sheet not shown")
        }
    }

    // MARK: A50 Start (D124, D126)

    /// A50: "Starta Lumen" at the top, the mode under it ("Läge: Standardläge. Byt läge"), "Lumen kan allt" with
    /// examples, and the Byt sheet (Sov under the modes). "APP:" marks a finding about the app, not the tour.
    private var a50: Bool { find(["Starta Lumen", "Starta Earmind", "Tillbaka till Lumen", "Tillbaka till Earmind"], buttonsOnly: true) != nil }

    private func a50Start() {
        guard waitFor(["Starta Lumen", "Starta Earmind", "Tillbaka till Lumen", "Tillbaka till Earmind"], timeout: 3) != nil else {
            log.append("note: no 'Starta Lumen' on Start (a build before A50)")
            return
        }
        if find(["Starta Lumen", "Starta Earmind"], buttonsOnly: true)?.isHittable != true {
            miss("APP: A50 'Starta Lumen' is not on the first screen without scrolling")
        }
        if find(["Läge:*"]) == nil { miss("APP: A50 no mode line ('Läge: … Byt läge') under Starta Lumen") }
        if find(["Lumen kan allt*", "Earmind kan allt*"]) == nil { miss("APP: A50 no 'Lumen kan allt' on Start") }
        for gone in ["Få A-svar till provet", "Bara fråga", "Fler lägen"] where find([gone]) != nil {
            miss("APP: A50 '\(gone)' is still on Start")
        }
        pause(3) // the examples change every few seconds: a second shot shows the next one
        shoot("start-lumen-kan-allt", note: "A50: Start a few seconds later (the next example)")
        guard tap(["Läge:*"], step: "start → Byt (mode line)") else { return }
        pause(1)
        shoot("byt-fran-start", note: "A50: Byt from Start (the modes and Sov)")
        if find(["Provläge*"]) == nil { miss("APP: A50 no Provläge in the Byt sheet") }
        closeSheet()
        capabilities()
    }

    /// A52 (D125): "Allt Lumen kan ›" (Earmind after A55) at the end of the box pushes "Vad kan Lumen?".
    private func capabilities() {
        let link = ["Allt Lumen kan*", "Allt Earmind kan*"]
        guard waitFor(link, timeout: 2) != nil else {
            log.append("note: no 'Allt Lumen kan' on Start (a build before A52)")
            return
        }
        guard tap(link, step: "start → Allt Lumen kan") else { return }
        pause(1.5)
        shoot("vad-kan", note: "A52: Vad kan Lumen?")
        for page in 2...3 {
            app.swipeUp()
            shoot("vad-kan-\(page)", note: "A52: Vad kan Lumen?, scrolled \(page - 1)")
        }
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists {
            back.tap()
        } else {
            app.swipeRight()
        }
        pause(1)
    }

    /// A53 (D126): "Mina svar" under the exam card. The list, and the writing page without writing (no `suggest` call).
    private func myAnswers() {
        guard tap(["Mina svar*"], step: "start → Mina svar") else { return }
        pause(1.5)
        shoot("mina-svar", note: "A53: Mina svar, first time")
        if waitFor(["Skriv en fråga*"], timeout: 2) != nil {
            tap(["Skriv en fråga*"], step: "Mina svar → Skriv en fråga")
            pause(1.5)
            shoot("mina-svar-skriv", note: "A53: Skriv en fråga (empty)")
            if waitFor(["Avbryt"], timeout: 2) != nil { tap(["Avbryt"], step: "Skriv en fråga → Avbryt") } else { closeSheet() }
            pause(1)
        }
        closeSheet()
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

        let pages: [(name: String, labels: [String])] = [
            ("anteckningar", ["Anteckningar", "Notes"]),
            ("forberedelser", ["Förberedelser"]),
            ("egna-kommandon", ["Egna kommandon"]),
            ("integritet", ["Integritet och samtycke", "Privacy & consent"]),
            ("historik", ["Historik", "History"]),
            ("minne", ["Minne"]),
            ("studiekort", ["Studiekort"]),
            ("feedback", ["Feedback och förslag", "Feedback & förslag", "Feedback & suggestions"]),
            ("rostkommandon", ["Röstkommandon"]),
            ("om-appen", ["Om appen"]),
        ]
        for page in pages {
            openFromSettings(page.labels, name: page.name)
        }
        // A13: "Avancerat" folds out its sections in place (not a page); the diagnostics rows are inside it.
        expandAdvanced()
        openFromSettings(["Rå transkription och svar"], name: "ra-transkription", advanced: true)
        openFromSettings(["Diagnostik", "Diagnostics"], name: "diagnostik", advanced: true)
        tap(["Klar"], step: "settings → Klar")
        pause(1)
    }

    /// Folds out "Avancerat" in Settings (once per sheet) and shoots the first screen of it.
    private func expandAdvanced() {
        guard let row = scrollTo(["Avancerat*"], buttonsOnly: true) else {
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
        if !app.navigationBars.buttons["Klar"].exists {
            log.append("note: Settings sheet closed before \(labels[0]), opening it again")
            tap(["Inställningar"], step: "start → Inställningar (again)")
            pause(1)
            if advanced { expandAdvanced() }
        }
        // Buttons only: a section header with the same words ("Diagnostik") is not the row.
        guard let row = scrollTo(labels, buttonsOnly: true) else {
            miss("settings row \(labels[0]) not found")
            return
        }
        // The back button, never the sheet's "Klar" (that would close Settings).
        let back = app.navigationBars.buttons.matching(NSPredicate(format: "label != 'Klar'")).firstMatch
        row.tap()
        pause(1.5)
        // The last rows sit at the sheet's bottom edge, where a tap can miss (seen at the largest text size):
        // look the row up again each time and tap it only when it is hittable, never a stale element.
        var attempt = 0
        while !back.exists, attempt < 3 {
            attempt += 1
            log.append("note: \(labels[0]) tap missed, retry \(attempt)")
            if let again = scrollTo(labels, buttonsOnly: true), again.isHittable {
                again.tap()
            } else {
                app.swipeDown()
            }
            pause(1.5)
        }
        shoot("installningar-\(name)", note: "Settings › \(labels[0])")
        app.swipeUp()
        shoot("installningar-\(name)-slut", note: "Settings › \(labels[0]), scrolled")
        if back.waitForExistence(timeout: 3) {
            back.tap()
            pause(1)
        } else {
            miss("no back button on \(labels[0])")
        }
    }

    // MARK: Modes (sketches 5 and 8)

    private func modesTour() {
        // A22: Start has "Bara fråga" (Frågor) and "Fler lägen" (Provläge, Intervju, Socialt, Rizz 18+).
        // A33: the first start's Frågor session can still be on behind Start ("Lyssnar … Avsluta" on top, seen in T8 on
        // the A33 build); a new mode does not open while it runs, so end it first.
        if let running = find(["Avsluta"]), running.isHittable {
            log.append("note: a session was still on at Start, ending it before Bara fråga")
            running.tap()
            pause(2)
            dismissSystemAlerts()
            for label in ["Klar", "Stäng"] where app.buttons[label].exists { app.buttons[label].tap(); pause(1); break }
        }
        // A50: one "Starta Lumen" starts the chosen mode (Standardläge after the first start).
        if tap(["Starta Lumen", "Starta Earmind", "Bara fråga", "Frågor"], step: "start → Starta Lumen / Bara fråga") {
            dismissSystemAlerts()
            if waitFor(["Tillbaka till start"], timeout: 10) != nil {
                pause(2)
                dismissSystemAlerts()
                shoot("lyssnar-fragor", note: "Lyssnar in Frågor (sketch 5)")
                // A18: "Byt läge" sits in the ⋯ menu ("Mer").
                tap(["Mer"], step: "lyssnar → ⋯")
                pause(0.5)
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
                noLyssnar(mode: "Frågor")
            }
        }

        sheetFromMode(["Intervju"], name: "intervju-setup", close: ["Avbryt", "Cancel"])
        sheetFromMode(["Socialt"], name: "socialt-start", close: ["Avbryt", "Cancel"])
        sheetFromMode(["Rizz 18+", "Rizz"], name: "rizz-aldersgrans", close: ["Avbryt", "Cancel"])
    }

    /// A22: the other modes sit in the "Fler lägen" sheet. Opens it (and shoots it once) when the mode is not on Start.
    private func openMoreModes(for labels: [String]) {
        if let onStart = find(labels), onStart.isHittable { return }
        // A50: "Fler lägen" is gone; the mode line under Starta Lumen opens the same list.
        let opener = a50 ? ["Läge:*"] : ["Fler lägen"]
        guard tap(opener, step: "start → \(opener[0])") else { return }
        pause(1)
        if !shotMoreModes {
            shoot("fler-lagen", note: "Fler lägen (A22)")
            shotMoreModes = true
        }
    }

    private var shotMoreModes = false

    private func sheetFromMode(_ labels: [String], name: String, close: [String]) {
        let newStart = a50
        openMoreModes(for: labels)
        // A50's sheet shows "Intervju, <tagline>": match the start of the label.
        guard tap(newStart ? labels.map { $0.hasSuffix("*") ? $0 : $0 + "*" } : labels, step: "start → \(labels[0])") else { return }
        pause(1)
        // A50: a tap in the sheet only chooses the mode; Starta Lumen starts it (unless the mode asked first).
        if newStart, waitFor(close, timeout: 1) == nil, find(["Starta Lumen", "Starta Earmind"], buttonsOnly: true) != nil {
            tap(["Starta Lumen", "Starta Earmind"], step: "start → Starta Lumen (\(labels[0]))")
        }
        pause(2)
        dismissSystemAlerts()
        shoot(name, note: "\(labels[0]) first screen")
        if waitFor(close, timeout: 2) != nil {
            tap(close, step: "\(name) → close")
        } else if waitFor(["Tillbaka till start"], timeout: 1) != nil {
            // It went straight to Lyssnar.
            endSession()
        } else {
            app.swipeDown(velocity: .fast) // pull the sheet down
        }
        pause(1)
        if waitFor(["Tillbaka till start"], timeout: 1) != nil { endSession() }
    }

    // MARK: Provläge

    private func provTour() {
        // A22 (D97): with an exam, "Få A-svar till provet" on Start; Provläge also sits in "Fler lägen".
        if a50 {
            // A50: Byt → Provläge ("För dina prov"), then Starta Lumen.
            openMoreModes(for: ["Provläge, För dina prov"])
            guard tap(["Provläge*"], step: "Byt → Provläge") else { return }
            pause(1)
            if find(["Läge: Provläge*"]) == nil { miss("APP: A50 the mode line does not say Provläge after choosing it") }
            shoot("start-provlage-valt", note: "A50: Start with Provläge chosen")
            guard tap(["Starta Lumen", "Starta Earmind"], step: "start → Starta Lumen (Provläge)") else { return }
        } else {
            if find(["Få A-svar till provet"]) == nil { openMoreModes(for: ["Provläge"]) }
            guard tap(["Få A-svar till provet", "Provläge"], step: "start → Få A-svar till provet") else { return }
        }
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
        if waitFor(["Tillbaka till start"], timeout: 8) != nil {
            pause(1)
            shoot("lyssnar-provlage", note: "Lyssnar in Provläge (sketch 5)")
            endSession()
        } else {
            shoot("provlage-startade-inte", note: "Provläge did not open Lyssnar")
            noLyssnar(mode: "Provläge")
        }
    }

    /// Lyssnar did not open. With the microphone denied that is right, but the user must then see sketch 9's card
    /// "Lumen hör dig inte" with "Öppna Inställningar". "APP:" marks a finding about the app, not the tour.
    private func noLyssnar(mode: String) {
        if micDenied {
            if waitFor(["Lumen hör dig inte*", "Öppna Inställningar"], timeout: 2) != nil {
                log.append("ok: \(mode) with the microphone denied shows 'Lumen hör dig inte'")
            } else {
                miss("APP: microphone denied, \(mode) tapped: nothing opens and no 'Lumen hör dig inte' card (sketch 9)")
            }
        } else {
            miss("Lyssnar did not open for \(mode)")
        }
    }

    private func endSession() {
        tap(["Avsluta"], step: "lyssnar → Avsluta")
        pause(2)
        dismissSystemAlerts()
        // Whatever follows the session (a summary, study cards) is a screen too.
        if waitFor(["Starta Lumen", "Starta Earmind", "Lägg till prov", "Få A-svar till provet"], timeout: 3) == nil {
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
        log.append("tap: \(step)")
        return true
    }

    /// Swipes up (then back down) until an element with one of the labels is hittable.
    private func scrollTo(_ labels: [String], buttonsOnly: Bool = false) -> XCUIElement? {
        for direction in [true, false] {
            // 25 swipes: Settings at the largest text size is about 30 screens long.
            for _ in 0..<25 {
                if let element = find(labels, buttonsOnly: buttonsOnly), element.isHittable { return element }
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
#endif
