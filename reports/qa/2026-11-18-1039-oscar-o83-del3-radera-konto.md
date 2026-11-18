# O83 del 3: radera kontot (K101), och omtest av taggarna (O80 F1), Oscar (moln)

**Resultat: K101 håller live.** Att radera kontot tar bort kontots egna prov, eget ljud och inbjudningskod, och delat ljud ligger kvar för andra. **Taggarna fungerar med riktig text:** med en riktig svensk text lade Haiku in v3-taggar i båda fallen. I går vägrade modellen min påhittade text. Kvar: `list` efter raderingen svarar 500 (Kevin känner till det). 2/2 live, 0 ElevenLabs (teströsten). Claude: två korta Haiku-taggningar. Actions 44276666233, 2026-11-18 09:31–09:33 UTC.

## K101: radera kontot (**verifierat live**, testkonton X, Y och Z)
Före raderingen hade X en egen text (140 tecken, eget ljud) och en text som Y också sparade. Y fick ljudet gratis (`cost 0`), alltså delat ljud.

| Steg | Svar |
|---|---|
| `POST /account/delete` utan `confirm` | 400 `confirm_required` "Bekräfta att kontot ska raderas." |
| med `{"confirm": true}` | 200 `deleted: true`, `removed: {audio_files: 1, shared_audio_kept: 1}`, `subscription: {active: false}`, `notice: null` |
| X hämtar sitt eget prov | 404 `not_found` |
| Y hämtar X:s prov | 404 |
| **Y:s prov med det delade ljudet** | **200, ljud 1/1 klart**, alltså kvar |
| **nytt konto Z, kostnad för X:s egna text** | **140**, alltså ljudet raderat |
| **Z, kostnad för den delade texten** | **0**, alltså ljudet kvar |
| Z tar X:s inbjudningskod `8eae6p52` | 404 `invite_not_found`, alltså koden raderad |
| radera igen med X:s token | 200 `deleted: true` (ofarligt) |
| X:s `list` efteråt | **500 `internal`** (känt, se nedan) |

Kravet i O83 del 3 är uppfyllt: allt kontots eget tas bort, och delat ljud lämnas kvar.

**Obs (låg, känt hos Kevin):** en gammal token efter raderingen ger 500 på `list`, när det borde vara 401. Det skapar ingen data, och appen loggar ut direkt (A145).

**Inte testat:**
- Att filerna i lagringen och raderna i krediter, attest och historik är borta. Det kontrollerades bara via API:t: kostnaden visar att ljudet är borta, och 404 att koden är borta. SQL för Deangelo finns nedan.
- Att en aktiv prenumeration får `notice`, eftersom det kräver ett riktigt köp.

## O80 F1 omtest: taggarna (**verifierat live**)
Kevin fann i loggen `style_failed Provider refused the request`: Haiku vägrade min påhittade text i går (påhittade ord, "Bafuko …"). Med riktig svensk text och stilen "Lugnt och tydligt, med pauser så att man hinner skriva" blev det så här:

| Text | Visade tecken | Rösttext utan stil (multilingual_v2) | Rösttext med stil (eleven_v3) |
|---|---|---|---|
| "Gustav Vasa valdes till kung i Strängnäs år 1523 …" | 248 | 264 (årtalet i ord) | **293**: 29 tecken taggar |
| "Fotosyntesen sker i växternas blad …" | 202 | 202 | **291**: 89 tecken taggar |

Taggarna läggs alltså in. Att orden är oförändrade kontrolleras i koden (`checkTagged`, 7/7 i mina hållout-tester), och den taggade texten finns bara i databasen.

**Obs (låg):** Haiku kan vägra en text, som mina påhittade ord. Då blir ljudet ändå gjort, utan taggar, med samma kostnad. Användaren märker bara att stilen inte hörs. Det är rimligt, men appen kan inte se det. Kanske bör `get` visa att stilen inte kunde användas.

## SQL för Deangelo (läs)
```sql
-- den taggade texten från dagens körning (väntat: [ … ]-taggar i texten)
select model, length(text) as tecken, left(text, 300) from drill_audio_files where voice_id = 'earmind-test-silent' and model = 'eleven_v3' and queued_at >= '2026-11-18T09:32:30+00:00' order by queued_at;
-- inget kvar efter raderade konton: rader i tabeller med user_id som saknas i auth.users (väntat 0 i alla)
select 'drills' t, count(*) from drills d where not exists (select 1 from auth.users u where u.id = d.user_id)
union all select 'credit_ledger', count(*) from credit_ledger c where not exists (select 1 from auth.users u where u.id = c.user_id)
union all select 'drill_quota', count(*) from drill_quota q where not exists (select 1 from auth.users u where u.id = q.user_id);
```
