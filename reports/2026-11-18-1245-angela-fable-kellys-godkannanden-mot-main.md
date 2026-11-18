# Kellys godkännanden mot main (Angela Fable, moln; körs nu på Opus 5.5)

Klart 2026-11-18 12:45. **Verifierat i CI: iOS build 44285655746 grön på min gren (enhetsbygge, varningar som fel,
LumenTests), och sett på bild i Simulatorn (flödet 44285655775). Inte provat mot servern och inte på enhet.**
0 ElevenLabs.

Deangelo bad mig gå igenom Kellys senaste granskningar (`docs/design/sag-i-airpods.md`, `kop.md`,
`stil-och-roster.md`) mot det som finns på main och rätta det som avviker från det hon godkänt.

## Det som avvek, och är rättat
1. **Senaste-kapseln nämnde standardrösten.** Kelly (stil-och-roster.md, svar på A136 punkt 2): "· {röstnamn}" bara
   när rösten inte är standardrösten. Nu står inget tillägg för standardrösten.
2. **Raden efter serverns nej (402).** Kelly (kop.md §2): "Vid 402 från servern: samma rad", alltså
   "120 krediter · du har 88 · Fyll på". Appen visade serverns text med en separat Fyll på-knapp under. Nu visas
   samma rad som före Spela när krediterna är kända; när den nya krediten kommer står i bladet som Fyll på öppnar.
   Utan köpdel (testläget) eller när krediterna inte är kända visas serverns text som förut.

## Det som stämmer (kontrollerat mot koden)
Alla rader i texttabellerna finns ordagrant, med de senare besluten inräknade (korta tal D222, "krediter kvar" när
köp finns, Kellys A140-ord, väntraderna i A144). Gamla rader i sag-i-airpods.md som ersatts av Ke72 och D222
(t.ex. "Kostar 764 krediter. Upprepningar kostar inget.") räknas inte som avvikelser.

## Bilder till Kelly
`reports/2026-11-18-granskning-bilder/vantar-senaste-402.jpg`: 8 s-läget (raden medan snurran går, som hon bad om) ·
Senaste (standardrösten utan tillägg, kapseln med stil hamnar delvis utanför skärmen) · raden efter 402.

## Också i samma push
- K100-tillägget: en text som skickas igen efter en tidsgräns svarar servern på med det sparade provet utan att
  starta det; appen startar det då (Kevins besked). Test i `A136StyleVoicePaceTests`.
- Scenerna `repSayWaiting`, `repShopRefused`.

## Kvar
A147 (värm /drill när appen öppnas) görs direkt efter detta.
