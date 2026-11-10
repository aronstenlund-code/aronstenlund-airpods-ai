# A16 – Övningsprov i appen (Angela, 2026-11-10)

Bygger på Kevins K15 (`reports/2026-11-10-1100-kevin-k15-practice-exam-voice.md`). **CI och simulatorlogik. Inget provat
på telefon, och inget riktigt `/exam`-anrop från appen.**

## Vad som gjordes
1. **Lägga till:** Förberedelser › Övningsprov (och Inställningar › Övningsprov) öppnar `ExamSetupView`.
   - Där finns tre sätt: PDF, bilder eller inklistrad text.
   - En PDF med textlager (minst 200 tecken) skickas som text till `/exam parse` med `text` (K15). Det är billigare och
     exakt. En PDF utan textlager, och foton, går som bilder som förut (D84).
   - Listan visar "Fråga N", ämnesordet (`topic`) och "Lumens svar" när facit saknades.
2. **Köra:** knappen "Kör övningsprovet" finns i `ExamSetupView` och under ⋯ i Lyssnar (Provläge). Rösten fungerar också:
   "Lumen, kör övningsprovet".
   - Provläge startar om det inte redan är på.
   - Lumen säger "Övningsprov, 12 frågor. Svara högt. Säg nästa, förra, fråga sju, hoppa över eller upprepa." och läser
     sedan fråga 1 med Kevins `spoken`, alltså tal i ord och poängen sist.
3. **Varje yttrande:**
   - Med eller utan "Lumen" går yttrandet till `PracticeNav`, som är Kevins `practiceNav` portad till Swift.
   - "nästa", "förra", "fråga sju", "uppgift 3b", "hoppa över", "upprepa", "avsluta" och "hur gick det" styr.
   - Allt annat är ett svar. Det går till `/exam grade` med `practice: true`, och Lumen läser upp återkopplingen ("Rätt.",
     "Delvis rätt." eller "Inte riktigt.", rätt svar och varför).
   - Sedan läser Lumen nästa obesvarade fråga direkt. Överhoppade frågor kommer sist.
   - Svaret går före utfyllnadsfiltret, så att "ja" kan vara ett svar.
   - Svar i förväg (D80), "Mer?"-erbjudandet, tips och anteckningsvakten är avstängda under körningen.
4. **Skärmen:**
   - Lyssnar visar "FRÅGA 3 AV 12", frågans text, poängen, en stapel för hur många som är rättade, och förra frågans
     återkoppling.
   - Raden under brickan säger "Övningsprov, fråga 3 av 12. Svara högt, eller säg nästa."
   - När provet är slut syns ett resultatkort: "7 rätt av 10", rätt, delvis och fel, och "Att öva på" (ämnesorden för det
     som inte blev rätt).
5. **Slutet:**
   - Det första "avsluta", eller den sista frågan, ger resultatet uppläst ("Du hade 7 rätt av 10. 2 delvis rätt och 1 fel.
     Öva på procent och ekvationer.").
   - "Övningsprov: öva på …" sparas i Minne.
   - Rätt och fel per ämnesord sparas i `ConceptStats` och skickas som `concept_stats` i varje Provläge-anrop, så att
     "testa mina svagaste" (K9) och sammanfattningen (K17) vet vad som gick fel.
   - Samma resultat sparas i studieplanens historik (A19).

## Beslut (DECISIONS A16)
- **Navigeringen avgörs i appen** (en port av `practice.ts`) i stället för ett `nav`-anrop per yttrande. Då flyttar
  "nästa" direkt och fungerar utan nät. Testerna är samma som Kevins `practice_test.ts`. Ändras `practice.ts` måste
  `PracticeNav` följa med.
- **Ett prov åt gången** på telefonen. Samma prov används för övningsprovet (A16) och provsessionen med provtid (D84).

## Tester
- `LumenTests/A16Tests.swift`:
  - Kevins 18 navigeringsfall;
  - startkommandot;
  - `spoken` och "Fråga 1 av 3";
  - rättning, nästa öppna fråga och summeringen med "Öva på";
  - överhoppade frågor;
  - taket på 30 i `concept_stats`;
  - att gamla sparade prov fortfarande läses och att K15:s fält läses.
- Skärmbild: scenen `practice` i `screenshots.yml`, med frågekortet och resultatkortet.

## Kända begränsningar och risker
- **Untested assumption:** att Scribe ger hela svaret som en tur. Ett långt resonemang med pauser längre än elevens
  paus (D80) blir två turer, och den andra rättas mot nästa fråga. Under rättningen hörs inget nytt svar, och det loggas.
- Rättningen kräver nät. Utan nät säger Lumen "Jag kunde inte rätta just nu. Säg svaret igen, eller nästa."
- "en gång till" upprepar Lumens senaste ljud (A17) innan `PracticeNav` hinner se det. Det är oftast frågan, men efter en
  rättning är det återkopplingen.
- Gränsen i `/exam` är 12 anrop per minut (K15). En elev hinner inte nå den.

## Till Toby
Ett E2E-test när kvoten är påfylld: lägg in ett övningsprov som text, kör det och svara med en ljudfil per fråga.

## CI
Grönt i CI: iOS build 42796721366 (`9b58004`, med A26, A16 och A19). Bygget för enhet räknar varningar som fel, och alla
LumenTests är gröna, A16Tests, A19Tests och A26Tests inräknade. Skärmbilder från simulatorn: körningarna 42796736014
(iPhone 17 Pro) och 42796744858 (SE), i `reports/2026-11-10-a26-a16-skarmbilder/`.
