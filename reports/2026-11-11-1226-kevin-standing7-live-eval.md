# Stående uppgift, omgång 7: nattens live-eval, fel som koden kan ta (Kevin, 2026-11-11 12:26)

Underlag: `reports/eval/2026-11-11.md`, nattens live-eval: 388 turer, 36 med anmärkning, cirka 0,93 USD (kördes av CI). Jag tog de anmärkningar där koden redan hade rätt svar men modellen läste upp det fel.

**Kostnad:** cirka 0,35 USD.
- Regressionen för `14ddf51`: 0,32 USD.
- Kontroller live: cirka 0,01 USD.
- ElevenLabs: 0.

## Gjort
| Fall | Före | Nu |
|---|---|---|
| tid-08 "vad är klockan i delhi när den är 14 här" | koden räknade ut 18:30, men modellen sa "tjugo över sex" (18:20) | **koden säger svaret**: "Klockan fjorton i Sverige är klockan arton och trettio i Delhi. Delhi är fyra och en halv timme före Sverige." |
| beräkning-09 "20 grader celsius i fahrenheit" | koden räknade ut 68, men modellen skrev "sextiotta" | **koden säger svaret**: "Tjugo grader Celsius är sextioåtta grader Fahrenheit." |
| "100 grader fahrenheit i celsius" | "trettiosju komma sju sju sju åtta" | "ungefär trettiosju komma åtta" |
| "vad är klockan i tokyo" | modellen | koden: "Just nu är klockan … i Sverige och … i Tokyo. Tokyo är åtta timmar före Sverige." |
| "sextiotta", "åttiotta" skrivna i ord av modellen | lästes upp | rättas i koden till "sextioåtta" och så vidare |

- `answer/calc.ts` `spokenComputed`: tidszoner och temperaturer besvaras nu av koden, utan modellanrop, som aritmetiken sedan 2026-11-08.
- Tidsskillnad utan klockslag och andra enhetsomvandlingar går fortfarande till modellen.
- `scripts/live-eval.py`: för tidszoner godtar förväntningen nu också "arton och trettio".

## Live (driftsatt)
- 4/4 rätt med `model: calc`: Delhi i Auto, 20 °C och 100 °F med tryck och prata, Tokyo i Auto.

## Regressionen
- 90,5 % för `14ddf51`. De två fall som föll är faktafel i historia: pl-071 Napoleon och pl-161 medeltiden.
- Inget av dem har med räknekoden att göra. Rådata ligger i artefakten `answer-regress`.

## Andra anmärkningar i nattens eval (inte tagna nu)
- **"Långsamt"** (16): recept och "hur gör man" går över 2,5 s, eftersom webbsökningen tar tid. Det är känt sedan K16.
- **"Källrad saknas"** (5, webb): det är en kontroll i eval-skriptet. Svaren säger källan i texten ("Källa: SVT").
- **webb-04** ("Also," på engelska) och **webb-03** ("(M)" i talad text) är **rättade efteråt** (`d41c139`, `f0e754b`):
  - ett engelskt "Also,", "However," och liknande i början av en svensk mening tas bort;
  - "(M)", "(S)" och så vidare efter ett namn i formen Förnamn Efternamn läses som partiet ("Ulf Kristersson, Moderaterna");
  - annars lämnas parentesen.
  - **Obs:** `d41c139` hade ett typfel som stoppade driftsättningen; `f0e754b` rättade det, och inget trasigt nådde servern.
- **socialt/minne:** "fråga tillbaka" (4). Det är avsiktligt i Socialt ("Vill du ta en fika?").

## Tester
`deno task test`: **459 gröna**, ny `answer/k_standing7_test.ts`.
