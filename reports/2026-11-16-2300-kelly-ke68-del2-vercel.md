# Kelly (moln) Ke68 del 2: Vercel-adressen och ihopslagning (D202)

## Vad som gjordes
- På grenen `kelly/ke66-earmind-site` (7ee7df4): `python3 scripts/site/set-site-url.py https://earmind.vercel.app/`
  bytte canonical, og:url och og:image (index.html), sitemap.xml och robots.txt. Ingen `github.io` kvar i `site/`.
- **Grenen är ihopslagen med main** (9291d6d, på Arons uppdrag via Deangelo). Den ändrar bara `site/` och
  `scripts/site/`. Med det kom EarMind (Ke66), sidan som appen (Ke67), `vercel.json` och adressen ut. Push till main
  publicerar också på GitHub Pages (`pages.yml`), som ligger kvar tills Vercel är verifierad (D202).

## Inte gjort: kontrollen live
Molnsessionens nät släpper inte igenom `earmind.vercel.app` (proxyn svarar 403). Jag bad om att lägga till
`earmind.vercel.app` och Supabase-projektets adress i miljön, men det nekades. Därför är **200-svaret, sidans storlek,
og-bilden och väntelistan inte kontrollerade live** (untested). Lokalt på grenen: alla hänvisningar finns, `site/` är
1 572 kB, inga JavaScript-fel i Chromium (Ke67).

Så kan någon med nät kontrollera (eller Aron i webbläsaren):
1. https://earmind.vercel.app/ öppnas och rubriken är "Kom förberedd till provet."
2. https://earmind.vercel.app/og-earmind-v2.png visar delningsbilden.
3. Väntelistan: skriv en testadress (till exempel `test+ke68@example.com`), kryssa i rutan, tryck "Mejla mig när appen
   finns". Ett fel om CORS betyder att Vercel-adressen saknas i `CORS_ORIGINS` (Kevin, K80).

## Nästa steg
- Kevin K80: `https://earmind.vercel.app` i CORS_ORIGINS.
- Deangelo/Toby/Oscar (någon med nät till adressen): kontrollerna ovan.
- Ke68 stängs här från min sida; liveverifieringen står i STATUS som öppen.
