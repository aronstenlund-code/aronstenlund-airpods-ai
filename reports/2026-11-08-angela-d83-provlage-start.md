# Angela — D83: Provläge's first start, nod to answer, subscription gate prepared

Date: 2026-11-08 · Assignment: Aron (chat), owner decision D83 · Device: **none**

**Result:** all three points are built. **Unverified on device.** CI: see the end of this report.

## What changed
| # | Change | Status |
|---|---|---|
| 1 | **First start of Provläge**, details below the table. | verified in CI |
| 2 | **Nod** (D60): `CMHeadphoneMotionManager` runs only for 6 s after a yes/no check question, and only when that style is chosen. A nod (pitch out and back ≥ 0.18 rad within 1.4 s) is "Ja", a shake (yaw) is "Nej", sent as the turn. Just turning the head is no answer. The motion handler is built outside the main actor (the crash lesson). Settings says when the AirPods have no head tracking; the voice always works. `NSMotionUsageDescription` added. | detector verified in CI; head tracking untested |
| 3 | **Subscription** for Rizzläge and Socialt läge: not built. Only `ModeAccess.liveModesNeedSubscription` (off, so every mode is open) and its check in `startHandsFree`. No StoreKit code until there is a paid Apple Developer account. | verified in CI |

**1. First start of Provläge.**
- **When:** the card "Få A-svar till provet" or the mode button opens five screens, one question each, with "Hoppa
  över" on every screen and "Hoppa över allt". Siri and voice starts never show them, since they are hands-free.
- **The questions:**
  - exam date: Idag / Imorgon / Inom en vecka / Senare with a date picker / Inget prov just nu;
  - grade: Åk 6–9, Gymnasiet 1–3 with an optional course name, Högskola, Annat;
  - subject: 15 common ones, or free text;
  - check questions: none / yes–no / short / hard;
  - explanation length: short / medium / detailed.
- **Where the answers go:**
  - stored on the phone;
  - mirrored into Minne as "Provprofil: prov i Biologi fredag 13 november 2026", always an absolute date;
  - sent on every Provläge call as `persona: "tutor"` with `persona_setup`, for example "Prov i Biologi fredag 13
    november 2026 (om 5 dagar). Årskurs: Gymnasiet 2, kurs Biologi 1. …". The backend accepts both since D42.
- **Changing them:**
  - in Settings → *Provläge: om dig*;
  - by voice: "Lumen, korta / mellanlånga / utförliga förklaringar", "Lumen, inga kontrollfrågor / ja–nej-frågor /
    korta frågor / svåra frågor", "Lumen, ämne kemi", "Lumen, provet är på fredag / den 20 november / imorgon / om
    3 dagar", "Lumen, inget prov".

## For Kevin
`persona: "tutor"` with `persona_setup` now arrives on every Provläge call. The tutor prompt should follow these
three fields:
- **Kontrollfrågor:** none / yes–no / short / hard. Yes–no means a question that can be answered "ja" or "nej", so
  a nod works.
- **Förklaringar:** short / medium / detailed.
- **The exam date.**

**Verified in docs** that the field is accepted (D42 contract). The behaviour in the prompt is not verified.

## Tests
`LumenTests/StudyProfileTests.swift`:
- **Profile:** quick answers become absolute dates; the setup text and the Minne facts.
- **Voice:** explanations, check questions, subject, "provet är på fredag" (the next Friday), "den 20 november",
  and an ordinary question is not mistaken for a command.
- **Head gestures:** a nod is yes, a shake is no, a turn of the head is nothing.
- **Subscription:** the flag is off.
- **Flow:** the first start shows the questions; afterwards Minne has the exam, the Provläge call carries
  `persona: "tutor"` with the profile, and the second start goes straight in.

## CI
- **Cancelled builds:** every push of `scripts/**` (Kevin's live-eval cases, Oscar's QA scripts) started an iOS
  build and cancelled the running one. That is why D82 never finished a run.
- **Fix:** `scripts/**` is now in the iOS workflow's `paths-ignore`, like `backend/**` and `site/**`. The iOS build
  uses nothing there.
- **This run:** the run of this commit checks D82 (with its fix) and D83 together.
- **First D83 run:** failed to build on one deprecation, which counts as an error: `CMHeadphoneDeviceMotionHandler` is
  `CMHeadphoneMotionManager.DeviceMotionHandler` in the iOS 26 SDK. Renamed.

## CI result
**Green:** run `42483764321` (commit `a571062`, D82 + its fix + D83 + its fix; the first attempt failed on package resolution before anything was built, the re-run passed: build, unit tests, licence check). IPA for Sideloadly: https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42483764321/artifacts/13619043317 (kept 14 days).

## Next
D81.
