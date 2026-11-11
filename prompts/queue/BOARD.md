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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K42b klar; stående uppgift (PLAN 2b) | nattpass till 07:30 | K42b klar 20:26 (Oscars O51-rester): vad heter appen, längd i ord (55/50, 20/20), klagomål, utveckla det. O51 och K42 klara. 494 tester | 2026-11-11 20:26 | 7 punkter, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A72 del 2 i CI (17d2937): en hållen fråga senast 6 s efter den hördes / 1,5 s efter fortsättningen | pågår | A71 klar (exakta ikoner, röstning A–F, CI 43079695710). A73, A74, A72 del 1 gröna. T15 visade att mikrofonen öppnas 0,6–0,8 s efter talet (krav 2 uppfyllt i simulatorn) | 2026-11-11 20:02 | 26 punkter, byt snart |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (omtest O51s när isCutOff rättats; kollar kön var 30:e min) | väntar på kö | **O51 20:20: K42 namn 0→9/10, fakta 17→20/20, längd 5→8/10, klagomål 1→4/10** (5 tysta, 1 löfte). O50 K41 godkänd. **Öppen REGRESSION O51s:** hela frågor tysta i Standardläge (isCutOff) — Kevin prio 1. Natt API ca 0,7 av 2 USD, ElevenLabs 0 | 2026-11-11 20:20 | 19 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15b väntar på A72 (del 2 bygger) | väntar | T16 klar 20:30: appikonen (glasklotet) syns på hemskärmen, A69 och A73 rätt, 0 appfel. T15 19:30: väntan efter "Half a question" (13–26 s) | 2026-11-11 20:30 | 10 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke44 klar 20:10: sajtens stegbilder från appen i dag (Lighthouse 99/100/100/100, 1 528 kB). Ke43: A71 godkänd. I kväll Ke22, Ke40–Ke44. API 0 USD | 2026-11-11 20:10 | 17 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
