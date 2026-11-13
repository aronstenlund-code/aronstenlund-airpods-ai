# Överlämning: Kevin (backend), 2026-11-13 21:00 (lokal session, Windows)

Sessionen gjorde stående omgång 21 och K45–K49 (repetitionsläget). Rapporter: `reports/2026-11-13-1750-kevin-standing21-interview-first-person.md`, `reports/2026-11-13-2035-kevin-k45-k48-repetition.md` och `reports/2026-11-13-2049-kevin-k49-publish.md`. Beslutet heter D153 (Deangelo numrerade om det). Nästa punkt är **K50** (röstval, gräns 30 frågor, kostnadskontroll, D151), sedan K6. Den hemlighet K6 väntade på finns nu.

**Arbetssätt på den här datorn**
- **Riktig Deno:** `npm i deno@2` i scratchpad och kör sedan `<mapp>/node_modules/.bin/deno task test` / `task check` i `backend/`. Ingen Node-shim behövs.
- **GitHub-API:t:** token via `git credential fill`, plus ett litet curl-skript (`gh.sh METHOD PATH [json]`). Ett flöde startas med `POST /actions/workflows/<fil>/dispatches {"ref":"main"}`.
- **Supabase:** den allmänna kopplingen (`mcp__393224ed…`) fungerar för `apply_migration`, `execute_sql` och `query_logs`. Fel i funktionerna syns i `query_logs`, sök på `unexpected_error`.
- **Bash-heredoc med Python som innehåller `'`, `\p{L}` eller `\d` går sönder.** Skriv patchskriptet med Write och kör `python -X utf8 -I fil.py`.
- **Delad utcheckning:** Angela, Deangelo, Oscar och Toby rebasar med autostash i samma mapp.
  - Lämna aldrig egna ändringar i DECISIONS, STATUS eller tavlan ocommittade. Committa direkt med en sökväg.
  - Är en annan sessions rebase igång (`.git/rebase-merge`): vänta, rör den inte.
  - Kolla beslutsnumret precis före commit, eftersom D148–D154 togs inom en timme i dag.
- **Anonyma inloggningar:** cirka 30 per timme och IP-adress. Livetesterna (`k45-measure.py`, `k46-live.py`, `k49-live.py`) gör 1–5 var.
- **PostgREST:** en massinsättning kräver samma nycklar i alla rader. En `void`-funktion svarar 204 utan innehåll, och då kastar `RestDb.rpc`. Låt funktioner returnera något.

**Läge**
- **`/exam`:** `drill`, `drill_answers`, `drill_one` och `doc_text`, med Haiku för frågorna och Sonnet för svaren. R3 ligger på 77 % frågor med högst 5 ord (kravet är 80 %, matte drar ner).
- **`/drill`:** save, get, status, list, delete, share, unshare, share_info och import, samt publicering: schools, publish, unpublish, search, report, played och moderate. Ljudet läggs i kön `drill_audio_files` och görs med `eleven_multilingual_v2` (`DRILL_TTS_MODEL`). K50 ändrar det per prov.
- **`/voice-lab` `sample`:** godtar både den gamla JWT-nyckeln och `sb_secret_`. Den nyckel Aron lade i GitHub är av det nya slaget.
- **`schools`:** 7 458 aktiva skolor, synkade varje måndag av "Schools sync (K49)".
- **Ej verifierat live:** `played` och `imports` efter rättningen av `bump_publication`. IP-gränsen hade nåtts. Kör `scripts/k49-live.py` igen.
- **ElevenLabs-nyckeln** kan inte läsa kontot (401 på `/v1/user/subscription`). Arons plan och krediter går inte att se härifrån.

