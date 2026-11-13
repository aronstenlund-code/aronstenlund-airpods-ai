# Stående uppgift, omgång 21 (K4-loopen): intervjusvar i du-form, evalens källrad (Kevin, 2026-11-13 17:50)

## Varför stående uppgift och inte K45–K48
Uppdraget 17:40 bad mig läsa `docs/design/repetitionslage.md` och D142–D145 och ta K48, K45, K46 och K47. **Inget av det finns i repot**, varken på main, på någon gren eller i historiken. Sista beslutet är D141, och min kö slutar med omgång 20. Angela, Toby, Oscar och Kelly startades samtidigt och saknar samma underlag. Jag gissar inte fram en spec (CLAUDE.md: stoppa och rapportera). Frågan står under Till Aron #11, och jag kör den stående uppgiften (PLAN 2b) tills underlaget finns.

**`git push` fungerar inte heller** (403 "You must verify your email address"), och GitHub Actions stoppar varje körning av samma skäl (Till Aron #12, Toby). Allt nedan är därför **committat lokalt men inte pushat och inte driftsatt**. Pusha och driftsätt när e-posten är verifierad.

## Eval
Nattens live-eval 2026-11-12 (388 turer, 35 anmärkningar) lästes utan ny kostnad. Fyra grupper av anmärkningarna var **fel i evalen, inte i svaren**:
- **webb-01–05 "källrad saknas" (5/5 varje natt sedan minst 11-09).** Sedan D65 skickar servern domänen som `done.source` och säger "Källa: Britannica." i texten. Evalen letade efter en gammal rad på formen `\nkälla: domän`. Nu läser `web_checks` `done.source` (`scripts/live-eval.py`).
- **text-02 "sjung helan går":** fallet krävde "halvan går". Visan säger "han heller inte halvan får", vilket är vad svaret sa. Kravet är rättat.
- **k7-logik-01:** svaret "Anna måste ha gått hemifrån senare än Fredrik" är rätt men saknade nyckelorden. "senare" godtas nu.
- **ämnesbyte-05:** "växte" träffade det förbjudna "växt". Det förbjudna är nu "växten", "växter" och "klorofyll".
- `--only` tar nu även fall-id, inte bara kategori.

**Verkligt sämsta fall (två nätter i rad och live i dag):** k9-ih-professional-2. I Intervjuläget gav "vad borde jag säga" coaching i du-form, till exempel "Ditt sommarjobb på kafé har gett dig vana vid tempo … Dessutom är du van att ta ansvar". Eleven kan inte säga det rakt av. Prompten säger redan "first person", men modellen glider.

## Ändring
- **`interviewFirstPerson` (`answer/speech.ts`):** i ett svar som eleven själv ska säga byts du/dig/din/ditt/dina mot jag/mig/min/mitt/mina. Svenska verb böjs inte efter person, så meningen blir rätt.
  - Bytet görs bara i en mening utan något jag-ord.
  - Frågor (motfrågor till intervjuaren), tackfraser och "som du sa" lämnas orörda.
- **Avgränsning (`interviewSay` i `handler.ts`):** gäller bara `interview_question` (med kommandona "vad borde jag säga", "bättre svar", "mer självsäkert", "jag fastnar") och `interview_improve`.
  - Feedback och sammanfattning talar till eleven med flit och berörs inte.
  - Övriga lägen berörs inte heller.
- Tester: `k_standing21_test.ts`, 3 nya. Där ingår text som kommer i små bitar, och att feedback och vanliga lägen lämnas orörda.

## Tester
- `deno task test`: **511 gröna** (508 + 3). `deno task check`: ren.
  - Körda med riktig Deno 2.9.6 från npm i scratchpad, inte med Node-shimmen.
  - Status: **verifierat lokalt**.
- `scripts/test_live_eval.py`: 41/41, med 2 nya fall för källan.
- Live, mot den driftsatta backenden (alltså utan dagens ändring), med den rättade evalen (webb, text-02, k7-logik-01, ämnesbyte-05 och intervju-professional 1–3; 16 turer):
  - **webb 3/5 utan anmärkning.**
    - webb-02 (väder): svaret säger ärligt att ingen säker prognos fanns, och därför finns ingen källa.
    - webb-04: timeout i läsningen. Det är ett nätverksfel, inte en källfråga.
  - text-02, ämnesbyte-05 och k7-logik-01 utan felanmärkning. k7 var långsam, 3,4 s.
  - **k9-ih-professional-2 fortfarande i du-form.** Väntat, eftersom rättningen inte är driftsatt.
  - Status: **untested assumption** att rättningen löser fallet live. Det mäts efter driftsättning.

## Kostnad
- **Claude:** cirka 0,09 USD (en riktad live-körning). Nattens eval var redan betald.
- **ElevenLabs:** 0 tecken. Ingen TTS kördes (D120).

## Kvar
- Pusha och driftsätta (Actions "Deploy backend") när GitHub-e-posten är verifierad. Kör sedan `--only k9-ih-professional-1,k9-ih-professional-2,k9-ih-professional-3,intervju` för att mäta.
- 20 långsamma svar i nattens eval (mest Sonnet för rangordningsfrågor och webben, 2,5–6,2 s). Det är nästa omgång om inget i kön kommer före.
- Socialt "fråga tillbaka" (3): ett förslag till eleven som slutar med en fråga till kompisen är naturligt. Evalens krav bör ses över, och jag har inte ändrat det.

## Nästa session
Pull. Läs Till Aron #11 och #12. När K45–K48 och `docs/design/repetitionslage.md` finns: ta dem i ordningen K48, K45, K46, K47. Annars: pusha den här omgången och mät.
