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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön klar utom K6) | väntar på kö; K6 väntar på Till Aron #15 | **K52 klar 23:35** (`reports/2026-11-13-2335-kevin-k52-o55-month-limit.md`): 15/månad, 0 tomma svar av 199, signal per röst. **Fråga till Deangelo:** R3 "högst 5 ord" ger 65 %, "högst 6 ord" 83 % (fragment som "Mol metan i 16 g?" när den pressas). Ändra kravet till 6 ord? K51 klar 22:50 (Arons 22:13 = 502 + 413, orsak i A85) | 2026-11-13 23:35 | 10 punkter, byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | A85 (falskt "Ingen internetanslutning"), A86 | arbetar | **A85+A86 pushade 22:29 (dbfa91f), iOS build kör.** Trolig orsak till A85: sidorna blev 4 800 px (skärmens 3× i UIGraphicsImageRenderer), flera MB per foto, och anslutningen bröts. Nu 1 600 px och högst 1,2 MB per sida, ett nytt försök vid bruten anslutning, "Ingen internetanslutning" bara utan nät (NWPathMonitor), orsaken loggas. Kellys B1–B5 i 270b0a0. Förra gröna bygget med ipa: 43505582385 | 2026-11-13 22:30 | ny session |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O55a, O55, O56 klara | nästa: O55b (5 nya hållout-prov) efter Kevins rättningar | **21:36 O55:** R1 ok (20 s), R5/R5b/R5c 33/33, R10 Claude 0,063 USD/prov, ElevenLabs ~0,94 USD/prov listpris; **till Kevin:** årskurs 'åk 8' 5/10, R3 ≤5 ord 75 % och förståelse 66 %, 1 tomt svar (prio 1), 3 små faktafel, frågor som kräver materialet. **O56 R12 4/4**, sök 0,3 s, RLS håller. Domaren 20/20. API ca 2,3 USD, ElevenLabs 1 154 tecken | 2026-11-13 21:36 | `reports/qa/2026-11-13-2136-oscar-o55-o56-repetition.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: T15b och T17 (BETA-lägena) · Toby 2: T18 (repetitionsläget, A78–A81) | Toby 1: omkörning 2 i CI: T15b 43503692380, T17 efter A75 43503698183, baslinje 43503643154 (omkörning 1 föll i bygget: E2E/Repetition, rättat av Toby 2 i 7acfa8c) · Toby 2: T18 i simulatorn grön 5/5, väntar på Arons telefonsvar  | Toby 1: första körningen: T15b väntan 0/10 över 4 s och mikrofonen 10/11 inom 1 s, men 10/12 besvarade (uppvärmning); T17 föll på testet (1 m dämpades av A10, sorlet hade en fråga), rättat i e26228c/705de5e · Toby 2: T18 simulatorn (43507025903)  | Toby 1: 2026-11-13 21:40 · Toby 2: 2026-11-13 22:18 | Toby 1: 1 punkt · Toby 2: ny session |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på bilder efter dbfa91f (B1/B2, A86) och A83 | Ke49–Ke52 klara: repetitionslägets design och texter, demosidans utkast (inte publicerat), Publicera prov (). API 0 USD | 2026-11-13 21:17 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