**Öppna trådar**
- Aron: välja röst i blindtestet via Deangelo, och Startup Grants (Till Aron #14).
- Oscar: O55 (R2 och R4) och O56 (R12).
- Ingen gallring av ljudfiler som inget prov längre använder.
- Ingen modereringsvy för Aron. `moderate` finns bara som API.

---

# Överlämning: Kevin (backend), 2026-11-11 20:11

Sessionen (molnet, komprimerad en gång) gjorde K36–K42, K40b och stående omgång 2–18. Nattpass till 2026-11-12 07:30. Nästa session: `git pull`, tavlan, `prompts/queue/kevin.md`. K6 väntar på `SUPABASE_SERVICE_ROLE_KEY`.

**Arbetssätt som sparar tid (molnet)**
- **Riktig Deno går att installera:** `npm i deno@2` i scratchpad, sedan länka `node_modules/.bin/deno` till `/usr/local/bin/deno`. Då fungerar `deno task test` och `deno task check`, med typkontroll. Node-shimmen behövs inte.
- Tavlan krockar ofta med andra sessioner. Lös det med `git checkout --ours prompts/queue/BOARD.md`, skriv in din rad igen och kör `rebase --continue`.
- Containerns klocka är UTC. Rapportnamn och tider på tavlan ska vara i svensk tid: `TZ=Europe/Stockholm date`.
- Supabase MCP: `apply_migration` kan ge Bad Gateway utan att något ändrats. Kontrollera med SQL och kör igen.
- `delete` via `execute_sql` och `create_edge_function_secret` frågar Aron och fastnar när han inte är där. Undvik dem i självständigt läge.
- Webbsidor med bot-skydd (UR Play ger 403) ska inte kringgås. K19 litar i stället på webbsökningens egna resultat.
- **Kör `deno task check` före push.** Testlistan i deploy-flödet typkontrollerar, så ett typfel stoppar driftsättningen. Det hände en gång i dag (`d41c139`).
- Regressionens rader finns som artefakten `answer-regress`: `gh run download <id> -n answer-regress`.
- Appen skickar Standardläge som `mode: "auto"`. Testa verktyg och liknande i `auto` med "Lumen, …", inte bara med `push_to_talk` (O41).

**Läge** (K42: `isRankQuestion` skickar rangordningsfakta till Sonnet, `asklength.ts` följer en uttalad längd, `lonecmd.ts` väntar på A74:s `stt_confidence`/`utterance_ms`)
- API: dagen cirka 4,3 USD, i kväll hittills cirka 2,5 USD (taket i natt är 6). Regression 0,33 USD per körning.
- Regressionen på 21 fall varierar mellan 81 och 100 % utan att koden ändrats, så en enskild körning säger lite.

**Öppna trådar**
- **Aron:** `SUPABASE_SERVICE_ROLE_KEY` (efter Oscars godkännande av K38) låser upp K6 och K22. Spotify-appen (klickväg i `docs/AGENT.md`). O16: ElevenLabs med zero retention före beta. En teströst (C) från Kevin ligger i `logo_votes`; den raderas när Aron kan bekräfta.
- **Angela:** A62: `done.quiz_key` till Scribe och tillbaka som `context.quiz_key` (K40-rapporten). A53 (Mina svar), A54 (`/logo-vote`), samtal, `music_open` och Spotify (protokollen i rapporterna och i `docs/AGENT.md`). Om appen bör säga samma sak som `self.ts` om ElevenLabs.
- **Oscar:** omtest av K38, grupp 13 och 14. Hans `o24`- och `o36`-skript känner igen svaren på de gamla texterna.
- **Concern (Oscar O39, Kevin instämmer):** Mina svar kan fungera som fusk under ett prov. Det är Architects beslut.
- Shopify (K35 fas 2) kan byggas på `connections` (`provider` får ett nytt värde) när Partner-appen finns.
- **Kris och verktyg (O42):** en sen krismarkör från modellen räknas inte för korta, riktade telefonkommandon utan krissignal i koden. "ring Bris, jag vill inte leva" ger krissvaret och samtalet. Rör det försiktigt.
- **Auto mot Provläge:** en avklippt fråga är tystnad i Auto men besvaras i Provläge (D87 "half"). Rättelser går till `/memory` med en Haiku-reserv (0/30 falska enligt O49). Appen skickar i dag bara fasta ord dit.

- **Akta filnamn:** `answer/length.ts` finns redan (svarstyp och fortsättning). Den uttalade längden ligger i `asklength.ts`. Kontrollera alltid med `ls` innan du skapar en ny fil.
