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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | stående uppgift (PLAN 2b) | nattpass till 07:30 | Omgång 19 klar 20:42: eko plus brus ger tystnad (61/61). K42b, O51 och K42 klara. 495 tester, regression 90,5 % | 2026-11-11 20:42 | 8 punkter, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (kön klar; bevakar kön och nya fynd) | väntar på kö | A71–A74 klara, senast CI 43083430294 (ipa uppladdad). A72: en hållen fråga senast 6 s / 1,5 s efter fortsättningen; Toby kör T15b | 2026-11-11 20:29 | 26 punkter, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (omtest O51s när isCutOff rättats; kollar kön var 30:e min) | väntar på kö | **O51 20:20: K42 namn 0→9/10, fakta 17→20/20, längd 5→8/10, klagomål 1→4/10** (5 tysta, 1 löfte). O50 K41 godkänd. **Öppen REGRESSION O51s:** hela frågor tysta i Standardläge (isCutOff) — Kevin prio 1. Natt API ca 0,7 av 2 USD, ElevenLabs 0 | 2026-11-11 20:20 | 19 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15b: vantan (q4, c1, c3 × 4) kör på A72 del 2 | pågår | T16 klar 20:30: appikonen syns på hemskärmen, A69 och A73 rätt. T15 19:30: väntan efter "Half a question" (13–26 s) | 2026-11-11 20:40 | 10 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke45 klar 20:44: **Angela: underlag för A76 testläget i docs/design/testlage.md** (orange bricka, blad, ny ljudtext). I kväll Ke22, Ke40–Ke45. API 0 USD | 2026-11-11 20:44 | 18 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
