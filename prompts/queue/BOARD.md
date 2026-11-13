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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar på kö (kollar var 20:e minut); K6 väntar på Till Aron #15 | **K54/K55 klara 23:45** (`reports/2026-11-13-2345-kevin-k54-k55-short-answer-first-audio.md`): första ljudet 2,0 s efter Starta prov; ≈ 5 000 krediter + 0,065 USD Claude per prov med 20 frågor. **Frågor till Deangelo:** (1) 20 frågor som standard men 15/månad → första provet får 402: föreslå högst det som finns kvar? (2) R3 5 eller 6 ord | 2026-11-13 23:45 | 13 punkter, byt (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Kellys N1–N4 och K51-fälten, sedan A87 · Angela Fable: A87 och A90 pushade (3382ae2), väntar på iOS build 43519409691 och fyra skärmbildskörningar; sedan 23:37 Apple-stil på PublishViews, DrillVoiceChoice och de två repetitionssektionerna i SettingsView (Aron) | arbetar | **NYTT BYGGE TILL ARON: iOS build 43511121798 GRÖN (dbfa91f), Lumen-unsigned.ipa uppladdad.** A85: sidorna var 4 800 px (3× skala) och 13,9 MB för 2 foton, nu 1 600 px och högst 1,2 MB per sida, ett nytt försök vid bruten anslutning, "Ingen internetanslutning" bara utan nät, serverns text vid 413/422/429. A86: "Kom förberedd till provet". Kellys B1–B5 med. Skärmbilder till Kelly startade 22:50 | 2026-11-13 22:52 | ny session |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O55a, O55, O56 klara | nästa: O55b (5 nya hållout-prov) efter Kevins rättningar | **21:36 O55:** R1 ok (20 s), R5/R5b/R5c 33/33, R10 Claude 0,063 USD/prov, ElevenLabs ~0,94 USD/prov listpris; **till Kevin:** årskurs 'åk 8' 5/10, R3 ≤5 ord 75 % och förståelse 66 %, 1 tomt svar (prio 1), 3 små faktafel, frågor som kräver materialet. **O56 R12 4/4**, sök 0,3 s, RLS håller. Domaren 20/20. API ca 2,3 USD, ElevenLabs 1 154 tecken | 2026-11-13 21:36 | `reports/qa/2026-11-13-2136-oscar-o55-o56-repetition.md` |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Toby 1: T20 (K53-uppladdningen 1/4/10/30 foton), sedan T19 när A83 är grön · Toby 2: T18 (repetitionsläget, A78–A81) | Toby 1: T20 kör på grenen toby/t20-upload (43521045476); T17/T15b körs om när Angelas db7a56a är grön · Toby 2: D163 (lång paus, 1/2/3 tryck) testas på toby/d163, checklistan uppdaterad; väntar på grönt iOS-bygge och Arons telefonsvar | Toby 1: T15b klar, T17 under krav (39/50, 2/50) → reports/apptest/2026-11-13-2305-toby1-t15b-t17.md · Toby 2: T18 simulatorn (43507025903) | Toby 1: 2026-11-13 23:40 · Toby 2: 2026-11-13 23:38 | Toby 1: 3 punkter · Toby 2: ny session |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – | väntar: A87-bilder (43519509067 m.fl.); kollar kön var 20:e minut | Ke49–Ke56 klara; Ke56 App Store-förberedelse (docs/appstore/). API 0 USD | 2026-11-13 23:42 | ny session |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
