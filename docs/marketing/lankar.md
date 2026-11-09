# Länkar per kanal

Sidan läser `?utm_source=` eller `?ref=` (små bokstäver, a–z, 0–9, `_`, `-`, högst 32 tecken), sparar värdet i sessionStorage och skickar det som `source` med väntelisteanmälan. Utan värde skickas `direkt`. Inga cookies, ingen tredjepartsanalys. Bara anmälningar räknas (kolumnen `source` i väntelistan), inte besök.

Basadress: `https://aronstenlund-code.github.io/aronstenlund-airpods-ai/`

| Kanal | Länk |
|---|---|
| TikTok | `…/?utm_source=tiktok` |
| Snapchat | `…/?utm_source=snap` |
| Instagram | `…/?utm_source=insta` |
| Skolan (affisch, QR, lärare) | `…/?utm_source=skola` |
| Direkt/delad länk | `…/` (blir `direkt`) |

Egen kampanj: `?utm_source=tiktok_a` och `?utm_source=tiktok_b` skiljer två annonser åt.
Läsa resultatet: `select source, count(*) from waitlist group by source order by 2 desc;` (kör via Supabase MCP, inte för hand av Aron).
