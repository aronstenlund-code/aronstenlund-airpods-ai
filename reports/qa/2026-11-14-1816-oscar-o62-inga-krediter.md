# O62: gör testerna några riktiga ElevenLabs-anrop efter Kevins rättning? K64 och K63 (Oscar, 2026-11-14 18:16)

Status för varje påstående: **verifierat live** (mot driftsatt backend, funktionsloggen och databasen via Supabase MCP), **verifierat i docs** eller **antagande, ej testat**.
Ingen app eller enhet. **0 riktiga ElevenLabs-anrop.** Claude under 0,01 USD (/help).

## Svaret till Aron
**JA. Testerna tar inga ElevenLabs-krediter längre.** Mina testkonton sparade, tog bort, publicerade och delade prov. Under anropen och 25 minuter efteråt (16:49–17:16 UTC) gjordes inga riktiga ElevenLabs-anrop:
- funktionsloggen har 0 rader om ElevenLabs, ljudkön eller skyddet, under 269 loggrader varav 137 testanrop
- databasen har 0 nya filer med riktig röst
- 78 nya filer har alla teströsten och 0 krediter

Det gäller testtrafik. Riktiga användare gör fortfarande riktigt ljud, och det ska de. Verifierat för det som anropas i dag (drill, tts, stt-token, voice-lab, provlage-eval). En ny funktion som anropar ElevenLabs behöver samma skydd (**antagande**, att ingen glömmer det).

## (1) Kevins rättning av mitt O61-fynd 1
| Steg | Resultat |
|---|---|
| `o55_drill_server.py`: spara, dela, importera, ändra, ta bort, RLS | 30/33. De 3 som avviker beror på testläget, se nedan |
| `o56_publish.py`: publicera, sök, hämta, rapportera, avpublicera, ta bort | 38/42. Samma 4 som i O61: 3 avsiktliga, 1 beror på testläget |
| K64-proven nedan: spara, ta bort, `slow`, `unavailable`, kvoten | allt rätt |
| Funktionsloggen 16:49–17:16 UTC (sökt på `elevenlabs`, `drill_audio`, `drill_pump`, `TestCredits`, `D180`) | **0 rader**. Loggen har 269 rader i fönstret, så sökningen fungerar |
| `drill_audio_files` som köats sedan 16:49 | 66 klara och 12 `failed` (borttagna prov), **alla med teströsten, 0 krediter**. 0 filer med riktig röst |
| Filer med riktig röst som inte är klara | 11, samma som 16:51. Inga nya försök på dem |

Andra kontrollen gjordes 17:16, alltså 12 minuter efter mina sista anrop och 26 minuter efter de första. Det är längre än de 10 minuterna innan filer utan krediter görs om.

**Avvikelser som beror på testläget (inga fel):**
- O55: "dela före klart ljud ger 409" kan inte testas, eftersom det falska ljudet blir klart direkt. Det går nu med `x-earmind-test: … slow`, se K64.
- O55: "ändrad fråga ger bara den frågans fil" och "mottagarens ändring kostar bara den frågan" kan inte mätas med `new_chars`. Testkonton får nu `new_chars 0`, eftersom det falska ljudet är gratis. Förut gav det 36 och 37.
- O56: ämnet tas från provet och en okänd rapportorsak blir "annat". Båda är avsiktliga och kända från O56 13 nov. "Ljudet inte klart" går nu att testa med `slow`.

## (2) K64 (`reports/qa/data/2026-11-14-1808-o62-k64.json`)
| Fall | Resultat |
|---|---|
| Spara 2 frågor med `x-earmind-test: oscar-qa slow` | 0 av 4 klara, och efter `status` fortfarande 0 av 4 (står kvar som väntande) |
| … och ta bort provet | alla 4 filer `failed`, "unused: the drill was deleted (K64)". **Fynd 2 rättat** |
| Spara med `… unavailable` | 4 av 4 `failed`, varje fil `error: "audio_unavailable"` |
| `/tts` med `… unavailable` | 503 `tts_unavailable` |
| … och ta bort provet | filerna "unused: the drill was deleted (K64)" |
| 15 sparade frågor, sedan en till | 402: "Du har gjort 15 av 15 frågor med ljud den här månaden. Nya frågor går att göra från den 1 december. Andras prov är gratis." "Köp ett abonnemang" är borta |

Begränsning: fynd 2 gällde filer med riktig röst. Testkonton kan bara skapa filer med teströsten, enligt D180. Samma kodväg tar bort filerna, och Kevins enhetstest täcker riktig röst, alltså **verifierat i docs** för riktig röst.

## (3) K63: EarMind med stort M (`reports/qa/data/2026-11-14-1753-o62-k63-earmind.json`)
- **/help:** 12 frågor, bland annat:
  - "vad heter du" och "vad är earmind"
  - Android, språk och Spotify
  - 2 frågor utanför appen

  Svaren och tipsen innehöll "EarMind" 9 gånger och den gamla stavningen 0 gånger. Exempel: "Jag är hjälpen i EarMind.", "EarMind för Android finns inte i dag." och tipset "Jag svarar bara på hur EarMind fungerar …".
- **Importen:** svaren innehåller inget appnamn. Importens text behåller elevens stavning ("Vad är EarMind?" blev kvar ordagrant).
- **Källorna:** `docs/HJALP.md`, `Shared/chatgpt-prompt.txt` och `Shared/capabilities.json` har 0 förekomster av "Earmind". De fasta texterna i `backend/supabase/functions` har inga heller (`x-earmind-…`, `earmind://` och `earmind.ai` är tekniska namn och är oförändrade).

## Fynd till Kevin
Inga nya fel. En liten iakttagelse: "vad kostar det" ger bara "Ett abonnemang kommer senare …" och nämner inte de 15 frågorna per månad. Det är inte fel, men det är halvt svar (prio 3).

## Filer
- `reports/qa/data/2026-11-14-175016-o55-drill-server.json`, `…-175039-o56-publish.json`, `…-1753-o62-k63-earmind.json`, `…-1808-o62-k64.json`

## Nästa
- Aron kan köpa krediter, från testernas sida.
- Oscar: väntar på kö.
