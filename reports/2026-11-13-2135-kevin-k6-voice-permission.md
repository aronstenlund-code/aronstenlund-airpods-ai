# K6: roliga röster väntar på en behörighet på ElevenLabs-nyckeln (Kevin, 2026-11-13 21:35)

## Vad som hände
- **Förberedelsen:** tjänstenyckeln finns nu i GitHub, så jag körde förhandsproven för K6. Det är fem påhittade karaktärer i `scripts/k6-voices.json`: säljcoach, sportkommentator, viskare, radioröst och sagoberättare. Texterna lästes 10 nov och igen i dag. De är påhittade och nämner inga verkliga personer.
- **Flödet** "Credits ready (K18 + K6)" fick valet `only: k6`, så att K18 inte mäts om (den är redan mätt, D120).
- **Resultatet:** alla fem gav 503. Med ElevenLabs felbeskrivning i svaret (bara tjänstenyckeln ser den) står det **verifierat live**: *"The API key you used is missing the permission voice_generation"* (401).
- **Kostnad:** 0 tecken och 0 krediter, eftersom anropen nekades. Skriptet stoppar nu efter första sådana fel.
- **Samma nyckel** saknar också rätt att läsa kontot (401 på `/v1/user/subscription`, K46). Därför syns Arons plan och krediter inte härifrån.

## Det Aron gör (Till Aron #15)
elevenlabs.io › Developers › API Keys › den nyckel som ligger i Supabase som `ELEVENLABS_API_KEY` › Edit:
1. Slå på **Voice Generation** (Voice Design). Behövs för K6.
2. Gärna också **User: Read**. Då kan servern logga plan och krediter (K46), men aldrig nyckeln.

Nyckeln behöver inte bytas och inget annat ändras. Säg till i chatten när det är gjort, så kör jag flödet igen. Det blir cirka 1 000 tecken text för fem karaktärer med tre förhandsprov var, och inget sparas i kontot.

## Sedan
Förhandsproven blir en artefakt, `k6-voice-previews`, för Aron att lyssna på. När han har valt sparas de valda rösterna i kontot. Det är en kontoändring som han godkänner först. Därefter läggs de i `/tts`-vitlistan med licens per röst i DECISIONS. Voice Design-röster som vi själva skapat får användas kommersiellt enligt ElevenLabs villkor. **Antagande, ej testat**: villkoren kontrolleras före sparandet.
