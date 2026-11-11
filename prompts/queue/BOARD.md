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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom utom K6; tar stående uppgift) | klar | Stående omgång 2 klar 11:29: självsvar efter fråga och sanna om ElevenLabs (live 10/10), länkar 0/10 → 9/10, Mina svar O39. Tidigare i dag K38, K37, K39, K36. API i dag ca 0,7 USD | 2026-11-11 11:29 | 5 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A55 Earmind i CI (711b4cb); A56 Tobys T5b/T7b-fynd byggd lokalt, pushas när A55:s device-bygge är grönt | pågår | A50, A53, A52, A54: device-bygge och alla enhetstester gröna i 42999877208 (körningen avbröts sedan i arkiveringssteget av nästa push); ej på enhet. Överlämning skriven | 2026-11-11 11:21 | 5 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`); fortsätter i självständigt läge |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (väntar på Kevins omgång 2 för omtest O34/O39; omtest av blockern när den är rättad) | **BLOCKER hittad** (O41) | **O41 BLOCKER 11:31: telefonverktygen (timer, kalender, ringa, musik) erbjuds aldrig i mode auto = Standardläge** ('Lumen, sätt en timer' → 'Jag kan inte starta timern här'; Provläge fungerar) — Kevin/Angela prio 1, Aron: prova timern i Provläge i kväll. K36 annars 26/29, B6 0 påhittade nummer. **O38 K38 godkänd** (Aron: lägg in SUPABASE_SERVICE_ROLE_KEY). **O39 K37 godkänd:** 0 falska träffar av 26 nya fall, 10/14 rätt. **O16 klar:** Scribe ≤20 kodpunkter/term, ≤50 termer; ElevenLabs loggar Scribe men appen säger 'sparas inte'. **O13 del 2: BUGG i K17 planDays** (sista dagarna före provet får 1 begrepp). **O34:** tal 11/11, länkar 0/10, Lumen-frågor 5/11 rätt besvarade. I dag 0,38 USD, 0 ElevenLabs, 62 Scribe-s **O40 K39 godkänd** 22/22 (utan att rösta). | 2026-11-11 11:32 | 7 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T8b + A50-rundan (förstagång och skärmtur) kör i CI på `toby/t5b-t7b-t8b-2` | pågår | T5b/T7b klara 10:45: Provläge 4/4 turer, Mer-fönstret 8/8 rätt; kvar till Angela: Frågor väntar 12–22 s på Scribe, långt svar efter ja 7–15 s (K13 inte inkopplat), 56 s döv efter långt svar | 2026-11-11 10:47 | 2 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; nästa: granska Tobys A50-runda och rättelserna V1/M1/G2/G3) | väntar på kö | Ke34 klar 11:28: A52 godkänd, A54 godkänd med V1 (Rösta ser aktiv ut avstängd), A53 godkänd med M1; G3 "Ljud sparas inte" osant med Sov/inspelning, till Deangelo. I dag Ke29–Ke34. API 0 USD, ElevenLabs 0 | 2026-11-11 11:28 | 6 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
