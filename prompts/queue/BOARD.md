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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | K36 Spotify och samtal | pågår | K39 klar 10:50: /logo-vote live (en röst per användare, procent från 20 röster, totalerna på Arons sida), 0 USD. K37 klar 10:41 (Mina svar live 29/29, 0/36 falska), K38 klar 10:26. API i dag ca 0,2 USD | 2026-11-11 10:50 | 3 punkter |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A50 i CI (d846660) + A53 Mina svar byggd, i samma CI-körning | pågår | A50: Starta Lumen-knapp, läget med Byt/Välj läge, Lumen kan allt (5 exempel, Ke29 S2), simulatorbilder 25×2 tagna (42993726421); A53: lista, förslag, stavning, inspelning på telefonen, versioner, Ditt svar. CI-körningar avbryts av andras pushar | 2026-11-11 10:46 | 0 punkter klara |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (O13 del 3 väntar på cachat ljud från Arons dator) | väntar på kö | **O38 K38 godkänd** (Aron: lägg in SUPABASE_SERVICE_ROLE_KEY). **O39 K37 godkänd:** 0 falska träffar av 26 nya fall, 10/14 rätt. **O16 klar:** Scribe ≤20 kodpunkter/term, ≤50 termer; ElevenLabs loggar Scribe men appen säger 'sparas inte'. **O13 del 2: BUGG i K17 planDays** (sista dagarna före provet får 1 begrepp). **O34:** tal 11/11, länkar 0/10, Lumen-frågor 5/11 rätt besvarade. I dag 0,38 USD, 0 ElevenLabs, 62 Scribe-s | 2026-11-11 10:50 | 5 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T8b + A50-rundan (förstagång och skärmtur) kör i CI på `toby/t5b-t7b-t8b-2` | pågår | T5b/T7b klara 10:45: Provläge 4/4 turer, Mer-fönstret 8/8 rätt; kvar till Angela: Frågor väntar 12–22 s på Scribe, långt svar efter ja 7–15 s (K13 inte inkopplat), 56 s döv efter långt svar | 2026-11-11 10:47 | 2 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (A54 och A52 granskas när de är byggda) | väntar på kö | Ke33 klar 10:39: A50 godkänd (CI 42993726421), 3 fynd kvar: länk till A52, grå ikoner i lägesbladet (låg), Ljud sparas inte före A53. I dag: Ke31 loggorna som vektor, Ke29 Start + Vad kan Lumen?, Ke30 Mina svar, Ke32 Earmind på sajten. API 0 USD, ElevenLabs 0 | 2026-11-11 10:39 | 5 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
