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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K-stående omgång 2: O34 (självsvar, länkar), O39 | pågår | K36 klar 11:04: ring + music_open live 13/13, Spotify väntar på Arons Spotify-app. K39, K37 (29/29, Oscar O39: 0 falska), K38 klara. API i dag ca 0,25 USD | 2026-11-11 11:05 | 4 punkter |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A55 Earmind i CI (711b4cb); A56 Tobys T5b/T7b-fynd byggd lokalt, pushas när A55:s device-bygge är grönt | pågår | A50, A53, A52, A54: device-bygge och alla enhetstester gröna i 42999877208 (körningen avbröts sedan i arkiveringssteget av nästa push); ej på enhet. Överlämning skriven | 2026-11-11 11:21 | 5 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`); fortsätter i självständigt läge |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O41 test av K36 (ringa, musik; B6 nummer); sedan omtest O34 g13/g14 + O39 när Kevins omgång 2 är klar | pågår | **O38 K38 godkänd** (Aron: lägg in SUPABASE_SERVICE_ROLE_KEY). **O39 K37 godkänd:** 0 falska träffar av 26 nya fall, 10/14 rätt. **O16 klar:** Scribe ≤20 kodpunkter/term, ≤50 termer; ElevenLabs loggar Scribe men appen säger 'sparas inte'. **O13 del 2: BUGG i K17 planDays** (sista dagarna före provet får 1 begrepp). **O34:** tal 11/11, länkar 0/10, Lumen-frågor 5/11 rätt besvarade. I dag 0,38 USD, 0 ElevenLabs, 62 Scribe-s **O40 K39 godkänd** 22/22 (utan att rösta). | 2026-11-11 11:26 | 6 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T8b + A50-rundan (förstagång och skärmtur) kör i CI på `toby/t5b-t7b-t8b-2` | pågår | T5b/T7b klara 10:45: Provläge 4/4 turer, Mer-fönstret 8/8 rätt; kvar till Angela: Frågor väntar 12–22 s på Scribe, långt svar efter ja 7–15 s (K13 inte inkopplat), 56 s döv efter långt svar | 2026-11-11 10:47 | 2 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; nästa: granska Tobys A50-runda och rättelserna V1/M1/G2/G3) | väntar på kö | Ke34 klar 11:28: A52 godkänd, A54 godkänd med V1 (Rösta ser aktiv ut avstängd), A53 godkänd med M1; G3 "Ljud sparas inte" osant med Sov/inspelning, till Deangelo. I dag Ke29–Ke34. API 0 USD, ElevenLabs 0 | 2026-11-11 11:28 | 6 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
