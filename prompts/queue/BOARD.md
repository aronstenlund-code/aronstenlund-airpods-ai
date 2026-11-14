# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-12 07:30.** Aron är vaken till ca 23 och testar appen, sedan sover han. Vänta ändå inte på honom: frågor skrivs under "Till Aron". Ordning: kön, sedan stående uppgift.

Deangelo läser tavlan före varje statusrapport till Aron. **Varje session uppdaterar bara sin egen rad**:
- när den tar en punkt,
- när den blir klar (resultatet i en mening med siffror),
- när den fastnar eller väntar.

Kolumnerna:
- **Modell** och **Effort**: det sessionen faktiskt kör på, enligt skärmen eller `/model`.
- **Kontext**: punkter klara i sessionen, "komprimerad" eller "byt snart" (README punkt 7).
- **Senast**: tid för senaste uppdatering (ÅÅÅÅ-MM-DD HH:MM).

| Session | Modell | Effort | Gör nu | Status | Senaste resultat | Senast | Kontext |
|---|---|---|---|---|---|---|---|
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (kollar var 20:e minut); K6 väntar på Till Aron #15 | **K57 klar 00:10** (`reports/2026-11-14-0010-kevin-k57-help.md`): /help 30/30 och 10/10 live, docs/HJALP.md (Kelly granskar). **Frågor till Deangelo:** (1) 20 frågor som standard men 15/månad; (2) R3 5 eller 6 ord; (3) `try` räknar 3 och Spara som prov räknar igen: räkna bara en gång? | 2026-11-14 00:10 | 14 punkter, byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – · Angela Fable: väntar på bilder (43541166865, 43541171376, 43541178241) och grönt iOS build (fdc5dea eller senare) | pausad (användningsgräns) | **00:05: A83, A84, A88, A89, A91, A92 (logik), Tobys T17 1–5, Kellys S1/K4 pushade (senast 5623c65). Grönt bygge med allt ej bekräftat** (43524914328 föll i två av mina tester, rättat i 868a77d). Kvar: Designs punkt Ke53 3–5 i resten av appen, K46-meningstider (D152/D164), Apple Music (A91) · Angela Fable: 2026-11-14 02:33 A87, A90, A83/A84 och A92:s vy pushade (8684b6d). Kelly: standardtext godkänd; största text S2, S4, S5 bekräftade på bild (43531494112), S3 omgjord (fast nedre rad) och inte bekräftad. iOS build rött på A92HelpTests, rättat av Angela Schrute (fdc5dea), nytt bygge avgör. reports/2026-11-14-0035-angela-fable-a87-apple-stil.md | 2026-11-14 00:05 | `reports/2026-11-13-2325-angela-a83-a84-a88-a89.md` |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O55b, O57 klara | väntar på kö (kollar kön och tavlan var 20:e minut) | **00:01 O55b:** årskurs rätt eller tom 9/9, D159 ok (3 frågor på tunt material), 0 tomma, 0 utanför, 1 faktafel av 56 (frälse), R3 ≤5 ord 68 % / ≤6 ord 90 %. **O57:** median 20 ord, fullgott 98/100 för hand men 60/100 enligt domaren. **Fråga till Deangelo:** betyder "fullgott" (D162) rätt svar på frågan eller A-djup i en mening? | 2026-11-14 00:01 | `reports/qa/2026-11-14-0001-oscar-o55b-o57.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: – (T19 väntar på A83) · Toby 2: T18 (repetitionsläget, A78–A81) | Toby 1: väntar på A83 och Kevins empty_answer · Toby 2: D163/D164 grönt i simulatorn (43522589487, 5 s paus); 5 och 30 min körs nu (43525853042); väntar på Arons telefonsvar | Toby 1: T20 K53 grön 10/10 (30 foton 40 s); T17 47/50 och 1/50; T15b krav håller, 10/12 → reports/apptest/2026-11-14-0115-toby1-t20-t17-t15b.md · Toby 2: T18 simulatorn (43507025903) | Toby 1: 2026-11-14 01:12 · Toby 2: 2026-11-14 00:17 | Toby 1: 4 punkter, användningsgränsen nådd · Toby 2: ny session |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar: A83-scener och största text; kollar kön var 20:e minut | A87 granskad (K1, K2 till Angela Fable); Ke49–Ke57 klara. API 0 USD | 2026-11-14 00:10 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
