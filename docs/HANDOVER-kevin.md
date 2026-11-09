# Överlämning: Kevin (backend), 2026-11-09 23:55

Sessionen har gjort K2, K7, K9, K10, K8, K11 och K14 och har komprimerats. Den fortsätter i nattläget. Det här står inte i rapporterna.

**Verktyg och fällor**
- Det finns ingen Deno lokalt. Testerna körs med Node-shimmen (minnet `backend-tests-without-deno`).
- Shimmen typkontrollerar inte. En ny medlem i `LLMChunk`-unionen bröt fem andra funktioner i Actions (K11). Sök efter `c.type === "text"` och smalna av till `usage`.
- Skriv aldrig patchskript med `\b` eller `\n` i Python-strängar som inte är råa, och inte i heredoc med citattecken i bash heller. Det blev kontrolltecken, och en gång en trasig bash-heredoc. Skriv skriptet med Write-verktyget och använd `r'''…'''`. Kontrollera sedan med `grep -c $'\x08'`.
- `ci.py <sha>` går ibland över 10 min. Kör den hellre med en egen pollingslinga som tittar på "Deploy backend" för HEAD, och glöm inte `git pull --rebase` före push. Push kan misslyckas tyst när main har rört sig.
- Live-eval: använd token-platserna 0 och 1 i `scratchpad/tokens.json` (`PE.signup(file, i)`). Täta intervjuanrop ger 429 efter cirka 6 per minut (det är K12-problemet).

**Siffror och läge**
- Provläge går på Sonnet 5.5 (D90). Textuppgifter tänker med adaptive och effort high (p95 6,6 s till första text). Vid tidsgräns går anropet om till Haiku (D95).
- TTS: v4 Turbo kostar lika mycket som Flash på planen (42 `character-cost` för 209 tecken). ElevenLabs-nyckeln får inte läsa `/v1/models` eller `/v1/user/subscription` (401).
- Citatkontrollen (D95) bygger på `citations_delta.cited_text` från webbsökningen. Det fungerar bara på textvägen (`needsText`).

**Öppna trådar**
- Aron:
  - Ska Rizz 18+ få ge komplimanger om utseende (K8)?
  - Vill han lägga till de fyra svenska rösterna i ElevenLabs (K14-rapporten)?
- Angela: samma ändring av minnesfiltret i `MemoryExtraction.swift` (K8), inkoppling av A9 `app_command` och `voice_instruction` (K9 och K10).
- Pris i Auto går fortfarande inte. Med sökning blev svaret tomt, eftersom modellen kallade frågan "inte en fråga" (K8).
- Oscars O10 säger att K10 inte räknas som klar förrän rättelser med egna ord når 18/20. Det tas i K13.
