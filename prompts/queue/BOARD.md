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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (kollar kön och tavlan var 20:e minut); K6 väntar på Till Aron #15 | K53 klar 00:10: 30 foton → frågor 22,5 s live, Angela har byggt in det (79a2bb8). Fråga till Deangelo kvar: R3 5 eller 6 ord | 2026-11-13 23:03 | 11 punkter, byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Kellys N1–N4 och K51-fälten, sedan A87 · Angela – Design: A87 pågår sedan 23:10 (Fable 5.2): Kellys Ke53 punkt 1–5 först, bara de fem repetitionsvyerna och repetitionsdelen av HomeView | arbetar | **NYTT BYGGE TILL ARON: iOS build 43511121798 GRÖN (dbfa91f), Lumen-unsigned.ipa uppladdad.** A85: sidorna var 4 800 px (3× skala) och 13,9 MB för 2 foton, nu 1 600 px och högst 1,2 MB per sida, ett nytt försök vid bruten anslutning, "Ingen internetanslutning" bara utan nät, serverns text vid 413/422/429. A86: "Kom förberedd till provet". Kellys B1–B5 med. Skärmbilder till Kelly startade 22:50 | 2026-11-13 22:52 | ny session |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O55a, O55, O56 klara | nästa: O55b (5 nya hållout-prov) efter Kevins rättningar | **21:36 O55:** R1 ok (20 s), R5/R5b/R5c 33/33, R10 Claude 0,063 USD/prov, ElevenLabs ~0,94 USD/prov listpris; **till Kevin:** årskurs 'åk 8' 5/10, R3 ≤5 ord 75 % och förståelse 66 %, 1 tomt svar (prio 1), 3 små faktafel, frågor som kräver materialet. **O56 R12 4/4**, sök 0,3 s, RLS håller. Domaren 20/20. API ca 2,3 USD, ElevenLabs 1 154 tecken | 2026-11-13 21:36 | `reports/qa/2026-11-13-2136-oscar-o55-o56-repetition.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: – (T17 väntar på Angelas fynd 1–2) · Toby 2: T18 (repetitionsläget, A78–A81) | Toby 1: väntar på Angela · Toby 2: T18 i simulatorn grön 5/5, väntar på Arons telefonsvar | Toby 1: T15b klar: 0/10 väntar över 4 s, mikrofonen 11/11 inom 1 s, inga ekon, 10/12 besvarade; T17 under krav: efter A75 39/50 och 2/50 falska (Lusen väcker), baslinjen 35/50 och 0/50 → reports/apptest/2026-11-13-2305-toby1-t15b-t17.md · Toby 2: T18 simulatorn (43507025903) | Toby 1: 2026-11-13 23:06 · Toby 2: 2026-11-13 22:18 | Toby 1: 2 punkter · Toby 2: ny session |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar: A87-bilder och 43514517449; kollar kön var 20:e minut | Ke49–Ke54 klara; Ke54 demosidan i Apple-stil som utkast (drafts/site-repetition/, inte publicerat). API 0 USD | 2026-11-13 23:26 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
