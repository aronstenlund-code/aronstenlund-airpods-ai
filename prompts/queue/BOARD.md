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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | high | – (kön tom; nästa session: stående uppgift K4-loopen) | slutat (PLAN 2e: två komprimeringar), överlämning `docs/HANDOVER-kevin.md` | K25–K27 klara och driftsatta (CI 42804686846, 42805093491, 42805896061): siffror O26 45/45, räknaren 0 fel, Rizz-nätet O27 25/25, känsliga minnen O28 27/27, självfrågor 20/20, eko 12/12, länkar 15/15. K23 (BLOCKER) klar: kris i Auto 44/44. API i dag 0,004 USD | 2026-11-10 12:27 | två komprimeringar: ny session behövs |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A46 vändkort i tyst läge; sedan A38/A43 när K31/K33 är klara | jobbar | I dag 31 punkter klara och gröna i CI (A16–A30, A33–A37, A39–A42, A45–A47); ej på enhet | 2026-11-10 19:27 | 31 punkter, komprimerad, byt (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | O13 del 3 (ämnesords uttal TTS → Scribe, 20 nya termer, korta meningar enligt D120) | arbetar; sedan O16 del 2 efter 01:00 (stt-token ger 429 för alla användare till 01:00, global dygnsgräns), K34 när Kevin har pushat (ingen Kevin-session igång 19:37) | O35/O36 klara 12:58 (se rapporter). API i dag 1,93 + 0,084 av 0,50 extra; ElevenLabs i kväll: se rapporterna | 2026-11-10 19:37 | komprimerad två gånger (PLAN 2e): gör Arons tre punkter, sedan slut och överlämning |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | medium | T5b, T7b, T8b, T10 del 2 | pågår | Fullrundan på main: Bara fråga öppnar inte Lyssnar efter första starten (appfel, till Angela) | 2026-11-10 19:38 | självständigt till 07:30 |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke25 App Store-sidan | pågår | Ke23 klar 19:32: 4 namn kollade (App Store 0 träffar, TMview 0 exakta; Pod/Whisper röda för Apple/OpenAI), rekommenderar Proviska + symbol 4. Ke24 väntar på Arons nummer. ElevenLabs 0, API 0 USD | 2026-11-10 19:33 | 1 punkt |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
