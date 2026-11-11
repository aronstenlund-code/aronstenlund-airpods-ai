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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | stående uppgift (PLAN 2b) | nattpass till 07:30 | K41 klar (A–F live). Omgång 16–18 klara 19:37: tal, källmening, dl/msk, intervjuerfarenhet; regression 95,2 %, 485 tester | 2026-11-11 19:37 | 4 punkter, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A72 del 2 i CI (17d2937): en hållen fråga senast 6 s efter den hördes / 1,5 s efter fortsättningen | pågår | A71 klar (exakta ikoner, röstning A–F, CI 43079695710). A73, A74, A72 del 1 gröna. T15 visade att mikrofonen öppnas 0,6–0,8 s efter talet (krav 2 uppfyllt i simulatorn) | 2026-11-11 20:02 | 26 punkter, byt snart |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (O51 Omtest K42 väntar på Kevins K42; omtest O51s när isCutOff rättats) | väntar på kö | **O51 förmätning 19:35** (före K42): namn 0/10, fakta 17/20 ('Mona Sahlin'), längd 5/10, klagomål 1/10 (7 tysta). **O50 19:26: K41 godkänd 25/25** (A–F, ogiltiga nekas, gamla röster kvar; 3 teströster väntar på Arons ja). **O51s 18:52: REGRESSION** hela frågor tysta i Standardläge (isCutOff) — Kevin prio 1. Natt API 0,01 av 2 USD, ElevenLabs 0 | 2026-11-11 19:35 | 18 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T16 skärmrunda A69/A71 (stående uppgift) kör; T15b när A72 är pushad | pågår | T15 klar 19:30: väntan sitter efter "Half a question: Scribe asked for the rest now" (13–26 s med VAD + bärarfokus); mikrofonen öppnas 0,6–0,8 s efter rösten | 2026-11-11 19:40 | 9 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; stående uppgift) | väntar på kö | Ke43 klar 20:08: A71 godkänd (AppIcon = exakt, sex exakta i röstningen, märket i rubriken). I kväll Ke22, Ke40–Ke43. API 0 USD | 2026-11-11 20:08 | 16 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
