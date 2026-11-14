# K67: Oscars O64-fynd, formler, språk och "the notes" (Kevin, 2026-11-14 21:28)

## Kort
Alla fyra punkterna är klara och driftsatta, plus Oscars två fynd från O65. Commits: f4c789f, 78f2089, 21ec111.
- **Kostnad Claude:** cirka 0,49 USD (2 livekörningar med 4 prov).
- **Kostnad ElevenLabs:** 0. Alla filer har teströsten `earmind-test-silent` (**verifierat live** i `drill_audio_files`).

| Punkt | Nu | Status |
|---|---|---|
| 1. "/" i formler (prio 2) | "v = s / t" läses "v är lika med s delat med t", "A = b · h / 2" blir "… gånger h delat med två", och "p = F/A" blir "F delat med A". "och/eller" och "ja/nej" behåller "/". Skärmen behåller "/" (`screen`) | **verifierat live**, texten som rösten får lästes ur databasen |
| 2. Varför-frågor utan orsak (prio 3) | Plan-prompten kräver att materialet självt ger orsaken ("eftersom", "leder till", en förklarad mekanism). `drill_answers` får nu `may_fix` (se nedan). Live på appens väg byttes "Varför betalade tredje ståndet nästan alla skatter …" till "Vad betalade tredje ståndet för skatter, och varför kändes det orättvist?" | **verifierat live**, 1 körning |
| 3. "the notes" på alla språk (prio 3) | `mentionsMaterial` fångar "the notes", "the text", "in the text", "the passage" och samma ord på spanska, tyska och franska. "notes to his mother" räknas inte | test, och 0 träffar live på 48 frågor |
| 4. Engelska siffror och visningstext (prio 3) | I ett engelskt prov läses talen inte längre med svenska ord. Siffrorna lämnas åt rösten, och formeltecknen blir engelska ord: "km/h" blir "kilometres per hour", "3/4" blir "three quarters", "25 %" blir "25 percent", "a²" blir "a squared". Svars-prompten ber om visningstext för alla årtal, datum, procent, decimaltal och mått | uppläsningstexten **verifierat live**. Att ElevenLabs läser "1850" som "eighteen fifty" är en **otestad antagelse** (D180) |

## Fynd under arbetet
- **Klimatprovet blev svenska på appens väg.** I första livekörningen skrev steg 1 (Haiku, `answers: false`) klimatprovets frågor på svenska, trots D182. Bara `may_fix` räddade det, eftersom svarssteget översatte alla 12.
- **Rättat:** kontrollsteget (`shortenQuestions`) får `<language>` för språkprov och översätter de frågor som inte är på provets språk. Översättningen får vara längre än originalet.
- **Andra körningen:** 0 frågor behövde översättas i båda engelskproven (**verifierat live**).

## Detaljer
- **`drill/handler.ts`:**
  - `voiceText(s, lang)` och `longVoice(…, lang)`
  - `divided()` gör "/" till "delat med" när någon sida är en enskild bokstav, ett tal eller ett talord
  - `foreignVoice()` används för språkprov
  - språket tas från provets ämne (`examLanguage(drill.subject)`, samma regel som D182 i `/exam`)
  - **ny ljudfil bara för nysparade frågor:** gamla prov behåller sina filer, eftersom filernas namn bygger på texten
- **`exam/drill.ts`:**
  - `drill_answers` tar `may_fix: true`. Då får genererade frågor bytas i svaret (`items[].question`).
  - **Angela Schrute:** sätt `may_fix: true` bara direkt efter `drill` med `answers: false`, aldrig för elevens egna frågor. Appen ska då använda `question` i svaret. Utan flaggan ändras ingen fråga, som förut.
- **Tester:** 616 gröna, `check` ren.
- **Data:**
  - `reports/qa/data/2026-11-14-211444-k67-live.json`
  - `reports/qa/data/2026-11-14-212343-k67-live.json`
  - skript `scripts/k67-live-check.py`, där varje prov får ett eget testkonto och alla prov tas bort efteråt

## Begränsningar
- En eller två körningar per prov.
- `may_fix` byter ibland en bra varför-fråga mot en längre fråga ("Varför var fängelset Bastiljen en symbol …" blev "Vad hände den fjortonde juli …").
- "h" ensamt efter "delat med" läses som bokstaven h, men det är ovanligt (O65).
- Ingen har lyssnat på hur något låter, eftersom D180 inte tillåter testljud.

## Nästa
- **Angela Schrute:** `may_fix: true` i `drill_answers` på appens väg, om hon vill ha det. Meddelad.
- **Oscar:** omtest om Deangelo vill.
- **Kevin:** väntar på kö.
