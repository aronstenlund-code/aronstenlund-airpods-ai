# A26 – Kellys rättelser R1–R6 efter A18 (Angela, 2026-11-10)

Underlag: `reports/2026-11-10-0805-kelly-granskning-a18.md` (Ke17, del 2) och Kellys bilder `docs/design/bilder/system/intro.png`
och `rost.png`. **CI och simulator, inget provat på telefon.**

| # | Fynd (Kelly) | Vad som gjordes |
|---|---|---|
| R1 | Ringarna mitt i Elias ansikte, Elias liten i ett brett kort | Bilden fyller nu kortet. `IntroHeroView.fill` skalar bilden så att den täcker kortet utan att förvrängas. Toppen syns, utom när hörluren då skulle hamna långt ner i kortet (SE): då flyttas bilden upp tills hörluren sitter på 60 % av kortets höjd. Ringarnas mitt räknas mot den synliga bilden, på hörluren (0,32; 0,37 i bilden). Kortet börjar under statusraden, inte 56 punkter ner. |
| R2 | På SE täcker Testa nu löfte 2–3 och Läs mer | Introt har en mening under rubriken ("Telefonen stannar i fickan."). Löftena är en lugn lista med tre rader, och "Ljud sparas inte · Läs mer" ligger på samma rad. Rubriken är 34 pt. Hjältebilden är 34 % av höjden på SE och högst 320 pt annars. Texten vid knappen är kortare: "Inget konto. Testa nu betyder att du godkänner punkterna ovan." |
| R3 | Mörkt läge: #000 bakom innehållet, #0F1218 längst ner | Intro och Första frågan har nu `background` bakom själva rullvyn. Skärmbildsscenen använder också `lumenScreen()`, som appen redan gjorde. |
| R4 | Brickan säger "Startar …" när den är pausad | `ListeningModel.isStarting` är sant bara medan en start pågår. Lyssnar säger "Pausad" när den inte lyssnar och inget startar, alltså samma sak som knappen "Lyssna igen". Första frågan säger "Pausad" och har knappen "Lyssna igen" när mikrofonen inte går, så att den aldrig står på "Startar …" (Tobys T8 fynd 1). |
| R5 | Rösten heter "Adam", Provlyssna är en egen rad | Ny sida Inställningar › Röst (`VoicePageView`). Varje röst beskrivs ("Lugn berättarröst, Svensk, tydlig"), med ▶ på raden och ✓ på den valda. Talhastigheten väljs i tre steg (Lugn, Normal, Snabb). ▶ spelar den rösten utan att välja den. |
| R6 | "Avsluta" i lyssnarraden är rött eller blått | "Avsluta" är i bläck. Punkten var redan blå sedan A18. |

## Rösternas beskrivningar
`/voices` skickar i dag bara namn och id. Appen läser nu ett valfritt fält `description` per röst, och det vinner när det
finns. Annars beskrivs Adam från K14 ("svensk berättarröst", **verified in docs**). Andra röster behåller sitt namn,
så att två rader aldrig ser likadana ut. Saga och Max har jag inte beskrivit, eftersom jag inte vet hur de låter.
**Till Kevin:** lägg till `description` i `/voices`, till exempel `Name:id:Beskrivning` i `ELEVENLABS_VOICES`.

## Tester
- `LumenTests/A26Tests.swift`:
  - bilden täcker kortet i fyra storlekar, utan förvrängning och med hörluren innanför;
  - SE-kortet flyttar upp bilden;
  - ett högt kort behåller toppen;
  - hjältens höjd på SE;
  - röstbeskrivningarna;
  - `description` läses från `/voices`.
- Skärmbilder: `screenshots.yml` har två nya scener, `voice` och `practice`.

## Kända begränsningar
- Att alla tre löftena och Läs mer syns ovanför knappen på SE vid standardtextstorlek syns i simulatorbilden. Den är
  inte provad på en riktig SE, och inte vid större text.
- Rösterna på röstsidan kommer från `/voices`. Utan nät syns bara iPhonens röster.

## CI
Grönt i CI: iOS build 42796721366 (`9b58004`, med A26, A16 och A19). Bygget för enhet räknar varningar som fel, och alla
LumenTests är gröna, A16Tests, A19Tests och A26Tests inräknade. Skärmbilder från simulatorn: körningarna 42796736014
(iPhone 17 Pro) och 42796744858 (SE), i `reports/2026-11-10-a26-a16-skarmbilder/`.

**Vad bilderna visar (skärmbild, simulator):**
- SE i mörkt läge: alla tre löftena och Läs mer syns ovanför Testa nu (R2).
- Bakgrunden är densamma över hela skärmen (R3).
- Ringarna sitter på hörluren, och Elias fyller kortet (R1).
- Första frågan visar "Pausad" och "Lyssna igen" (R4).
- Röstsidan har beskrivningar, ▶ och ✓ (R5).

SE:s introbild i ljust läge blev hemskärmen, eftersom appen inte hann starta före bilden. Den saknas därför.

Efter bilderna, i en egen commit:
- "Läs mer" och "Lyssna igen" är blå. I bilden syntes de i bläck.
- iPhonens röster heter "Alva" i stället för "Apple · Alva".
