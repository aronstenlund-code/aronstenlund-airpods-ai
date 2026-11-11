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
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kollar kön; O43d omtest när listuppläsningen hanteras) | väntar på kö | **O43 14:16: enordssvar i förhör tyst 38→40/40 med K40+A62, prat 34/35; BUGG: tyst elev i sorl får 'Rätt' 2/20** (Scribe läser upp keyterms, A62 lägger facit först) — Kevin/Angela. O44: K36 29/29. I dag: K36–K40 godkända, O16, O34, O13 del 2. API ca 2,7 USD, ElevenLabs 367 tecken, Scribe ca 540 s | 2026-11-11 14:16 | 11 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T8c förstagång efter A60 + skärmtur (3 lägen) kör på grenen | pågår | T11 klar 13:10: A50/A52/A53 rätt i ljust, mörkt + största text och SE; största text bryter lägesraden och NÄSTA PROV mitt i ord. T12 klar 13:00 (Frågor 10/10) | 2026-11-11 13:10 | 5 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; granskar A64 när Tobys tur med största text finns) | väntar på kö | 13:53: A64 kontrollerad i koden, följer SYSTEM.md avsnitt 10 (staplade rader, rubriken bryts, loggan skalar); bilder saknas. Ke37 klar. **G3 "Ljud sparas inte" saknar fortfarande punkt.** I dag Ke29–Ke37. API 0 USD | 2026-11-11 13:53 | 9 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
