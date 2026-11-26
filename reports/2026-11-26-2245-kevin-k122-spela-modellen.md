# Kevin (moln) – K122 (D265): prompt-utskrift och återspelning, eval utan API-krediter

**Datum:** 2026-11-26 22:45. **Uppdrag:** Deangelo 22:36 (Aron: "prompta sönder – vi har en dag på oss").
**Regler:** inga riktiga modellanrop, 0 ElevenLabs. Ingen funktionskod är ändrad, så inget driftsattes.

## Vad som gjordes

Allt nedan är **verifierat i test** (`backend/scripts/k122_test.ts` 8/8, hela sviten 880/880).

1. **`backend/scripts/k122-dump-prompts.ts`** skriver ut exakt det servern skickar till Messages API.
   - Fälten är `model`, `max_tokens`, `system`, `messages`, `tools`, `tool_choice`, `thinking` och `output_config`, byte för byte. Nyckeln skickas i en header och följer inte med.
   - Det gäller 125 fall:
     - `scripts/qa/cases.json` (svarsbanken, där Rizz skickas som run.py gör, både flirt och socialt).
     - `backend/scripts/k122-cases.json`: Provläge via `/provlage-eval` (Sonnet och Haiku), domaren (Sonnet), provets drill (sv och en), ledtråd, rättning, komprimera, hjälp, hjälp utanför appen och "prova".
   - Körningen gav **146 promptfiler** i `reports/qa/k122-prompts/` och `index.json` med status per fall.
   - 8 räknefall svarar servern själv, utan modell. Där står det användaren hör i `index.json`.
   - **Temperatur skickas aldrig.** 5.5-modellerna tar den inte, se `anthropic.ts`.
2. **`backend/scripts/k122-replay.ts`** tar ett sparat modellsvar och kör det genom resten av den riktiga kedjan. Ut kommer det användaren hör (`said`), meta- och done-fälten, felkoden, kostnadsraderna (`answer_usage`) och kreditanropen. Kedjan är:
   - talformat (K115),
   - krismarkören och kontrollfrågan (D256),
   - källraden (D254),
   - längdtak.
3. **Ett gemensamt motorbibliotek, `k122-lib.ts`.** Det är serverns egna handlers (`createHandler`, `createEvalHandler`, `createExamHandler`, `createHelpHandler`) med den riktiga `AnthropicProvider`.
   - Providerns fetch är skriptad: varje anrop fångas och besvaras med det sparade svaret som en Anthropic-SSE-ström.
   - Alla andra värdar nekas och listas i `blocked`.
   - Skripten körs **utan `--allow-net`**, så Deno vägrar varje anslutning. Ingenting kan nå Anthropic eller ElevenLabs.
   - Evalens `transcribe` (Scribe) körs aldrig.

## Så kör Oscar det (O102)

1. Läs en prompt, till exempel `reports/qa/k122-prompts/F03.t1.c1.json`.
   - `anthropic_request` är exakt det modellen får.
   - `reply_hint` säger vilket format servern läser. Direktläge (tryck och prata) är bara svarstext. Auto och Provläge vill ha JSON-metaraden först. Kriskontrollen vill ha "ja" eller "nej". Prov, hjälp och domaren vill ha JSON.
2. Skriv svaret som `reports/qa/k122-replies/F03.t1.c1.txt`. Ett fel eller en ström skrivs som `.json`:
   - `{"text": "..."}`
   - `{"error": {"status": 402, "message": "credit balance too low"}}`
   - `{"events": [...]}` för webbsök eller verktyg.
3. Kör återspelningen:

   ```bash
   cd backend && deno run --allow-read --allow-write --allow-env scripts/k122-replay.ts --case F03
   ```

   Ett eget anrop går också, med `--endpoint answer --body '{...}' --reply-text "..."`.
