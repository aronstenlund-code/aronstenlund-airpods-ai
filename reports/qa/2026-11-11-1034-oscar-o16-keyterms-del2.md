# Oscar O16 del 2: Scribes regler för keyterms, mätta live

Datum: 2026-11-11, 10:15–10:27 (svensk tid). Molnsession (Linux), inte Arons dator.
Uppgift: O16 i `prompts/queue/oscar.md`. Ta reda på exakt vilken regel Scribe v2 Realtime har för keyterms (längd, byte/tecken, antal ord, specialtecken, antal termer), och kontrollera att appens filter (A8.5/A14) och `/study-profile` aldrig skickar något som bryter den. Del 1: `reports/qa/2026-11-10-0825-oscar-o16-keyterms-del1.md`.

**Skript:**
- `scripts/qa/o16_keyterms.py`: 36 försök.
- `scripts/qa/o16b_keyterms_extra.py`: 7 försök, nytt (NFD, emoji, omkörning).

**Rådata:** `reports/qa/data/2026-11-11-1015-o16-probe.json`, `…-1024-o16.json` och `…-1026-o16b.json`.

**Kostnad:**
- **0 ElevenLabs-tecken.** Det cachade O12-klippet ligger bara på Arons dator, så ljudet är 1 s lokalt syntetiserat tal (espeak-ng, "Vad är fotosyntes?"), D120.
- **61,6 Scribe-sekunder** (44 strömmar × 1,4 s inklusive tystnad).
- 0 USD i API.
- Varje ström öppnas som appen gör: `/stt-token`, VAD-värdena från Provläge, 16 kHz och en enda varierad keyterm-uppsättning.

## Regeln (verified live)
Scribe stänger anslutningen med `1008 invalid_request` och ett tydligt felmeddelande i exakt två fall:

| Regel | Felet från Scribe | Försök |
|---|---|---|
| **En term får vara högst 20 tecken, räknat i Unicode-kodpunkter** (inte byte, inte grafem) | `Each keyterm must be at most 20 characters. 'abcdefghijklmnopqrstu' is 21 characters.` | 20 a–t godtas, 21 nekas. 20 tecken med å/ä/ö (NFC, 23 byte i UTF-8) godtas, 21 nekas. **NFD "kärnkraftsolyckornaö"** (20 grafem, 22 kodpunkter) **nekas: "is 22 characters"**. NFD 17 grafem = 20 kodpunkter godtas. 🧬 + 19 bokstäver (20 kodpunkter) godtas |
| **Högst 50 termer** | `Number of keyterms cannot exceed 50. You provided 100 keyterms.` | 20 och 50 godtas, 100 och 101 nekas |

**Allt annat godtas:**
- 2–6 ord.
- Siffror, bindestreck, snedstreck, `&`, parenteser, kolon, apostrof, komma, punkt, `%`, `+=`, frågetecken och emoji.
- Inledande mellanslag, tom sträng, dubbletter och versaler.

Deangelos Historia-lista godtas. Samhälle-listan nekas på grund av `tryckfrihetsförordningen` (24 tecken). Det är samma mekanism som i del 1 ("industriella revolutionen", 25).

**Brus, inte regeln:** 6 av 44 strömmar stängdes med `1006` (onormal stängning), men först **efter** att Scribe hade gett transkriptet. Det hände när mitt skript stängde anslutningen. Omkörning av två av dem gav ett godkänt resultat. Det har inget med keyterms att göra, och det är inte prövat om appen ser samma sak.

## Appen mot regeln
`ScribeKeyterms.sanitized` (`Lumen/Core/Transcription/ScribeProvider.swift:60`), som allt passerar (`TranscriptionCoordinator.scribeKeyterms`):
- **Antal:** högst 20 termer, under Scribes 50. **OK.**
- **Längd:** högst 20 med Swifts `String.count`, som räknar **grafem**. Scribe räknar **kodpunkter**. **Lucka:**
  - Ett ord i NFD-form, där å/ä/ö är bokstav plus kombinerande tecken, kan vara 20 grafem men 21–25 kodpunkter. Appen släpper igenom det och Scribe stänger sessionen. Samma sak gäller emoji med ZWJ (👨‍👩‍👧 är 1 grafem men 5 kodpunkter).
  - **Hur troligt:** text från iOS-tangentbordet är NFC. NFD kommer från inklistrad text, PDF:er, filnamn från macOS och vissa OCR-flöden.
  - Med A8.5 öppnar appen sedan resten av körningen utan keyterms. Det blir alltså sämre igenkänning av ämnesorden, inte döv mikrofon. **verified in code**, inte på enhet.
- `/study-profile` skickar termer upp till 40 tecken (`PROFILE_LIMITS.term`). Det är **OK** så länge allt går genom appens filter. Det gör det enligt koden.

**Fynd till Angela (prio 3, en rad):** i `ScribeKeyterms.sanitized`, normalisera först med `precomposedStringWithCanonicalMapping` (NFC). Räkna sedan längden med `unicodeScalars.count` i stället för `count`, både i jämförelsen och när ord delas eller kapas (`prefix` på kodpunkter). Testfall: `"kärnkraftsolyckornaö".decomposedStringWithCanonicalMapping` ska bli 20 kodpunkter eller kortare.

## Bifynd: ElevenLabs sparar Scribe-sessionerna (verified live)
Alla 38 strömmar som Scribe godtog (de 6 nekade fick bara felet) fick det här svaret från Scribe:

> `Zero retention mode was requested (enable_logging=false) but was not applied. Only users from the enterprise or trial tier can use ZRM mode. This session is still being logged.`

Kevin vet det redan: det står i kommentarerna i `stt-token/handler.ts:195` och `provlage-eval/handler.ts:221`. Men det eleven läser stämmer inte:
- `Lumen/Features/Settings/AboutView.swift:38`: "ElevenLabs Scribe … Ljudet skickas för att skrivas ut och **sparas inte**." Det är **osant** med vår nuvarande ElevenLabs-nivå.
- `ConsentView.swift:35`: "Lumen sparar aldrig ljud". Det är sant för Lumen, men eleven kan uppfatta det som att ingen sparar ljudet.

Det rör B2 (samtycke) och GDPR, eftersom det är andra människors röster. Gäller troligen `/tts` också (D48), men det är inte kontrollerat i dag.

## Till Aron
Ett beslut. **Rekommenderar (a)** nu och (b) inför beta:
- **(a)** Ändra texten i appen till sanningen: "ElevenLabs skriver ut ljudet och kan spara det enligt sina villkor." Det kan Angela göra.
- **(b)** Ta reda på priset för ElevenLabs med zero retention (enterprise) före TestFlight med elever.

## Till Angela
1. `ScribeKeyterms`: räkna kodpunkter och normalisera till NFC (se ovan).
2. Texten i Om appen, efter Arons beslut.

## Kvar
- O16 är klar.
- O13 del 3 (uttal genom `/tts`) kräver det cachade TTS-ljudet. Det ligger bara på Arons dator (`scripts/qa/audio-cache/o13d3/`, git-ignorerat) och finns inte i molnsessionen. Jag genererar det inte igen (D120), se min rad på tavlan.
