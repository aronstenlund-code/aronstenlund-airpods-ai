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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (omgång 6 klar; nästa stående omgång) | klar | Omgång 6 klar 12:16: resten av O41 (talade nummer, inga samtal på frågor, inget engelskt tal), Standardläge 16/16. O41 BLOCKER rättad 11:47. API i dag ca 1,9 USD | 2026-11-11 12:16 | 10 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A59 Spotify via servern + A60 Kellys Ke35 och Tobys T8b-fynd, i CI (1667961) | pågår | A50–A58 gröna i CI 43005793046 (ipa uppladdad till Arons test i kväll). A59:s första bygge föll på `return switch` (rättat). A60: första passet slutar på Start, varje Starta tom, Provläge en fråga, en fråga blir inte provsvar | 2026-11-11 12:10 | 9 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`); fortsätter i självständigt läge |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (väntar på Kevins omgång 2 för omtest O34/O39; omtest av blockern när den är rättad) | **BLOCKER hittad** (O41) | **O41 BLOCKER 11:31: telefonverktygen (timer, kalender, ringa, musik) erbjuds aldrig i mode auto = Standardläge** ('Lumen, sätt en timer' → 'Jag kan inte starta timern här'; Provläge fungerar) — Kevin/Angela prio 1, Aron: prova timern i Provläge i kväll. K36 annars 26/29, B6 0 påhittade nummer. **O38 K38 godkänd** (Aron: lägg in SUPABASE_SERVICE_ROLE_KEY). **O39 K37 godkänd:** 0 falska träffar av 26 nya fall, 10/14 rätt. **O16 klar:** Scribe ≤20 kodpunkter/term, ≤50 termer; ElevenLabs loggar Scribe men appen säger 'sparas inte'. **O13 del 2: BUGG i K17 planDays** (sista dagarna före provet får 1 begrepp). **O34:** tal 11/11, länkar 0/10, Lumen-frågor 5/11 rätt besvarade. I dag 0,38 USD, 0 ElevenLabs, 62 Scribe-s **O40 K39 godkänd** 22/22 (utan att rösta). | 2026-11-11 11:32 | 7 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T11 skärmrunda A50/A52/A53 (ljust, mörkt + största text, SE) i CI; sedan förstagång igen efter Angelas A56 | pågår | T5b/T7b/T8b + A50-rundan klara 12:05 (rapporter 1045 och 1200). Testerna klarade inte Earmind-namnen (A55): rättat på grenen | 2026-11-11 12:25 | 3 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; granskar Angelas rättelser när de kommer) | väntar på kö | Ke35 klar 12:01: Tobys A50-fynd → första passet slutar på Start, tom Lyssnar vid varje Starta, Provläge högst en fråga (docs/design/forsta-passet.md). Ke34: A52 godkänd, A54 V1, A53 M1 (rättad i A58). I dag Ke29–Ke35. API 0 USD, ElevenLabs 0 | 2026-11-11 12:01 | 7 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