4. Ett fall stannar vid första anropet som saknar svar (`needs_reply`) och skriver nästa prompt. Det kan vara tur 2, som då innehåller det användaren hörde i tur 1, eller kriskontrollen. Skriv det svaret och kör igen.
5. För att skriva ut promptarna på nytt efter en promptändring:

   ```bash
   cd backend && deno run --allow-read --allow-write --allow-env scripts/k122-dump-prompts.ts
   ```

   Den tar `--only F01,E02` och `--cat fakta`.

## Vad demokörningen visade (verifierat i test)

- **F05:** "Kebnekaise är 2097 meter högt" hördes som "tvåtusen nittiosju meter". K115 fungerar.
- **F03 i direktläge med en JSON-metarad först:** raden lästes upp ("noll komma nio fem …"). Det är rätt beteende för direktläge, men det är just den sortens formatfel som den som spelar modellen måste undvika. Därför finns `reply_hint`.
- **Krisfallet:** `[[KRIS]]` gav kontrollanropet. Svaret "ja" gav krissvaret. Ett 402 gav `provider_quota`.

## Begränsningar (untested assumption där inget annat står)

- **Token och kostnad:** antalet token i återspelningen är uppskattat (tecken/4 in, tecken/3,5 ut), så kostnaden är ungefärlig. Modellnamn och parametrar är korrekta.
- **Ordning på samtidiga anrop:** provets drill gör flera modellanrop samtidigt (batchar). De numreras i den ordning servern startar dem, vilket är densamma varje körning med samma indata.
- **Inställningar i drift:** motorn använder kodens standardinställningar. Om en secret i drift skriver över en modell (LLM_MODEL, TUTOR_MODEL, EXAM_MODEL, DRILL_ANSWER_MODEL) skiljer sig promptens `model` från drift. Samma env-namn kan sättas vid körningen.
- **Webbsök:** ett textsvar på en prompt med webbverktyg läses som ett svar givet utan sökning. För ett sökt svar behövs `events` med `server_tool_use`-block.
- **Inte med:** /memory, /drill-stylern och studieplanen.

## Kön i övrigt

- **Angela Schrute (O97, fråga):**
  - **Svar: nej. Inga krediter dras när `/exam` eller `/drill` svarar `provider_*`, inte heller om modellen ger upp halvvägs.** Verifierat i kod.
  - `/exam` har ingen funktion som drar krediter alls. `quota` läser bara (n = 0), och ett prov som avbryts sparas inte.
  - `/drill` drar krediter på ett enda ställe, vid spara (`useQuota(cost)`), och kostnaden är tecken i nytt ljud.
  - `/drill` använder modellen på två ställen. Röstväljaren körs före dragningen och stylern efter, och båda fångar sina fel (`.catch(() => null)`). Ett modellfel ger därför aldrig `provider_*` från /drill; ljudet görs med vanlig text.
  - Ljud som inte gick att göra för att ElevenLabs saknade krediter ges tillbaka (K78).
- **Kelly (Ke88, fråga):**
  - Adressen finns redan: `GET https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/purchase`. Den kräver ingen JWT eller apikey (`verify_jwt = false`) och har CORS för earmind.vercel.app.
  - Svaret är `{"launch_offer": null | {"starts_at", "ends_at", "percent", "product_suffix"}}`.
  - Kellys `readOffer` i `site/index.html` läser redan `launch_offer.ends_at`, så inget behöver ändras.
  - Live: **verifierat live 2/2** (kevin-live körning 99, 21:34 UTC). Utan nyckel och med bara Origin earmind.vercel.app blev svaret 200, `access-control-allow-origin: https://earmind.vercel.app` och `{"launch_offer":null}`. Ett annat origin fick inget allow-origin.

## Nästa

- **Oscar:** O102 (efter O101 och omtestet av O100).
- **Kevin:** rätta promptarna efter Oscars fynd. Skriv sedan ut promptarna igen med dump-skriptet, så att Oscar spelar den nya versionen.
