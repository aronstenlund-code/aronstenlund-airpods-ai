# K45–K48: repetitionslägets server, blindtestet och omgång 21 (Kevin, 2026-11-13 20:35)

Status för varje påstående: **verifierat live** (mot den driftsatta backenden), **verifierat i docs** eller **antagande, ej testat**. Ingen enhet behövs för serverdelen. Appen (A78–A83) är Angelas.

## Kort
- **K48 klar.** Filerna A, B och C ligger i `docs/rost-blindtest/`: samma tre meningar och appens röst med Multilingual v2, v3 och Flash i slumpad ordning. Facit står bara i `FACIT.md`, för Deangelo. Kostnad: 1 488 tecken. **Verifierat live**.
- **K45 klar och driftsatt.** `/exam` `drill` gör om material till sammanfattning, 20 frågor och korta och långa svar.
  - Frågorna kommer på 4–9 s och alla svar inom 24 s (R1: 30 s / 90 s).
  - Claude kostar cirka 0,06 USD per prov (R10: ≤ 0,30).
  - Det långa svaret börjar med det korta i 119/119 fall (D145).
- **K46 klar och driftsatt.** `/drill` sparar prov per konto. Ljudet görs i spelordning med ordtider och delas mellan alla konton.
  - Ett annat konto med samma text betalar 0 tecken.
  - RLS håller: ett främmande konto får 404 och 0 rader.
- **K47 klar och driftsatt.** Ett prov kan bara delas när ljudet är klart. Importen tar 1,4 s och kostar 0 tecken.
- **Omgång 21 (före K45):** "vad borde jag säga" i Intervjuläget svarar nu i jag-form, och intervju ger 19/19. Nattens eval räknade 5 webbkällor som saknade utan att de var det. Det är rättat. Rapport: `reports/2026-11-13-1750-kevin-standing21-interview-first-person.md`.

## K48: blindtest av röstmodeller (D144, D146)
- **`/voice-lab` `sample`:** bara tjänstenyckeln når åtgärden. Appens standardröst läser samma text med `eleven_multilingual_v2`, `eleven_v3` eller `eleven_flash_v2_5`. Formatet är mp3 44,1 kHz 128 kbit/s för alla tre, så det enda som skiljer är modellen.
- **Flödet "Voice blind test (K48)":** körs manuellt. `scripts/k48-blindtest.py` slumpar ordningen med `secrets.SystemRandom` och skriver aldrig modellnamnen i den publika loggen.
- **Första körningen:** 401, eftersom hemligheten saknades.
- **Andra körningen:** 401 igen. Nyckeln i GitHub var inte samma värde som funktionens inbyggda `SUPABASE_SERVICE_ROLE_KEY`. Supabase har två sorters tjänstenycklar: den gamla JWT-nyckeln och den nya `sb_secret_…`.
  - Rättning: `voice-lab` godtar en nyckel av rätt form om databasen behandlar den som tjänstenyckel. Kontrollen läser tabellen `drill_audio_files`, som bara tjänstenivån når. Test: `voice-lab/handler_test.ts`.
- **Tredje körningen gick igenom.** A = 575 kB, B = 731 kB och C = 551 kB, alla mp3 (ID3). **Verifierat live**.
- **Kostnad:** 1 488 ElevenLabs-tecken, cirka 0,10 USD efter listpris. Budgeten var 3 000 tecken.
- **Nästa:** Deangelo skickar filerna till Aron utan facit. Aron väljer. Om han inte hör någon skillnad mot Flash halveras ljudkostnaden. Byte görs med `DRILL_TTS_MODEL` (sätts nu till `eleven_multilingual_v2`).

## K45: material till frågor och svar
**Kontrakt** (finns i `backend/README.md`, avsnittet "Repetitionsläget"):
- `drill`: bilder (högst 20), text och dokumenttext går in. Ut kommer `summary`, `notes` (materialet som kort text) och `items`. Med `answers:false` kommer bara frågorna.
- `drill_answers` och `drill_one` gör svaren för listade eller enstaka frågor.
- `doc_text` läser .docx i kod med Denos `DecompressionStream`, utan bibliotek och utan modell.

**Modeller och kostnad:**
- Steg 1 på Haiku 5.5 (0,10/0,50 USD per miljon tokens): läser materialet och gör sammanfattning, anteckningar och 24 frågeförslag.
- Kortningssteg på Haiku: bara frågor över 5 ord, oftast under 0,001 USD.
- Svaren på Sonnet 5.5 (2/10 USD per miljon tokens, **verifierat i docs**, claude-api-referensen 2026-11-13), i satser om 5 som körs parallellt.

