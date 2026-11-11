# Överlämning: Kevin (backend), 2026-11-11 11:30

Sessionen (molnet) gjorde K38, K37, K39, K36 och stående omgång 2, och är inte komprimerad. Nästa session börjar med `git pull`, tavlan och `prompts/queue/kevin.md`. Kön är tom utom K6, som väntar på `SUPABASE_SERVICE_ROLE_KEY`.

**Arbetssätt som sparar tid (molnet)**
- **Riktig Deno går att installera:** `npm i deno@2` i scratchpad, sedan länka `node_modules/.bin/deno` till `/usr/local/bin/deno`. Då fungerar `deno task test` och `deno task check`, med typkontroll. Node-shimmen behövs inte.
- Tavlan krockar ofta med andra sessioner. Lös det med `git checkout --ours prompts/queue/BOARD.md`, skriv in din rad igen och kör `rebase --continue`.
- Containerns klocka är UTC. Rapportnamn och tider på tavlan ska vara i svensk tid: `TZ=Europe/Stockholm date`.
- Supabase MCP: `apply_migration` kan ge Bad Gateway utan att något ändrats. Kontrollera med SQL och kör igen.
- `delete` via `execute_sql` och `create_edge_function_secret` frågar Aron och fastnar när han inte är där. Undvik dem i självständigt läge.
- Webbsidor med bot-skydd (UR Play ger 403) ska inte kringgås. K19 litar i stället på webbsökningens egna resultat.
- Avbrutna `/answer`-anrop loggas inte i `answer_usage`, så kostnaden får uppskattas.

**Läge**
- API i dag: cirka 0,7 USD (K37 0,2, regressionen 0,32, länktester 0,12, K36 0,02).
- Regressionen på 21 fall varierar mellan 81 och 100 % utan att koden ändrats, så en enskild körning säger lite.

**Öppna trådar**
- **Aron:** `SUPABASE_SERVICE_ROLE_KEY` (efter Oscars godkännande av K38) låser upp K6 och K22. Spotify-appen (klickväg i `docs/AGENT.md`). O16: ElevenLabs med zero retention före beta. En teströst (C) från Kevin ligger i `logo_votes`; den raderas när Aron kan bekräfta.
- **Angela:** A53 (Mina svar), A54 (`/logo-vote`), samtal, `music_open` och Spotify (protokollen i rapporterna och i `docs/AGENT.md`). Om appen bör säga samma sak som `self.ts` om ElevenLabs.
- **Oscar:** omtest av K38, grupp 13 och 14. Hans `o24`- och `o36`-skript känner igen svaren på de gamla texterna.
- **Concern (Oscar O39, Kevin instämmer):** Mina svar kan fungera som fusk under ett prov. Det är Architects beslut.
- Shopify (K35 fas 2) kan byggas på `connections` (`provider` får ett nytt värde) när Partner-appen finns.
- Två beslut heter "D98", och D124 och D125 finns två gånger, både som owner-beslut och som Kevin-beslut. Rör det inte.
