# K62b, K62 och K63: inga ElevenLabs-krediter för tester, vart krediterna tog vägen och EarMind (Kevin, 2026-11-14 17:16)

## Kort
- **K62b (D180): klart och driftsatt.**
  - Servern känner igen testtrafik och svarar med falskt ljud (tystnad) och falsk transkription. Det gäller `drill`, `tts`, `stt-token`, `voice-lab` och `provlage-eval`.
  - Ett skydd kastar ett fel och loggar `elevenlabs_blocked_test` om ett test ändå når ElevenLabs-klienten.
  - **Verifierat live:**
    - ett skriptkonto fick falskt svar i alla tre funktionerna jag provade: tts, stt-token och drill
    - flödet "Test mode check" från GitHub Actions, med appens egen user agent, fick falskt ljud (run 43612276103)
    - sedan Oscars fynd rättades loggas inga ElevenLabs-anrop från tester
  - Fyra flöden som mätte riktigt ElevenLabs-ljud är avstängda.
- **K62: siffror nedan.**
  - **Det mesta gick till tester**, framför allt Scribe i Tobys simulatorkörningar och ljud i testkörningar, även mina egna.
  - **Krediterna tog slut** 2026-11-14 13:01:43 UTC (14:01 svensk tid), med 183 av 65 000 kvar.
  - **Felkod till appen:** filer som inte kan göras får nu `status: "failed"` och `error: "audio_unavailable"` (Angelas b58678d). De görs om efter 10 minuter när kvoten är tillbaka.
  - **Varning:** morgonrapporten varnar i Till Aron under 20 %. Varningen är redan skriven, eftersom 0 % är kvar.
- **K63 (D179): EarMind med stort M** i hjälp-AI:n, HJALP.md, capabilities.json, svaren om namnet och testerna.
  - **Verifierat live:** "Jag heter EarMind." och "EarMind hjälper dig att plugga …".

## K62b: så känns testtrafik igen (`_shared/testmode.ts`)
En begäran räknas som test när något av detta gäller:

| Regel | Vad som räknas | Vem det gäller |
|---|---|---|
| `header` | huvudet `x-earmind-test` (vilket värde som helst) | appens UI-tester, Oscars skript (hans 20 skript sätter det nu, O61) |
| `account` | JWT:n har `app_metadata.test` eller `user_metadata.test` = true | konton som en gång setts som test, oavsett nät |
| `script` | user agent är ett skript eller en headless-webbläsare (python, curl, Deno, node, Go, Java, HeadlessChrome, Playwright …) eller saknas | alla konton som skript skapar, alltså mina, Oscars och nattlig eval |
| `ci` | anroparens IP finns i GitHubs publicerade Actions-intervall (api.github.com/meta, sparas 12 h) | CI, nattlig eval och Tobys simulatorkörningar, också med appens user agent |

- **Ägaren** (Aron, inloggad med e-post) räknas aldrig som test, utom med huvudet.
- **Riktiga användare** ser ut som appen: CFNetwork som user agent från ett vanligt nät. Demosidan räknas som webbläsare. Båda behandlas som förut.
- **Testkonton registreras** i den nya tabellen `test_accounts` (vem, skäl, första funktion), och kontot får `app_metadata.test = true`. **Verifierat i databasen:** mina skriptkonton, Oscars konton (`header`) och provlage-eval-kontona är med. Listan över testkonton är `select * from test_accounts`.

## K62b: vad testerna får

| Funktion | Svar till test |
|---|---|
| `/tts` | 1 s tyst MP3, huvudet `x-earmind-fake: 1` |
| `/stt-token` (GET) | `{fake: true, token: null, ws_url: null, transcript: "Det här är en testtranskription."}`. Appen ska använda sina inspelade transkript (D180). |
| `/drill` | testkonton får en egen röst (`earmind-test-silent`). Deras filer är tysta, görs utan ElevenLabs, delas aldrig med riktiga användare (annan hash) och kostar 0 krediter. |
| `/voice-lab` | alltid falskt, utom när `x-earmind-real-audio` är lika med hemligheten `VOICE_LAB_REAL_AUDIO_TOKEN`. Den sätter bara Aron, och bara efter sitt ja. |
| `/provlage-eval transcribe` | falsk transkription |

