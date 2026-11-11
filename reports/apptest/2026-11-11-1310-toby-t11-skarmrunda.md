# T11 – Skärmrunda på A50, A52 och A53 i ljust, mörkt med största text och iPhone SE (Toby, 2026-11-11 13:10)

**Simulatorn räknas aldrig som verifiering på enhet.** Skärmturen (`AppTests/E2E/Screens/ScreenTourTests.swift`) kör
med Apples igenkänning och röst och kostar därför inga krediter. Egen punkt (README 8, PLAN 2b).

- **Körning:** [43008489738](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43008489738).
  - Bygget är main före A60, med A50, A52, A53, A54 och A55 (Earmind).
  - Lägen: `pro-light`, `pro-dark-storsta-text` (mörkt och största text) och `liten-light` (iPhone SE).
- **Bilder:** `reports/apptest/2026-11-11-t11-skarmrunda/`. Översikterna `oversikt-storsta-text-mork.jpg` och
  `oversikt-iphone-se.jpg` visar Start, Start med prov, Vad kan Earmind?, Mina svar och Ny fråga sida vid sida.
- **Nytt i turen:**
  - Den klarar namnen Lumen och Earmind (A55).
  - Den öppnar "Allt Earmind kan ›" och fotograferar Vad kan … (A52), tre skärmar.
  - Den öppnar Mina svar och Skriv en fråga utan att skriva något (A53), så inget `suggest`-anrop görs.
  - Branch-körningar tar nu tre lägen i stället för två.

## Resultat
| Kontroll | Pro ljust | Mörkt, största text | iPhone SE |
|---|---|---|---|
| Starta Earmind syns utan att rulla | ja | ja | ja |
| Lägesraden "Läge: … Byt läge" och Byt-arket med Provläge | ja | ja | ja |
| "Earmind kan allt" med exempel | ja | ja | ja |
| "Få A-svar", "Bara fråga" och "Fler lägen" borta | ja | ja | ja |
| "Allt Earmind kan ›" → Vad kan Earmind? | ja | ja (rubriken kapas) | ja |
| Mina svar och Ny fråga öppnas och stängs | ja | ja | ja |
| Starta Earmind i Standardläge öppnar Lyssnar | **nej** | **nej** | **nej** |

Den sista raden är T8b fynd 4 (bygget hade inte A60). Med Apples igenkänning, som inte startar i simulatorn, blev Start
kvar utan något meddelande. A60 ska visa "Earmind kom inte igång. Tryck igen om en stund.". Det prövas i körningen som
går nu.

## Fynd till Angela (största text)
1. **Lägesraden bryter mitt i ordet:** "Standardläg" / "e" · Byt (`pro-dark-storsta-text-11-start-utan-prov.jpg`).
   Förslag: tillåt två rader med radbrytning mellan orden, eller låt "Byt" gå ner på egen rad.
2. **"NÄSTA PROV" bryts bokstav för bokstav** ("NÄ / STA / PR / OV") bredvid "7 dagar kvar"
   (`pro-dark-storsta-text-19-start-med-prov.jpg`). Förslag: lägg chipet under rubriken vid stora textstorlekar
   (`ViewThatFits` eller `dynamicTypeSize >= .accessibility1`).
3. **Rubriken "Vad kan Ear…" kapas** (`pro-dark-storsta-text-14-vad-kan.jpg`). Det är en stor navigationsrubrik. Den
   får brytas, eller använda den lilla rubriken vid största text.
4. **Raden "Mina svar / Lägg till ›"** står i två smala spalter med två rader var. Det går att läsa, men den ser
   trång ut. Förslag: "Lägg till" under "Mina svar" vid stora storlekar.

## Övrigt
- **iPhone SE:** allt får plats. Start utan prov visar Starta Earmind, lägesraden, Earmind kan allt med "Allt Earmind
  kan ›" och början på "Har du prov snart?" på första skärmen. **Bra.**
- **Exempelraderna byts med en övertoning.** På en SE-bild (`liten-light-11`) ligger två exempel ovanpå varandra
  mitt i bytet. Det är troligen bara bildtillfället. Med "Reducera rörelse" byts de enligt A50 utan rörelse.
  **Untested assumption** att det ser rent ut för en människa.
- Turens miss "Studiekort" på SE är turens egen rullning (känd sedan T9), inte appen.
- Vad kan Earmind? visar Förhör och Svar på frågor med "Inget att ställa in" och Mina svar med "I Provläget".
  Kalender, timer och resten ligger längre ner (`vad-kan-2`, `vad-kan-3`).

## Till Kelly
Fynd 1–4 är layout vid största text. Bilderna ligger i mappen, för granskning mot SYSTEM.md och Ke29/Ke30.

## Kvar
- En ny körning på main efter A60 (gren 77e9f6e) går nu: skärmturen i samma tre lägen och förstagångstestet (T8c).
  Den visar om "Earmind kom inte igång" syns och hur första passet slutar på Start.
- Den nattliga turen (03:30) tar alla sju lägen.
