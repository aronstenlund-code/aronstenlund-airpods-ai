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

    /// T44 (Kevin 2026-11-17 16:40): sound that already exists is free (D213), so the text gets a part of its own each
    /// run; otherwise the capsule never goes down with x-earmind-test.
    static let text = "Klorofyllet i bladen fångar ljuset. Växten gör socker av vatten och koldioxid. Körning \(Int(Date().timeIntervalSince1970) % 1_000_000)."

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
        // T53 (A148, Kelly Ke79): t53.sh runs the same class with the largest text (simctl content_size AX XXXL) and
        // only the accessibility sections.
        // T55 (D238): the reviewer's way from a new installation, one step at a time, with the credits after each.
        if env["LUMEN_T36_REVIEW"] == "1" {
            launch(header)
            guard section("Granskare 1: Välkommen (ny installation)", { reviewWelcome() }) else { return }
            section("Granskare 2: Säg i AirPods → Spela", { reviewSay() })
            section("Granskare 3: prov från en text", { reviewExam() })
            section("Granskare 4: Krediter (paketen, Villkor, Integritet, Återställ köp)", { reviewCredits() })
            section("Granskare 5: Radera konto", { deleteAccount() })
            log.append("T55 credits along the way: \(creditTrail.map { "\($0.0) \($0.1.map(String.init) ?? "-")" }.joined(separator: " → "))")
            return
        }
        if env["LUMEN_T36_A11Y"] == "1" {
            launch(header)
            guard section("Första starten till Start (AX5)", { firstStart() }) else { return }
            section("Första skärmen: VoiceOver-orden (Ke79)", { a11yFirstScreen() })
            section("Kortet som spelar: en mening (Ke79 punkt 9)", { a11yPlayingCard() })
            section("Senaste: hela texten och stilen (Ke79 punkt 4)", { a11yRecents() })
            section("Kreditbladet och köpdelen (Ke79)", { a11yCredits() })
            section("Radera konto: orden (A145, Ke79)", { a11yDeleteAccount() })
            return
        }
        launch(header)
        guard section("Första starten till Start", { firstStart() }) else { return }
        guard section("Säg i AirPods: skriv en text", { writeText() }) else { return }
        section("Spela på kortet (A132)", { playOnCard() })
        section("Spelaren från kortet: varv 2", { repeatInPlayer() })
        section("Pausa och hoppa (1 och 2 tryck)", { pauseAndSkip() })
        section("Senaste lägger tillbaka texten, inget Nästa prov (A132)", { recentsPutBack() })
        section("Utan nät: samma text spelas, en ny säger till efter 10 s (A135)", { offlineSay() })
        section("Långsamt ljud: 8 s och 25 s (A144, D225)", { slowSound() })
        section("Stil och Skriv i takt (A136, A140)", { styleAndPace() })
        section("Fältet växer högst 5 rader (A132)", { fieldStopsGrowing() })
        section("Krediter, + och Klistra in länk (A116, A117)", { plusLinkAndCredits() })
        section("Nytt prov: Klistra in länk finns (A116)", { newDrillLinkRow() })
        section("Krediter: köpbladet (A134, A141)", { shopSheet() })
        section("Radera konto (A145, K101)", { deleteAccount() })
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
        creditsAtStart = creditsLeft()
        pause(1.5) // the cost comes from the server about 0,7 s after the last key (A132 point 8)
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
    /// T55 (2), D238, A153: at AX5 the test must reach Spela without hiding the keyboard itself (no tap beside the
    /// field, no swipe, no drag). While this is on, tap() never hides it and never swipes; the bar's
    /// "Spela i 10 min. Kostar … krediter" above the keyboard is the button to find.
    private var keepKeyboard = false
    private var creditsAtStart: Int?

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
        var retried = false
        var slowSeen = false
        repeat {
            up = text(starting: "Spelar i AirPods") != nil || text(starting: "Gör ljudet") != nil || timeLeft() != nil
            // Run 44230731193: 20 s after the network came back the first try said "Ljudet kunde inte hämtas. Kolla
            // nätet." with Försök igen. Try again once, and say so. Angela Fable 07:19: with the network up the line is
            // "Det tar längre tid än vanligt. Försök igen om en stund."
            if !up, !slowSeen, let slow = text(starting: "Det tar längre tid än vanligt") {
                // D225/A144 (Angela Fable 10:36): after 8 s this stands while the spinner goes on; not an end.
                slowSeen = true
                log.append(String(format: "T50 '%@' after %.0f s; still waiting", slow, 60 - end.timeIntervalSinceNow))
            }
            if !up, !retried, let line = text(starting: "Ljudet kunde inte hämtas") {
                retried = true
                note("Spela said '\(line)'; tapped Försök igen once")
                tap(["Försök igen"], "Försök igen", counted: false, quiet: true)
            }
            if !up { pause(2) }
        } while !up && Date() < end
        if up {
            // K100 (D225): a new text is saved and started in one call, so Spela should answer in a few seconds.
            log.append(String(format: "K100 Spela → '%@' after %.1f s", text(starting: "Spelar i AirPods") ?? text(starting: "Gör ljudet") ?? timeLeft() ?? "-", 60 - end.timeIntervalSinceNow))
            answerReminder(); return true
        }
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
    /// A148 (Ke79 point 9, run 44424911694): the card is one element, "Spelar i AirPods med Adam, 9 minuter kvar"
    /// (", pausad" when paused); before it the clock stood alone, "9:55 kvar".
    private func timeLeft() -> String? {
        Self.labels(in: app.debugDescription, kind: "StaticText").first { label in
            if label.contains(" minuter kvar") || label.contains(" minut kvar") || label.contains("sekunder kvar") { return true }
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
        if !(waitText(starting: "Varv 1", 20) || lapAtLeast(1) != nil) {
            // Angela Fable 03:20: seen twice, a tap on the card's text that did not open the player while the next one
            // did. Say so (with the time, for the app's "Say: the text on the card pressed" line) and tap once more.
            screen("utan-varv", "No Varv line after the first tap on the card's text")
            note(String(format: "the first tap on the card's text did not open the player (at %.1f s); tapped again", Date().timeIntervalSince(started)))
            guard tap(Self.cardText, "the text on the card, again", counted: false) else { return false }
            guard waitText(starting: "Varv 1", 20) || lapAtLeast(1) != nil else { return miss("two taps on the card's text did not open the player with 'Varv 1'") }
        }
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

    /// Hides the keyboard without typing into the field: a tap on the screen's title area.
    /// Run 44439180352 (AX5): `app.keyboards` was empty while the keyboard's keys (skift, retur) stood in the tree and
    /// covered Spela. Look for the keys too.
    private var keyboardUp: Bool {
        if app.keyboards.count > 0 { return true }
        // Run 44444292610: neither app.keyboards nor app.buttons["retur"] saw the keys, but the tree did.
        let keys = Self.labels(in: app.debugDescription, kind: "Button")
        return keys.contains("retur") || keys.contains("skift") || keys.contains("return")
    }

    private func hideKeyboard() {
        guard keyboardUp else { return }
        for attempt in 0..<3 {
            switch attempt {
            case 0:
                // A text that is not a control: "Kom förberedd till provet" stands under the card.
                let plain = app.staticTexts["Kom förberedd till provet"].firstMatch
                if plain.exists, plain.isHittable { plain.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07)).tap() }
            case 1: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07)).tap()
            default: app.swipeDown(velocity: .slow)
            }
            testTaps += 1
            pause(1)
            if !keyboardUp { break }
        }
        log.append("keyboard hidden: \(!keyboardUp)")
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
    /// Angela Fable 02:10 (run 44430660402): since Ke79 a capsule reads the whole text (", <stil eller röst>" after
    /// it), not "Klorofyllet i bladen få…". While a text plays the card's own text button has the same label, so one
    /// is taken away then.
    private func recentCapsules() -> [String] {
        var all = Self.labels(in: app.debugDescription, kind: "Button").filter { $0.hasPrefix("Klorofyllet") }
        if timeLeft() != nil || text(starting: "Gör ljudet") != nil || text(starting: "Spelar i AirPods") != nil,
           let card = all.firstIndex(of: Self.text) { all.remove(at: card) }
        return all
    }

    /// Run 44163010444: the deletes did nothing (110 characters after "clearing" 78): a tap puts the cursor where it lands.
    /// Put it at the end first (bottom right of the field), then delete; check, and say so if text is left.
    private func clearField() {
        guard field.exists else { return }
        let value = (field.value as? String) ?? ""
        guard value.contains("Klorofyllet") || value.contains("Bladen") || value.contains("Långsamt") || value.localizedCaseInsensitiveContains("example") else { return }
        guard focusField("Säg i AirPods (to clear it)", counted: false) else { return }
        for _ in 0..<2 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.95)).tap(); testTaps += 1
            pause(0.5)
            let now = (field.value as? String) ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: now.count + 5))
            pause(1)
            let left = (field.value as? String) ?? ""
            if !(left.contains("Klorofyllet") || left.contains("Bladen") || left.contains("Långsamt") || left.localizedCaseInsensitiveContains("example")) { return }
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
        pause(3)
        let afterPlay = creditsLeft()
        log.append("T44 capsule: \(creditsAtStart.map(String.init) ?? "-") before the first Spela of a new text, \(afterPlay.map(String.init) ?? "-") after Stoppa")
        if let a = creditsAtStart, let b = afterPlay, b >= a { note("T44: the capsule did not go down after a new text (\(a) → \(b))") }
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

    /// T49 (D219, A135): sound that is on the phone plays without asking the server. With the network off, the text
    /// that was played before (put back from Senaste) plays at once; a new text shows the spinner at most 10 s and then
    /// "Ljudet kunde inte hämtas. Kontrollera nätet och försök igen." and the button "Försök igen". Senaste shows
    /// every text once.
    private func offlineSay() -> Bool {
        goToStart()
        guard network(on: false) else { return false }
        defer { _ = network(on: true); goToStart() }
        var ok = true
        clearField()
        guard let capsule = recentCapsules().first else { return miss("no capsule in Senaste to play offline") }
        guard tap([capsule], "the capsule in Senaste (offline)") else { return false }
        pause(1)
        let t0 = Date()
        guard tap(Self.playLabels, "Spela i … (offline, a played text)") else { return false }
        var plays = false
        let end = Date().addingTimeInterval(15)
        repeat { plays = text(starting: "Spelar i AirPods") != nil || timeLeft() != nil; if !plays { pause(0.5) } } while !plays && Date() < end
        log.append(String(format: "T49 the played text offline: playing %@ after %.1f s", plays ? "yes" : "no", Date().timeIntervalSince(t0)))
        screen("utan-nat-samma", "Offline: the text that was played before")
        if !plays { ok = miss("offline, the text that was played before did not play in 15 s") }
        answerReminder()
        stopOnCard()
        clearField()
        // A new text: no sound on the phone, so the server is needed.
        let fresh = "Ny text utan nät \(Int(Date().timeIntervalSince1970) % 100000). Bladen är gröna."
        guard focusField("Säg i AirPods (a new text, offline)") else { return miss("the field got no keyboard") }
        field.typeText(fresh)
        pause(1)
        // Angela Fable 00:15: log the button before the press; the keyboard is hidden first so the tap reaches Spela.
        hideKeyboard()
        if let play = find(Self.playLabels) { log.append("T49 Spela before the press offline: '\(play.label)', enabled \(play.isEnabled), hittable \(play.isHittable)") }
        let t1 = Date()
        guard tap(Self.playLabels, "Spela i … (offline, a new text)") else { return false }
        var said: String?
        let end2 = Date().addingTimeInterval(25)
        // Run 44230731193: when the phone knows it is offline the line is "Ingen internetanslutning. Försök igen när du är
        // uppkopplad." at once (and the button stays Spela); "Ljudet kunde inte hämtas …" + Försök igen is for a network
        // that is there but does not answer. Either says what is wrong; Försök igen is required only with the second.
        repeat { said = text(starting: "Ljudet kunde inte hämtas") ?? text(starting: "Ingen internetanslutning"); if said == nil { pause(0.5) } } while said == nil && Date() < end2
        let waited = Date().timeIntervalSince(t1)
        log.append(String(format: "T49 a new text offline: '%@' after %.1f s, Försök igen: %@", said ?? "-", waited, find(["Försök igen"]) != nil ? "yes" : "no"))
        screen("utan-nat-ny", "Offline: a new text")
        if said == nil { ok = miss("offline, a new text gave no line ('Ljudet kunde inte hämtas …' or 'Ingen internetanslutning …') in 25 s") }
        else if waited > 14 { note(String(format: "the line came after %.0f s (A135: at most 10 s)", waited)) }
        if said?.hasPrefix("Ljudet kunde inte hämtas") == true, find(["Försök igen"]) == nil { ok = miss("no 'Försök igen' button after the line") }
        if text(starting: "Spelar i AirPods") != nil { ok = miss("a new text played offline (there should be no sound for it)") }
        clearField()
        let capsules = recentCapsules()
        log.append("T49 Senaste after the offline tries: \(capsules)")
        if capsules.count > 1 { ok = miss("Senaste shows the text \(capsules.count) times (A135: once)") }
        return ok
    }

    /// D225/A144 with fake times: `x-earmind-test: slow` keeps the drill files pending (K64), so a new text never gets
    /// its sound. After 8 s "Det tar längre tid än vanligt." stands while the spinner goes on; only after 25 s comes
    /// "Ljudet kunde inte hämtas." with Försök igen. The app is relaunched with LUMEN_TEST_HEADER=slow and back after.
    private func slowSound() -> Bool {
        launch("slow")
        defer { launch(header); _ = wait(["Nytt prov"], 15) }
        guard wait(["Nytt prov"], 20) != nil else { return miss("Start not shown after the relaunch with slow") }
        var ok = true
        clearField()
        let slowText = "Långsamt ljud \(Int(Date().timeIntervalSince1970) % 1_000_000). Rötterna tar upp vatten."
        guard focusField("Säg i AirPods (slow)") else { return miss("the field got no keyboard") }
        field.typeText(slowText)
        pause(1.5)
        guard tap(Self.playLabels, "Spela i … (slow)") else { return false }
        let t0 = Date()
        var slowAt: Double?
        var failAt: Double?
        var playedAt: Double?
        while Date().timeIntervalSince(t0) < 45, failAt == nil {
            let now = Date().timeIntervalSince(t0)
            if slowAt == nil, text(starting: "Det tar längre tid än vanligt") != nil { slowAt = now }
            if text(starting: "Ljudet kunde inte hämtas") != nil { failAt = now }
            if playedAt == nil, text(starting: "Spelar i AirPods") != nil { playedAt = now }
            pause(0.5)
        }
        let retry = find(["Försök igen"]) != nil
        log.append(String(format: "A144 slow: 'Det tar längre tid än vanligt.' at %@ s, 'Ljudet kunde inte hämtas.' at %@ s, Försök igen %@, playing %@",
                          slowAt.map { String(format: "%.1f", $0) } ?? "-", failAt.map { String(format: "%.1f", $0) } ?? "-",
                          retry ? "yes" : "no", playedAt.map { String(format: "at %.1f s", $0) } ?? "no"))
        let waitingCard = text(starting: "Gör ljudet") != nil
        log.append("A144 slow: the card shows 'Gör ljudet …' while waiting: \(waitingCard), \(timeLeft() ?? "-")")
        screen("langsamt", "Slow sound: after the wait")
        if let a = slowAt { if a < 6 || a > 12 { ok = miss(String(format: "'Det tar längre tid än vanligt.' came after %.1f s (A144: 8 s)", a)) } }
        else { ok = miss("no 'Det tar längre tid än vanligt.' in 45 s") }
        if let b = failAt { if b < 22 || b > 32 { ok = miss(String(format: "'Ljudet kunde inte hämtas.' came after %.1f s (A144: 25 s)", b)) } }
        else { ok = miss("no 'Ljudet kunde inte hämtas.' in 45 s") }
        if failAt != nil, !retry { ok = miss("no Försök igen with 'Ljudet kunde inte hämtas.'") }
        // Run 44283940066: with K100 the card goes to its playing state ("Gör ljudet …", the time counting down) and
        // the field is gone, so stop first.
        stopOnCard()
        if field.exists { clearField() }
        return ok
    }

    /// T50 (D220, A136/A140): with text in the field the card has the style row "Hur ska det låta?" (four suggestions
    /// above the keyboard), the voice capsule only when the server has a catalogue, and "Skriv i takt" first in the
    /// tempo menu (capsule "I takt"). A style asks the cost again. Played with fake audio; the app logs the pauses as
    /// "Reading: pace: N words, pause X s" (t36.sh prints them). 0 ElevenLabs.
    private func styleAndPace() -> Bool {
        goToStart()
        var ok = true
        if !((field.value as? String) ?? "").contains("Klorofyllet") { clearField(); retype() }
        let styleField = app.textFields.matching(NSPredicate(format: "label ==[c] 'Hur ska det låta?'")).firstMatch
        guard styleField.waitForExistence(timeout: 8) else { screen("utan-stil", "No style row"); return miss("no 'Hur ska det låta?' with text in the field") }
        let voice = find(["Röst, *"])
        log.append("T50 voice capsule: \(voice?.label ?? "none (no catalogue from /voices)")")
        let costBefore = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.contains("krediter") && !$0.contains("kvar") }
        tapElement(styleField, "Hur ska det låta?")
        pause(1.5)
        let suggestions = ["Tydligt", "Lugnt", "Glatt", "Viskande"]
        let seen = suggestions.filter { app.buttons.matching(NSPredicate(format: "label ==[c] %@", $0)).firstMatch.exists }
        log.append("T50 suggestions above the keyboard: \(seen.isEmpty ? "none" : seen.joined(separator: ", "))")
        screen("stil-forslag", "The style row with its suggestions (A136)")
        if seen.count < 4 { ok = miss("the suggestions above the keyboard are not all there (\(seen))") }
        if seen.contains("Lugnt") { tap(["Lugnt"], "Lugnt (suggestion)") } else { styleField.typeText("Lugnt") }
        pause(2) // the cost is asked again with the style (about 0,7 s after the last key)
        let styleValue = (styleField.value as? String) ?? ""
        let costAfter = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.contains("krediter") && !$0.contains("kvar") }
        log.append("T50 style: '\(styleValue)', cost before \(costBefore ?? "-"), after \(costAfter ?? "-")")
        if !styleValue.contains("Lugnt") { ok = miss("the suggestion did not write 'Lugnt' in the style row") }
        if costAfter == nil { note("no cost by Spela with a style") }
        // Skriv i takt, first in the tempo menu.
        if app.keyboards.count > 0 { app.swipeDown(velocity: .slow); pause(1) }
        guard tap(["Tempo*"], "Tempo") else { return false }
        pause(1)
        let paceFirst = find(["Skriv i takt"]) != nil
        screen("tempo-meny", "The tempo menu with Skriv i takt")
        guard paceFirst, tap(["Skriv i takt"], "Skriv i takt") else { closeMenu(); return miss("no 'Skriv i takt' in the tempo menu") }
        pause(1)
        let tempoLabel = find(["Tempo*"])?.label ?? "-"
        log.append("T50 tempo after Skriv i takt: \(tempoLabel)")
        if tempoLabel != "Tempo, Skriv i takt" { ok = miss("the tempo capsule is '\(tempoLabel)', not 'Tempo, Skriv i takt'") }
        mark("PACE-PLAY start")
        guard playFromCard() else { return false }
        answerReminder()
        pause(25)
        screen("i-takt-spelar", "Playing in pace (I takt)")
        let playing = text(starting: "Spelar i AirPods") ?? "-"
        log.append("T50 playing in pace: \(playing), \(timeLeft() ?? "-")")
        mark("PACE-PLAY end")
        stopOnCard()
        // Back to 1,0× and no style, for the sections after this one.
        if tap(["Tempo*"], "Tempo (back)", counted: false) { pause(1); tap(["1,0×"], "1,0×", counted: false, quiet: true); pause(1) }
        if styleField.exists, !((styleField.value as? String) ?? "").isEmpty, styleField.value as? String != "Hur ska det låta?" {
            tapElement(styleField, "Hur ska det låta? (clear)", counted: false)
            styleField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
            if app.keyboards.count > 0 { app.swipeDown(velocity: .slow) }
        }
        log.append("T50 Senaste after a text with a style: \(Self.labels(in: app.debugDescription, kind: "Button").filter { $0.hasPrefix("Klorofyllet") })")
        return ok
    }

    /// T48 (D218, D224, A134/A141): a tap on the capsule opens Krediter with Fyll på (100, 500, 2 000, Bäst värde),
    /// Varje vecka (Veckokort), Bjud in and Villkor · Integritet · Återställ köp. With the scheme's StoreKit file
    /// (StoreKit testing, never a real purchase) a cancelled purchase changes nothing, and a made one is refused by the
    /// server (a local transaction), so the line says the purchase could not be put in and the capsule stays.
    private func shopSheet() -> Bool {
        goToStart()
        pause(2)
        let before = creditsLeft()
        let capsule = Self.labels(in: app.debugDescription, kind: "Button").first { $0.contains("krediter kvar") || $0.contains("kredit kvar") }
        guard let capsule, tap([capsule], "the credit capsule") else { return miss("no credit capsule on Start") }
        return shopSheetOpen(before: before)
    }

    private func shopSheetOpen(before: Int?) -> Bool {
        // Run 44300125934: after 3 s neither the products nor Fable's line were there; StoreKit may take longer. Wait
        // up to 15 s for one of them.
        let shopEnd = Date().addingTimeInterval(15)
        repeat {
            let t = app.debugDescription
            if t.contains("Paketen kunde inte hämtas") || t.contains("label: 'Köp ") { break }
            pause(1)
        } while Date() < shopEnd
        var ok = true
        let tree = app.debugDescription
        let all = (Self.labels(in: tree, kind: "StaticText") + Self.labels(in: tree, kind: "Button") + Self.labels(in: tree, kind: "Link"))
            .map { $0.replacingOccurrences(of: "\u{00A0}", with: " ") }
        let want = ["Fyll på", "100 krediter", "500 krediter", "2 000 krediter", "Bäst värde", "Ett prov ≈ 6 000 krediter.",
                    "Varje vecka", "Veckokort", "Bjud in", "Få 2 000 krediter", "Villkor", "Integritet", "Återställ köp"]
        let missing = want.filter { w in !all.contains { $0.localizedCaseInsensitiveContains(w) } }
        let buys = all.filter { $0.hasPrefix("Köp ") }
        log.append("T48 Krediter: missing \(missing.isEmpty ? "none" : missing.joined(separator: ", ")); buy buttons \(buys)")
        screen("krediter-blad", "Krediter with Fyll på, Varje vecka, Bjud in (A134)")
        // Run 44253148974: without products from App Store (the StoreKit file does not reach a UI test: xcodebuild
        // takes it only from a test plan) Fyll på and Varje vecka are left out. Only the rest is required here.
        let needsProducts = ["Fyll på", "100 krediter", "500 krediter", "2 000 krediter", "Bäst värde", "Ett prov ≈ 6 000 krediter.", "Varje vecka", "Veckokort"]
        let hard = missing.filter { !needsProducts.contains($0) }
        if !hard.isEmpty { ok = miss("Krediter lacks \(hard.joined(separator: ", "))") }
        if buys.isEmpty, !missing.isEmpty { note("no products in Krediter, so Fyll på and Varje vecka are not there (\(missing.joined(separator: ", ")))") }
        // Angela Fable 09:28 (T48): without products Fyll på stays with "Paketen kunde inte hämtas från App Store just nu."
        // and Försök igen.
        if buys.isEmpty {
            let said = all.first { $0.hasPrefix("Paketen kunde inte hämtas") }
            log.append("T48 without products: \(said ?? "no line")")
            if said == nil { ok = miss("no products and no 'Paketen kunde inte hämtas från App Store just nu.' in Krediter") }
        }
        // Återställ köp: no purchases on this Simulator.
        if tap(["Återställ köp"], "Återställ köp") {
            var line: String?
            let end = Date().addingTimeInterval(20)
            repeat { line = text(starting: "Det fanns inga köp") ?? text(starting: "Det gick inte att hämta köpen"); if line == nil { pause(1) } } while line == nil && Date() < end
            log.append("T48 Återställ köp: \(line ?? "no line in 20 s")")
            // Angela Fable 09:28: Återställ köp always answers, after at most 15 s.
            if line == nil { ok = miss("Återställ köp gave no line in 20 s (A134 after T48: at most 15 s)") }
        }
        // A test purchase, only when the products came from the StoreKit file.
        guard let buy = buys.first(where: { $0.contains("100 krediter") }) ?? buys.first else {
            note("no prices in Krediter (the StoreKit file did not reach the app): no test purchase")
            dismissCredits()
            return ok
        }
        // 1. Cancelled.
        guard tap([buy], "\(buy) (to cancel)") else { closeSheet(); return false }
        let cancelled = storeSheet(confirm: false)
        pause(3)
        let lineAfterCancel = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Köpet") }
        log.append("T48 cancelled purchase: sheet \(cancelled), line \(lineAfterCancel ?? "none")")
        if lineAfterCancel != nil { ok = miss("a cancelled purchase said '\(lineAfterCancel!)' (A134: it says nothing)") }
        // 2. Made: the server refuses a local transaction.
        guard tap([buy], "\(buy)") else { closeSheet(); return false }
        let made = storeSheet(confirm: true)
        var line: String?
        let end = Date().addingTimeInterval(40)
        repeat { line = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Köpet") }; if line == nil { pause(1) } } while line == nil && Date() < end
        log.append("T48 test purchase: sheet \(made), line \(line ?? "none in 40 s")")
        screen("krediter-kop", "After a StoreKit test purchase")
        if made, line == nil { note("no line after a test purchase in 40 s") }
        closeSheet()
        goToStart()
        pause(3)
        let after = creditsLeft()
        log.append("T48 capsule: \(before.map(String.init) ?? "-") before, \(after.map(String.init) ?? "-") after the test purchase")
        if let before, let after, after > before { note("the capsule went up after a test purchase (\(before) → \(after)); the server took a local transaction") }
        return ok
    }

    /// Run 44294585063: after Återställ köp the Krediter sheet stayed open through "Klar" and twelve "back to Start"
    /// taps. Tap Klar in its bar, check, then drag it down; say which one closed it.
    private func dismissCredits() {
        let open = { Self.labels(in: self.app.debugDescription, kind: "StaticText").contains("Så räknas det") }
        guard open() else { return }
        let klar = app.navigationBars.buttons.matching(NSPredicate(format: "label ==[c] 'Klar'")).firstMatch
        if klar.exists { tapElement(klar, "Klar (Krediter)", counted: false); pause(1.5) }
        if !open() { log.append("T48 Krediter closed with Klar"); return }
        log.append("T48 Krediter still open after Klar (\(klar.exists ? "hittable \(klar.isHittable)" : "no Klar in the bar")); dragging it down")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        testTaps += 1
        pause(1.5)
        log.append("T48 Krediter after the drag: \(open() ? "still open" : "closed")")
        if open() { note("the Krediter sheet did not close with Klar or a drag") }
    }

    /// The StoreKit test sheet (in the app or over it). Confirms or cancels it; false when no sheet came.
    private func storeSheet(confirm: Bool) -> Bool {
        let yes = ["Köp", "Purchase", "Buy", "Bekräfta", "Confirm", "Prenumerera", "Subscribe"]
        let no = ["Avbryt", "Cancel", "Stäng", "Close"]
        let end = Date().addingTimeInterval(20)
        repeat {
            for host in [app!, springboard!] {
                for label in (confirm ? yes : no) {
                    let b = host.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).allElementsBoundByIndex.first { $0.exists && $0.isHittable }
                    if let b { b.tap(); testTaps += 1; log.append("T48 store sheet: tapped \(label)"); pause(2)
                        if confirm, let ok = ["OK", "Okej"].lazy.compactMap({ l in host.buttons.matching(NSPredicate(format: "label ==[c] %@", l)).allElementsBoundByIndex.first { $0.exists && $0.isHittable } }).first { ok.tap(); testTaps += 1 }
                        return true }
                }
            }
            pause(1)
        } while Date() < end
        log.append("T48 store sheet: none seen (\(confirm ? "confirm" : "cancel"))")
        return false
    }

    /// A145 (K101): Inställningar › Konto › Radera konto deletes the account on the server for real. The test account
    /// is the one this Simulator made at its first start, made only for this run. Avbryt does nothing; offline the line
    /// says nothing is deleted; then the deletion: the app starts over with Välkommen and "Kontot är raderat", and no
    /// exam or said text is left.
    private func deleteAccount() -> Bool {
        goToStart()
        pause(2)
        var ok = true
        let before = recentCapsules().count
        log.append("A145 before: \(before) capsule(s) in Senaste, credits \(creditsLeft().map(String.init) ?? "-")")
        guard openAccount() else { return false }
        // 1. Avbryt.
        guard askDelete() else { return false }
        tapAlert("Avbryt")
        pause(2)
        let stillThere = find(["Radera konto"]) != nil
        log.append("A145 Avbryt: still in Inställningar \(stillThere)")
        if !stillThere { ok = miss("after Avbryt the account part is gone") }
        // 2. Offline: nothing is deleted.
        guard network(on: false) else { return false }
        if askDelete() {
            tapAlert("Radera konto")
            var line: String?
            let end = Date().addingTimeInterval(20)
            repeat { line = text(starting: "Det gick inte att radera kontot"); if line == nil { pause(1) } } while line == nil && Date() < end
            log.append("A145 offline: \(line ?? "no line in 20 s")")
            screen("radera-utan-nat", "Radera konto offline")
            if line?.contains("Inget är raderat") != true { ok = miss("offline the line does not say that nothing is deleted ('\(line ?? "-")')") }
        } else { ok = false }
        _ = network(on: true)
        goToStart()
        pause(2)
        let afterOffline = recentCapsules().count
        log.append("A145 after the offline try: \(afterOffline) capsule(s)")
        if afterOffline < before { ok = miss("an offline try removed texts (\(before) → \(afterOffline))") }
        // 3. Delete.
        guard openAccount(), askDelete() else { return false }
        tapAlert("Radera konto")
        var done: String?
        let end = Date().addingTimeInterval(45)
        repeat { done = text(starting: "Kontot är raderat") ?? (find(["Välkommen till EarMind"]) != nil ? "Välkommen till EarMind" : nil); if done == nil { pause(1) } } while done == nil && Date() < end
        pause(2)
        let box = text(starting: "Kontot är raderat") != nil
        let welcome = find(["Välkommen till EarMind"]) != nil
        log.append("A145 after Radera konto: 'Kontot är raderat' \(box), Välkommen \(welcome), \(text(starting: "EarMind börjar om") ?? "-")")
        screen("raderat", "After Radera konto")
        if !box { ok = miss("no 'Kontot är raderat' after the deletion") }
        if !welcome { ok = miss("the app did not start over with Välkommen") }
        for label in ["OK", "Okej", "Stäng", "Fortsätt"] where text(starting: "Kontot är raderat") != nil {
            if let b = app.alerts.firstMatch.buttons[label].exists ? app.alerts.firstMatch.buttons[label] : nil { b.tap(); testTaps += 1; pause(1) }
        }
        if welcome { _ = firstStart() }
        pause(3)
        let left = recentCapsules().count
        let examHeads = Self.labels(in: app.debugDescription, kind: "StaticText").filter { ["nästa prov", "andra prov", "senaste"].contains($0.lowercased()) }
        log.append("A145 Start afterwards: \(left) capsule(s), headings \(examHeads), credits \(creditsLeft().map(String.init) ?? "-")")
        screen("efter-radering", "Start after the deletion")
        if left > 0 || !examHeads.isEmpty { ok = miss("texts or exams are left after the deletion (\(left) capsules, \(examHeads))") }
        return ok
    }

    private func openAccount() -> Bool {
        dismissCredits()
        goToStart()
        guard tap(["Inställningar"], "Inställningar") else { return false }
        pause(1.5)
        // Run 44300125934: Konto is the last part of Inställningar, and the list makes it only when it is scrolled to.
        // Run 44698563479 (SE, AX5): the 10th swipe brought Radera konto up and the loop did not look again. Look after
        // every swipe, at most 16.
        for n in 0...16 {
            if app.buttons.matching(NSPredicate(format: "label ==[c] 'Radera konto'")).firstMatch.exists {
                if n > 0 { log.append("A145 Radera konto after \(n) swipes in Inställningar") }
                return true
            }
            if n == 16 { break }
            app.swipeUp(velocity: .fast)
            pause(0.7)
        }
        screen("installningar-utan-konto", "Inställningar without Radera konto")
        return miss("no 'Radera konto' in Inställningar after 16 swipes")
    }

    private func askDelete() -> Bool {
        // Run 44424970760 (AX5): found by openAccount but gone a moment later; look again for 5 s and scroll.
        var button: XCUIElement?
        let end = Date().addingTimeInterval(20)
        var up = true
        var tries = 0
        repeat {
            button = app.buttons.matching(NSPredicate(format: "label ==[c] 'Radera konto'")).allElementsBoundByIndex.first { $0.exists }
            if button == nil {
                // Run 44433667156: the audit scrolls the list while it walks it; look both ways.
                if up { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
                tries += 1
                if tries % 6 == 0 { up.toggle() }
                pause(0.7)
            }
        } while button == nil && Date() < end
        guard let button else { return miss("no 'Radera konto' button") }
        var swipes = 0
        while !button.isHittable, swipes < 6 { app.swipeUp(); swipes += 1 }
        tapElement(button, "Radera konto")
        guard app.alerts.firstMatch.waitForExistence(timeout: 5) else { return miss("no 'Radera kontot?' question") }
        log.append("A145 question: \(app.alerts.firstMatch.label)")
        return true
    }

    private func tapAlert(_ label: String) {
        let button = app.alerts.firstMatch.buttons[label]
        if button.exists { tapElement(button, "\(label) (Radera kontot?)") } else { log.append("MISS: no '\(label)' in the question") }
    }

    // MARK: T55 – the reviewer's way (D238)

    private var creditTrail: [(String, Int?)] = []
    static let reviewMaterial = "Fotosyntes\nVäxter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas som en restprodukt och släpps ut genom klyvöppningarna. Socker används som energi eller lagras som stärkelse i rötter och frön."

    /// The exact number in Krediter ("1 500, krediter kvar"), not the short capsule ("1,5k").
    private func exactCredits(_ when: String) -> Int? {
        goToStart()
        pause(2)
        let capsule = Self.labels(in: app.debugDescription, kind: "Button").first { $0.contains("krediter kvar") || $0.contains("kredit kvar") }
        guard let capsule, tap([capsule], "the credit capsule (\(when))", counted: false) else { creditTrail.append((when, nil)); return nil }
        pause(3)
        let line = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasSuffix("krediter kvar") && $0.first?.isNumber == true }
        let n = line.flatMap { Self.creditNumber($0) }
        log.append("T55 credits \(when): \(line ?? "-") → \(n.map(String.init) ?? "-")")
        creditTrail.append((when, n))
        dismissCredits()
        goToStart()
        return n
    }

    private func reviewWelcome() -> Bool {
        guard wait(["Välkommen till EarMind"], 25) != nil else { return miss("Välkommen not shown") }
        pause(1)
        screen("granskare-valkommen", "Välkommen on a new installation")
        guard tap(["Fortsätt"], "Fortsätt") else { return false }
        pause(1.5)
        screen("granskare-efter-fortsatt", "After Fortsätt (notification question?)")
        if wait(["Senare"], 8) != nil { tap(["Senare"], "Senare") }
        pause(2)
        systemAlerts()
        goToStart()
        screen("granskare-start", "Start, first time")
        _ = exactCredits("at the first Start")
        return atStart() || miss("Start not shown")
    }

    private func reviewSay() -> Bool {
        goToStart()
        guard focusField("Säg i AirPods (reviewer)") else { return miss("the field got no keyboard") }
        field.typeText(Self.text)
        pause(2)
        let cost = (Self.labels(in: app.debugDescription, kind: "StaticText") + Self.labels(in: app.debugDescription, kind: "Button")).first { $0.hasPrefix("Kostar ") || ($0.contains("krediter") && !$0.contains("kvar")) }
        log.append("T55 Säg: the cost before Spela: \(cost ?? "-")")
        hideKeyboard()
        screen("granskare-sag-text", "Säg i AirPods with a text")
        guard playFromCard() else { return false }
        pause(6)
        screen("granskare-spelar", "The text plays on the card")
        stopOnCard()
        goToStart()
        _ = exactCredits("after the first Säg text")
        return true
    }

    private func reviewExam() -> Bool {
        // The reviewer would type or photograph the material; LUMEN_TEST_MATERIAL (Debug) puts the same kind of text in
        // Nytt prov, since XCUITest cannot type into Skriv text (T21, T28).
        // Angela Fable 10:57 (K109): Actions runs with the plain test header skip the server's estimate, so the exam
        // was made although the credits did not cover it. "user-path" asks for what a user gets (the estimate and its
        // 402); it is still a test call with fake audio (D180).
        launch("user-path", material: Self.reviewMaterial)
        log.append("T55 exam: relaunched with x-earmind-test user-path (the user's path, K109)")
        _ = wait(["Inställningar"], 20)
        goToStart()
        guard tap(["Nytt prov"], "Nytt prov") else { return false }
        guard wait(["Skapa frågor", "Frågor"], 20) != nil else { screen("granskare-inget-prov", "No Nytt prov with the text"); return miss("Nytt prov did not open with the text") }
        if find(["Frågor"]) != nil { tap(["Frågor"], "Gör: Frågor", counted: false, quiet: true) }
        pause(1)
        screen("granskare-nytt-prov", "Nytt prov with the text")
        // Angela Fable 17:22: Nytt prov reads the price per question from /drill quota, so with too few credits the
        // box ("Ett prov med 3 frågor kostar cirka …" + Fyll på, or "Krediterna räcker till N frågor.") stands as soon
        // as the quota is read, before Skapa frågor. Wait for it a few seconds before tapping anything.
        var atOpen: String?
        let openEnd = Date().addingTimeInterval(8)
        repeat {
            atOpen = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Ett prov med") || $0.hasPrefix("Krediterna räcker") }
            if atOpen == nil { pause(1) }
        } while atOpen == nil && Date() < openEnd
        let made = Date()
        if let atOpen {
            log.append("T55 exam (A154, at open): '\(atOpen)' before Skapa frågor")
        } else {
            log.append("T55 exam: no credit box when Nytt prov opened (8 s)")
            guard waitEnabled(["Skapa frågor"], 15), tap(["Skapa frågor"], "Skapa frågor") else { return miss("Skapa frågor not tappable") }
        }
        // A154 (Angela Fable 2026-11-20 09:05, K109): with too few credits the server answers 402 before the questions
        // are made. Nytt prov comes back with "Ett prov med 3 frågor kostar cirka … Du har …", Fyll på, and "Krediterna
        // räcker inte till ett prov." under the switched-off Skapa frågor; or "Krediterna räcker till N frågor." and the
        // bottom button "Skapa N frågor".
        guard wait(["Ser rätt ut", "Spara frågorna", "Hittade*", "Krediterna räcker*"], 180) != nil else { screen("granskare-inga-fragor", "No questions"); return miss("no questions in 180 s") }
        let short = Self.labels(in: app.debugDescription, kind: "StaticText").filter { $0.contains("räcker") || $0.hasPrefix("Ett prov med") }
        if !short.isEmpty, find(["Ser rätt ut", "Spara frågorna"]) == nil {
            log.append(String(format: "T55 exam (A154): after %.0f s the form says %@", Date().timeIntervalSince(made), short.joined(separator: " | ")))
            screen("granskare-racker-inte", "Nytt prov: the credits are not enough (A154)")
            let skapa = find(["Skapa frågor"])
            log.append("T55 exam (A154): Skapa frågor enabled \(skapa?.isEnabled.description ?? "-"), Fyll på \(find(["Fyll på"]) != nil), Skapa N \(Self.labels(in: app.debugDescription, kind: "Button").first { $0.hasPrefix("Skapa ") && $0.hasSuffix(" frågor") && $0 != "Skapa frågor" } ?? "-")")
            if let fewer = Self.labels(in: app.debugDescription, kind: "Button").first(where: { $0.hasPrefix("Skapa ") && $0.hasSuffix(" frågor") && $0 != "Skapa frågor" }) {
                guard tap([fewer], fewer) else { return miss("'\(fewer)' not tappable") }
                guard wait(["Ser rätt ut", "Spara frågorna", "Hittade*"], 180) != nil else { screen("granskare-inga-fragor", "No questions"); return miss("no questions in 180 s after '\(fewer)'") }
            } else {
                var ok = true
                if skapa?.isEnabled == true { ok = miss("Skapa frågor is still enabled with too few credits (A154: off)") }
                guard tap(["Fyll på"], "Fyll på (A154)") else { return miss("no Fyll på with too few credits (A154)") }
                let end = Date().addingTimeInterval(15)
                repeat { if app.debugDescription.contains("Paketen kunde inte hämtas") || app.debugDescription.contains("label: 'Köp ") || app.debugDescription.contains("Så räknas det") { break }; pause(1) } while Date() < end
                let sheet = app.debugDescription.contains("Så räknas det") || app.debugDescription.contains("Paketen kunde inte hämtas")
                log.append("T55 exam (A154): Fyll på opened Krediter: \(sheet)")
                screen("granskare-fyll-pa", "Fyll på from Nytt prov (A154)")
                if !sheet { ok = miss("Fyll på did not open Krediter (A154)") }
                dismissCredits()
                pause(1)
                if find(["Avbryt", "Stäng"]) != nil { tap(["Avbryt", "Stäng"], "close Nytt prov", counted: false, quiet: true) }
                goToStart()
                _ = exactCredits("after the exam that did not fit (A154)")
                return ok
            }
        }
        log.append(String(format: "T55 exam: questions after %.0f s", Date().timeIntervalSince(made)))
        screen("granskare-fragor", "The questions made from the text")
        let questions = Self.labels(in: app.debugDescription, kind: "StaticText").filter { $0.hasSuffix("?") }.count
        log.append("T55 exam: \(questions) questions on Stämmer det här?")
        if find(["Ser rätt ut"]) != nil { tap(["Ser rätt ut"], "Ser rätt ut") } else { tap(["Spara frågorna"], "Spara frågorna") }
        // A154: at Ser rätt ut the app asks the server's cost first; when the credits do not cover it the exam is not
        // saved and "Det här kostar … Du har … kvar." stands with Fyll på (run 44704162235 went to Start past it).
        var costLine: String?
        let costEnd = Date().addingTimeInterval(15)
        repeat {
            costLine = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Det här kostar") || $0.contains("räcker inte") || $0.hasPrefix("Ett prov med") }
            if costLine == nil { pause(1) }
        } while costLine == nil && Date() < costEnd
        // NewDrillView puts the line in a section under the questions and does not scroll to it (run 44708423048: not
        // in the tree after 15 s). Is it below the fold? Screen first, then scroll down and count.
        var costSwipes = 0
        if costLine == nil {
            screen("granskare-ser-ratt-ut-15s", "15 s after Ser rätt ut, before any scroll")
            while costLine == nil, costSwipes < 6, find(["Ser rätt ut"]) != nil {
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.7))
                from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.3)))
                costSwipes += 1
                pause(0.7)
                costLine = Self.labels(in: app.debugDescription, kind: "StaticText").first { $0.hasPrefix("Det här kostar") || $0.contains("räcker inte") }
            }
            log.append("T55 exam (A154): the cost line \(costLine == nil ? "not found" : "found") after \(costSwipes) drags down the questions")
        }
        if let costLine {
            if costSwipes > 0 { note("T55: after Ser rätt ut the line '\(costLine)' was below the fold (\(costSwipes) drags); nothing visible changed at the button") }
            log.append("T55 exam (A154) at Ser rätt ut: '\(costLine)', Fyll på \(find(["Fyll på"]) != nil)")
            screen("granskare-ser-ratt-ut-kostar", "Ser rätt ut: the credits do not cover the exam (A154)")
            note("T55: \(questions) questions were made and could not be saved: '\(costLine)'")
            guard tap(["Fyll på"], "Fyll på (A154, at Ser rätt ut)") else { return miss("no Fyll på with '\(costLine)'") }
            let end = Date().addingTimeInterval(15)
            repeat { if app.debugDescription.contains("Så räknas det") || app.debugDescription.contains("Paketen kunde inte hämtas") { break }; pause(1) } while Date() < end
            let sheet = app.debugDescription.contains("Så räknas det") || app.debugDescription.contains("Paketen kunde inte hämtas")
            log.append("T55 exam (A154): Fyll på at Ser rätt ut opened Krediter: \(sheet)")
            dismissCredits()
            pause(1)
            if find(["Avbryt"]) != nil { tap(["Avbryt"], "close Nytt prov", counted: false, quiet: true) }
            goToStart()
            _ = exactCredits("after the exam that could not be saved (A154)")
            return sheet || miss("Fyll på at Ser rätt ut did not open Krediter")
        }
        log.append("T55 exam: no cost line after Ser rätt ut (still on the questions: \(find(["Ser rätt ut"]) != nil))")
        pause(3)
        goToStart()
        screen("granskare-prov-pa-start", "The exam on Start")
        guard waitEnabled(["Starta prov"], 240) else { screen("granskare-ingen-start", "No Starta prov"); return miss("Starta prov not enabled in 240 s") }
        guard tap(["Starta prov"], "Starta prov") else { return false }
        if wait(["Styr med dina AirPods"], 5) != nil {
            for _ in 1...3 { if let skip = wait(["Hoppa över"], 10) { tapElement(skip, "Hoppa över (no AirPods)", counted: false) } }
            tap(["Starta ändå", "Starta prov"], "Start on the control check", quiet: true)
        }
        let end = Date().addingTimeInterval(120)
        var seen = false
        repeat { seen = text(starting: "Fråga 1") != nil || find(["Avsluta"]) != nil; if !seen { pause(2) } } while !seen && Date() < end
        pause(5)
        screen("granskare-provet-spelar", "The exam plays")
        if !seen { note("the exam's player did not show 'Fråga 1' or Avsluta in 120 s") }
        tap(["Avsluta"], "Avsluta", quiet: true)
        pause(2)
        goToStart()
        _ = exactCredits("after the exam from a text")
        return seen || miss("the exam did not start")
    }

    private func reviewCredits() -> Bool {
        goToStart()
        let capsule = Self.labels(in: app.debugDescription, kind: "Button").first { $0.contains("krediter kvar") || $0.contains("kredit kvar") }
        guard let capsule, tap([capsule], "the credit capsule (reviewer)") else { return miss("no credit capsule") }
        let end = Date().addingTimeInterval(15)
        repeat { if app.debugDescription.contains("Paketen kunde inte hämtas") || app.debugDescription.contains("label: 'Köp ") { break }; pause(1) } while Date() < end
        screen("granskare-krediter", "Krediter as a reviewer sees it")
        var ok = true
        for name in ["Villkor", "Integritet", "Återställ köp"] {
            var e = app.links.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch
            if !e.exists { e = app.buttons.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch }
            var swipes = 0
            while !(e.exists && e.isHittable), swipes < 6 { app.swipeUp(); swipes += 1 }
            log.append("T55 Krediter '\(name)': \(e.exists ? "there" : "missing")")
            if !e.exists { ok = miss("no '\(name)' in Krediter") }
        }
        let buys = Self.labels(in: app.debugDescription, kind: "Button").filter { $0.hasPrefix("Köp ") }
        log.append("T55 Krediter packages: \(buys.isEmpty ? (text(starting: "Paketen kunde inte hämtas") ?? "none") : buys.joined(separator: " | "))")
        if tap(["Återställ köp"], "Återställ köp") {
            var line: String?
            let stop = Date().addingTimeInterval(20)
            repeat { line = text(starting: "Det fanns inga köp") ?? text(starting: "Det gick inte att hämta köpen"); if line == nil { pause(1) } } while line == nil && Date() < stop
            log.append("T55 Återställ köp: \(line ?? "no line in 20 s")")
            if line == nil { ok = miss("Återställ köp gave no line in 20 s") }
        }
        screen("granskare-krediter-efter", "Krediter after Återställ köp")
        dismissCredits()
        return ok
    }

    // MARK: T53 – accessibility with the largest text (A148, Kelly Ke79)

    /// Xcode's accessibility audit of what is on screen; findings are written, never a failure (as A95's audit).
    private func audit(_ name: String) {
        var counts: [String: Int] = [:]
        var lines: [String] = []
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let type = Self.auditName(issue.auditType)
                counts[type, default: 0] += 1
                var line = "AUDIT \(name) [\(type)] \(issue.compactDescription)"
                if let e = issue.element, e.exists { line += " – \(e.elementType.rawValue) '\(e.label)' h=\(Int(e.frame.height))" }
                lines.append(line)
                return true
            }
        } catch { lines.append("AUDIT \(name): audit failed: \(error)") }
        log.append("T53 audit \(name): \(counts.isEmpty ? "no findings" : counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
        log.append(contentsOf: lines.prefix(25))
        screen("ax5-\(name)", "AX5: \(name)")
    }

    nonisolated private static func auditName(_ type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"), (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"), (.trait, "trait"),
        ]
        return names.first { type.contains($0.0) }?.1 ?? "type \(type.rawValue)"
    }

    /// A button's or field's VoiceOver label, read from the tree.
    private func label(of kind: String, starting prefix: String) -> String? {
        Self.labels(in: app.debugDescription, kind: kind).first { $0.hasPrefix(prefix) }
    }

    /// Ke79 points 2, 3 and 8, and the order of the first screen.
    private func a11yFirstScreen() -> Bool {
        goToStart()
        var ok = true
        guard focusField("Säg i AirPods (AX5)") else { return miss("the field got no keyboard") }
        field.typeText(Self.text)
        pause(2) // the cost comes about 0,7 s after the last key
        // T55 (2): the keyboard stays up (A153 gives Spela above it); a swipe here would hide it.
        log.append("T55 AX5 keyboard up after typing: \(keyboardUp)")
        let fieldLabel = field.label
        let cost = (Self.labels(in: app.debugDescription, kind: "StaticText") + Self.labels(in: app.debugDescription, kind: "Button")).first { $0.hasPrefix("Kostar ") }
        let tempo = label(of: "Button", starting: "Tempo") ?? "-"
        let howLong = label(of: "Button", starting: "Hur länge") ?? "-"
        let play = label(of: "Button", starting: "Spela") ?? "-"
        log.append("T53 field '\(fieldLabel)', cost '\(cost ?? "-")', tempo '\(tempo)', how long '\(howLong)', play '\(play)'")
        if fieldLabel != "Säg i AirPods" { ok = miss("the field reads '\(fieldLabel)' (Ke79 2: 'Säg i AirPods'; iOS adds 'textfält')") }
        if cost == nil { ok = miss("no cost read as 'Kostar N krediter' (Ke79 3)") }
        if tempo != "Tempo, normal" { ok = miss("tempo reads '\(tempo)' (Ke79 8: 'Tempo, normal')") }
        if !howLong.hasPrefix("Hur länge, ") { ok = miss("no 'Hur länge, …'") }
        // The "›" mark must not be read (Ke79 1): it is hidden, so it must not stand as a text of its own.
        if Self.labels(in: app.debugDescription, kind: "StaticText").contains("›") { note("'›' stands as a text in the tree (Ke79 1; Angela: hidden, the tree shows hidden elements)") }
        audit("start-text")
        return ok
    }

    /// Ke79 point 9: "Spelar i AirPods med <röst>, N minuter kvar" as one element.
    /// AX5 (run 44433667156): Spela stood below the screen and swipeUp moved the field, not the page. Drag the page
    /// from its lower part until the element can be tapped.
    private func scrollIntoView(_ labels: [String]) {
        for _ in 0..<8 {
            guard let e = find(labels) else { return }
            if e.isHittable { return }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.85))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.35)))
            pause(0.7)
        }
        if let e = find(labels) { log.append("scrollIntoView: '\(e.label)' hittable \(e.isHittable), frame \(NSCoder.string(for: e.frame))") }
    }

    private func a11yPlayingCard() -> Bool {
        // T55 (2), D238: no hideKeyboard() and no scrollIntoView (a drag on Start hides the keyboard, A153).
        let upBefore = keyboardUp
        log.append("T55 AX5 before Spela: keyboard up \(upBefore)")
        if !upBefore { note("T55: the keyboard was not up before Spela (it should still be up after typing)") }
        // Run 44436344437: Spela was never hittable at AX5. Write every match with its frame and the window, so it is
        // seen whether it is off the screen (and cannot be scrolled to) or covered.
        let window = app.windows.firstMatch.frame
        for b in app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Spela'")).allElementsBoundByIndex where b.exists {
            log.append("T53 Spela match '\(b.label)': frame \(NSCoder.string(for: b.frame)), hittable \(b.isHittable), enabled \(b.isEnabled), window \(NSCoder.string(for: window))")
        }
        screen("ax5-spela", "AX5: where Spela is")
        keepKeyboard = true
        let played = playFromCard()
        keepKeyboard = false
        log.append("T55 AX5 Spela reached with the keyboard up: \(played && upBefore), the test hid the keyboard: no")
        guard played else { return miss("T55: Spela could not be reached at AX5 without hiding the keyboard") }
        pause(4)
        let all = Self.labels(in: app.debugDescription, kind: "StaticText") + Self.labels(in: app.debugDescription, kind: "Other") + Self.labels(in: app.debugDescription, kind: "Button")
        let one = all.first { $0.hasPrefix("Spelar i AirPods") && $0.contains("kvar") }
        log.append("T53 playing card: '\(one ?? all.filter { $0.hasPrefix("Spelar") || $0.hasSuffix("kvar") }.joined(separator: "' + '"))'")
        audit("start-spelar")
        stopOnCard()
        guard let one else { return miss("the playing card is not one sentence 'Spelar i AirPods med …, N minuter kvar' (Ke79 9)") }
        return one.contains("minut") || miss("the playing card reads '\(one)' (Ke79 9: '… N minuter kvar')")
    }

    /// Ke79 point 4: a capsule reads the whole text (at most 80 characters), and its style or voice.
    private func a11yRecents() -> Bool {
        goToStart()
        pause(2)
        let caps = Self.labels(in: app.debugDescription, kind: "Button").filter { $0.hasPrefix("Klorofyllet") }
        log.append("T53 Senaste capsules: \(caps)")
        guard let first = caps.first else { return miss("no capsule in Senaste") }
        if first.contains("…") && first.count < 30 { return miss("the capsule reads the cut text '\(first)' (Ke79 4: the whole text)") }
        return first.hasPrefix("Klorofyllet i bladen fångar ljuset") || miss("the capsule reads '\(first)'")
    }

    /// Ke79: Bäst värde in the buy button, 44 points for Villkor, Integritet, Återställ köp; audit of the sheet.
    private func a11yCredits() -> Bool {
        goToStart()
        let capsule = Self.labels(in: app.debugDescription, kind: "Button").first { $0.contains("krediter kvar") || $0.contains("kredit kvar") }
        guard let capsule, tap([capsule], "the credit capsule (AX5)") else { return miss("no credit capsule") }
        let end = Date().addingTimeInterval(15)
        repeat { if app.debugDescription.contains("Paketen kunde inte hämtas") || app.debugDescription.contains("label: 'Köp ") { break }; pause(1) } while Date() < end
        var ok = true
        let buys = Self.labels(in: app.debugDescription, kind: "Button").filter { $0.hasPrefix("Köp ") }
        log.append("T53 buy buttons: \(buys.isEmpty ? "none (no products in a UI test)" : buys.joined(separator: " | "))")
        if let best = buys.first(where: { $0.contains("2 000") || $0.contains("2\u{00A0}000") }), !best.hasSuffix("bäst värde") { ok = miss("'\(best)' lacks ', bäst värde' (Ke79 7)") }
        for name in ["Villkor", "Integritet", "Återställ köp"] {
            var element = app.links.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch
            if !element.exists { element = app.buttons.matching(NSPredicate(format: "label ==[c] %@", name)).firstMatch }
            var swipes = 0
            // Run 44698563479 (SE, AX5): after Villkor the sheet's rows were gone from the tree. Drag at the right edge
            // (away from the links) and write what the sheet holds after each drag.
            while !element.exists || !element.isHittable, swipes < 10 {
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.8))
                from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.4)))
                swipes += 1
                pause(0.6)
                let sheet = (Self.labels(in: app.debugDescription, kind: "Button") + Self.labels(in: app.debugDescription, kind: "Link")).filter { ["Villkor", "Integritet", "Återställ köp", "Bjud in", "Försök igen", "Klar"].contains($0) }
                log.append("T53 Krediter drag \(swipes) for '\(name)': \(sheet), web views \(app.webViews.count), Safari \(XCUIApplication(bundleIdentifier: "com.apple.mobilesafari").state.rawValue), app \(app.state.rawValue)")
            }
            let h = element.exists ? Int(element.frame.height) : -1
            log.append("T53 '\(name)': height \(h) after \(swipes) drags")
            if h >= 0, h < 44 { note("'\(name)' is \(h) points high; its tap area may still be 44 (the audit's hitRegion says)") }
            if h < 0 { ok = miss("no '\(name)' in Krediter") }
        }
        audit("krediter")
        dismissCredits()
        return ok
    }

    /// A145 with the largest text: the button, the question and its words; nothing is deleted here (Avbryt).
    private func a11yDeleteAccount() -> Bool {
        guard openAccount() else { return false }
        guard askDelete() else { audit("installningar-konto"); return false }
        let alert = app.alerts.firstMatch
        let buttons = alert.buttons.allElementsBoundByIndex.map(\.label)
        log.append("T53 Radera kontot?: '\(alert.label)', buttons \(buttons)")
        tapAlert("Avbryt")
        pause(1)
        audit("installningar-konto")
        let ok = buttons.contains("Radera konto") && buttons.contains("Avbryt")
        return ok || miss("the question lacks Radera konto or Avbryt (\(buttons))")
    }

    /// Asks t36.sh to turn the runner's network off or on (t36-net-off/on.request), and waits for it.
    private func network(on: Bool) -> Bool {
        let name = on ? "t36-net-on" : "t36-net-off"
        let done = out.appendingPathComponent(name + ".done")
        try? FileManager.default.removeItem(at: done)
        try? "\(Date())\n".write(to: out.appendingPathComponent(name + ".request"), atomically: true, encoding: .utf8)
        mark(on ? "NET-ON request" : "NET-OFF request")
        let end = Date().addingTimeInterval(90)
        while Date() < end {
            if FileManager.default.fileExists(atPath: done.path) {
                mark(on ? "NET-ON done" : "NET-OFF done")
                pause(on ? 20 : 6) // NWPathMonitor and DHCP
                return true
            }
            pause(2)
        }
        return miss("\(name): the runner did not answer in 90 s")
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
    /// Run 44241367646: with a style the same text is saved twice (A136: another style is another exam), and Senaste
    /// shows a text once (A135), so removing one shows the other. Remove until none is left (at most 3), then look again
    /// after 10 s: none may come back.
    private func cleanUp() -> Bool {
        goToStart()
        pause(2)
        let before = recentCapsules().count
        guard before > 0 else { note("no capsule in Senaste to remove"); return true }
        var removed = 0
        for _ in 0..<3 {
            guard let label = recentCapsules().first, let capsule = find([label]) else { break }
            capsule.press(forDuration: 1.2); testTaps += 1
            guard tap(["Ta bort"], "Ta bort (long press in Senaste)") else { return false }
            pause(1)
            _ = confirmDestructive("Ta bort")
            removed += 1
            pause(3)
        }
        // Angela Fable 13:30 (run 44064540048): a removed reading came back after a 404. Look again after 10 s.
        pause(10)
        goToStart()
        let after = recentCapsules().count
        log.append("T36 capsules for the text in Senaste: \(before) before, \(removed) removed, \(after) 10 s after")
        screen("borta-10s", "Start 10 s after Ta bort in Senaste")
        if after > 0 { return miss("the text is still (or back) in Senaste after removing \(removed) (\(after) left)") }
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

    private func launch(_ value: String, material: String? = nil) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(sv)", "-AppleLocale", "sv_SE"]
        app.launchEnvironment["LUMEN_TEST_HEADER"] = value
        if let material { app.launchEnvironment["LUMEN_TEST_MATERIAL"] = material }
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
        // Angela Fable 00:15 (44312213280): a centre tap on a button under the keyboard lands on the keyboard. Never
        // tap through it.
        let keyboard = app.keyboards.firstMatch
        // Run 44439180352: with the keyboard's keys in the tree but no keyboard element, a button in its lower half
        // counts as under it.
        let underKeyboard = (keyboard.exists && keyboard.frame.contains(CGPoint(x: frame.midX, y: frame.midY)))
            || (!keyboard.exists && keyboardUp && frame.midY > app.windows.firstMatch.frame.height * 0.55)
        if !element.isHittable, underKeyboard {
            if keepKeyboard { log.append("\(step): '\(element.label)' is under the keyboard; not hiding it (T55), looking for a hittable twin") } else { log.append("\(step): '\(element.label)' is under the keyboard; hiding it"); hideKeyboard(); element = find(labels) ?? element }
        }
        if !element.isHittable, !underKeyboard, !frame.isEmpty, app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) {
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
        while !element.isHittable, !keepKeyboard, swipes < 6 {
            app.swipeUp()
            swipes += 1
            if let again = find(labels) { element = again }
        }
        if swipes > 0 { note("\(step): '\(labels[0])' was below the screen (\(swipes) swipes)") }
        guard element.isHittable else { log.append("MISS: \(step): '\(labels[0])' not hittable"); return false }
        if keepKeyboard { log.append("T55 AX5 tapped '\(element.label)' at \(NSCoder.string(for: element.frame)), keyboard up \(keyboardUp)") }
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
