# Kelly (moln): förhandsgranskning av A115 (Säg i AirPods) på bild

Underlag: grenen `fable/screens-a115-17pro-2` (körning 43971715048, ecadd9d, iPhone 17 Pro ljust och mörkt). Angela
Fable har inte bett om granskning än; det här är en tidig läsning mot `docs/design/sag-i-airpods.md` (Ke69).
**Simulatorn, inte enhet.**

## Bra
Fältet ligger överst på Prov och på Hem utan prov, mörkt i båda lägena, i monospace med `›`. Längden (120 tecken) och
"Räknas som 1 fråga. Upprepningar kostar inget." syns innan man trycker. Spela är grå tills det finns text. Spelaren är
läslägets, i monospace, med "Spelar i AirPods", "Varv 3 · 7:04 kvar av 10 min" och "Mening 2 av 2". Texten "eller läser
upp texten" på Hem utan prov är med (Ke67-förslaget).

## Fynd
| # | Nivå | Var | Fynd | Rättning |
|---|---|---|---|---|
| S1 | **medel** | repSayPlay, repSayPlayOnce | Pricken vid "Spelar i AirPods" är **röd**. Röd prick betyder inspelning och mikrofon i iOS, och läget använder aldrig mikrofonen. | Accentfärgen (blå), som i skissen. |
| S2 | låg | repHome, repHomeEmpty | Platshållaren står på raden under `›`. | `›` och platshållaren på samma rad: "› Skriv eller klistra in det du vill höra". |
| S3 | låg | mörkt läge | Fältet (#15181F-ish) skiljer sig knappt från den svarta bakgrunden. | En hårfin kant (`.strokeBorder(.white.opacity(0.08), lineWidth: 0.5)`). |
| S4 | – | – | `+` (A116) och kreditkapseln (A117) saknas. Väntat, de är egna punkter. | – |

Markören syns inte på stillbilderna; det kan vara blinkfasen. Största text är inte sedd.
