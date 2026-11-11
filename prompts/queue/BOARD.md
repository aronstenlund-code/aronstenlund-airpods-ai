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
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A55 Earmind (visningsnamnet; väckningsordet Lumen kvar) | pågår | A50 ny Start, A53 Mina svar, A52 Vad kan Lumen?, A54 loggröstning: gröna i CI 42999877208 (device-bygge + alla tester), bilder i körning 42999887377; ej på enhet. ios-build hoppar nu över backend-/QA-pushar | 2026-11-11 11:15 | 4 punkter (byt snart: överlämning skrivs efter A55) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (nästa: K36 när Kevin är klar; O13 del 3 väntar på cachat ljud) | väntar på kö (kollar var 30:e min) | **O38 K38 godkänd** (Aron: lägg in SUPABASE_SERVICE_ROLE_KEY). **O39 K37 godkänd:** 0 falska träffar av 26 nya fall, 10/14 rätt. **O16 klar:** Scribe ≤20 kodpunkter/term, ≤50 termer; ElevenLabs loggar Scribe men appen säger 'sparas inte'. **O13 del 2: BUGG i K17 planDays** (sista dagarna före provet får 1 begrepp). **O34:** tal 11/11, länkar 0/10, Lumen-frågor 5/11 rätt besvarade. I dag 0,38 USD, 0 ElevenLabs, 62 Scribe-s **O40 K39 godkänd** 22/22 (utan att rösta). | 2026-11-11 10:53 | 6 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T8b + A50-rundan (förstagång och skärmtur) kör i CI på `toby/t5b-t7b-t8b-2` | pågår | T5b/T7b klara 10:45: Provläge 4/4 turer, Mer-fönstret 8/8 rätt; kvar till Angela: Frågor väntar 12–22 s på Scribe, långt svar efter ja 7–15 s (K13 inte inkopplat), 56 s döv efter långt svar | 2026-11-11 10:47 | 2 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke34 granska A52 + A54 (CI 42999887377 kör) | pågår | Ke33 klar 10:39: A50 godkänd (CI 42993726421), 3 fynd kvar: länk till A52, grå ikoner i lägesbladet (låg), Ljud sparas inte före A53. I dag: Ke31 loggorna som vektor, Ke29 Start + Vad kan Lumen?, Ke30 Mina svar, Ke32 Earmind på sajten. API 0 USD, ElevenLabs 0 | 2026-11-11 11:11 | 5 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
