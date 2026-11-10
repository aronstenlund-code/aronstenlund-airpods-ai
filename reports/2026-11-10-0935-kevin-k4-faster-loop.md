# Kevin K4: Snabbare förbättringsloop

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K4 · Driftsatt (Deploy backend 42783098943 med förebildssvaren, commit cff70e7) · **Verified live** där inget annat står.

## Resultat
| Del | Status | Siffror |
|---|---|---|
| 1. Varje backendändring som rör svar körs mot ett urval ur D87 i CI, och resultatet skrivs i en commitkommentar | **Klar, verified live** | Nytt jobb `regress` i `deploy-backend.yml`: 21 fall (vart tionde), Sonnet svarar och bedömer, efter varje driftsättning som ändrar `answer/`, `_shared/` eller `provlage-eval/`. Första körningen kommenterade commit cff70e7: "första svaret räcker **95,2 %** … kostnad 0,312 USD". Ett nytt push avbryter en pågående körning, och `[skip eval]` hoppar över den |
| 2. 8–12 förebildssvar för Provläge i den cachade prompten, mätt före och efter | **Klar, verified live** | 10 förebilder (`TUTOR_EXAMPLES`). Ämnena finns med flit inte i D87-banken: enzym, reformationen, en felhörd "glaciär", en följdfråga om hjärnan, primtal, past tense, kolonialism, rättegång, en textuppgift och sonett. Samma 30 fall: första svaret räcker **90,0 % → 93,3 %**, naturligt språk **73,3 → 80,0 %**, rätt längd **16,7 → 40,0 %**, ord p50 127 → 114, första text p50 1 417 → 1 236 ms, kostnad per svar 0,0112 → 0,0095 USD |
| 3. Riktiga fel blir testfall varje natt (anonymiserat) | **Byggd, väntar på en hemlighet** | Nytt flöde `reported-cases.yml` (02:47 UTC) med `scripts/reported-cases.py`. De 15 senaste "det där var fel"-rapporterna som inte är behandlade ställs igen och bedöms. **Bara siffror sparas**, ingen text och id:n hashade. Provkört: stoppade med en tydlig varning, eftersom `SUPABASE_ACCESS_TOKEN` inte får läsa tjänstenyckeln (403) |
| 4. Kunskapskrav från Skolverket som underlag | **Undersökt, inte byggt** | Se nedan |

Filer: `reports/eval/provlage-2026-11-10-sonnet-k4-before-sample.*` och `…-k4-after-sample.*`.

## Om del 3: varför bara siffror
Rapporterna innehåller användarens egna ord, och D80 raderar dem efter 90 dagar. Att lägga in dem i git som testfall skulle spara dem för alltid. Därför körs de igen varje natt medan de finns, och bara utfallet sparas. Delningshistoriken (`shared_history`) används inte, eftersom den med flit inte är öppen för admin (D57).

## Om del 4: Skolverkets texter
- URL 9 § undantar författningar och myndighetsbeslut från upphovsrätten (lagen.nu, Ds 1999:7; KTH:s genomgång). Kursplanerna för grundskolan är föreskrifter (SKOLFS), och då bör de få citeras fritt. Det är verifierat i allmänna källor, men Skolverkets egna villkor har jag inte läst (**untested assumption**).
- Nästa steg: korta utdrag ur "betygskriterier för A" per ämne och årskurs (Lgr22) och per gymnasiekurs, i en fil i `answer/`, skickade med profilen som `<criteria>`. Mät som i del 2.

## Till Aron
- **För del 3**, lägg in hemligheten så att natten kan läsa felrapporterna. Klickväg: Supabase → Project Lumen → Project Settings → API Keys → kopiera `service_role` (eller secret key). Sedan GitHub → repot → Settings → Secrets and variables → Actions → New repository secret → namn `SUPABASE_SERVICE_ROLE_KEY`, och klistra in nyckeln.
- **Kostnad:** regressionen kostar cirka 0,3 USD per driftsättning som rör svar (i dag 5–10 stycken), och natten cirka 0,2 USD. Säg till om taket ska vara lägre, till exempel 10 fall.

## Kostnad
Ungefär 1,2 USD (två körningar av 30 fall och den första regressionen).
