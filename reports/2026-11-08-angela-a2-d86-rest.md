# Angela — A2: the rest of D86 (the list screens, the modes' start screens, the short consent card)

Date: 2026-11-08 · Assignment: `prompts/queue/angela.md` A2 · Device: **none** (Simulator screenshots only)

**Result:** all three parts are built. **Unverified on device.** The Simulator screenshots are linked below; they are
not a device check. CI: see the end of this report.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **List screens in the new look**, details below the table. | verified in CI (build); look in screenshots |
| 2 | **The modes' start screens**, details below the table. | verified in CI (build) |
| 3 | **The short consent card**, details below the table. | verified in CI (build) |
| 4 | **Screenshots**, details below the table. | see below |

**1. List screens in the new look**
- **Which screens:** Settings, Diagnostik, Rå transkription, Anteckningar, Förberedelser, Egna kommandon, Historik,
  Minne, Feedback, Studiekort, Provsession.
- **What they get** (`lumenForm()`):
  - the squared-paper ground (#F5F8FC / #161C2A);
  - Familjen Grotesk;
  - no capitals over headings;
  - the blue accent;
  - Swedish titles.
- **What they keep:** the system's grouped rows, so they stay readable in light and dark and with large text.

**2. The modes' start screens**
- **Which screens:** Intervjuläge, Socialt/Rizzläge and the 18+ question, rebuilt in the new design.
- **Layout:** the mode's round colour, a short Swedish text, the app's fields, and one clear start button at the
  bottom.
- **Behaviour:** the same as before (CV, job ad, interests, the start screen's confirmation, the age gate).

**3. The short consent card** (approved by the Architect)
- **The card:** the intro now has it, with three points:
  - Lumen lyssnar bara när du har startat den.
  - Du ser alltid när den lyssnar.
  - Ljud sparas inte.
- **"Läs mer"** opens the full consent text (a new read-only mode of `ConsentView`).
- **"Testa nu"** is the consent and goes straight to the first question, so the full consent screen is no longer a
  step in the first start, and the first answer can come within 30 s.
- **Withdrawing:** after the first start the full text and withdrawing stay in Settings → *Integritet och samtycke*.
  A withdrawn consent shows the full screen again, as before.

**4. Screenshots**
- **How they are made:** `.github/workflows/screenshots.yml`, started by hand. It builds for the Simulator, starts the
  app with `-LumenScreenshot <screen>`, and saves light and dark pictures.
- **The hook:** a Debug-only `ScreenshotStage` with demo data: three exams, a profile, a practice item, two answers.
  No microphone, no network.
- **Screens:** intro, the first question, Start with and without an exam, Lägg till prov, Lyssnar, Byt läge, the
  errors, Settings, Intervju, Socialt.

## Known limits
- **Settings and Diagnostik:** the rows keep the system's grouped cells. Only the ground, font and accent are the new
  design.
- **The Lyssnar screenshot** shows "Startar …" in the header, because the demo has no live session.

## Next session
A3 (choose a voice) depends on Kevin's K6.
