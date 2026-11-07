# Deangelo – överlämning till ny session (2026-11-07 14:45)

Läs först: `reports/2026-11-06-1845-deangelo-handoff.md` (roller, överenskommelser, infrastruktur). Den här filen lägger bara till vad som hänt sedan dess.

## Läge
- **Backend live sedan 2026-11-07 14:30** via GitHub Actions `.github/workflows/deploy-backend.yml` (tester först, sedan alla 9 funktioner till `xjczbzfkmbjdebwlccki`, smoke-test 403). Repo-secret `SUPABASE_ACCESS_TOKEN` (Aron), token scoped: bara Lumen, Edge Functions read-write + Project Settings read, giltig 30 dagar (förnyas ca 2026-12-07). `supabase-lumen` MCP behövs inte längre för funktioner.
- Migrationer D57/D62 applicerade av Deangelo via Supabase MCP (projekt Lumen).
- Verifierat live: datum utan systemformulering, inget gissat spärrnummer, social/flirt första förslag 1,0–1,4 s, flirt utan `adult_confirmed` = 403. Flirt lät för likt social → D69.
- Testlänk: https://raw.githack.com/aronstenlund-code/aronstenlund-airpods-ai/c2ce9a9/backend/webtest/index.html (byt commit när webtest ändras).

## Beslut sedan förra överlämningen
D63 (Rizz flirt-only 18+, Socialt läge), D64–D68 (Kevin/Kelly/Angela), **D69** (Rizz alltid flirtig+rolig+självsäker, röstkalibrering `social.calibrate`, Socialt läge = skämt på det gruppen sa, byte med röst), **D70** (osignerad .ipa från CI + Sideloadly på Windows för första enhetstestet).

## Köer
- Angela: D70 först (ipa + `docs/INSTALL-SIDELOADLY.md`), sedan D69.
- Kevin (ny session, Opus high): D69, prompt caching (cache_read_tokens var 0), labbfunktioner → 410, sedan Oscars omgång 2.
- Oscar (Sonnet): omgång 2 mot live.
- Kelly: vänta; publicera demosidan efter Oscars godkännande.

## Aron
- Vill ha korta svar, hela prompter, inga SQL/CLI själv. Nickfunktion D60 bestämmer han själv. Appnamn ej bestämt.
- Rekommenderat tokensparande: Oscar/Kelly på Sonnet, nya sessioner per uppgift, stäng onödiga kopplingar.
