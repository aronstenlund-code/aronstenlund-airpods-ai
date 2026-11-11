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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (omgång 5 klar; nästa stående omgång) | klar | Omgång 5 klar 12:00: Auto byter inte ämne vid felhörda egna ord (Toby T5b), 6/6. Omgång 4: K17-planen 19/19, filtret 26/26. O41 BLOCKER rättad. API i dag ca 1,9 USD | 2026-11-11 12:00 | 9 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A55 Earmind i CI (711b4cb); A56 Tobys T5b/T7b-fynd byggd lokalt, pushas när A55:s device-bygge är grönt | pågår | A50, A53, A52, A54: device-bygge och alla enhetstester gröna i 42999877208 (körningen avbröts sedan i arkiveringssteget av nästa push); ej på enhet. Överlämning skriven | 2026-11-11 11:21 | 5 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`); fortsätter i självständigt läge |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (väntar på Kevins omgång 2 för omtest O34/O39; omtest av blockern när den är rättad) | **BLOCKER hittad** (O41) | **O41 BLOCKER 11:31: telefonverktygen (timer, kalender, ringa, musik) erbjuds aldrig i mode auto = Standardläge** ('Lumen, sätt en timer' → 'Jag kan inte starta timern här'; Provläge fungerar) — Kevin/Angela prio 1, Aron: prova timern i Provläge i kväll. K36 annars 26/29, B6 0 påhittade nummer. **O38 K38 godkänd** (Aron: lägg in SUPABASE_SERVICE_ROLE_KEY). **O39 K37 godkänd:** 0 falska träffar av 26 nya fall, 10/14 rätt. **O16 klar:** Scribe ≤20 kodpunkter/term, ≤50 termer; ElevenLabs loggar Scribe men appen säger 'sparas inte'. **O13 del 2: BUGG i K17 planDays** (sista dagarna före provet får 1 begrepp). **O34:** tal 11/11, länkar 0/10, Lumen-frågor 5/11 rätt besvarade. I dag 0,38 USD, 0 ElevenLabs, 62 Scribe-s **O40 K39 godkänd** 22/22 (utan att rösta). | 2026-11-11 11:32 | 7 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (T10 väntar på Arons telefonsteg) | väntar på kö | T5b/T7b/T8b + A50-rundan klara 12:05: A50 Start rätt (Starta Lumen → Lyssnar 2,5 s + svar), Lyssnar 0,1 s efter mikrofonfrågan; till Angela: fråga efter ett svar ställs aldrig och blir röstprofil vid Avsluta, döv efter svar, gamla svar i ny session, ja→långt svar 7–15 s | 2026-11-11 12:05 | 3 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | Ke35 designbeslut på Tobys A50-fynd 3, 5, 6 | pågår | Ke34 klar 11:28: A52 godkänd, A54 godkänd med V1 (Rösta ser aktiv ut avstängd), A53 godkänd med M1; G3 "Ljud sparas inte" osant med Sov/inspelning, till Deangelo. I dag Ke29–Ke34. API 0 USD, ElevenLabs 0 | 2026-11-11 12:00 | 6 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
