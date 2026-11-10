# Tavla: vem gör vad

**Självständigt läge (README punkt 8): på till 2026-11-11 07:30.** Aron sover och kan inte svara.

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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | Tobys /stt-token 429, sedan K30 | jobbar (självständigt till 07:30) | K34 (BLOCKER) klar i tre omgångar, driftsatt 1c14046: O17d 37/40 live före omgång 3, kodlagret nu 0 utan träff, B5 14/14; väntar på Oscars O17e. K28 klar (D113 A1–A3). K29 byggd men av (D125, Haiku 75 % korrekt). API i kväll cirka 2,0 USD (mest CI-regression och K29-mätning) | 2026-11-10 20:11 | – |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A46 vändkort i tyst läge; sedan A38/A43 när K31/K33 är klara | jobbar | I dag 31 punkter klara och gröna i CI (A16–A30, A33–A37, A39–A42, A45–A47); ej på enhet | 2026-11-10 19:27 | 31 punkter, komprimerad, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | O13 del 3 och O16 del 2 (Scribe realtid, cachat ljud, D120) | väntar till 01:00: stt-token ger 429 för alla användare (global dygnsgräns 600); provlage-eval transcribe ger 413 över 64 KB (till Kevin) | **O37 K34: BLOCKER liten men kvar** — O17d 36→37/40 i Auto efter a9fa3c4 (var 31/40), 'lägga mig på spåret i kväll' tyst / 'sov gott'; falska 3–4/40; B5-minne 14/14. API i dag 1,93 + 0,177 av 0,50 extra; ElevenLabs 501 tecken, 0 Scribe-s | 2026-11-10 20:05 | komprimerad två gånger (PLAN 2e): gör Arons tre punkter, sedan slut och överlämning |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | T5b, T7b, T8b efter 01:00 | pågår | T10 del 2 grön; /stt-token 429 (dagstaket), till Kevin | 2026-11-10 20:12 | självständigt till 07:30 |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke25 App Store-sidan | pågår | Ke23 klar 19:32: 4 namn kollade (App Store 0 träffar, TMview 0 exakta; Pod/Whisper röda för Apple/OpenAI), rekommenderar Proviska + symbol 4. Ke24 väntar på Arons nummer. ElevenLabs 0, API 0 USD | 2026-11-10 19:33 | 1 punkt |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
