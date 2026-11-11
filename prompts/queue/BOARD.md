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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (omgång 7 klar; nästa stående omgång) | klar | Omgång 7 klar 12:26: tidszoner och temperaturer sägs av koden (Delhi 18:30, 68 °F, live 4/4). Omgång 6: O41-resten. O41 BLOCKER rättad 11:47. API i dag ca 2,3 USD | 2026-11-11 12:26 | 11 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A59 Spotify via servern + A60 Kellys Ke35 och Tobys T8b-fynd, i CI (1667961) | pågår | A50–A58 gröna i CI 43005793046 (ipa uppladdad till Arons test i kväll). A59:s första bygge föll på `return switch` (rättat). A60: första passet slutar på Start, varje Starta tom, Provläge en fråga, en fråga blir inte provsvar | 2026-11-11 12:10 | 9 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`); fortsätter i självständigt läge |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kollar kön var 30:e min; O13 del 3 väntar på cachat ljud) | väntar på kö | **O42 12:27: O41-blockern BORTA** (timer/ring/musik i Standardläge 3/3 live). K17 19/19, K38-filter 26/26, självsvar 11/11 sanna, länkar 9/10, Mina svar 0 falska. Kvar till Kevin: 'ring Bris' tyst, 'spela musik' utan artist ostabil, 'ring mamma' utan Lumen ringer i Auto. Tidigare: K38/K37/K39 godkända, O16, O34, O13 del 2. API i dag ca 0,90 USD, 0 ElevenLabs, 62 Scribe-s | 2026-11-11 12:28 | 8 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T11 skärmrunda A50/A52/A53 (ljust, mörkt + största text, SE) i CI; sedan förstagång igen efter Angelas A56 | pågår | T5b/T7b/T8b + A50-rundan klara 12:05 (rapporter 1045 och 1200). Testerna klarade inte Earmind-namnen (A55): rättat på grenen | 2026-11-11 12:25 | 3 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom; granskar Angelas rättelser när de kommer) | väntar på kö | Ke35 klar 12:01: Tobys A50-fynd → första passet slutar på Start, tom Lyssnar vid varje Starta, Provläge högst en fråga (docs/design/forsta-passet.md). Ke34: A52 godkänd, A54 V1, A53 M1 (rättad i A58). I dag Ke29–Ke35. API 0 USD, ElevenLabs 0 | 2026-11-11 12:01 | 7 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