**D145 i kod:** modellen skriver det korta svaret och resten var för sig. Det långa svaret blir kort + resten, så det kan aldrig skilja sig från det korta.

**R3 i kod:** av de 24 förslagen tas först rena minnesfrågor bort ("Vad är/betyder/Vilka …"), sedan frågor över 5 ord, sedan de längsta. Ordningen behålls.

**Mätning, sista körningen** (verifierat live; `reports/eval/k45-drill-2026-11-13.json`). Sex av Oscars påhittade prov, aldrig elevtext: biologi med 10 foton och PDF-text, kemi med .docx via `doc_text`, historia med 3 foton, matte med PDF-text, svenska med .docx, religion med 2 foton och .docx.

| | Resultat | Krav |
|---|---|---|
| Frågor på skärmen | 5,4–9,3 s | R1 ≤ 30 s |
| Alla svar klara | 18,4–22,5 s | R1 ≤ 90 s |
| Frågor ≤ 5 ord | 92/119 (77 %), matte 9/19 (räknefrågor behöver sina tal); alla ≤ 8 | R3 ≥ 80 % |
| Förståelsefrågor (min grova regel: varför/hur/vad händer/jämför/skillnad/förklara) | 83/119 (70 %) | R3 ≥ 70 % enligt rubrik, bedöms av Oscar |
| Långt svar börjar med kort (D145) | 119/119 | 100 % |
| Långt svar, ord | median 80–100, max 118 | cirka 90; komplett A+-svar går före ordgränsen (D146) |
| Claude per prov (20 frågor) | 0,058–0,069 USD | R10 ≤ 0,30 |

- **Hur R3 utvecklades:** 56 % på högst 5 ord före kortningssteget och 77 % efter. Ett tidigare försök gav 96 % men bara 59 % förståelsefrågor och fragment som "Vad säger m?". Prompten kräver nu att varje fråga ska gå att förstå när den bara hörs.
- **Kvar:** R2 (täckning, inga frågor utanför materialet) och R4 (A-nivå, faktafel) är Oscars i O55. Jag har läst stickprov, och svaren var sakliga, men ingen domare har kört.
- **Antagande, ej testat:** riktiga mobilfoton med skuggor och snett papper. Oscars bilder är renderade.

## K46: prov och ljud per konto
**Migrationer** (lagda med Supabase MCP):
- `drills`: `drills`, `drill_items` och `drill_audio_files`, privat bucket `drill_audio` och funktionen `claim_drill_audio`.
- `drill_shares`.
- Appen kan läsa och radera sina egna rader direkt (RLS). Skrivningar går bara genom funktionen, eftersom det är den som räknar ut hasharna.

**Ljudfiler:**
- Två filer per fråga: frågan och det långa svaret. Det korta svaret är början av den långa filen fram till `short_end_ms`, enligt ElevenLabs tidsstämplar per tecken.
- Filnamnet är `sha256(texten som rösten läser, modell, röst, format)`.
- Texten görs uttalbar innan hashen räknas: ingen markdown, tal i ord, K18-stavningar.
- Finns hashen redan hos något konto görs ingenting nytt.
- **Taket:** bara nya tecken räknas mot 60 000 per konto och dygn och 600 000 totalt. Värdena ändras med `DRILL_TTS_*`.

**Kön:** filerna tas i spelordning, tre åt gången. Kön körs i bakgrunden efter sparandet och av varje `status`-anrop. Om ett bakgrundsjobb dör blir arbetet ändå klart. En fil som fastnat tas igen efter 3 minuter, med högst 3 försök.

**Livetest** (verifierat live; `reports/eval/k46-live-2026-11-13.json`, `scripts/k46-live.py`). Tre frågor ur K45-körningen, 1 910 tecken (gränsen var 2 000):
- **Ljudet:** alla 6 filer var klara efter 10,4 s.
- **Filen:** den långa filen är en giltig mp3 på 43,6 s, och det korta svaret slutar vid 8,4 s.
- **Andra konto, samma prov (R5b):** 0 nya tecken och 6/6 filer klara.
- **Delning (R5c):** A delar och B importerar. Det tar 1,4 s, kostar 0 tecken och `shared_from` stämmer. B kan inte stänga av A:s länk (404).
- **RLS (R5):**
  - B får 404 från funktionen och 0 rader via PostgREST, medan A får sin rad.
  - Ljudtabellen ger 403 för vanliga användare.
