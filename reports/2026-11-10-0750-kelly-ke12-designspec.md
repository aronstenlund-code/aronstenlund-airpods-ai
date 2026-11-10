# Ke12 (stående uppgift): gemensam designspec för appen och sidan (Kelly, 2026-11-10)

Kort: `docs/design/designspec.md` ställer appens och sidans värden bredvid varandra (färger, typsnitt, knappar, kort,
rutpapper).
- Alla 11 gemensamma färger är lika i ljust och mörkt.
- Två skillnader är rättade på sidan.
- Två punkter går till Angela.
- Lighthouse mobil ger 100/100/100/100.

**Ej provat i Safari eller på iPhone.**

## Rättat på sidan (`site/index.html`)
1. **Tysta knappar som appens sekundära:** "Stoppa" i demon och i exemplen var röd, och "Ställ en ny fråga" var vit med kant.
   - Båda har nu appens `chip`-yta och bläck-text, med en tunn kant så att de syns på rutpappret.
   - Rött används bara för fel, som i förslaget för appen.
   - Bilder: `reports/2026-11-10-ke9-sida/ke12-stoppa-light.png`, `-dark.png`.
2. **Väntelistans knapp:** texten är nu 18 px semibold som appens knappar (förut 17 px).

## Till Angela (i `designspec.md`)
1. Röd Avsluta blir en tyst Klar på Lyssnar (står redan i Ke9/Ke10-underlaget).
2. Elias i introt: behåll den frilagda stillbilden. Kortet behövs bara om den byts mot en bildruta ur sekvensen.

## Mätt
- Lighthouse mobil: 100/100/100/100.
- `site/`: 1 731 kB.
- Exemplets knapp byter till "Stoppa" med klassen `stop` och chip-utseende, provat i Chrome (puppeteer) i ljust och mörkt.

## Till Aron
Inget nytt.

## Concerns
Inga.
