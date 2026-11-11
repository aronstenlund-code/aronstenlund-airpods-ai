# Oscar O52: Omtest av K44 (Earmind vet vad den heter och vad den kan) + omtest av klockan (O52s) och K43 (O53)

Datum: 2026-11-11. Förmätning 21:42 och eftermätning 23:24–23:28 (svensk tid).
Uppgift: O52 i `prompts/queue/oscar.md` (Deangelo 21:20). K44 (`1d5237a`, `8d91f5a`, slutrapport `03b057d`, D141) svarar utifrån `Shared/capabilities.json`.
- K44 driftsattes först 23:15–23:19 med `b1e9305` och `8d91f5a`. De köade jobben för `1d5237a` och `e3fedc0` står fortfarande i kö efter GitHub-störningen, men de är inaktuella.

**Fallen:** 40 nya frågor av typen "kan du …?", "vad kan du?", "vad är Earmind?" och "hur gör jag …?", skrivna 21:35 utifrån `capabilities.json` och inte ur Kevins tester.
- Alla körs i Standardläge (`mode: auto`), och de 12 första även i Provläge (`mode: tutor`).

**Skript:** `scripts/qa/o52_k44_live.py`.
**Rådata:** `reports/qa/data/2026-11-11-214227-o52-k44-fore.json` och `…-232455-o52-k44-efter.json`.
**Kostnad:** cirka 0,2 USD (Haiku), 0 ElevenLabs.

## Resultat: **K44 GODKÄND**
| | Före K44 | **Efter K44** | Krav |
|---|---|---|---|
| Standardläge | 26/40 | **39/40** | |
| Provläge | 9/12 | **12/12** | |
| Förnekar något som finns ("Jag kan inte sätta timers", kalender, webb, väder, anteckningar …) | **7** | **1** | aldrig |
| Tysta (kan du översätta, kolla vädret, hur pausar jag dig …) | **8** | **0** | |
| "studieassistent" | 2 | **0** | aldrig ✅ |
| Namnet ("vem är du", "vad heter du", "vad är Earmind") | 3/3 med Earmind (men "Jag heter Earmind, **inte Lumen**" 2 gånger) | **3/3, och "inte Lumen" 0 gånger** | ✅ |

**Exempel efter:**
- "Lumen, vad kan du göra" ger "Jag är en AI-agent i dina AirPods för vardag, skola och jobb. I skolan: svar på frågor, förhör, mina svar. I vardagen: kalender, påminnelser, timer, l…"
- "kan du kolla vädret" ger "Ja. Säg till exempel: Lumen, vad blir vädret i morgon?."

**Kvar (prio 3, till Kevin):**
1. **Morgonrapport:** "kan du ge mig en morgonrapport om min sömn" ger "Jag har ingen tillgång till din sömndata, så en morgonrapport kan jag inte ge än. Säg … 'Lumen, sömn'". Sömn har status "finns" (`say`: "Tryck Sov på kvällen, så får du en morgonrapport när du vaknar"), så svaret borde vara just det.
2. **Spotify:** "kan du styra Spotify och byta låt" ger "**Ja.** Säg till exempel: Lumen, spela lugn pluggmusik." Att styra Spotify har status "kommer", och `music_open` byter ingen låt. Svaret borde vara "Det kommer snart; i dag kan jag öppna musik åt dig".
3. **Skiljetecken:** "…i morgon?." (punkt efter frågetecken) syns i texten. Det hörs inte, men det står på skärmen.

## Omtest O52s: klockan, **RÄTTAD**
`b1e9305`: den lokala tiden sägs av kod. `scripts/qa/o52_clock_live.py`, `…-232437-o52-clock.json`:
- 23:24, med 5 formuleringar, gav **5/5 rätt**: "Klockan är sex minuter i halv tolv på kvällen, alltså tjugotre och tjugofyra." (före: 0/5)

## Omtest O53: K43 testläget, **RÄTTAT**
- `opt_in` och `enabled()` kräver nu `amr` otp/magiclink, alltså inloggning med e-postkod (`debug-audio/handler.ts:101` och `:127`, verified in code).
- Klientsidan är fortfarande **23/23 stängd** (`…-232447-o53-k43.json`).
- Gränsen för antal byte per dygn finns inte: 3000 turer × 1,5 MB per användare och 30 000 totalt (`DEBUG_AUDIO_LIMITS`). Nu når bara Aron och testare med e-postkod uppladdningen, så risken är liten. Inte blockerande.

## Till Aron
- "Vad är klockan?" svarar nu rätt.
- "Vad kan du?" beskriver hela Earmind och förnekar inte timers, kalender eller väder längre.

## Tillägg 2026-11-12 00:02: omtest efter Kevins K44b (`9e0e85b`, driftsatt 23:57)
Rådata: `reports/qa/data/2026-11-12-000238-o52-k44-efter2.json`. Sex frågor körs i Standardläge och Provläge (12 anrop, under 0,01 USD).
- **Morgonrapport:** "kan du ge mig en morgonrapport om min sömn" ger "Ja. Tryck Sov på kvällen, så får du en morgonrapport när du vaknar." (2/2) **Rättat.**
- **Spotify:** "kan du styra Spotify och byta låt" ger "Det kommer snart. Styra Spotify (spela, pausa, nästa låt) går inte än. I dag kan jag öppna musik åt dig …" (2/2) **Rättat.**
- **Skiljetecken:** "?." 0 gånger. **Rättat.**
- **Ny, prio 3:** "**hur gör jag** för att få en morgonrapport" går inte genom listan. I Standardläge hittar modellen på att det är "en sammanfattning av dagens väder, kalender och viktiga nyheter". I Provläge säger den "En morgonrapport kan jag inte skapa som en återkommande funktion än". Frågor av typen "hur gör jag …" om något som finns i listan bör få listans `say` (här: "Tryck Sov på kvällen").
