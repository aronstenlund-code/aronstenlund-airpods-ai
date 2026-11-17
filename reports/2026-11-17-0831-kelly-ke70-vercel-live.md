# Kelly (moln) Ke70: livekontroll av earmind.vercel.app

Körning 44039239887 av `.github/workflows/kelly-site-check.yml` (curl från GitHub Actions, resultat på grenen
`kelly/site-check`). **Verifierat från CI**, inte i Safari eller på iPhone.

| Kontroll | Resultat |
|---|---|
| https://earmind.vercel.app/ | **200**, 82 176 byte HTML, `server: Vercel` |
| Titel och rubrik | "EarMind: plugga med AirPods utan att röra mobilen" / "Kom förberedd till provet." (Ke67) |
| canonical och og:image | `https://earmind.vercel.app/` och `https://earmind.vercel.app/og-earmind-v2.png` |
| "Earmind" med litet m | 0 |
| Delningsbilden | **200**, PNG 1200 × 630, 105 234 byte |
| Allt sidan hänvisar till (även bilder som laddas sent) | 267 038 byte, inga saknade filer. Elias-sekvensen som skriptet laddar efteråt räknas inte här. |
| Cache på bilder | `public, max-age=86400, stale-while-revalidate=604800` (vercel.json fungerar) |
| sitemap.xml och robots.txt | 200 och 200 |
| Väntelistan, CORS-preflight från earmind.vercel.app | **204**, `access-control-allow-origin: https://earmind.vercel.app` |
| Väntelistan, POST med testadress | **200** `{"ok":true}` med samma CORS-huvud |

## Fynd
Inga. Sidan är live på Vercel med EarMind, den nya texten och fungerande väntelista.

## Att städa
- Testraden i väntelistan: `test+ke68@example.com` (source `ke68-check`, två anrop: 22:02 och 08:30). Kevin kan ta bort den.
- GitHub Pages (`pages.yml`) publicerar fortfarande samma sida. Enligt D202 kan Pages stängas nu när Vercel är
  verifierad (Deangelo/Aron: Settings → Pages → Source: None, eller ta bort deploy-jobbet).

## Nästa steg
Granska Angela Fables text för A122 (D209) när hon säger till.
