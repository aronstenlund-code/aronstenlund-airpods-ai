# Kevin (moln): K79 – testkontrollens IP-lista kan vara tom (Oscar O71) – 2026-11-16 20:10

**Fyndet:** `loadCiRanges` (`_shared/testmode.ts`) hämtar GitHubs Actions-IP från `api.github.com/meta` utan inloggning och fick 403 sex gånger 10:24–10:28 UTC. En ny isolate utan lista känner då inte igen anrop från Actions som test (D180). Inget hände den gången, eftersom alla anrop hade testhuvudet.

**Rättat (commit efter `41a3f05`):**
- Svarar GitHub, sparas listan i den nya tabellen `ci_ranges` (en rad, bara service role). Det sker i bakgrunden och stoppar aldrig anropet.
- Svarar GitHub inte (403, timeout), läses den sparade listan i stället. Den används i en timme, sedan frågas GitHub igen.
- Är listan ändå tom loggas `ci_ranges_empty`, så att `query_logs` visar det.
- Migration `ci_ranges` är tillämpad. Tabellen fylls första gången en funktion får svar från GitHub.
- Test: `_shared/testmode_test.ts` "K79" (403 ger den sparade listan och "ci"; ett svar från GitHub sparas). `deno task test` 653/653.

**Inte gjort:** ett dagligt GitHub Actions-flöde som hämtar listan med GitHubs egen token och skriver den i tabellen med service-nyckeln. Det automatiska läget nekade att skapa det. Reservlistan bygger därför bara på att funktionerna själva lyckas någon gång. **untested assumption** att det räcker. Vill Deangelo ha flödet behöver det godkännas.

**Kvar att kontrollera:** att `ci_ranges` får en rad efter nästa kalla start. Kontrolleras med SQL i nästa runda.

**Tillägg 21:35 (verified live, SQL):** `ci_ranges` har en rad, `source = function`, med 8 358 adressintervall, uppdaterad 20:31:58 UTC. En funktion fick alltså svar från GitHub och sparade listan, och reserven finns nu till nästa gång GitHub svarar 403.