## K62b: skyddet
- **`guardedFetch`:** i tts, stt-token, voice-lab och provlage-eval kastar varje anrop till ElevenLabs inom ett test `TestCreditsError` och loggar `elevenlabs_blocked_test`.
- **`/drill`:** den riktiga ElevenLabs-vägen vägrar varje fil med teströsten.
- **Oscars fynd 1 (O61, prio 1), rättat:** ett testanrop startade den gemensamma ljudkön, och kön gjorde då andras väntande filer med riktig röst. Det gav 10 försök kl. 15:49–15:50 UTC, alla `quota_exceeded`, alltså 0 krediter.
  - Nu startar ett testanrop aldrig kön. Det gör bara sina egna tysta filer.
  - Kreditkollen (`/v1/user/subscription`) körs inte för tester.
  - **Test:** `drill/handler_test.ts` "K62b (Oscar O61)".
  - **Verifierat i loggen:** efter driftsättningen kl. 16:11 UTC finns inga `drill_audio_failed` och inga `elevenlabs_subscription` från testanrop.
- **Fyra oanvända filer med riktig röst** (466–1 681 tecken, test från O60) är markerade så att de aldrig görs om.

## K62b: CI och nattlig eval
- **Avstängda med ett första steg som stoppar och förklarar:**
  - `audio-eval`: Scribe
  - `credits-ready`: K18-uttal och K6-provröster, cirka 7 000 tecken per körning
  - `oscar-ab-audio`
  - `voice-blindtest`

  En körning som behöver riktigt ljud kräver Arons ja i chatten.
- **Kvar, men skyddade av servern** (alla kör från Actions-IP och får falskt ljud): Tobys apptest-flöden och nattlig eval, som bara använder `/answer` med Claude.

## K62: vad som förbrukade krediterna
- **Källor:**
  - `answer_usage`: tts-tecken per modell, Scribe-sekunder (`stt`)
  - `drill_audio_files`: `credits`, ElevenLabs egna `character-cost`
  - funktionsloggen
  - GitHub-körningar
- **Vad som inte kan mätas:** ElevenLabs saldo kan inte läsas, eftersom nyckeln saknar User Read (401). Därför är periodens start okänd, och jag räknar från 1 november.
- **Statusmarkering:** "mätt" betyder ElevenLabs egna siffror, "uppskattat" betyder beräknat med kända priser.

| Funktion | Mängd (1–14 nov) | Krediter | Hur |
|---|---|---|---|
| Repetitionsljud (`drill`) | 124 filer, 30 298 tecken | **10 781** (13 nov 10 062, 14 nov 719) | mätt |
| `/tts` Flash v2.5 | 72 170 tecken, 909 anrop | cirka 14 400 | uppskattat, 0,2 per tecken (K50) |
| `/tts` v4 Turbo | 28 053 tecken, 526 anrop | cirka 5 600 | **otestad antagelse:** samma pris som Flash |
| `/tts` Multilingual v2 | 6 914 tecken, 53 anrop | cirka 2 800 | uppskattat, 0,4 per tecken (mätt i K50) |
| `voice-lab` (K48 blindtest) | cirka 1 500 tecken | cirka 600 | uppskattat |
| **Scribe realtid** (`stt-token`/`stt`) | **394 minuter** i 510 sessioner, 363 konton | **cirka 30 600** (resten upp till 64 817) | **härlett:** cirka 78 krediter per minut. Priset är inte verifierat. |

