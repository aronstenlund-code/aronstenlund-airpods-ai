// Only in the LumenScreenTour UI-test target (AppTests/E2E/project-e2e.yml sets the flag), like ScreenTourTests.
#if LUMEN_SCREEN_TOUR
import UIKit
import XCTest

/// T24 (Toby 2, Deangelo for Aron 2026-11-14): the whole repetition flow the way a new user would go, so Aron's phone
/// test finds nothing we could have found. Fake audio only (D180): the app sends `x-earmind-test` (Angela's
/// `LUMEN_TEST_HEADER`, 37ae1c1) and the simulator in Actions is a `ci` test anyway.
///
/// Three phases, two Simulators (`scripts/apptest/fullflow.sh`), `LUMEN_T24_PHASE`:
/// - `a` (Simulator A, new account): first start, Fota sidor, Välj bilder, Skapa frågor, Ser rätt ut, Starta prov,
///   the control check, the first question, Frågor och svar and a question, Gör med ChatGPT (a pasted answer as
///   ChatGPT writes it), Dela, Publicera prov (school "Central insamlingsenhet", Kiruna: an office, no pupils).
/// - `b` (Simulator B, a second new account): Prov från din skola → the exam A published → Lägg till i mina prov;
///   then the server's `slow` and `unavailable` modes on a new import, as the user sees them.
/// - `c` (Simulator A again): Mina svar → Spela in (own answer), then clean-up: Ta bort publiceringen, Ta bort provet.
/// Each section is independent: a section that fails is photographed and logged, the app is relaunched and the next
/// one runs. Every step is timed and every tap counted; "UNCLEAR:" lines are what a user would stumble on.
/// AirPods presses (1, 2, 3) cannot be sent from a UI test; the press logic is T18 (`RepetitionE2ETests`).
/// Simulator only: never a verification on a device.
@MainActor
final class FullFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var springboard: XCUIApplication!
    private var phase = "a"
    private var header = "1"
    private var started = Date()
    private var taps = 0
    private var testTaps = 0
    private var shots = 0
    private var log: [String] = []
    private var sections: [String] = []
    private var unclear: [String] = []
    private var out: URL!

    static let school = "Central insamlingsenhet"
    static let place = "Kiruna"

    /// As ChatGPT answers the app's own prompt: numbered questions, "Svar:" lines, the first sentence short.
    static let chatGPTAnswer = """
    Här är frågorna:

    Fråga 1: Vad behöver växter för fotosyntesen?
    Svar: Koldioxid, vatten och solljus. Med ljusets energi gör växten socker av koldioxid och vatten, och syre bildas.

    Fråga 2: Var i bladet sker fotosyntesen?
    Svar: I kloroplasterna. Där finns klorofyllet som fångar ljuset.

    Fråga 3: Vad används sockret till?
    Svar: Som energi och byggmaterial. Växten använder sockret för att växa och för att bygga cellväggar.
    """

    func testFullFlow() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard let chosen = env["LUMEN_T24_PHASE"] else { throw XCTSkip("T24 runs from scripts/apptest/fullflow.sh") }
        phase = chosen
        header = env["LUMEN_T24_HEADER"] ?? "1"
        out = URL(fileURLWithPath: env["LUMEN_T24_OUT"] ?? NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addTeardownBlock { @MainActor [weak self] in self?.finish() }
        launch(header)
        // Run 43639763574: in the Simulator every relaunch was a new anonymous account (the Keychain session is not
        // kept in the unsigned build), and Start then lost every uploaded exam. So phase a never relaunches, and a and
        // b run at the same time: A publishes and waits for B's "found" file, then removes what it published itself.
        switch phase {
        case "a":
            section("Första starten till första frågan") { firstStartToFirstQuestion() }
            section("Frågor och svar och en fråga") { questionList() }
            section("Gör med ChatGPT") { chatGPTImport(title: "ChatGPT-provet") }
            section("Dela") { share() }
            let published = section("Publicera prov") { publish() }
            section("Mina svar: spela in eget svar") { recordOwnAnswer() }
            if published {
                section("Väntar på att konto B hittar provet") { waitForFile("t24-found.txt", 900) }
            }
            section("Ta bort publiceringen och provet") { cleanUp() }
        default:
            section("Andra kontot: första starten utan prov") { firstStartLater() }
            // Phase b alone (workflow input phases: "b"): no phase a publishes, so the school step is skipped.
            if env["LUMEN_T24_SOLO"] == "1" {
                log.append("phase b alone: Prov från din skola skipped (no phase a)")
            } else {
                section("Prov från din skola") {
                    waitForFile("t24-published.txt", 1800) && findPublished()
                }
            }
            try? "done\n".write(to: out.appendingPathComponent("t24-found.txt"), atomically: true, encoding: .utf8)
            section("Läget slow (ljudet dröjer)") { soundMode("slow", title: "Långsamt prov") }
            section("Läget unavailable (inga krediter)") { soundMode("unavailable", title: "Utan ljud") }
            section("Proven finns kvar efter omstart (D183)") { examsSurviveRelaunch() }
        }
    }

    // MARK: Phase a

    private func firstStartToFirstQuestion() -> Bool {
        guard wait(["Välkommen till EarMind"], 20) != nil else { return miss("Välkommen not shown") }
        screen("valkommen", "Välkommen")
        guard tap(["Fortsätt"], "Fortsätt") else { return false }
        guard wait(["Fota sidor"], 10) != nil else { return miss("Nytt prov not shown after Fortsätt") }
        screen("nytt-prov", "Nytt prov, first time")
        tap(["Fota sidor"], "Fota sidor")
        systemAlerts()
        pause(2)
        screen("kamera", "Fota sidor (photo library in the Simulator)")
        closePicker()
        guard pickPhoto() else { return false }
        lowerQuestions(to: 3)
        guard tap(["Skapa frågor"], "Skapa frågor") else { return false }
        guard wait(["Ser rätt ut"], 180) != nil else { return miss("Stämmer det här? not shown in 180 s") }
        screen("stammer", "Stämmer det här?")
        guard waitEnabled(["Ser rätt ut"], 120), tap(["Ser rätt ut"], "Ser rätt ut") else { return miss("Ser rätt ut not tappable") }
        guard waitEnabled(["Starta prov"], 240) else { screen("gor-ljud", "No Starta prov"); return miss("Starta prov not enabled in 240 s") }
        screen("start-med-prov", "Start with the exam, sound ready")
        tap(["Starta prov"], "Starta prov")
        if wait(["Styr med dina AirPods"], 10) != nil {
            screen("styr", "Styr med dina AirPods")
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov"], "Starta on the control check")
        }
        guard wait(["Tryck på AirPods för svaret", "Tänk", "Avsluta"], 20) != nil else { return miss("no player") }
        screen("forsta-fragan", "The first question")
        pause(8)
        screen("efter-betanketid", "After the thinking time (no press)")
        tap(["Avsluta"], "Avsluta")
        // Run 43639763574: the player was still there in lap 2 two minutes later. Start lies under the player, so
        // "Nytt prov" is in the tree either way: what counts is that Avsluta is gone.
        if !gone(["Avsluta"], 6) {
            screen("avsluta-kvar", "The player is still open 6 s after Avsluta")
            note("Avsluta did not close the player at once (tapped during the thinking time of question 2)")
            tap(["Avsluta"], "Avsluta again")
            if !gone(["Avsluta"], 6) { return miss("Avsluta does not close the player") }
        }
        return atStart() || miss("Start did not come back after Avsluta")
    }

    /// True when none of `labels` is hittable within `timeout`.
    private func gone(_ labels: [String], _ timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if find(labels)?.isHittable != true { return true }
            pause(0.5)
        } while Date() < end
        return false
    }

    /// Start in front: "Nytt prov" hittable and no player or sheet on top.
    private func atStart() -> Bool {
        // Run 43645092271: an imported exam is titled "Nytt prov" too, so the gear (only on Start) is the sign.
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Inställningar'")).firstMatch.isHittable
            && find(["Avsluta"])?.isHittable != true
    }

    /// Back to Start without relaunching (a relaunch is a new account in the Simulator, see above).
    private func goToStart() {
        for _ in 0..<6 {
            // A109: "Vill du ha en påminnelse?" after the first finished exam (T30 tests it).
            if find(["Vill du ha en påminnelse?"]) != nil, let notNow = find(["Inte nu"]), notNow.isHittable {
                tapElement(notNow, "Inte nu (reminder question)", counted: false)
                pause(1)
                continue
            }
            if atStart() { return }
            // Run 43656117870: after Publicera prov an alert "Publicerat." with Okej stays up and blocked everything.
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
            // Run 43782880704: Start had been paged sideways to Fler lägen.
            if find(["FLER LÄGEN"]) != nil { app.swipeRight(); pause(1) }
            app.swipeDown(velocity: .fast)
            pause(1)
        }
        if !atStart() { log.append("goToStart: Start not in front after 6 tries") }
    }

    /// Waits for a file another Simulator's phase writes (shared folder on the runner).
    private func waitForFile(_ name: String, _ seconds: TimeInterval) -> Bool {
        let url = out.appendingPathComponent(name)
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            pause(5)
        }
        return miss("\(name) did not come in \(Int(seconds)) s")
    }

    private func questionList() -> Bool {
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        guard wait(["Frågor"], 10) != nil else { return miss("question list not shown") }
        screen("fragelistan", "Frågor och svar")
        guard tap(["Fråga 1*"], "the first question") else { return false }
        pause(1)
        screen("fraga-1", "Editing question 1")
        tap(["Avbryt"], "Avbryt in the editor")
        return true
    }

    private func chatGPTImport(title: String) -> Bool {
        goToStart()
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        guard tap(["Gör med ChatGPT*"], "Gör med ChatGPT") else { return false }
        guard wait(["Kopiera prompten"], 10) != nil else { return miss("the ChatGPT steps did not show") }
        screen("chatgpt-steg", "Gör med ChatGPT: the three steps")
        tap(["Kopiera prompten"], "Kopiera prompten")
        // Never read the pasteboard here: iOS asks the test runner for permission and the run hangs (43632852744).
        note("Öppna ChatGPT leaves the app (Safari or the ChatGPT app): not tapped in the test")
        UIPasteboard.general.string = Self.chatGPTAnswer
        guard tap(["Klistra in", "Paste"], "Klistra in (the answer from ChatGPT)") else { return false }
        systemAlerts()
        if let allow = wait(["Tillåt klistra in", "Allow Paste"], 3) { tapElement(allow, "Tillåt klistra in") }
        guard wait(["Hittade*"], 15) != nil else { screen("chatgpt-fel", "No questions found"); return miss("Hittade n frågor not shown") }
        screen("chatgpt-hittade", "Hittade n frågor med svar")
        guard tap(["Spara frågorna"], "Spara frågorna") else { return false }
        pause(3)
        screen("chatgpt-sparat", "After Spara frågorna")
        return true
    }

    /// A110 (D198): Dela and Publicera prov are only there for a started exam. Start the next exam once and close the
    /// player, as a user does before sharing it.
    private func startOnce() {
        goToStart()
        guard waitEnabled(["Starta prov"], 20) else { return }
        tap(["Starta prov"], "Starta prov (before Dela, A110)")
        if wait(["Styr med dina AirPods"], 8) != nil {
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov"], "Starta on the control check", quiet: true)
        }
        if wait(["Avsluta"], 20) != nil { pause(4); tap(["Avsluta"], "Avsluta (after starting, A110)") }
        pause(2)
        goToStart()
    }

    /// A110 on the exam's own screen: when Dela is not there the exam is not started; start this one, close the player
    /// and come back to its screen (run 43766804245: startOnce on Start had started the other exam).
    private func startHereIfNeeded() {
        guard find(["Dela"]) == nil, let start = find(["Starta prov"]), start.isHittable else { return }
        tapElement(start, "Starta prov (on the exam's screen, A110)")
        if wait(["Styr med dina AirPods"], 8) != nil {
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov"], "Starta on the control check", quiet: true)
        }
        if wait(["Avsluta"], 20) != nil { pause(4); tap(["Avsluta"], "Avsluta (A110)") }
        pause(2)
        if find(["Vill du ha en påminnelse?"]) != nil { tap(["Inte nu"], "Inte nu", counted: false, quiet: true) }
        if find(["Dela"]) == nil { tap(["Frågor och svar"], "Frågor och svar (again)", quiet: true); pause(1) }
    }

    private func share() -> Bool {
        goToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        pause(1)
        startHereIfNeeded()
        guard tap(["Dela"], "Dela") else { return false }
        pause(3)
        screen("dela", "Dela")
        if wait(["Kopiera", "Copy", "Kopiera länk"], 5) == nil { note("Dela: no share sheet with Kopiera seen") }
        closeSheet()
        return true
    }

    private func publish() -> Bool {
        goToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        pause(1)
        startHereIfNeeded()
        guard tap(["Mer"], "Mer") else { return false }
        guard tap(["Publicera prov"], "Publicera prov in Mer") else { return false }
        pause(2)
        screen("publicera", "Publicera prov")
        if find(["Sök skola eller ort"]) != nil || app.searchFields.firstMatch.exists {
            guard pickSchool() else { return false }
        } else if tap(["Skola*", "Välj skola*", "Byt"], "choose a school", quiet: true) {
            guard pickSchool() else { return false }
        }
        screen("publicera-skola", "Publicera prov with the school")
        if tap(["Ämne*"], "Ämne", quiet: true) {
            tap(["Biologi"], "Biologi", quiet: true)
        }
        let name = app.textFields["Användarnamn"]
        if name.exists {
            name.tap(); taps += 1
            if app.keyboards.firstMatch.waitForExistence(timeout: 4) { name.typeText("Toby test") } else { note("Användarnamn: no keyboard (Simulator)") }
        }
        // Run 43649698914: Provdatum is required ("Saknas: provdatum"). The date picker opens a calendar; a day a week
        // ahead is picked by its label ("lördag 22 november"), then the calendar is closed.
        if tap(["Provdatum*"], "Provdatum", quiet: true) {
            pause(1)
            let day = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            let format = DateFormatter()
            format.locale = Locale(identifier: "sv_SE")
            format.dateFormat = "d MMMM"
            let wanted = format.string(from: day)
            let target = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", wanted)).firstMatch
            if target.waitForExistence(timeout: 3), target.isHittable {
                tapElement(target, "the date \(wanted)")
            } else {
                note("Provdatum: the day '\(wanted)' was not found in the calendar")
                screen("kalender", "Provdatum calendar", counts: false)
            }
            pause(1)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap() // outside the calendar
            testTaps += 1
            pause(1)
        }
        if find(["Saknas*"]) != nil {
            note("Publicera prov: the main button looks tappable while '\(find(["Saknas*"])?.label ?? "")' is shown")
        }
        screen("publicera-ifyllt", "Publicera prov filled in")
        guard tap(["Publicera prov"], "Publicera prov (the main button)") else { return false }
        guard wait(["Publicerat", "Ta bort publiceringen"], 30) != nil else { screen("publicera-fel", "Not published"); return miss("Publicerat not shown in 30 s") }
        screen("publicerat", "Publicerat")
        let title = app.navigationBars.firstMatch.identifier
        try? "\(title)\n".write(to: out.appendingPathComponent("t24-published.txt"), atomically: true, encoding: .utf8)
        log.append("published: '\(title)' at \(Self.school), \(Self.place)")
        return true
    }

    // MARK: Phase b

    private func firstStartLater() -> Bool {
        guard wait(["Välkommen till EarMind"], 20) != nil else { return miss("Välkommen not shown") }
        tap(["Fortsätt"], "Fortsätt")
        guard tap(["Senare"], "Senare (no exam yet)") else { return false }
        pause(2)
        screen("start-utan-prov", "Start without an exam")
        if find(["Hitta prov från din skola", "Prov från din skola"]) == nil { note("A user without an exam: no way to the school's exams on Start") }
        return true
    }

    private func findPublished() -> Bool {
        guard tap(["Hitta prov från din skola", "Prov från din skola"], "Hitta prov från din skola") else { return false }
        pause(2)
        screen("skolan", "Prov från din skola")
        if app.searchFields.firstMatch.exists || find(["Sök skola eller ort"]) != nil {
            guard pickSchool() else { return false }
        }
        let published = (try? String(contentsOf: out.appendingPathComponent("t24-published.txt"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        log.append("looking for the exam A published: '\(published)'")
        pause(3)
        screen("skolans-prov", "The school's exams")
        guard let add = wait(["Lägg till*"], 15) else { return miss("no exam to add at the school") }
        tapElement(add, "Lägg till")
        pause(2)
        screen("publicering", "The published exam")
        guard tap(["Lägg till i mina prov"], "Lägg till i mina prov") else { return false }
        guard wait(["Starta prov", "Öppna"], 30) != nil else { return miss("not added") }
        screen("tillagt", "Added to my exams")
        return true
    }

    /// The server's test modes as a user sees them: a new import, then the question list for up to 40 s.
    private func soundMode(_ mode: String, title: String) -> Bool {
        launch(mode)
        guard wait(["Nytt prov"], 15) != nil else { return miss("Start not shown") }
        guard chatGPTImport(title: title, relaunch: false, mode: mode) else { return false }
        relaunchToStart(keepHeader: true)
        // A107 (D190): no sound is made before Starta prov, so the modes show nothing until the exam is started. Start it
        // (the player opens and waits for the sound), close it, and read Start as before.
        if waitEnabled(["Starta prov"], 20) {
            tap(["Starta prov"], "Starta prov (\(mode), A107)")
            if wait(["Styr med dina AirPods"], 8) != nil {
                for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
                tap(["Starta ändå", "Starta prov"], "Starta on the control check", quiet: true)
            }
            pause(6)
            let inPlayer = Self.labels(in: app.debugDescription, kind: "StaticText").filter { $0.contains("jud") || $0.contains("klara") }
            log.append("mode \(mode): in the player after Starta prov: \(inPlayer.joined(separator: " | "))")
            screen("lage-\(mode)-spelaren", "The player in the '\(mode)' mode")
            tap(["Avsluta"], "Avsluta (\(mode))", quiet: true)
            pause(2)
        } else {
            note("\(mode): Starta prov not tappable after the import")
        }
        var seen: [String] = []
        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline {
            let texts = Self.labels(in: app.debugDescription, kind: "StaticText")
            for t in texts where (t.contains("Ljud") || t.contains("ljud")) && !seen.contains(t) { seen.append(t) }
            pause(4)
        }
        screen("lage-\(mode)", "Start in the server's '\(mode)' mode after 40 s")
        log.append("mode \(mode): sound lines seen on Start: \(seen.joined(separator: " | "))")
        if mode == "unavailable", !seen.contains(where: { $0.contains("Ljudet kan inte göras just nu") }) {
            note("unavailable: 'Ljudet kan inte göras just nu' never shown on Start in 40 s")
        }
        if mode == "slow", seen.isEmpty { note("slow: no line about the sound on Start") }
        return true
    }

    private func chatGPTImport(title: String, relaunch: Bool, mode: String = "") -> Bool {
        if relaunch { return chatGPTImport(title: title) }
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        // Run 43687320010 (slow): "Gör med ChatGPT" was not there after Nytt prov once; close and open Nytt prov again.
        if wait(["Gör med ChatGPT*"], 8) == nil {
            screen("nytt-prov-utan-chatgpt", "Nytt prov without Gör med ChatGPT", counts: false)
            closeSheet()
            goToStart()
            guard tap(["Nytt prov"], "Nytt prov (again)") else { return false }
        }
        guard tap(["Gör med ChatGPT*"], "Gör med ChatGPT") else { return false }
        tap(["Kopiera prompten"], "Kopiera prompten")
        // Angela Schrute 07:30 (L5): the fixed questions already had sound from earlier runs (D144: the file name comes
        // from the text and the test voice), so `slow` and `unavailable` had nothing to delay or refuse. A tag that is
        // new in every run makes the server make the sound (fake audio, D180), so the modes are tried for real.
        let tag = String(Int(Date().timeIntervalSince1970) % 1_000_000)
        UIPasteboard.general.string = Self.chatGPTAnswer.replacingOccurrences(of: "fotosyntesen", with: "fotosyntes")
            .replacingOccurrences(of: "?\n", with: " (test \(tag) \(mode))?\n")
        log.append("questions tagged 'test \(tag) \(mode)' so their sound is new")
        guard tap(["Klistra in", "Paste"], "Klistra in") else { return false }
        if let allow = wait(["Tillåt klistra in", "Allow Paste"], 3) { tapElement(allow, "Tillåt klistra in") }
        guard wait(["Hittade*"], 15) != nil else { return miss("Hittade not shown") }
        return tap(["Spara frågorna"], "Spara frågorna")
    }

    /// D183 (Angela Schrute 09885ad, Toby 2's T24 finding): a relaunch in the Simulator is a new anonymous account,
    /// and before D183 Start then deleted every uploaded exam. The two imports above are given 30 s to upload, then
    /// the app is relaunched twice; Start must still list them (not "Kom förberedd till provet").
    private func examsSurviveRelaunch() -> Bool {
        launch(header)
        guard wait(["Inställningar"], 20) != nil else { return miss("Start not shown") }
        pause(30)
        let before = Self.labels(in: app.debugDescription, kind: "StaticText").filter { $0.contains("frågor") }
        log.append("before the relaunches: \(before.joined(separator: " | "))")
        for n in 1...2 {
            launch(header)
            guard wait(["Inställningar"], 20) != nil else { return miss("Start not shown after relaunch \(n)") }
            pause(8) // refresh() runs on opening
            screen("efter-omstart-\(n)", "Start after relaunch \(n) (D183)")
            if find(["Kom förberedd till provet"]) != nil {
                return miss("relaunch \(n): Start is empty, the exams are gone (D183 not working)")
            }
        }
        let after = Self.labels(in: app.debugDescription, kind: "StaticText").filter { $0.contains("frågor") }
        log.append("after two relaunches: \(after.joined(separator: " | "))")
        return true
    }

    // MARK: Phase c

    private func recordOwnAnswer() -> Bool {
        goToStart()
        guard wait(["Nytt prov", "Fler lägen"], 20) != nil else { return miss("Start not shown") }
        guard tap(["Fler lägen"], "Fler lägen") else { return false }
        pause(2)
        screen("fler-lagen", "Fler lägen")
        // Run 43649698914: Fler lägen shows "Läge: Standardläge. Byt läge"; Provläge is in that sheet.
        if find(["Provläge*"]) == nil { tap(["Läge:*", "Byt"], "Byt läge") ; pause(2); screen("lagen", "Byt läge", counts: false) }
        guard tap(["Provläge*"], "Provläge") else { return false }
        pause(2)
        screen("provlage", "Provläge")
        systemAlerts()
        if wait(["Mina svar"], 10) == nil {
            // Run 43674540972: Provläge (BETA, listening) shows "Lägg till prov" although the user has made an exam in
            // the repetition flow; Mina svar comes only with an exam added there. Not a failure of the flow, a finding.
            if find(["Lägg till prov"]) != nil {
                note("Mina svar: Provläge says 'Lägg till prov' although an exam was made in the repetition flow; Mina svar (Spela in) only comes after an exam is added there, so the two exams are not the same")
                return true
            }
            note("Mina svar is not on the first screen of Provläge")
        }
        guard tap(["Mina svar"], "Mina svar") else { return false }
        pause(2)
        screen("mina-svar", "Mina svar")
        guard tap(["Spela in*"], "Spela in") else { return false }
        pause(2)
        screen("spela-in", "Spela in")
        if tap(["Välj ur provet", "Fråga 1*"], "pick a question", quiet: true) {
            pause(1.5)
            // Angela Fable 14:36: "Välj ur provet" opens a sheet with the exam's questions; without a question chosen the
            // sheet covers "Spela in svaret" (and the button is grey). Choose the first question in the sheet.
            let rows = app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && $0.label.contains("?") }
                + app.cells.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && $0.label.contains("?") }
            if let first = rows.first {
                tapElement(first, "the first question in the sheet (\(first.label.prefix(40)))")
                pause(1.5)
            } else {
                screen("valj-ur-provet", "Välj ur provet: no question row found", counts: false)
                note("Välj ur provet: no question row with '?' to choose in the sheet")
            }
        }
        if tap(["Spela in svaret"], "Spela in svaret", quiet: true) {
            systemAlerts()
            pause(4)
            screen("spelar-in", "Recording the answer (silence in the Simulator)")
            tap(["Stoppa"], "Stoppa", quiet: true)
            pause(3)
            screen("inspelat", "After Stoppa")
            tap(["Klar"], "Klar", quiet: true)
            pause(5)
            screen("klar", "After Klar (fake transcript)")
        } else {
            note("Spela in: 'Spela in svaret' was not reached")
        }
        return true
    }

    /// The destructive button of a confirmation (a sheet or an alert) – only ever a hittable one: run 43661618294 tapped
    /// the list's own button behind the dialog, XCTest stopped the test, and the publication stayed.
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

    private func cleanUp() -> Bool {
        goToStart()
        // Run 43782880704: once the exam has a date the Start card is NÄSTA PROV with "Ändra <title>", no Frågor och svar.
        if !tap(["Frågor och svar"], "Frågor och svar", quiet: true) {
            var edit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ändra '")).firstMatch
            for _ in 0..<4 where edit.exists && !edit.isHittable { app.swipeUp(); edit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ändra '")).firstMatch }
            guard edit.exists, edit.isHittable else { return miss("Frågor och svar: neither it nor 'Ändra …' found on Start") }
            tapElement(edit, "\(edit.label) (NÄSTA PROV card)")
            pause(2)
            if find(["Ta bort publiceringen", "Mer"]) == nil { _ = tap(["Frågor och svar"], "Frågor och svar (after Ändra)", quiet: true) }
        }
        if tap(["Ta bort publiceringen"], "Ta bort publiceringen", quiet: true) || (tap(["Mer"], "Mer", quiet: true) && tap(["Ta bort publiceringen"], "Ta bort publiceringen", quiet: true)) {
            pause(1)
            if !confirmDestructive("Ta bort publiceringen") { note("Ta bort publiceringen: no confirmation button to tap") }
            pause(3)
            screen("publicering-borta", "After Ta bort publiceringen")
            // Run 43674540972: "Publiceringen är borttagen." stays as an alert with Okej and covers Mer.
            for _ in 0..<3 where app.alerts.firstMatch.exists {
                let alert = app.alerts.firstMatch
                log.append("ALERT: \(alert.label) — " + alert.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " / "))
                let ok = ["Okej", "OK", "Ok", "Stäng"].lazy.map { alert.buttons[$0] }.first { $0.exists }
                (ok ?? alert.buttons.element(boundBy: 0)).tap(); testTaps += 1
                pause(1)
            }
            if let ok = find(["Okej"]), ok.isHittable { tapElement(ok, "Okej (Publiceringen är borttagen.)", counted: false); pause(1) }
        } else {
            note("Ta bort publiceringen not found: the test exam may still be published at \(Self.school)")
        }
        guard tap(["Mer"], "Mer") else { return false }
        guard tap(["Ta bort provet"], "Ta bort provet") else { return false }
        pause(1)
        if !confirmDestructive("Ta bort provet") { note("Ta bort provet: no confirmation button to tap") }
        pause(3)
        screen("provet-borta", "After Ta bort provet")
        return true
    }

    // MARK: Shared steps

    private var retriedLibrary = false

    private func pickPhoto() -> Bool {
        closePicker()
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
        // Nightly 43900691284: the library stayed empty for 60 s. Close it and open it once more before giving up.
        if cells.isEmpty, !retriedLibrary {
            retriedLibrary = true
            note("Välj bilder: no pictures in 60 s, the library was opened again")
            closePicker()
            return pickPhoto()
        }
        screen("bildbiblioteket", "Välj bilder: the photo library", counts: false)
        guard let width = cells.map(\.frame.width).max(), let top = cells.map(\.frame.minY).min() else {
            return miss("no grid of pictures")
        }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: width / 2, dy: top + width / 2)).tap()
        taps += 1
        if let add = wait(["Lägg till", "Add", "Klar", "Done"], 3) { tapElement(add, "Lägg till in the photo library") }
        return wait(["1 foto*"], 20) != nil || waitEnabled(["Skapa frågor"], 10) || miss("the picture did not get in")
    }

    private func pickSchool() -> Bool {
        let field = app.searchFields.firstMatch
        guard field.waitForExistence(timeout: 5) else { return miss("no school search field") }
        field.tap(); taps += 1
        guard app.keyboards.firstMatch.waitForExistence(timeout: 5) else { return miss("school search: no keyboard") }
        field.typeText("Kiruna")
        pause(3)
        screen("skolsok", "School search: Kiruna", counts: false)
        guard tap([Self.school + "*"], Self.school) else { return false }
        pause(2)
        return true
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

    /// Nightly 43839516709: the photo library from Fota sidor stayed open (a "Platsen är inkluderad … Läs mer… Stäng" row
    /// in it), so Välj bilder and everything after was covered. Close it with a hittable Avbryt, or drag it down, and check.
    private func closePicker() {
        let pickerSigns = ["Samlingar", "Sortera och filtrera", "Collections"]
        for attempt in 1...4 {
            guard find(pickerSigns) != nil else { return }
            let cancel = ["Avbryt", "Cancel"].lazy.compactMap { label in
                self.app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).allElementsBoundByIndex.first { $0.exists && $0.isHittable }
            }.first
            if let cancel { tapElement(cancel, "Avbryt (photo library, try \(attempt))", counted: false) } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
                log.append("closePicker: dragged the photo library down (try \(attempt))")
            }
            pause(1.5)
        }
        if find(pickerSigns) != nil { note("the photo library from Fota sidor did not close") }
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
            XCTFail("[t24-\(phase)] \(name)")
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
        let fileName = String(format: "t24%@-%02d-%@", phase, shots, name)
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
        var lines = ["T24 phase \(phase) (simulator, not a device), header x-earmind-test=\(header)",
                     "taps (a user's): \(taps), test taps: \(testTaps), screens: \(shots)", "", "Sections:"] + sections
        lines += ["", "Not obvious:"] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 }) + ["", "Log:"] + log + [""]
        let text = lines.joined(separator: "\n")
        try? text.write(to: out.appendingPathComponent("t24-\(phase)-log.txt"), atomically: true, encoding: .utf8)
        return text
    }

    private func finish() {
        let text = writeLog()
        let summary = XCTAttachment(string: text)
        summary.name = "t24-\(phase)-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
