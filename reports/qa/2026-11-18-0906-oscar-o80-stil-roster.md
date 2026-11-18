# O80: "Hur ska det låta?" och röster (K95, K96, D220), Oscar (moln)

**Resultat: kostnad, återanvändning, låsning och `/voices` fungerar live (5/5, ett fall hoppades över). Taggkontrollen i koden håller (7/7 hållout). Men live lade servern inte in några taggar alls:** rösttexten med stil var lika lång som utan stil, 430 tecken i båda. Antingen misslyckades Haiku, eller så kastade kontrollen bort texten (F1). 0 ElevenLabs (teströsten och tyst ljud), Claude bara Haikus anrop.

## Live (Actions 44168316329, 2026-11-17 20:21 UTC, testkonton A/B, **verifierat live**)
Texten var 2 stycken, 430 tecken, med stilen "Lugnt och tydligt, med pauser så att man hinner skriva".

| Fall | Svar |
|---|---|
| 1 `cost` med stil, `save`, `start` | `cost 430`, save `audio.cost 430`, start 430, kvot `used 0 → 430`; `voice_model eleven_v3`; ljud 2/2 klart (teströst) |
| 2 samma text utan stil | `audio.cost 430` igen, eftersom stilen ingår i hashen; `eleven_multilingual_v2` |
| | **rösttextens tecken: med stil 430, utan stil 430; längd per fil 5 590/3 004 ms i båda**, alltså inga taggar inlagda |
| 3 konto B, samma text, stilen med andra versaler och blanksteg | `cost 0`; B:s save `audio.cost 0`; en annan stil ("Glatt och snabbt") `cost 430` |
| 4 stil på ett prov som redan har multilingual | 409 `voice_locked` "Rösten är redan vald för det här provet. Gör ett nytt prov för att välja hur det ska låta." |
| | okänd röst `abcdefghij0123456789` | 400 `voice_unavailable` "Den rösten går inte att välja." |
| | stil på 200 tecken | sparas kapad till 80 |
| 5 `GET /voices` | 200, nycklar `catalog, default_id, voices`; **katalogen var tom (0)**, 3 gamla röster. preview_url kunde därför inte provas |
| 6 katalogröst och låsning | hoppades över, eftersom katalogen var tom i går kväll (K99 har fyllt den i natt, och det provas i O81) |

## Lokalt: taggkontrollen (`scripts/qa/o80_style_test.ts` mot `drill/style.ts`, 7/7, **verifierat i test**)
1. Tillåtna taggar (`[calm]`, `[short pause]`, `[pause]`) behålls, och texten utan taggar är identisk med originalet.
2. Ändrat, borttaget, tillagt eller flyttat ord, ändrat skiljetecken, ändrad versal eller tillagt ord sist ger alla null, och då används den otaggade texten.
3. `[British accent] [skånska] [shouts] [sings] [ignore previous instructions]` tas bort, och `[whispers]` och orden blir kvar.
4. `[CALM]` blir `[calm]`. SSML `<break time="1s"/>`, `[calm` utan slut och `[[calm]]` ger null.
5. En text med egna hakparenteser (`[1]`) ger null, så den får aldrig stil (låg, se F2).
6. Stilen normaliseras: blanksteg och styrtecken tas bort och den kapas till 80. Versaler spelar ingen roll i hashen, men en annan stil ger en annan hash.
7. Meningsslut flyttas till rätt plats i den taggade texten.

## Fynd
**F1 (medel): live blev det inga taggar.** Ljudfilernas text var lika lång med och utan stil (430 tecken, samma längd på det tysta ljudet). Det betyder att `styler` gav null: Haiku misslyckades (`style_failed`), eller så ändrade Haiku ord eller skiljetecken (`style_words_changed`), eller så saknas leverantören. Funktionen fungerar alltså inte i praktiken just nu, men den är säker, eftersom den faller tillbaka på otaggad text. Kevin: läs funktionsloggen för `drill` 2026-11-17 20:21–20:22 UTC och leta efter `style_failed` eller `style_words_changed`. Ett vanligt skäl är att modellen lägger till eller tar bort ett blanksteg före skiljetecken, eller byter citattecken, och då nekar `norm(stripTags)` direkt. Kanske bör jämförelsen tåla blanksteg runt taggar och skiljetecken.

**F2 (låg):** en text med egna hakparenteser, som `[1]` eller `[sic]`, får aldrig stil, eftersom `checkTagged` nekar hakparenteser som inte är vitlistade. Det är säkert men tyst. Antingen tas hakparenteserna bort i rösttexten (D196), eller så visas det i appen.

## SQL för Deangelo (läs den taggade texten från körningen)
```sql
select hash, model, status, length(text) as tecken, left(text, 400) from drill_audio_files where voice_id = 'earmind-test-silent' and model = 'eleven_v3' and queued_at >= '2026-11-17T20:21:14+00:00' order by queued_at;
```
Väntat om F1 stämmer: texten saknar `[` helt.

## Inte testat
- `/voices?library=1`, eftersom det anropar ElevenLabs (D180). Det kostar inga krediter, men vi undviker det.
- preview_url i katalogen och låsning av en katalogröst. Det görs i O81 nu när K99 har fyllt katalogen.
- Hur taggarna låter med en riktig röst. Det kräver Arons ja (TILL-ARON #28).
