# Överlämning: Kevin (backend), 2026-11-10 12:20

Sessionen har gjort cirka 25 punkter (K2–K27), har komprimerats två gånger och slutar därför enligt PLAN 2e. Nästa session börjar med `git pull`, tavlan och `prompts/queue/kevin.md`. Kön är tom. Nästa steg är den stående uppgiften (K4-loopen, kostar API).

**Arbetssätt som sparar tid**
- Lokala tester körs med Node-shimmen (minnet `backend-tests-without-deno`). Shimmen typkontrollerar inte, så Actions är grinden. Oscars offlineskript i `scripts/qa/o2*_offline.mjs` och `o3*_offline.mjs` körs direkt med `node --experimental-transform-types` och kostar inget. Ge dem `< /dev/null`.
- Skriv patchskript med Write-verktyget. Bash-heredoc med `\p` eller citattecken och Python-f-strängar med `{…}` har gått fel flera gånger.
- Committa med pathspec, `git commit -m … -- <mina sökvägar>`, eftersom indexet delas och andras ändringar ligger ostagade (`git pull --rebase` vägrar då). Kör `git fetch`, kontrollera `HEAD..origin/main` och pusha.
- `[skip eval]` i commit-meddelandet hoppar över regressionen (cirka 0,3 USD).
- `memory/handler.ts` `SENSITIVE_RAW` måste stå på en rad, eftersom Oscars O28 läser det ur filen.

**Läge**
- API i dag: bara K23:s live-test (0,004 USD av de godkända 0,50). K25–K27 gjordes helt offline.
- **När ElevenLabs-krediterna finns:** `python scripts/dispatch.py credits-ready.yml` (K18 del 2 och K6).
- Oscar bör köra om O24, O26–O28, O30–O32 och O17c (kris).

**Öppna trådar (Aron)**
- `SUPABASE_SERVICE_ROLE_KEY` för K22, men först efter Oscars godkännande av K24. Samma hemlighet behövs för K4.3 och K6.
- Godkänna krissvarets text (K21/K23), Sonnet i demon (K5) och raderingen av Oscars testrad i väntelistan (K5).
- Komplimanger om utseende i Rizz 18+ (K8). De svenska rösterna (K14).

**Öppna trådar (teknik)**
- Angela: appens `SensitiveFilter` ska följa serverlistan (`answer/k26_test.ts`). `echo.quoted` (K27) finns bara på servern.
- Oscars förslag om en Haiku-kontroll av Rizz-raderna är inte byggt (D107). Ta det om O27-omtestet hittar nya luckor.
- Auto söker aldrig på webben (D46).
- `self.ts`: svarstexterna är ordagrant ur `AboutView.swift`, så båda måste ändras tillsammans.
- Två beslut heter "D98". Rör det inte.
