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
| Kevin (backend) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (K40 klar; kön tom utom K6) | klar | K40 klar 12:56: förhörssvar jämförs ljudmässigt (live 7/7; 'om ni har redan svarat' = 'Menade du Nilen?'), namnen i keyterms; A62 till Angela. O42 rättat. API i dag ca 3,0 USD | 2026-11-11 12:56 | 13 punkter, byt snart (överlämning docs/HANDOVER-kevin.md) |
| Angela (app) | Opus 5.5 (claude-opus-5-5) | low (sessionens inställning) | A62 rätt svar som nyckelord (K40) + A61 Ke35-avdelaren, i CI (69cf911) | pågår | A50–A60 gröna i CI, senast 43010551241 (ipa uppladdad). A62: quiz_key tillbaka till servern, svaret först bland Scribes nyckelord, omanslutning medan frågan läses upp, tiden loggas till Oscars O43 | 2026-11-11 12:53 | 12 punkter, byt snart (överlämning `docs/HANDOVER-angela.md`) |
| Oscar (QA) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | O43 enordssvar i förhör: mätning FÖRE K40/A62 (40 fall × tyst/klassrumsprat, cachat tal) | pågår | **O42 12:27: O41-blockern BORTA** (timer/ring/musik i Standardläge 3/3 live). K17 19/19, K38-filter 26/26, självsvar 11/11 sanna, länkar 9/10, Mina svar 0 falska. Kvar till Kevin: 'ring Bris' tyst, 'spela musik' utan artist ostabil, 'ring mamma' utan Lumen ringer i Auto. Tidigare: K38/K37/K39 godkända, O16, O34, O13 del 2. API i dag ca 0,90 USD, 0 ElevenLabs, 62 Scribe-s | 2026-11-11 12:49 | 8 punkter, byt snart (överlämning `docs/HANDOVER-OSCAR.md`) |
| Toby (apptest) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | T11 skärmrunda (A50/A52/A53, mörkt + största text, SE) kör; sedan förstagång efter A60 | pågår | T12 klar 13:00: Frågor 10/10 besvarade (var 8/10), Provläge 4/4; kvar: fortsättning väntar 11–17 s, ja → nytt anrop 6,7 s (inget done.more i Frågor) | 2026-11-11 13:00 | 4 punkter |
| Kelly (demosida) | Opus 5.5 (claude-opus-5-5) | (sessionens inställning) | – (kön tom) | väntar på kö | Ke36 klar 12:45: A55–A61 godkända (V1, M1, G2 stängda; Ke35 byggd). **G3 öppet: "Ljud sparas inte" osant med Sov (30 dagar), ord till Deangelo i rapporten.** I dag Ke29–Ke36. API 0 USD, ElevenLabs 0 | 2026-11-11 12:45 | 8 punkter, byt snart (överlämning docs/HANDOVER-KELLY.md) |
| Ryan (annonser) | – | – | R1 konton och spårning | ny | – | – | – |