- **Scribe per dag (sekunder):**

  | 9 nov | 10 nov | 11 nov | 12 nov | 13 nov | 14 nov fram till stoppet |
  |---|---|---|---|---|---|
  | 7 331 | 303 | 2 089 | 1 899 | 4 636 | 3 791 |

  Timmarna 13 nov 20–23 och 14 nov 00 och 12–14 är Tobys T17-körningar (`apptest-retest`). 13 och 14 nov ger tillsammans 140 minuter, cirka 11 000 krediter.
- **Per konto och test:**
  - **Scribe:** 363 olika konton för 510 sessioner. Nästan alla är nya simulatorinstallationer i CI, alltså test.
  - **Troligen Arons telefon:** det enda långlivade kontot `6da712ad…`, skapat 7 nov, med 752 anrop och 30 Scribe-sessioner. Det står för 4 388 s, alltså 73 min och cirka 5 700 krediter. **Otestad antagelse** att det är Arons telefon.
  - **Repetitionsljud:** 10 119 av 10 781 krediter gäller prov som togs bort efteråt, alltså testskript. Det var mina livetester K46–K57 (13 nov) och Oscars O55, O56 och O60. 653 kom från ett konto som skapades 14 nov 13:43 med 3 anrop, troligen ett test.
  - **`/tts`:** 199 olika konton, de flesta från Tobys `apptest-screens` (100 körningar 8–14 nov) och `apptest-chain`/`retest`.
  - **Bedömning:** cirka 85–90 % av krediterna gick till tester. Mina egna livetester i repetitionsläget står för cirka 9 000–10 000 krediter.

## K62: felkoden och varningen
- **`audio_unavailable` (Angela b58678d):**
  - När ElevenLabs svarar quota, credit, 401 eller 402 blir filen `failed` med `error: "audio_unavailable"`. Filer som redan är klara går fortfarande att spela.
  - Andra fel ger `audio_failed`.
  - `status` gör om sådana filer, och ljudsignalerna, efter 10 minuter, när kvoten är tillbaka. Det gäller aldrig för testanrop.
  - **Uppdaterat i databasen:** de 11 filer som föll 14:01 har nu koden.
  - **Test:** "K62: out of ElevenLabs credits".
- **Varningen under 20 %:**
  - `/drill` sparar det den ser i `provider_status`: prenumerationen när nyckeln får läsa den, annars "X credits remaining" ur felmeddelandet.
  - Morgonrapporten skriver "ElevenLabs-krediter (K62)" och lägger en rad i Till Aron en gång per månad under 20 %.
  - **Verifierat:** körningen 43613123343 gav "183 av 65 000 kvar (0 %)" och raden i Till Aron.
  - **Till Aron:** för att saldot ska stämma efter påfyllning behöver nyckeln behörigheten User Read. Klickvägen står i raden: elevenlabs.io › Developers › API Keys › nyckeln › User: Read.

## K63 (D179)
- **Ändrat:** "Earmind" blev "EarMind" i:
  - `help/handler.ts`, `help/index.ts` och testerna
  - `docs/HJALP.md` och dess kopia (synkad)
  - `Shared/capabilities.json` och kopian i `_shared/`
  - `answer/self.ts` och `answer/validate.ts`, där standardnamnet ger "Jag heter EarMind"
  - prompten i `answer/handler.ts`
  - kommentarer i drill
- **Oförändrat:** väckningsordet jämförs utan hänsyn till versaler. `Shared/ListeningActivity.swift` är appens fil (A101) och ändrades inte.

## Tester och kostnad
- **Tester:** 606 gröna, `check` ren. Nya tester:
  - `testmode_test.ts` (3)
  - drill: teströsten, O61 och audio_unavailable
- **Kostnad ElevenLabs:** 0 krediter. Alla mina anrop i dag efter 14:01 var falska eller fick quota.
- **Kostnad Claude:** cirka 0,02 USD.

## Till andra
- **Angela:**
  - `stt-token` ger `fake: true` och `transcript` till testkonton.
  - `audio_unavailable` finns på filerna.
- **Toby:** tester från CI får falskt ljud och falsk transkription, och appen behöver testvägen för transkription (D180).
- **Oscar:** fynd 1 är rättat.
