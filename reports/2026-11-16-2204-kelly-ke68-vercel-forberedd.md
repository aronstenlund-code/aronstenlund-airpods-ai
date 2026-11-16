# Kelly (moln) Ke68: demosidan redo för Vercel (D202), del 1

## Vad som gjordes (grenen `kelly/ke66-earmind-site`, eeb738c, inte publicerat)
- **Adressen på ett ställe:** `site/site-url.txt` håller sidans adress. `scripts/site/set-site-url.py <ny adress>` byter
  den i canonical, og:url, og:image (index.html), sitemap.xml och robots.txt. Metataggarna står kvar som vanlig text,
  eftersom delningstjänster och sökmotorer inte kör JavaScript; en JS-konstant hade inte räckt. Provat på en kopia med
  `https://earmind-test.vercel.app/`: 3 + 1 + 1 ställen bytta, ingen gammal adress kvar.
- **`site/vercel.json`** (Vercel-projektets rot är site/): `cleanUrls`, och cache en dag (+ en vecka stale-while-revalidate)
  för img/, audio/, favicons och delningsbilden. Inga typsnitt finns längre (Ke67). Filen är ofarlig på GitHub Pages.
- Pages-kontrollen i `pages.yml` körd lokalt på grenen: alla lokala hänvisningar finns, inga absoluta sökvägar,
  site/ är 1 572 kB (under 2 MB).

## Inte gjort, och varför
- **Ihopslagning med main:** `site/**` på main publiceras direkt på GitHub Pages (`pages.yml`). Grenen innehåller
  EarMind (Ke66) och den nya sidan (Ke67), och Aron har inte sagt ja till att publicera dem (#18). D202 säger att Pages
  ligger kvar tills Vercel-sidan är verifierad. **Till Deangelo/Aron:** slå ihop när Aron säger ja, eller koppla Vercel
  direkt till grenen (Vercel → Project → Settings → Git → Production Branch: `kelly/ke66-earmind-site`), så publiceras
  bara Vercel och inte Pages.
- **Byta adressen, kontrollera 200, storlek, og-bilden och väntelistan:** väntar på att Aron skapar Vercel-projektet
  (TILL-ARON #23). Väntelistan kräver också att Vercel-adressen läggs i Supabase-hemligheten `CORS_ORIGINS` (Kevin, K80).

## Nästa steg
När adressen finns: `python3 scripts/site/set-site-url.py https://<adress>/` på grenen, push, och kontrollera live
(200-svar, sidans storlek, og-bilden, väntelistan med en testadress). Ke68 står kvar öppen i kön till dess.
