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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom utom K6; stående omgångar) | klar | Omgång 11 klar 13:36: rättelser med egna ord 4/20 → 20/20, kommandon 3/10 → 9/10 (O22), 'Standardläge' som läge. K40 klar 13:02. API i dag ca 4,0 USD | 2026-11-11 13:36 | 16 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A63 Tobys T12 (vakten med two_level, halv fråga ber om slutet, diagnostik) | pågår | A50–A62 gröna, senast CI 43015648947 (ipa uppladdad). A62: quiz_key tillbaka till servern, svaret först bland Scribes nyckelord, omanslutningens tid loggas (O43) | 2026-11-11 13:18 | 13 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O43 enordssvar i förhör: mätning FÖRE K40/A62 (40 fall × tyst/klassrumsprat, cachat tal) | pågår | **O44 13:04: K36 godkänd** (O41-regressionen 29/29, ring Bris/spela musik/Auto kräver Lumen rättade). O43 förmätning pågår. **O42 12:27: O41-blockern BORTA** (timer/ring/musik i Standardläge 3/3 live). K17 19/19, K38-filter 26/26, självsvar 11/11 sanna, länkar 9/10, Mina svar 0 falska. Kvar till Kevin: 'ring Bris' tyst, 'spela musik' utan artist ostabil, 'ring mamma' utan Lumen ringer i Auto. Tidigare: K38/K37/K39 godkända, O16, O34, O13 del 2. API i dag ca 0,90 USD, 0 ElevenLabs, 62 Scribe-s | 2026-11-11 13:04 | 8 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T8c förstagång efter A60 + skärmtur (3 lägen) kör på grenen | pågår | T11 klar 13:10: A50/A52/A53 rätt i ljust, mörkt + största text och SE; största text bryter lägesraden och NÄSTA PROV mitt i ord. T12 klar 13:00 (Frågor 10/10) | 2026-11-11 13:10 | 5 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke37 klar 13:21: SYSTEM.md avsnitt 10 Största text (Tobys T11 fynd 1–4 + 2). Ke36: A55–A61 godkända. **G3 "Ljud sparas inte" saknar fortfarande punkt.** I dag Ke29–Ke37. API 0 USD, ElevenLabs 0 | 2026-11-11 13:21 | 9 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
