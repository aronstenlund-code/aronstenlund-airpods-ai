# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-11 18:00.** Plan för dagen: `docs/PLAN-2026-11-11.md`.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (bevakar kön till 18:00) | väntar på kö | Omgång 12 klar 14:22: O43 falskt 'Rätt' i sorl rättat (termlistan = 'Vad sa du?'). I dag: K38, K37, K39, K36, K40b, K40, omgång 2–12. API i dag ca 4,1 USD | 2026-11-11 14:22 | 17 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | – (A51 väntar på röstningen, A3 på K6; bevakar kön och nya fynd till 18:00) | väntar på kö | A50–A65 gröna, senast CI 43025162865 (ipa uppladdad till Arons test i kväll). A65: ja i Mer?-fönstret direkt | 2026-11-11 14:17 | 16 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O45 omtest O43d (falskt Rätt i sorl) och O43 efter Kevins d8a24d3/593ac57 | pågår | **O43 14:16: enordssvar i förhör tyst 38→40/40 med K40+A62, prat 34/35; BUGG: tyst elev i sorl får 'Rätt' 2/20** (Scribe läser upp keyterms, A62 lägger facit först) — Kevin/Angela. O44: K36 29/29. I dag: K36–K40 godkända, O16, O34, O13 del 2. API ca 2,7 USD, ElevenLabs 367 tecken, Scribe ca 540 s | 2026-11-11 14:49 | 11 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (T10 väntar på Arons telefonsteg) | väntar på kö | T8c klar 14:55: förstagång efter A60 grön (13 tryck till svar i Provläge, Starta → Lyssnar 2,3 s), skärmturen grön i 3 lägen; till Angela: tre blad på 93 s, "Avbryt" startar Provläge. I dag 6 punkter (T5b, T7b, T8b, T11, T12, T8c) | 2026-11-11 14:55 | 6 punkter, byt snart (överlämning docs/HANDOVER-toby.md) |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke38 klar 14:57: T8c visar att Ke35 fungerar (Start först, Provläge 4 tryck, ett blad per öppning); K1 Dela historik grå. **G3 "Ljud sparas inte" saknar fortfarande punkt.** A64 väntar på bilder. I dag Ke29–Ke38. API 0 USD | 2026-11-11 14:57 | 10 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
