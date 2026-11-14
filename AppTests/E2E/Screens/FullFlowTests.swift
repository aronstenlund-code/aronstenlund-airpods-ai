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
        switch phase {
        case "a":
            section("Första starten till första frågan") { firstStartToFirstQuestion() }
            section("Frågor och svar och en fråga") { questionList() }
            section("Gör med ChatGPT") { chatGPTImport(title: "ChatGPT-provet") }
            section("Dela") { share() }
            section("Publicera prov") { publish() }
        case "b":
            section("Andra kontot: första starten utan prov") { firstStartLater() }
            section("Prov från din skola") { findPublished() }
            section("Läget slow (ljudet dröjer)") { soundMode("slow", title: "Långsamt prov") }
            section("Läget unavailable (inga krediter)") { soundMode("unavailable", title: "Utan ljud") }
        default:
            section("Mina svar: spela in eget svar") { recordOwnAnswer() }
            section("Ta bort publiceringen och provet") { cleanUp() }
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
        closeSheet()
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
        return wait(["Nytt prov"], 15) != nil || miss("Start did not come back after Avsluta")
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
        relaunchToStart()
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        guard tap(["Gör med ChatGPT*"], "Gör med ChatGPT") else { return false }
        guard wait(["Kopiera prompten"], 10) != nil else { return miss("the ChatGPT steps did not show") }
        screen("chatgpt-steg", "Gör med ChatGPT: the three steps")
        tap(["Kopiera prompten"], "Kopiera prompten")
        log.append("prompt copied: \((UIPasteboard.general.string ?? "").count) characters")
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

    private func share() -> Bool {
        relaunchToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        guard tap(["Dela"], "Dela") else { return false }
        pause(3)
        screen("dela", "Dela")
        if wait(["Kopiera", "Copy", "Kopiera länk"], 5) == nil { note("Dela: no share sheet with Kopiera seen") }
        closeSheet()
        return true
    }

    private func publish() -> Bool {
        relaunchToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
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
        if find(["Prov från din skola"]) == nil { note("A user without an exam: 'Prov från din skola' is not on Start") }
        return true
    }

    private func findPublished() -> Bool {
        guard tap(["Prov från din skola"], "Prov från din skola") else { return false }
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
        guard chatGPTImport(title: title, relaunch: false) else { return false }
        relaunchToStart(keepHeader: true)
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

    private func chatGPTImport(title: String, relaunch: Bool) -> Bool {
        if relaunch { return chatGPTImport(title: title) }
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        guard tap(["Gör med ChatGPT*"], "Gör med ChatGPT") else { return false }
        tap(["Kopiera prompten"], "Kopiera prompten")
        UIPasteboard.general.string = Self.chatGPTAnswer.replacingOccurrences(of: "fotosyntesen", with: "fotosyntes")
        guard tap(["Klistra in", "Paste"], "Klistra in") else { return false }
        if let allow = wait(["Tillåt klistra in", "Allow Paste"], 3) { tapElement(allow, "Tillåt klistra in") }
        guard wait(["Hittade*"], 15) != nil else { return miss("Hittade not shown") }
        return tap(["Spara frågorna"], "Spara frågorna")
    }

    // MARK: Phase c

    private func recordOwnAnswer() -> Bool {
        guard wait(["Nytt prov", "Fler lägen"], 20) != nil else { return miss("Start not shown") }
        guard tap(["Fler lägen"], "Fler lägen") else { return false }
        pause(2)
        screen("fler-lagen", "Fler lägen")
        guard tap(["Provläge*"], "Provläge") else { return false }
        pause(2)
        screen("provlage", "Provläge")
        systemAlerts()
        if wait(["Mina svar"], 10) == nil { note("Mina svar is not on the first screen of Provläge") }
        guard tap(["Mina svar"], "Mina svar") else { return false }
        pause(2)
        screen("mina-svar", "Mina svar")
        guard tap(["Spela in*"], "Spela in") else { return false }
        pause(2)
        screen("spela-in", "Spela in")
        if tap(["Välj ur provet", "Fråga 1*"], "pick a question", quiet: true) { pause(1) }
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

    private func cleanUp() -> Bool {
        relaunchToStart()
        guard tap(["Frågor och svar"], "Frågor och svar") else { return false }
        if tap(["Ta bort publiceringen"], "Ta bort publiceringen", quiet: true) || (tap(["Mer"], "Mer", quiet: true) && tap(["Ta bort publiceringen"], "Ta bort publiceringen", quiet: true)) {
            pause(1)
            let confirm = app.buttons.matching(NSPredicate(format: "label ==[c] 'Ta bort publiceringen'"))
            if confirm.count > 0 { confirm.element(boundBy: confirm.count - 1).tap(); taps += 1 }
            pause(3)
            screen("publicering-borta", "After Ta bort publiceringen")
        } else {
            note("Ta bort publiceringen not found: the test exam may still be published at \(Self.school)")
        }
        guard tap(["Mer"], "Mer") else { return false }
        guard tap(["Ta bort provet"], "Ta bort provet") else { return false }
        pause(1)
        let confirm = app.buttons.matching(NSPredicate(format: "label ==[c] 'Ta bort provet'"))
        if confirm.count > 0 { confirm.element(boundBy: confirm.count - 1).tap(); taps += 1 }
        pause(3)
        screen("provet-borta", "After Ta bort provet")
        return true
    }

    // MARK: Shared steps

    private func pickPhoto() -> Bool {
        guard tap(["Välj bilder"], "Välj bilder") else { return false }
        systemAlerts()
        pause(3)
        let samples = ["2009", "2010", "2011", "2012"]
        let cells = app.images.allElementsBoundByIndex.filter { image in
            image.exists && samples.contains { image.label.contains($0) } && image.frame.width < 250
        }
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
    private func section(_ name: String, _ body: () -> Bool) {
        let t0 = Date()
        let taps0 = taps
        log.append("=== \(name)")
        let ok = body()
        let line = String(format: "%@ %@: %.0f s, %d tryck", ok ? "OK " : "FEL", name, Date().timeIntervalSince(t0), taps - taps0)
        sections.append(line)
        log.append(line)
        if !ok {
            screen("fel-\(sections.count)", "Section failed: \(name)", counts: false)
            XCTFail("[t24-\(phase)] \(name)")
        }
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

    private func finish() {
        var lines = ["T24 phase \(phase) (simulator, not a device), header x-earmind-test=\(header)",
                     "taps (a user's): \(taps), test taps: \(testTaps), screens: \(shots)", "", "Sections:"] + sections
        lines += ["", "Not obvious:"] + (unclear.isEmpty ? ["(none)"] : unclear.map { "- " + $0 }) + ["", "Log:"] + log + [""]
        let text = lines.joined(separator: "\n")
        try? text.write(to: out.appendingPathComponent("t24-\(phase)-log.txt"), atomically: true, encoding: .utf8)
        let summary = XCTAttachment(string: text)
        summary.name = "t24-\(phase)-log"
        summary.lifetime = .keepAlways
        add(summary)
    }
}
#endif
