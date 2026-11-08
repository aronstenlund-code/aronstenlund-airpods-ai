# Angela — D86: the new design for the whole app

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D86 · Sketches:
https://claude.ai/artifact/UZeuuk1zxGMKVA6A9CQC1x (I read them: Start, Intro, the first question, Lägg till prov, Start
without an exam, Lyssnar, Byt läge, lock screen, errors, light and dark) · Device: **none**

**Result:** all seven points are built. **Unverified on device: the whole look must be checked on an iPhone.**
CI: see the end of this report.

**One push for all seven screens.** The owner asked for a push after each screen. The screens depend on each other:
Start opens Lyssnar, the first start ends in "Lägg till prov", and all of them use one theme. A push for each would
also have cancelled the build before it (`cancel-in-progress`), so there would not have been an IPA per screen anyway.
Each screen has its own section below.

## The look
- **Fonts:** Familjen Grotesk is used everywhere. Kalam (handwriting) is used only for the user's questions and the red
  pen. Handwriting is a setting, Settings → *Utseende* → *Frågor i handstil*, on by default.
- **Fonts and Dynamic Type:** every size grows with the user's text size (`relativeTo`).
- **Font files:** they are bundled in `Lumen/Resources/Fonts/`, with the OFL licence texts. Familjen Grotesk is also in
  the Live Activity extension.
- **Colours:** the owner's light and dark values, as dynamic colours (`Shared/LumenStyle.swift`). The mode colours'
  dark variants come from the sketches.
- **Light and dark:** the app follows the iPhone by default. Settings → *Utseende* locks it to Ljust or Mörkt.
- **Shapes:** squared paper with lines every 18 pt; corners 10 pt, the exam card 6 pt.
- **Text rules:** no capitals over headings (`textCase(nil)` in Settings), and no middle dots in the user's texts.

## The screens
| # | Screen | Status |
|---|---|---|
| 1 | **First start** | untested |
| 2 | **Lägg till prov** | verified in CI (logic) |
| 3 | **Start** | untested (look) |
| 4 | **Lyssnar** | untested (look) |
| 5 | **Lock screen and Dynamic Island** | untested |
| 6 | **Problems in Swedish, with what to do** | verified in CI (mapping) |
| 7 | **Handwriting, text size, VoiceOver** | untested |

**1. First start**
- **The steps:**
  - Intro: "Fråga högt. Få svaret i örat.", "Testa nu".
  - The consent screen.
  - iOS asks for the microphone straight away.
  - "Fråga vad som helst": Lumen listens in Frågor, and the first question gets its answer on the card.
  - "Lägg till prov", which can be skipped.
- **Photo:** the intro's photo is a placeholder (grid paper, listening rings, AirPods), until a freely licensed photo
  exists.
- **Speech recognition permission:** asked only when the phone's own recogniser is used, as it already was (in
  `LegacySpeechProvider`).

**2. Lägg till prov**
- **The form:** grade (Åk 6–9, Gy 1–3, Högskola; a course field for Gy and Högskola); area Matte, NO, SO, Språk,
  Praktiskt or Annat, which folds out its subjects (Annat: free text); a real date (Imorgon, or the date picker);
  "Vad kommer på provet?".
- **"Eller säg det":** the next sentence about an exam, "Jag har prov i biologi på fredag", is saved through D84's
  statement.
- **Several exams** are kept on the phone (`ExamPlanStore`). The same subject on the same day is one exam.
- **The profile:** the saved exam becomes Provläge's profile (D83/D84), and its topics go along in `persona_setup`
  ("På provet: …"). Kevin's `/study-profile` adds the subject's terms.

**3. Start**
- **The exam card:** the nearest exam as a squared card with its name, date and grade, and the red pen's ring around
  "N dagar kvar".
- **"Öva mer på"**, from:
  - Minne's "Provträning" (D84);
  - else study cards answered wrong (D81);
  - else the topics.
- **Buttons on the card:** "Få A-svar till provet", and *Minitest* when there are cards.
- **Other exams:** rows with a microphone that starts Provläge for that exam. A long press removes an exam.
- **Also on Start:** "Lägg till prov", four round mode buttons, and the line about switching by voice.
- **Without an exam:** "Har du ett prov snart?" with a dashed grid card.

**4. Lyssnar**
- **The header:** squared paper with the exam (or the mode).
- **"Byt läge":** a sheet with every mode, the current one marked. The listening goes on; the same checks as before
  apply (18+, start screen, interview setup).
