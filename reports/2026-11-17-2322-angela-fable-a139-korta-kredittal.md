# A139 (D222): korta kredittal, och en rättning av ljudtaket (Angela Fable, moln)

Klart 2026-11-17 23:22. **Verifierat i CI, inget på enhet och inget sett på bild.** 0 ElevenLabs (D180).

## A139: en formatterare för alla kredittal
| Tal | Saldo (avrundas nedåt) | Kostnad (avrundas uppåt) |
|---|---|---|
| 999 | 999 | 999 |
| 1 000 | 1,0k | 1,0k |
| 1 251 | 1,2k | 1,3k |
| 5 392 | 5,3k | 5,4k |
| 9 999 | 9,9k | 10k |
| 10 000 | 10k | 10k |
- Används i kapseln ("5,3k krediter kvar"), kostnaden vid Spela ("1,3k krediter", "5,4k krediter · du har 1,2k"),
  provkortet och provets skärm ("Kostar 2,4k krediter"), "räcker inte"-raden och raden i Nytt prov ("1,2k av 1,5k
  krediter kvar den här månaden"). Det exakta talet står i kreditbladet.
- **Kapseln säger "Veckokort"** när kvotsvaret har `subscription.active: true` (Kevins K94) och **"Obegränsat"** för
  `unlimited: true` (admin går före).
- **Aron sa "5392 ska stå som 5,4".** D222 avrundar saldot nedåt, så kapseln visar "5,3k"; samma tal som kostnad
  visas "5,4k". Vill Aron ha 5,4 också för saldot är det en ändring av D222.
- Kelly har godkänt talen. Hon vill hellre ha raden i Nytt prov utan "den här månaden" om den blir för lång i största
  text; det är inte ändrat och inte sett på bild.

## Rättning av A135: ljudtaket hämtade om det som just tagits bort (Angela Schrutes fynd)
Över 500 MB tog Start bort de äldsta ljudfilerna och hämtade sedan samma filer igen, vid varje besök. Nu märks ett
prov som tappat ljud för utrymmets skull (`Drill.audioTrimmed`) och hämtas inte om förrän det startas; då hämtas
ljudet och spelaren väntar på det. Kortet och provets skärm säger "Ljudet hämtas när du startar" i stället för en
räknare som står still, och Starta prov är tryckbar. Rensningen rör bara ljudfiler.
- Kellys kortare rad efter 10 sekunder utan ljud: "Ljudet kunde inte hämtas. Kolla nätet."
- Orden "Ljudet hämtas när du startar (provet)" är mina; Kelly har inte sett dem.

## Tester
- **iOS build 44164755738 grön på min gren** (enhetsbygge, varningar som fel, LumenTests).
- **A135/A133/K92 på main: iOS build 44164099966 grön.**
- Nya tester i `LumenTests/A122LockedPhoneTests.swift`: gränserna för de korta talen (999, 1 000, 1 251, 5 392,
  9 999, 10 000 m.fl., nedåt och uppåt, aldrig "10,0k"); samma formatterare i kapseln, vid Spela och i "räcker inte";
  exakt tal i bladet; kapseln "Veckokort" med prenumeration och "Obegränsat" för admin; ljud som rensats hämtas inte om
  förrän provet startas.

## Otestat (antaganden)
- Inget är sett på bild (talen kräver en scen med över 1 000 krediter; scenerna har 1 236, så kapseln där blir
  "1,2k krediter kvar").
- Prenumerationsfälten finns på servern först när Kevins databasändringar är körda (Deangelo); inget riktigt svar med
  `subscription` har gått genom appen.
- Inget på enhet.

## Nästa session
- A136 (stil, Skriv i takt, röster): Kevin har svarat på fälten (ordtider i `audio.text.words`, `drill.style`,
  `drill.voice_id`, `/voices` med `catalog`). Sedan A140, A141 och A134.
