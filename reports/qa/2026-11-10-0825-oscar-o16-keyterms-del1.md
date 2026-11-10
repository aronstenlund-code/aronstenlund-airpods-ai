# Oscar O16 del 1: Scribe stänger anslutningen på vissa keyterms (utan Scribe)

Datum: 2026-11-10 08:10–08:25
Uppgift: `prompts/queue/oscar.md` O16 (underlag: `reports/qa/2026-11-10-0815-deangelo-audio.md`, fynd 1)
Skript: `scripts/qa/o16_keyterms.py` (36 små Scribe-försök, färdigt att köra)
Rådata: `reports/qa/data/2026-11-10-0810-o16-probe.json`

## Status: Scribe-delen väntar på ElevenLabs-krediter
Första försöket fick inget svar från Scribe. Det gick helt utan keyterms.
- Scribe skickade `{'message_type': 'quota_exceeded', 'error': 'You have exceeded your quota.'}`.
- Därefter stängde Scribe med kod 1000 och `insufficient_funds_initial_check` (**verified live 08:10**).
- Därför går det inte att mäta Scribes regel nu. Skriptet är färdigt och körs så snart krediterna är påfyllda.

Det jag kunde göra utan Scribe står nedan.

## Vad Deangelos 22 stängda strömmar berodde på (verified from data)
- Alla 22 strömmar som stängdes med `1008 invalid_request` hade Historia-profilen ("his"). Inga andra profiler stängdes:
  - bio 26, kem 16, fys 15, mat 12, sam 3 och eng 3 strömmar gick bra;
  - de 45 strömmarna utan profil gick också bra.
- Historia-profilen i `scripts/qa/deangelo_audio.py` innehåller "industriella revolutionen". Termen har **25 tecken**.
- Hans skript kortar inte termerna. Det tar bara de första 20 termerna (`keyterms[:20]`).
- Det stämmer med regeln från O6: **en term över 20 tecken stänger sessionen**. Samhällskunskap var inte inblandat, trots vad rapporten säger. Den profilens längsta term är "Riksbanken" (10 tecken).

## Kan appen skicka något som bryter regeln? (verified in code)
- Alla Scribe-adresser byggs på ett ställe:
  - `ScribeProvider.swift:51` skickar keyterms genom `ScribeKeyterms.sanitized`;
  - inget annat i `Lumen/` sätter `keyterms`.
- `sanitized` ger högst 20 termer om högst 20 tecken:
  - en längre term delas på hela ord, och fyllnadsord tas bort;
  - ett ord som är för långt kapas vid 20;
  - samma term tas bara med en gång.
- Det finns enhetstester i `LumenTests/ScribeTests.swift:107–115`.
- `/study-profile` ger termer upp till **40** tecken (`PROFILE_LIMITS.term = 40`) och upp till 50 termer. Det är säkert så länge allt går genom appens filter, vilket det gör i dag.
- A8.5: om Scribe ändå stänger med 1008 öppnar appen igen utan keyterms (`scribeKeytermsDropped`). Ett dåligt ord gör alltså inte appen döv hela passet. Det är **verified in code**, inte på enhet.

## Risker som bara Scribe kan avgöra (untested assumption)
1. **Hur Scribe räknar tecken.** Swift `count` räknar grafem (det man ser som ett tecken).
   - Ett "ä" är ett grafem men två byte i UTF-8, och två kodpunkter om texten är NFD (till exempel inklistrad från vissa källor).
   - Om Scribe räknar byte eller kodpunkter kan "kärnkraftsolyckornaö" (20 grafem, 22 byte) stänga sessionen.
   - Försöken "len 20 with å/ä/ö" och "len 21 with å/ä/ö" i skriptet testar det.
2. **Specialtecken.** Appens filter tar inte bort `?`, `&`, `%`, `/`, `(`, emoji eller apostrof. `/study-profile` tar bort `.!?:;`, men termer från egna anteckningar eller övningsprov kan innehålla de andra tecknen. Skriptet har ett försök per tecken.
3. **Antal termer:** 20, 50, 100 och 101 provas. Appen skickar högst 20, så det gäller bara om gränsen höjs.

## Till Angela (förslag, inte bekräftat fel)
- Normalisera keyterms till NFC (`precomposedStringWithCanonicalMapping`) innan de räknas, så att ett "ä" alltid är en kodpunkt.
- Om O16 del 2 visar att Scribe räknar byte: räkna `utf8.count` mot gränsen.

Båda ändringarna är små i `ScribeKeyterms.sanitized`. Gör dem först när del 2 har visat vad Scribe kräver.

## Till Aron
Se O12 och O15: ElevenLabs-krediterna är slut. Det gäller både rösten (`/tts` 503) och taligenkänningen (Scribe `quota_exceeded`).
- Om appens reserver fungerar som koden säger blir det telefonens egen röst och taligenkänning tills krediterna fylls på. Det är inte provat på enhet.
- Jag fortsätter med O16 del 2 när krediterna finns.

## Kostnad
- 0 USD Anthropic.
- 1 Scribe-försök, som ElevenLabs nekade.
