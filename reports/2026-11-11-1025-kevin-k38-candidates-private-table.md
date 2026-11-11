# K38: K22-kandidaterna ligger i en privat tabell, inte i en publik artefakt (Kevin, 2026-11-11 10:25)

Uppgift: `prompts/queue/kevin.md` K38, efter Oscars O36 (`reports/qa/2026-11-10-1257-oscar-o36-k24-k27-omtest.md` avsnitt 1). Kostnad: **0 USD** (inga modellanrop, ingen ElevenLabs).

## Vad som är gjort
1. **Ingen artefakt längre.** `.github/workflows/real-users.yml` laddar inte upp något (`upload-artifact` borta, ett test kontrollerar det). Loggen skriver bara siffror.
2. **Kandidaterna läggs i tabellen `real_user_candidates`**, migrering `backend/supabase/migrations/20261111100000_real_user_candidates.sql`, **applicerad via MCP**.
   - Bara tjänstenyckeln når den (RLS på, inga policyer, `revoke all` från anon och authenticated).
   - Kolumner: text, läge, antal installationer, antal gånger, vecka och beslut. Inget användar-id och inget installations-id.
   - Rader som väntar eller är godkända raderas efter 30 dagar. Strukna rader sparas i 90 dagar så att samma fråga inte erbjuds varje vecka (cron `purge-real-user-candidates`, 03:29 UTC).
3. **Granskning, rad för rad:**
   - **Aron:** `backend/webtest/qa.html` har en ny del, "Riktiga användare: kandidater till testbanken", med knapparna Godkänn, Stryk och Ångra. Den går mot den nya funktionen `/functions/v1/real-users-admin`, som har samma ägarkontroll som K30: OWNER_EMAIL och inloggning med e-post. Kontrollen är utbruten till `_shared/owner.ts` och används nu av båda.
   - **Oscar:** via Supabase MCP, `update public.real_user_candidates set decision = 'approved' where id = '…'` (eller `'rejected'`).
4. **Till repot bara efter beslut.** Kör arbetsflödet "Real users (weekly)" för hand med rutan **approve** ikryssad. Jobbet `approve` (det enda med `contents: write`) gör då tre saker:
   - läser raderna med `decision = 'approved'` och filtrerar dem en gång till;
   - committar dem till `scripts/real-user-cases.json` och `real-user-bank.json`;
   - raderar dem ur tabellen, först efter att pushen gått igenom.
5. **Oscars förslag om fler skäl att stryka en rad** (O36 avsnitt 1), i `scripts/real_users.py` `why_dropped`:
   - skola med namn (Vasaskolan, Kungsholmens gymnasium; inte grundskolan, högskolan eller folkskola);
   - klass ("9B", "8C", "P14");
   - "rektorn", "koden"/"portkoden", lösenord och wifi, skåp, tandläkar- och läkartid, numret och adressen till någon;
   - förnamn plus efternamn eller förnamn i genitiv ("Zlatko Jönsson", "Arons"), utom kända efternamn ("Olof Palme", "Martin Luther King") och platser ("Nya Zeeland");
   - metodfrågor utan "jag" (tabletter för att dö, hur djupt, sluta äta, avskedsbrev, hänga sig …). De är **bara** i det här filtret. `crisis.ts` (svaren) är orörd.

## Tester
| | Före | Efter |
|---|---|---|
| Oscars O25b (34 fall): privata rader som aldrig blir kandidater | 12/22 | **22/22** |
| Oscars O25b: allmänna frågor som behålls | 12/12 | **12/12** |
| Oscars O25 (52 gamla fall) | 22/22, 20/20, 10/10 | **22/22, 20/20, 10/10** |
| Mina nya fall (skrivna efter rättningen, inte Oscars): privata rader stoppas | – | **19/19** (först 18/19; "portkoden" missades och lades till) |
| Mina nya fall: allmänna frågor behålls | – | **19/19** (först 14/19: folkskola, en rektor, "5 a", Mona Lisa, Martin Luther King; rättade) |
| `scripts/test_real_users.py` | 5 | **8 OK** (nya: tabellflödet med låtsad REST, Oscars O36-fall, ingen artefakt i flödet) |
| Backend `deno task test` / `deno task check` | 420 | **422 gröna**, typkontroll ren (riktig Deno 2.9.6 i molnet, inte Node-shimmen) |

**Verifierat live:**
- Med den publika nyckeln ger tabellen 401 för anon.
- För en anonym inloggad användare ger både läsning och skrivning 403 (`permission denied`).
- Supabase-rådgivaren ger bara INFO "RLS utan policy" för tabellen, vilket är avsiktligt, som för `qa_log`.

**Verifierat i GitHub:** de två tidigare körningarna av flödet (42793197521, 42803593382) har **0 artefakter**, eftersom hemligheten saknades. Inget med användartext har alltså någonsin laddats upp. Repot är publikt.

**Ej verifierat:**
- Hela kedjan med riktiga rader: hämtning, tabell, Godkänn, approve-körning, commit. Den kräver `SUPABASE_SERVICE_ROLE_KEY`, och det finns inga delade rader än.
- Att knapparna på sidan fungerar med Arons riktiga inloggning (inte provat, eftersom jag inte har hans e-post).

## Begränsningar och risker
- Filtren är mönster. Det som slinker igenom stoppas av människan i granskningen, sedan av filtret en gång till i approve-steget. Filtret stryker hellre en allmän fråga än släpper en privat.
- Godkända rader som filtret ändå stoppar i approve-steget raderas ur tabellen utan att skrivas till repot.
- `real-users-admin` är driftsatt (Deploy backend 42994924362 grön). Live: 403 för en anonym användare vid både GET och POST, 401 utan JWT. Flödet "Real users" kört för hand på main (42994942284): 8 tester OK, och hämtningen hoppades över eftersom hemligheten saknas.

## Till Aron
Det här gör du **när Oscar har godkänt K38** (han testar om):
- GitHub › repot › Settings › Secrets and variables › Actions › **New repository secret**.
- Name: `SUPABASE_SERVICE_ROLE_KEY`.
- Secret: Supabase › projektet Lumen › Project Settings › API Keys › **service_role** (eller en `sb_secret_…`-nyckel) › Reveal › kopiera.
- Det låser också upp K6 (röstproven) och nattens K4-körning.

## Nästa
- Oscar: omtest av K38 (nya oberoende fall, och att tabellen inte nås utan tjänstenyckel).
- Kevin: K37.
