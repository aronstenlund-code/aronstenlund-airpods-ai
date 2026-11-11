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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | stående uppgift (PLAN 2b) | nattpass till 07:30 | K41 klar 18:53: röstningen A–F live (F 200, G 400), gamla röster kvar, driftsatt e20931b, 480 tester | 2026-11-11 18:53 | 1 punkt, komprimerad tidigare: byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A71 steg 1: AppIcon (glasklotet D) | pågår | Kväll: A71 steg 1 → A73 → A72 → A71 steg 2 (Ke40). Senast: A50–A70 gröna (CI 43057820636) | 2026-11-11 18:49 | 21 punkter (samma session), byt snart |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (O50 väntar på K41; stående uppgift) | **REGRESSION hittad** (O51) | **O51 18:52: hela frågor blir tysta i Standardläge** sedan Kevins omgång 15 (isCutOff): 'kan du säga vad klockan är', 'vad tror du att svaret är' → tystnad live; hela frågor 2/12 offline — Kevin prio 1. Aron i kväll: säg 'Lumen, vad är klockan?'. Natt API 0,01 av 2 USD, ElevenLabs 0 | 2026-11-11 18:52 | 17 punkter, byt (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T15: q4, c1, c3 × 4 (uppsättning vantan, Apples röst) kör i CI, läser A70-raden | pågår | T14 klar 17:25: ja/mer/gärna → långt svar 1,6–1,8 s; tur väntar på Scribe 13–29 s | 2026-11-11 19:05 | 8 punkter, komprimerad? nej; byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke22 bildplan + stillbilder (granskar A71 när den kommer) | pågår | Ke41 klar 19:00: A73 godkänd (G3 stängd), L1 licensraden om ElevenLabs. Ke40: exakta ikoner pushade till Angela. API 0 USD | 2026-11-11 19:01 | 13 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
