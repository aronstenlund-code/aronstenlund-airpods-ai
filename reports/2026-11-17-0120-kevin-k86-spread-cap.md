# Kevin (moln): K86 – spridning och eget tak (D207) – 2026-11-17 01:20

Driftsatt i `4437862`, plus en kontroll av nästan likadana frågor i commiten efter. **0 ElevenLabs** (bara Claude, testkonton).

## Vad som byggdes (`exam/coverage.ts`, `exam/drill.ts` efter steg 1)
- **Eget tak:** `codeCap` ger 1 fråga per 600 tecken, högst det användaren bad om. Målet är det högsta av modellens tak (`questions_possible`, D159) och kodens tak. Raden "Materialet räckte till N frågor" visas bara när färre än det begärda till slut kom fram.
- **Andelar:** `shares` delar målet mellan delarna efter deras längd (störst rest först). Varje del får minst en så länge det räcker, och med tre eller fler delar kommer **högst hälften från en del**. Med två delar gäller längden (D207).
- **Urval:** steg 1 ger redan 6 reservfrågor utöver antalet. De placeras först (TF-IDF, K85), och varje del behåller sina första upp till sin andel (`allocate`, svaga frågor sist). En del som fortfarande har för få får **ett eget anrop** som bara ser den delen.
- **Samma kontroller** för alla frågor: `cleanQuestion`, ingen fråga som lutar sig mot materialet, inga dubbletter och nu också inga **nästan likadana frågor** (`nearDuplicate`, minst 75 % av innehållsorden gemensamma). Bara koden avgör, och inget slumptal kommer från en modell.
- `usage.coverage` har nu också `target` och `max_share` (största antalet frågor från en del).
- `fetch-url` ingår nu i `deno task check`.

## Mätning (`scripts/k83-coverage.py`, run 43985023956, 4 material × 2 körningar, 12 frågor, nytt testkonto per körning)
| Material | Delar | Täckta före → efter | Flest frågor från en del (före K86 → nu) | Frågor |
|---|---|---|---|---|
| bio-fotosyntes | 2 | 2 → 2 | – → 7 (två delar: efter längd) | 12, 12 |
| SO: tre material i rad | 3 | 2 → 3 | 10 → 5 | 12, 12 |
| NO: tre material i rad | 4 | 2–3 → 4 | – → 3 | 12, 12 |
| Wikipedia "Fotosyntes" | 6 | 4–5 → 6 | – → 2 | 12, 12 |
| **Summa** | **30** | **21 → 30** | | **96 av 96** |

- SO-fallet, som var 10/1/1 (Oscars O73 och min K83-körning), blev 4–5/4/3–4.
- Alla 8 genereringar gav 12 frågor (Oscar såg 6 av 12 i 3 av 12 genereringar).
- Kostnad: 0,023 USD för 8 genereringar (cirka 0,003 USD var). Tid: 7–14 s.
- Data: `reports/qa/data/2026-11-17-000903-k83-coverage.json`.
- I den mätningen fanns två nästan likadana frågor från de kompletterande anropen ("Varför är/blir det kallare vid polerna", två om Golfströmmen och Kanada). Därför kom kontrollen `nearDuplicate` till efteråt. Den är **inte** livemätt ännu, bara testad i kod.

## Tester
`exam/coverage_test.ts`: andelarna (lika, en lång del får högst hälften, två delar efter längd, färre frågor än delar), kodens tak, `allocate`, nästan likadana frågor och `handleDrill` med en modell som ger 10/1/1, vilket blir 12 frågor i tre delar med högst 6 från en. `deno task test` 668/668.

## Begränsningar
- Placeringen bygger fortfarande på ord (TF-IDF). En fråga med helt andra ord än materialet kan placeras fel.
- För foton utan text bygger delningen på anteckningarna.
- Fler kompletterande anrop för långa material (upp till ett per del, parallellt). Kostnaden är fortfarande under 0,01 USD per generering.

## Nästa
Oscar O74 omtestar (`o73_coverage_live.py`).
