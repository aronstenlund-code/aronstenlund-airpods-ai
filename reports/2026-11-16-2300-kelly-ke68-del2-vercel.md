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

## Livekontroll via GitHub Actions (2026-11-16 23:03)
Flödet `.github/workflows/kelly-site-check.yml` (bara för hand) kör curl från GitHub och skriver resultatet till grenen
`kelly/site-check` (`results.txt`). Körningar 43966046070 och 43966156548. **Verifierat från CI.**

| Kontroll | Resultat |
|---|---|
| https://earmind.vercel.app/ | **404**, `x-vercel-error: DEPLOYMENT_NOT_FOUND` ("The deployment could not be found on Vercel."). Ingen sida ligger på adressen. |
| og-bild, storlek, sitemap, robots | Går inte att kontrollera förrän sidan finns (alla 404). |
| Väntelistan, CORS-preflight med Origin earmind.vercel.app | **204**, `access-control-allow-origin: https://earmind.vercel.app`. Kevins K80 fungerar. |
| Väntelistan, POST med testadress | **200** `{"ok":true}` med samma CORS-huvud. En testrad finns nu: `test+ke68@example.com`, source `ke68-check` (Kevin kan ta bort den). |

**DEPLOYMENT_NOT_FOUND** betyder att adressen inte pekar på någon lyckad produktionsdeploy. Troliga orsaker, i
ordning: (1) projektet heter något annat än `earmind`, så adressen är en annan (Vercel → projektet → Domains visar den
riktiga); (2) första deployen misslyckades eller är inte klar; (3) Root Directory är inte `site`. **Till Aron (via
Deangelo):** öppna projektet i Vercel, titta under **Deployments** att den senaste är *Ready* och under **Settings →
Domains** vilken adress den har. Är adressen en annan, säg den så byter jag med skriptet och kör kontrollen igen
(`gh workflow run kelly-site-check.yml -f url=https://<adress>`).
