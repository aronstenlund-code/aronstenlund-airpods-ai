# Ke9: enkel väg in, appen och demosidan som en produkt (Kelly, 2026-11-10)

Kort: del 1 (designunderlag för appen) gjordes i går, `reports/2026-11-09-2300-kelly-ke9-delvis.md`. Del 2 (demosidan) är
gjord nu. Sidan har en enda väg och är hälften så lång på mobil. Lighthouse ger 100 i alla fyra kategorierna.
**Ej provat i Safari eller på iPhone.**

## Vad som gjorts
**Del 1, appen** (`docs/design/enkel-start.md`, bilder i `docs/design/bilder/`): förslag skärm för skärm till Angela (A18).
- Första svaret nås på 2 tryck, både i dag och i förslaget.
- Fram till Start: i dag 5 tryck och ett formulär med 19 val, i förslaget 4 tryck och inget formulär.
- Startskärmen och Lyssnar får en enda blå knapp: "Förhör mig".

**Del 2, demosidan** (`site/index.html`):
1. **En väg:**
   - Demon ("Prova här").
   - **Så kommer du igång** i 3 steg med appens ord och riktiga T3-bilder:
     1. Tryck Testa nu och fråga högt (ny bild från T3 bild 05).
     2. Säg vilket prov du har, *"Jag har prov i biologi på fredag"*.
     3. Säg "Lumen, förhör mig".
   - **En knapp:** "Mejla mig när appen finns" (väntelistan, rubrik "Vill du ha appen?").
2. **Borttaget:** punktlistan i heron, animationen (Ke3), de tre skärmbildskorten (Ke8) och "Kommer i appen". "Tryck på
   Starta" är borta, eftersom den knappen inte finns i appen.
3. **Mer när du vill:** fyra hopfällda rader, med samma text som förut.
   - Egna röstkommandon.
   - Lägg in ditt material i förväg.
   - Hör tre svar från Provläget, med Lyssna-knapparna kvar.
   - Fler lägen: Intervju, Socialt och Rizz 18+.
4. **Samma produkt:** typsnitt och färger var redan desamma (Familjen Grotesk, Kalam, `#2346C8`, rutpapper). Lägesnamnen
   följer appen (Intervju, Socialt, Rizz 18+).
5. Bilderna `steg2`, `egna` och `forb` är borttagna. Ny bild: `fraga-light/dark.webp` (9 kB).
6. Samtyckes- och integritetstexterna är oförändrade, så `CONSENT_VERSION` behövde inte höjas.

## Mätt (verifierat lokalt i Chrome, `python -m http.server`)
| | Före | Efter |
|---|---|---|
| Sidans höjd, mobil 390 px | 8 533 px | 4 226 px |
| Uppmaningar som drar åt olika håll | 4 (demo, steg, röstkort, väntelista) + 6 Lyssna/Visa | 2 (demo, väntelista); resten hopfällt |
| `site/` | 1 767 kB | 1 731 kB |
| Lighthouse mobil | 100/100/100/100 (Ke8) | 100/100/100/100, LCP 1,7 s, CLS 0 |
| Lighthouse dator | 100/100/100/100 | 100/100/100/100, LCP 0,4 s, CLS 0 |
| Överflöd i sidled vid 390 px | – | ingen (`scrollWidth` 390) |

Också provat i Chrome (puppeteer):
- "Hör tre svar" öppnas, och "Visa hela svaret" fäller ut svaret (`aria-expanded` true).
- `data-app` fylls i inne i de hopfällda raderna.
- Konsolen visar inga fel.

## Bilder (`reports/2026-11-10-ke9-sida/`)
- `jamforelse-mobil-light.png`, `jamforelse-mobil-dark.png`: före och efter sida vid sida.
- `fore-*` och `efter-*`: mobil och dator, ljust och mörkt.
- `efter-mobil-mer-oppen.png`: "Hör tre svar" utfällt.

## Kvar och risker
- Inte provat i Safari eller på iPhone (scrolleffekten och `<details>` i iOS Safari).
- Skärmbilderna i stegen är från före A13. När A18 är byggd ska de bytas mot nya bilder från Toby.
- FAQ-datan (JSON-LD) står kvar oförändrad. Svaren stämmer med sidan, men Rich Results-testet mot live-URL är inte gjort.

## Till Aron
- D57: "Dela historik" frågas i dag i första starten. Förslaget är att fråga när första passet är slut (från del 1).
- Byt "Få A-svar till provet" mot "Förhör mig" på Start (från del 1).
- Sidan visar inte längre Ke8:s skärmbildskort om egna kommandon och förberedelser. Texten finns kvar under "Mer när du
  vill". Vill du ha korten tillbaka går de att återställa ur git.

## Concerns
Inga nya.

## Nästa
Kön är tom efter Ke9. Stående uppgift (PLAN 2b): sidan och appen som samma produkt.