- **Första livekörningen gav 500.** PostgREST kräver att alla rader i en massinsättning har samma nycklar. Det är rättat, och ljudet läggs nu i kön innan provet sparas, så ett fel lämnar inget halvsparat prov. Det halvsparade testprovet är raderat.

**Arons plan och krediter:** går inte att läsa. ElevenLabs-nyckeln får inte läsa kontot (401 på `/v1/user/subscription`). Klickväg för Aron: elevenlabs.io › profilbilden › Subscription.

**Startbidrag:** ElevenLabs Startup Grants ger 33 miljoner krediter under 12 månader till bolag med färre än 25 anställda (**verifierat i docs**: elevenlabs.io/startup-grants och ElevenLabs blogg). Står som Till Aron #14.

## K47: dela prov
Åtgärderna `share`, `unshare`, `share_info` och `import` finns i `/drill`. Kontraktet står i `backend/README.md`.
- **Kod och länk:** koden har 10 tecken utan 0, o, 1, l och i. Länken är `https://earmind.ai/p/<kod>`.
  - **Antagande, ej testat:** universal link kräver att earmind.ai serverar en apple-app-site-association-fil. Till dess finns `earmind://prov/<kod>`.
- **Krav:** delning kräver att allt ljud är klart. Annars kommer 409 med förloppet, "Delas när ljudet är klart (54 av 90)".
- **Kopian:** den är mottagarens egen och har samma ljudhashar. Mottagarens ändringar gör bara nya filer för det som ändras och rör aldrig originalet. Testat i `drill/handler_test.ts`.
- **Vem som får importera:** alla inloggade konton. Kravet på e-postkonto avgörs i appen (D153).

## Tester
- `deno task test`: **530 gröna** och `deno task check` ren. Körda med riktig Deno 2.9.6 (npm), inte med Node-shimmen.
- Nya testfiler:
  - `exam/drill_test.ts`: 8 tester. Frågornas ordgräns, kortning, rensning, D145, satser och nya försök, vikt i hastighetsgränsen, .docx (deflate och stored).
  - `drill/handler_test.ts`: 9 tester. Hashar mellan konton, ändrad fråga, var det korta svaret slutar, RLS, teckentak, delning och import.
  - `voice-lab/handler_test.ts`: 2 nya tester.
- Varje push har gått genom Actions "Deploy backend" (grön).

## Kostnad i dag (Claude och ElevenLabs var för sig)
| | Claude | ElevenLabs |
|---|---|---|
| Omgång 21 (eval) | cirka 0,10 USD | 0 |
| K45-mätningar (fem körningar, 22 prov) | cirka 1,40 USD | 0 |
| K46/K47 livetest | 0 | 1 910 tecken ≈ 0,15 USD |
| K48 blindtest | 0 | 1 488 tecken ≈ 0,10 USD |
| Kreditkontroll | 0 | 4 tecken |
| **Summa** | **cirka 1,50 USD** | **3 402 tecken ≈ 0,25 USD** |

**Per prov med 20 frågor (R10):**
- **Claude:** cirka 0,06 USD. **Verifierat live** på 6 prov.
- **ElevenLabs:** cirka 12 700 tecken ≈ 1,0 USD med Multilingual v2. Räknat på livetestets 637 tecken per fråga, alltså fråga plus långt svar.
- **Lagring:** cirka 7,4 MB (1,1 MB per tre frågor).
- **Repetition och delning:** 0 tecken.

## Kända begränsningar och risker
- R3 ligger nära kravet (77 % mot 80 %). Matte drar ner, eftersom räknefrågor behöver sina tal.
- Raderas ett prov ligger dess ljud kvar, eftersom andra konton kan använda det. Det finns ännu ingen gallring av filer som ingen använder.
- `status` måste anropas för att kön ska fortsätta om bakgrundsjobbet stoppas. Appen gör det redan medan förloppet visas.
- Anonyma konton kan spara och importera. Ett nytt prov per konto och dygn begränsas av teckentaket, inte av antalet konton.
- Andra sessioners autostash gav två konflikter i DECISIONS i dag. Mitt beslut fick numret D153, eftersom D148–D150 togs medan jag arbetade.

## Nästa
1. Oscar O55: R2, R4 och R10 på hela banken. Underlaget finns i `scripts/k45-measure.py` och `scripts/k46-live.py`.
2. Angela A82/A83: koppla appen till `/exam drill` och `/drill` enligt `backend/README.md`.
3. Aron: välj röst i blindtestet (via Deangelo) och ansök om startbidraget (#14).
4. Kevin: K49 (Publicera prov), sedan K6 (hemligheten finns nu).
