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
/// T46 (Deangelo 2026-11-17 18:10, A132/D215): Spela plays on the card on Start ("Spelar i AirPods", "M:SS kvar",
/// Pausa/Fortsätt, Stoppa); the text on the card opens the player; the locked-phone line goes after the first Spela;
/// a said text is not an exam but a capsule in "Senaste" that puts the text back (long press: Ta bort); the field stops
/// growing at 5 rows. "At most one filled blue button" is a look, so only the screenshots show it.
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
        section("Spela på kortet (A132)", { playOnCard() })
        section("Spelaren från kortet: varv 2", { repeatInPlayer() })
        section("Pausa och hoppa (1 och 2 tryck)", { pauseAndSkip() })
        section("Senaste lägger tillbaka texten, inget Nästa prov (A132)", { recentsPutBack() })
        section("Fältet växer högst 5 rader (A132)", { fieldStopsGrowing() })
        section("Krediter, + och Klistra in länk (A116, A117)", { plusLinkAndCredits() })
        section("Nytt prov: Klistra in länk finns (A116)", { newDrillLinkRow() })
        section("Ta bort i Senaste", { cleanUp() })
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
        if let play = find(Self.playLabels), play.isEnabled { note("Spela is tappable before any text (A115: grey without text)") }
        guard focusField("Säg i AirPods (the field)") else { return miss("the field got no keyboard after 3 taps") }
        field.typeText(Self.text)
        pause(1)
        let value = (field.value as? String) ?? ""
        log.append("T36 field value: \(value)")
        if !value.contains("Klorofyllet") { return miss("the text did not get into the field (value '\(value)')") }
        // A132 (Ke72): the cost stands by the button as "120 krediter" (or "… · du har 88").
        let cost = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.contains("krediter") && !$0.contains("kvar") }
        log.append("T46 cost by the button: \(cost ?? "-")")
        if cost == nil, find(["Räknas som 1 fråga*", "Kostar *"]) == nil { note("no cost by Spela ('N krediter', A132)") }
        lockLineBefore = text(starting: "Du kan låsa telefonen") != nil
        log.append("T46 the locked-phone line before the first Spela: \(lockLineBefore)")
        if !lockLineBefore { note("no 'Du kan låsa telefonen. Det hörs i AirPods ändå.' before the first Spela (A132)") }
        log.append("T36 Hur länge: \(find(["Hur länge*"])?.label ?? "-"), tempo: \(find(["Tempo*"])?.label ?? "-")")
        log.append("T46 the main button: \(find(Self.playLabels)?.label ?? "-")")
        screen("text", "Säg i AirPods with a text")
        return waitEnabled(Self.playLabels, 5) || miss("Spela i … not tappable with a text")
    }

    /// A132 (D215.6): Spela plays on the card on Start; the player over the whole screen opens only from the text.
    static let playLabels = ["Spela i*", "Spela"]
    /// The text on the playing card is a button with the whole text; Senaste's capsule is only its first 23 characters + "…".
    static let cardText = [text, "Klorofyllet i bladen fångar ljuset.*"]

    private var lockLineBefore = false

    /// Taps "Spela i 10 min" and waits for the card's "Spelar i AirPods" (or "Gör ljudet …") on Start.
    private func playFromCard() -> Bool {
        guard tap(Self.playLabels, "Spela i …") else { return false }
        if wait(["Styr med dina AirPods"], 5) != nil {
            for n in 1...3 { if let skip = wait(["Hoppa över"], 15) { tapElement(skip, "Hoppa över \(n) (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov", "Spela i*", "Spela"], "Start on the control check", quiet: true)
        }
        // Run 44100858965: the lines tick every second; read the tree, for up to 60 s.
        let end = Date().addingTimeInterval(60)
        var up = false
        repeat {
            up = text(starting: "Spelar i AirPods") != nil || text(starting: "Gör ljudet") != nil || timeLeft() != nil
            if !up { pause(2) }
        } while !up && Date() < end
        if up { answerReminder(); return true }
        screen("ingen-spelning", "Spela did not show 'Spelar i AirPods' on the card")
        return miss("no 'Spelar i AirPods' on the card after Spela")
    }

    /// Run 44163010444: "Vill du ha en påminnelse?" (A109) comes up a few seconds after the first Spela and covers the
    /// card, so the card's Pausa and text got no taps. Wait for it a moment and answer Inte nu.
    private func answerReminder() {
        guard wait(["Vill du ha en påminnelse?"], 6) != nil else { return }
        log.append("T46 the reminder question came up over the playing card")
        if let notNow = find(["Inte nu"]) { tapElement(notNow, "Inte nu (reminder question)", counted: false) }
        pause(1.5)
    }

    /// The card's time line, "7:32 kvar" or "7:32 kvar · pausad".
    private func timeLeft() -> String? {
        Self.labels(in: app.debugDescription, kind: "StaticText").first { label in
            guard let range = label.range(of: " kvar") else { return false }
            let clock = label[..<range.lowerBound]
            return clock.contains(":") && clock.allSatisfy { $0.isNumber || $0 == ":" }
        }
    }

    private func stopOnCard() {
        if !tap(["Stoppa"], "Stoppa", quiet: true) { tap(["Avsluta"], "Avsluta", quiet: true) }
        pause(2)
    }

    /// T46: Spela stays on Start and plays on the card: "Spelar i AirPods", the time that is left, Pausa/Fortsätt, Stoppa.
    /// The locked-phone line is gone after the first Spela.
    private func playOnCard() -> Bool {
        guard playFromCard() else { return false }
        pause(2)
        screen("spelar-kort", "Spelar i AirPods on the card (A132)")
        var ok = true
        let onStart = app.buttons.matching(NSPredicate(format: "label ==[c] 'Inställningar'")).firstMatch.exists
        log.append("T46 Start still in front while playing: \(onStart)")
        if !onStart { ok = miss("Spela opened something over Start (A132: it plays on the card)") }
        let left = timeLeft()
        log.append("T46 time left on the card: \(left ?? "-")")
        if left == nil { ok = miss("no 'M:SS kvar' on the card while it plays") }
        if find(["Stoppa"]) == nil { ok = miss("no Stoppa on the card") }
        if text(starting: "Du kan låsa telefonen") != nil { ok = miss("the locked-phone line is still there after Spela") }
        // The card's pause button: Pausa → "· pausad" → Fortsätt.
        if tap(["Pausa"], "Pausa on the card") {
            pause(2)
            let pausedLine = timeLeft() ?? "-"
            log.append("T46 after Pausa on the card: \(pausedLine)")
            if !pausedLine.hasSuffix("pausad") { ok = miss("no '· pausad' after Pausa on the card ('\(pausedLine)')") }
            screen("kort-pausad", "The card paused")
            if !tap(["Fortsätt"], "Fortsätt on the card") { ok = false }
            pause(2)
        } else { ok = false }
        return ok
    }

    /// The text on the card opens the player with the sentences; the text goes round (10 min), so lap 2 comes.
    private func repeatInPlayer() -> Bool {
        if timeLeft() == nil {
            if !((field.value as? String) ?? "").contains("Klorofyllet") { retype() }
            guard playFromCard() else { return false }
        }
        guard tap(Self.cardText, "the text on the card (opens the player)") else { return false }
        guard waitText(starting: "Varv 1", 20) || lapAtLeast(1) != nil else { screen("utan-varv", "No Varv line"); return miss("the text on the card did not open the player with 'Varv 1'") }
        log.append("T36 repeat: \(lapAtLeast(1) ?? "-")")
        screen("varv-1", "The player from the card, Varv 1")
        // Run 44009183791: with fake audio the laps go by in about a second, so any lap from 2 on counts.
        let end = Date().addingTimeInterval(150)
        var lap2: String?
        while lap2 == nil, Date() < end { lap2 = lapAtLeast(2); if lap2 == nil { pause(2) } }
        guard let lap2 else { return miss("no 'Varv 2' in 150 s (the text did not start again)") }
        log.append("T36 repeat: \(lap2)")
        screen("varv-2", "The player, Varv 2")
        return true
    }

    /// Run 44159967813 (slow Simulator, 112 s to Start): typeText failed with "Neither element nor any descendant has
    /// keyboard focus" after one tap. Tap until the keyboard is up, at most 3 times.
    @discardableResult
    private func focusField(_ step: String, counted: Bool = true) -> Bool {
        for n in 0..<3 {
            tapElement(field, n == 0 ? step : "\(step), again", counted: counted && n == 0)
            let end = Date().addingTimeInterval(4)
            repeat { if app.keyboards.count > 0 { pause(0.5); return true }; pause(0.5) } while Date() < end
        }
        return false
    }

    private func retype() {
        guard focusField("Säg i AirPods (again)") else { return }
        field.typeText(Self.text)
        pause(1)
    }

    /// Still in the player: 1 press pauses and goes on, 2 presses skip to the next sentence.
    private func pauseAndSkip() -> Bool {
        if lapAtLeast(1) == nil, text(starting: "Mening ") == nil {
            if timeLeft() == nil {
                if !((field.value as? String) ?? "").contains("Klorofyllet") { retype() }
                guard playFromCard() else { return false }
            }
            tap(Self.cardText, "the text on the card (opens the player)", quiet: true)
            pause(2)
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
        goToStart()
        stopOnCard()
        goToStart()
        return first != second || miss("two 1 presses did not toggle pause")
    }

    /// Senaste's capsules (buttons) for the test text: "Klorofyllet i bladen få…".
    private func recentCapsules() -> [String] {
        Self.labels(in: app.debugDescription, kind: "Button").filter { $0.hasPrefix("Klorofyllet") && $0.contains("…") && $0.count < 60 }
    }

    /// Run 44163010444: the deletes did nothing (110 characters after "clearing" 78): a tap puts the cursor where it lands.
    /// Put it at the end first (bottom right of the field), then delete; check, and say so if text is left.
    private func clearField() {
        let value = (field.value as? String) ?? ""
        guard value.contains("Klorofyllet") || value.contains("Bladen") || value.localizedCaseInsensitiveContains("example") else { return }
        guard focusField("Säg i AirPods (to clear it)", counted: false) else { return }
        for _ in 0..<2 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.95)).tap(); testTaps += 1
            pause(0.5)
            let now = (field.value as? String) ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: now.count + 5))
            pause(1)
            let left = (field.value as? String) ?? ""
            if !(left.contains("Klorofyllet") || left.contains("Bladen") || left.localizedCaseInsensitiveContains("example")) { return }
        }
        log.append("clearField: text left in the field: \(((field.value as? String) ?? "").prefix(40))")
    }

    /// T46: a said text is not an exam (no Nästa prov / Andra prov); a tap on its capsule in Senaste puts it back in the
    /// field without playing it.
    private func recentsPutBack() -> Bool {
        goToStart()
        pause(2)
        var ok = true
        let texts = Self.labels(in: app.debugDescription, kind: "StaticText") + Self.labels(in: app.debugDescription, kind: "Other")
        let examHeads = texts.filter { ["nästa prov", "andra prov"].contains($0.lowercased()) }
        log.append("T46 exam headings on Start after a said text: \(examHeads.isEmpty ? "none" : examHeads.joined(separator: ", "))")
        if !examHeads.isEmpty { ok = miss("a said text shows as \(examHeads.joined(separator: "/")) (A132: only in Senaste)") }
        let capsules = recentCapsules()
        log.append("T46 Senaste: \(text(starting: "Senaste") != nil), capsules \(capsules)")
        screen("senaste", "Start with Senaste after Stoppa")
        guard !capsules.isEmpty else { return miss("no capsule for the text in Senaste") }
        clearField()
        log.append("T46 field before the capsule: \((field.value as? String)?.prefix(40) ?? "-")")
        guard tap([capsules[0]], "the capsule in Senaste") else { return false }
        pause(2)
        let value = (field.value as? String) ?? ""
        log.append("T46 field after the capsule: \(value.prefix(60))")
        if !value.contains("Klorofyllet i bladen fångar ljuset") { ok = miss("the capsule did not put the text back in the field") }
        if text(starting: "Spelar i AirPods") != nil || timeLeft() != nil { ok = miss("a tap on the capsule started playing (it should only put the text back)") }
        screen("senaste-tillbaka", "The text back in the field from Senaste")
        return ok
    }

    /// T46 (D215.4): while it is written in, the field grows to 5 rows and then scrolls inside.
    private func fieldStopsGrowing() -> Bool {
        clearField()
        tapElement(field, "Säg i AirPods (rows)", counted: false)
        pause(0.5)
        let row = "Bladen fångar ljuset varje dag. "
        if !((field.value as? String) ?? "").isEmpty, ((field.value as? String) ?? "").contains("Klorofyllet") { return miss("the field could not be cleared before measuring") }
        var heights: [CGFloat] = []
        // Run 44151565954: all four heights were 108 with no keyboard, i.e. the field had lost focus (3 rows by design).
        // Measure only while it is written in: tap it again when the keyboard is gone.
        // A short word first (one row: the field shows its 3-row minimum), then past 5 rows.
        if app.keyboards.count == 0 { focusField("Säg i AirPods (rows)", counted: false) }
        field.typeText("Hej")
        pause(1)
        let short = field.frame.height
        log.append("T46 'Hej': height \(Int(short)), \(((field.value as? String) ?? "").count) characters")
        for chunk in [1, 3, 8, 14] {
            if app.keyboards.count == 0, !focusField("Säg i AirPods (focus again)", counted: false) { return miss("the field got no keyboard") }
            let have = ((field.value as? String) ?? "").components(separatedBy: row).count - 1
            if chunk > have { field.typeText(String(repeating: row, count: chunk - have)) }
            pause(1)
            log.append("T46 \(chunk) sentences: keyboard \(app.keyboards.count > 0), height \(Int(field.frame.height)), \(((field.value as? String) ?? "").count) characters")
            heights.append(field.frame.height)
        }
        log.append("T46 field heights at 1, 3, 8, 14 sentences: \(heights.map { String(format: "%.0f", $0) }.joined(separator: ", "))")
        screen("falt-14", "The field with a long text (at most 5 rows)")
        clearField()
        guard let last = heights.last, heights.count == 4 else { return false }
        if short >= last { return miss("the field did not grow while written in ('Hej' \(Int(short)), 14 sentences \(Int(last)))") }
        // 8 and 14 sentences are both well past 5 rows in a monospaced body font, so the height must have stopped.
        return abs(heights[3] - heights[2]) <= 2 || miss("the field still grows past 5 rows (\(heights[2]) → \(heights[3]))")
    }

    /// A text on screen that starts with `prefix`, read from the tree (labels that change every second are not queried).
    private func text(starting prefix: String) -> String? {
        Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix(prefix) }
    }

    /// The lap line ("Varv n · … kvar av 5 min") when n is at least `minimum`.
    private func lapAtLeast(_ minimum: Int) -> String? {
        Self.labels(in: app.debugDescription, kind: "StaticText").first { label in
            guard label.hasPrefix("Varv ") else { return false }
            let number = label.dropFirst(5).prefix { $0.isNumber }
            return (Int(number) ?? 0) >= minimum
        }
    }

    private func waitText(starting prefix: String, _ timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat { if text(starting: prefix) != nil { return true }; pause(1) } while Date() < end
        return false
    }

    /// A117: the capsule "N frågor kvar" (Testläge off), as a number.
    private func creditsLeft() -> Int? {
        let tree = app.debugDescription
        let all = Self.labels(in: tree, kind: "Button") + Self.labels(in: tree, kind: "StaticText")
        // A131 (D213): with a server that counts characters the capsule says "1 236 krediter kvar" (U+00A0 between thousands).
        let ends = ["frågor kvar", "fråga kvar", "krediter kvar", "kredit kvar"]
        guard let line = all.first(where: { label in ends.contains { label.hasSuffix($0) } }) else { return nil }
        return Self.creditNumber(line)
    }

    /// "1 236 krediter kvar" → 1236; A139 (Angela Fable 20:58): "5,3k krediter kvar" → 5300 (rounded by the app, so a
    /// change smaller than 100 is not seen above 1 000).
    nonisolated static func creditNumber(_ line: String) -> Int? {
        // Run 44168262433: "1 500 krediter kvar" was read as 1 500 000, since the k of "krediter" was taken; a k counts
        // only right after a digit ("5,3k").
        var head = String(line.prefix { $0.isNumber || $0 == " " || $0 == "\u{00A0}" || $0 == "," })
        let rest = line.dropFirst(head.count)
        if rest.hasPrefix("k "), head.last?.isNumber == true { head += "k" }
        if head.hasSuffix("k") {
            let number = head.filter { $0.isNumber || $0 == "," }.replacingOccurrences(of: ",", with: ".")
            return Double(number).map { Int(($0 * 1000).rounded()) }
        }
        return Int(head.filter(\.isNumber))
    }

    /// A116: "+" in the field (Lägg till material) has Fota sidor, Välj bilder, Lägg till fil and Klistra in länk; a
    /// link puts the page's text in the field. A117: the capsule before and after a new text is played.
    private func plusLinkAndCredits() -> Bool {
        goToStart()
        pause(3)
        let before = creditsLeft()
        log.append("T36 credits before: \(before.map(String.init) ?? "no capsule")")
        if before == nil { note("no 'N frågor kvar' capsule on Start (A117; Testläge is off in the test)") }
        guard tap(["Lägg till material"], "+ (Lägg till material)") else { return false }
        pause(1)
        let items = ["Fota sidor", "Välj bilder", "Lägg till fil", "Klistra in länk"]
        let missing = items.filter { find([$0]) == nil }
        log.append("T36 + menu: missing \(missing.isEmpty ? "none" : missing.joined(separator: ", "))")
        screen("plus-meny", "The + menu (A116)")
        if !missing.isEmpty { note("the + menu lacks \(missing.joined(separator: ", "))") }
        guard tap(["Klistra in länk"], "Klistra in länk") else { return false }
        let linkField = app.alerts.firstMatch.textFields.firstMatch
        guard linkField.waitForExistence(timeout: 5) else { return miss("no field in 'Klistra in länk'") }
        tapElement(linkField, "the link field", counted: false)
        linkField.typeText("https://example.com")
        guard tap(["Lägg till"], "Lägg till") else { return false }
        // The server reads the page (fetch-url, no ElevenLabs); example.com says "Example Domain".
        let end = Date().addingTimeInterval(40)
        var value = ""
        while Date() < end {
            value = (field.value as? String) ?? ""
            if value.localizedCaseInsensitiveContains("example") { break }
            if app.alerts.firstMatch.exists, find(["Okej", "OK"]) != nil {
                log.append("T36 link alert: \(app.alerts.firstMatch.label)")
                tap(["Okej", "OK"], "OK (link alert)", counted: false)
            }
            pause(2)
        }
        log.append("T36 field after the link: \(value.prefix(120))")
        screen("lank", "The field after Klistra in länk")
        guard value.localizedCaseInsensitiveContains("example") else { return miss("the page's text did not come into the field in 40 s") }
        let counts = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Räknas som") || $0.hasPrefix("Kostar") } ?? "-"
        log.append("T36 the line before playing the page: \(counts)")
        guard playFromCard() else { return false }
        pause(3)
        // Run 44064540048: the text from the link was saved but never started (audio_started_at null, a 404 from /drill
        // first). Photograph the player and say whether it really plays (Spelar i AirPods or a lap).
        screen("lank-spelar", "The card after Spela with the text from the link")
        let playing = text(starting: "Spelar i AirPods") != nil || timeLeft() != nil
        log.append("T36 the link text plays: \(playing)")
        if !playing { note("the text from the link did not start playing (no 'Spelar i AirPods' and no time left)") }
        stopOnCard()
        pause(2)
        goToStart()
        pause(5) // the quota is asked again after a sound is made
        let after = creditsLeft()
        log.append("T36 credits after playing the page: \(after.map(String.init) ?? "no capsule") (before \(before.map(String.init) ?? "-"))")
        if let before, let after, after >= before { note("the capsule did not go down after a new text was played (\(before) → \(after))") }
        if let before, let after { log.append("T36 the capsule went down by \(before - after) (A131: the text's characters when the server counts credits)") }
        return true
    }

    private func newDrillLinkRow() -> Bool {
        goToStart()
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        let row = wait(["Klistra in länk"], 8) != nil
        screen("nytt-prov-lank", "Nytt prov with Klistra in länk (A116)")
        closeSheet()
        goToStart()
        return row || miss("no 'Klistra in länk' under Material in Nytt prov")
    }

    private func paused() -> Bool {
        !app.buttons.matching(NSPredicate(format: "label ==[c] 'Pausa'")).firstMatch.exists
    }

    /// A132: a said text is removed with a long press on its capsule in Senaste ("Ta bort").
    private func cleanUp() -> Bool {
        goToStart()
        pause(2)
        let before = recentCapsules().count
        guard before > 0, let capsule = find([recentCapsules()[0]]) else { note("no capsule in Senaste to remove"); return true }
        capsule.press(forDuration: 1.2); testTaps += 1
        guard tap(["Ta bort"], "Ta bort (long press in Senaste)") else { return false }
        pause(1)
        _ = confirmDestructive("Ta bort")
        // Angela Fable 13:30 (run 44064540048): a removed reading came back after a 404. Look again after 10 s.
        pause(10)
        goToStart()
        let after = recentCapsules().count
        log.append("T36 capsules for the text in Senaste: \(before) before Ta bort, \(after) 10 s after")
        screen("borta-10s", "Start 10 s after Ta bort in Senaste")
        if after >= before { return miss("the removed text is still (or back) in Senaste after 10 s (\(before) → \(after))") }
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
        // Run 44151565954 (A132): the card's Pausa and its text were on screen but not "hittable" to XCTest; swiping
        // only scrolled the page away. An element that is inside the window is tapped at its centre, and said so.
        let frame = element.frame
        if !element.isHittable, !frame.isEmpty, app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) {
            log.append("NOT HITTABLE (tapped at its centre): \(step): '\(element.label)' at \(Int(frame.midX)),\(Int(frame.midY))")
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if counted { taps += 1 } else { testTaps += 1 }
            log.append(String(format: "%@ at %6.1f s: %@ (centre)", counted ? "TAP \(taps)" : "TEST TAP", Date().timeIntervalSince(started), step))
            return true
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
