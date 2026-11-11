# Stående uppgift, omgång 20 (K4-loopen): intervjuläget utan CV (Kevin, 2026-11-12 00:50)

## Eval
Jag körde en del av live-evalen: kommando, appkommando, intervju, minne, om-lumen, profil och nivå. Av 148 turer var 139 utan anmärkning, och appkommando gav 57/57.
- **Talintervallet från omgång 16** stämmer nu live: "mellan ett komma fyra och fem komma sju grader".
- **Kvar:**
  - 5 långsamma svar, mest "ställ en svår fråga" på cirka 3,2 s.
  - Minne: "Jag åkte skidor, du då?". Det är den sociala repliken, och evalen räknar den som en fråga tillbaka. Den är oförändrad.
  - De två intervjufynd som rättas nedan.

## Ändringar (driftsatta i `dc710dd`)
1. **intervju-06:** "vad har du för erfarenhet av vård" gav "Jag har inte jobbat med vård tidigare". Utan CV skickar appen bara annonsen, utan "Jobbannons:"-prefix (`InterviewProfile.swift:47`), och servern räknade annonsens "Extrajobb som vårdbiträde" som elevens egen erfarenhet.
   - Nu räknas texten utan "CV:" alltid som annonsen och aldrig som elevens fakta (`interviewfacts.ts` `userFacts`).
   - Detsamma gäller "B-körkort krävs" i en annons.
   - Det fall som stod under "Kvar" i omgång 18 är därmed löst.
2. **"Det är en bra fråga att svara på."** (k9-ih-professional-2) sägs inte längre i intervjusvar (`INTERVIEW_META`). En mening som "Jag ställer gärna en bra fråga om rutinerna" sägs fortfarande.

## Tester
- `deno task test`: **508 gröna**. `check` är ren.
- **Live-eval intervju** efter driftsättningen: **19/19 utan anmärkning** (förut 17/19).

**Kostnad:** cirka 0,4 USD. I natt hittills cirka 4,5 USD.

## Till Aron
Inget nytt.