- **The answer area:**
  - the latest question in handwriting and the answer large;
  - the one before dimmed;
  - a thumb down (report);
  - in Rizz/Socialt, the suggestion and "Nästa förslag".
- **The commands line:** "Lumen, förhör mig / pausa / avsluta".
- **Pausa** (Fortsätt while paused) and **Avsluta**: the same words in the app, on the lock screen and by voice.
- **"Lumen, förhör mig"** in Provläge is now one check question. "minitest" stays the mini test.
- **"Tillbaka"** goes to Start with the session still on. The listening line above Start then opens Lyssnar again.

**5. Lock screen and Dynamic Island**
- **Shown:** the logo, the exam's name (or the mode), "Lyssnar"/"Pausad", the latest answer on one line, and Pausa and
  Avsluta.
- **Avsluta** is a new `StopListeningIntent`.

**6. Problems in Swedish, with what to do**
- **The four problems:**
  - Microphone denied: "Lumen hör dig inte" + *Öppna Inställningar*.
  - Offline: a card, and "Ingen internetanslutning." in the ear.
  - AirPods disconnected: the answers go on in the phone's speaker, + *Pausa*.
  - Every other answer failure: "Försök igen om en minut" + *Försök igen*, the same line in the ear.
- **AirPods disconnected, setting:** Settings → *Pausa när AirPods kopplas bort*, off by default, pauses at once as
  before.
- **Raw details:** codes, HTTP status, the raw transcript, sources and milliseconds are only in Settings →
  *Diagnostik* → *Rå transkription och svar*.
- **The typed question** (MVP item 6) is there too.

**7. Handwriting, text size, VoiceOver**
- **Handwriting:** a setting (on by default).
- **Text size:** every font follows Dynamic Type, and layouts wrap (the exam card's ring moves under the date).
- **VoiceOver:** every button has a Swedish label; decorations are hidden from VoiceOver.
- **Touch targets:** at least 44 pt.
- **Reduce Motion:** the listening rings stop pulsing.

## Moved, kept, removed
- **Kept:** the consent screen (a guardrail) and the listening indicator. The indicator is the line above Start while
  listening; Lyssnar is the indicator itself.
- **Moved to Settings → *Mer*:** Notes, Prep, Commands, Privacy and consent, the exam session upload (D84), and
  "Spara samtalet som anteckning".
- **Removed from the main screen:** the live transcript list, the mode picker, "Ask about the last sentence", the text
  field and the latency overlay. The raw details are in Diagnostik.

## D85
There is no D85 document in the repo. The D86 points include the quick fixes as the owner described them: Swedish
errors, the same Pausa/Avsluta words, and speech permission only when needed.

## Tests
`LumenTests/DesignTests.swift`:
- **Exam names and days left:** "Biologiprovet", "5 dagar kvar", "Fre 13 nov, åk 9", no middle dots.
- **The areas' subjects** and the subject → area lookup.
- **An exam becomes the profile** (topics included; the user's own settings kept).
- **Several exams:** nearest first, past ones hidden, one exam per subject and day, saved on disk.
- **Appearance:** follows the iPhone, handwriting on by default.
- **Problems:** answer failures map to Swedish problems with no codes; the spoken lines.
- **"förhör mig"** is a check question, not the mini test.

## Concerns
- **Consent:** the consent screen stays in the first start. That makes "an answer within 30 s" depend on reading
  speed. The Architect can decide whether a shorter consent screen with "Läs mer" is enough under the guardrails.
- **AirPods out:** keeping listening after the AirPods are taken out means the answers are heard in the room. The owner
  chose this; the card and the setting say so.
- **First start for existing users:** existing users also see the first start once after the update (intro, then
  straight to the first question, since they already consented).

## Known limits
- **Not checked on a device:** the look itself (spacing, the red ring's drawing, the fonts' weights through the
  variable font, Dynamic Island).
- **Photo:** the intro's photo is a placeholder until there is a freely licensed one.
- **Other screens:** Settings, Diagnostics, Notes and the mode setup screens keep their list layout and the system
  font. They follow light/dark and the blue accent, and Settings has no capitals over its headings. Restyling them is
  a later step.

## CI
- **Green:** run `42493099848` on commit `0f99e1c` (D81 + D84 + D86 + D87 together: build, unit tests, licence check). IPA for Sideloadly: https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42493099848/artifacts/13621679810 (kept 14 days).

## Next session
After a green CI: checklist 3z9 on Aron's iPhone.
