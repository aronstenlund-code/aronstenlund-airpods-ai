# Överlämning: Kevin (backend), 2026-11-10 10:50

Sessionen har gjort cirka 20 punkter (K2–K22) och har komprimerats. Nästa session börjar med `git pull`, tavlan och `prompts/queue/kevin.md`. Det här står inte i rapporterna.

**Arbetssätt som sparar tid**
- Lokala tester körs med Node-shimmen (minnet `backend-tests-without-deno`). Shimmen typkontrollerar inte, så nya fält eller nya medlemmar i `LLMChunk` måste kontrolleras för hand. Actions är grinden.
- Skriv patchskript med Write-verktyget och `r'''…'''`. Bash-heredoc med citattecken eller `$` och Python-f-strängar med `{…}` i text har gått fel flera gånger. Använd `%`-formatering eller strängsammanfogning för STATUS- och DECISIONS-rader.
- Committa med pathspec, `git commit -m … -- <mina sökvägar>`, eftersom indexet delas med andra sessioner. Nya filer måste få `git add` först. Kör sedan `git fetch` och `git rebase --autostash origin/main` och pusha.
- Tider: använd `date`. Några av dagens rapportnamn ligger för sent (1015–1230 skrevs runt 09:30).
- Regressionen (K4.1) körs för varje driftsättning som rör `answer/` och kostar cirka 0,3 USD. `[skip eval]` i commit-meddelandet hoppar över den.
- Webbtaket är 20 per användare och dag. Mätningar med sökning behöver nya token-platser i `scratchpad/tokens.json`, och nya anonyma inloggningar stoppas efter cirka 30 per timme och IP.

**Läge**
- API i dag cirka 6,1 USD (riktmärket är 6). ElevenLabs-krediterna har varit slut sedan 07:45.
- **När krediterna finns:** `python scripts/dispatch.py credits-ready.yml` (K18 del 2 och K6). Det stannar utan kostnad om de fortfarande är slut.
- Efter uttalsmätningen: lägg in alias för de felhörda ämnesorden i `/tts` (ingen ändring i kontot behövs) och kör `… tag=after`.

**Öppna trådar (Aron)**
- Hemligheten `SUPABASE_SERVICE_ROLE_KEY` i GitHub låser upp K4.3 (felrapporter varje natt), K22 (riktiga användare) och förhandsproven i K6.
- Godkänna texten i krissvaret (K21). Godkänna Sonnet i demon (K5). Radera Oscars testrad i väntelistan (K5).
- Komplimanger om utseende i Rizz 18+ (K8). De svenska rösterna i ElevenLabs (K14).

**Öppna trådar (teknik)**
- Auto söker aldrig på webben (D46). Aktuella frågor i Auto besvaras ur minnet. Att ändra det kräver att metasteget inte kallar frågan "inte en fråga" (K8 W1), och att det mäts.
- Oscars fall i K21 finns nu i mina tester. Be honom om en ny, oberoende uppsättning (O17b).
- Angela: `two_level` och `more` (K13), `done.source` som `recent_qa[].source` (K16), `meta.safety` (K21), `done.resource` (K19), `/study-plan` och `session_end` (K17), övningsprov (K15), A9 `app_command`.
- `self.ts` (K20) använder exakt texten i `AboutView.swift`. Ändras "Om appen" måste båda ändras.
- Två beslut heter "D98" (mitt och ägarens, "D98 (owner)"). Det rör jag inte.
