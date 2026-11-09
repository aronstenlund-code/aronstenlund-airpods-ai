# Oscar: O9, oberoende test av kommandona i backend (K9)

Datum 2026-11-09 18:20–18:30 · Uppgift: `prompts/queue/oscar.md` O9 · Underlag: `docs/COMMANDS.md` och Kevins `reports/2026-11-09-1810-kevin-k9-commands-level2.md`.
Skript:
- `scripts/qa/o9_commands.mjs`: Kevins `commands.ts` körd direkt i Node 24, alltså samma matchning som är driftsatt.
- `scripts/qa/o9_live.py`: 9 anrop mot driftsatt `/answer`.

Data: `reports/qa/data/2026-11-09-o9-offline.json` och `reports/qa/data/2026-11-09-1827-o9-live.json`. Kostnad **0,06 USD** av 0,15.

**Det rätta svaret är taget från `docs/COMMANDS.md`**, alltså vad frasen betyder, inte från Kevins regex. Ingen av mina fraser finns i `k9_test.ts` eller i live-evalen. `task` syns inte i svaret från `/answer`, så jag testade matchningen offline och beteendet live. **Inget är testat på telefon.**

## Kort

- **Rätt `task`: 90 av 93** nya formuleringar (3 per uppgift, 31 uppgifter).
- **Falska träffar: 0 av 15** vanliga meningar med kommandoord. Ingen gav heller en stående regel. Live besvarades båda kontrollmeningarna som vanliga frågor.
- **Tre missar,** alla i matchningen:
  1. **"förhör mig på mina sämsta begrepp" → `quiz_topic`** med ämnet "mina sämsta begrepp", inte `weak_areas`. `quiz_topic` står före `weak_areas` i `FAMILIES` och tar allt efter "förhör mig på". Live blev frågan ändå om cellandning (det svagaste begreppet), men det var turen att provprofilen nämnde det.
  2. **"hur går det för mig" → ingen task.** `WRAP_END` stryker "för mig" som artighetsord, så texten blir "hur går det" och matchar inte `self_assessment`. **Live är det ett verkligt fel.** Svaret blev "Du har bara tränat på fotosyntes så här långt …", fast `concept_stats` visade cellandning med 1 rätt och 4 fel. Utan task läses statistiken inte, och eleven får en påhittad lägesbild.
  3. **"kan du göra det roligare" → ingen task.** Efter normaliseringen blir det "göra det roligare", men familjen har bara "gör det roligare". Live gjorde det inget: kalibreringen blev ändå "fler skämt; lättsam ton" (D69-vägen).

## Detaljer

**Rätt, exempel på mina nya fraser.** Alla i tabellen fick rätt task offline.

| Fras | Task |
|---|---|
| "Lumen, kan jag få ett exempel?", "visa ett exempel på det" | `example` |
| "ge mig det viktigaste" | `summary` |
| "säg det på A-nivå" | `a_level` |
| "fråga mig något svårare" | `harder_question` |
| "kör fem korta frågor", "Lumen, snabbquiz" | `quick_quiz` |
| "kör ja-nej-frågor" | `yes_no_quiz` |
| "quizza mig i ekvationer" | `quiz_topic` |
| "vad är jag sämst på" | `weak_areas` |
| "kolla noga", "är du säker på det där" | `careful` |
| "vad pratade de om" | `catch_up` |
| "svara med bara en mening" | `brief_style` |
| "vad säger jag" | `interview_help:professional` |
| "säg ett bättre svar" | `interview_help:better` |
| "jag kommer inte på något" | `interview_help:stuck` |
| "vad bör jag svara" | `social:reply` |
| "nytt ämne" | `social:change_topic` |
| "vad menade hen med det" | `social:what_meant` |
| "Lumen, rizz" | `rizz:more` |
| "flörtigare" | `rizz:flirty` |
| "ge mig tre varianter" | `alternatives:3` |

**Vanliga meningar som inte ska ge någon task:** alla 15 gav ingen task och ingen stående regel.
- "vad är ett bra exempel på en näringskedja"
- "sammanfatta andra världskriget för mig"
- "hur bra kan en hund höra"
- "vad sa Martin Luther King i sitt tal"
- "vad missade jag på provet om cellen"
- "ge mig fem exempel på adjektiv"
- "jag fastnar alltid på bråktal, varför"
- "vad betyder diskret i matematik"
- "är du säker på att jorden är 4,5 miljarder år"
- "en mening om fotosyntes"
- "testa mig" (ensamt; appen översätter det till "förhör mig")
- intervju: "vad säger jag om min största svaghet"
- socialt: "det går dåligt i skolan för mig just nu" och "vad menade du med att du skulle åka bort"

**Beteendet live** (Provläge med profil, `recent_qa` om fotosyntes och `concept_stats`):
- `example`: ett *nytt* exempel (alg i en sjö) och vad det visar. Bra.
- `summary`: 4 meningar plus en kontrollfråga på slutet, eftersom profilen ber om kontrollfrågor. Det är rimligt, men regeln säger "Nothing new". Kevin får avgöra.
- `quiz_topic` "förhör mig om cellandningen": "Vilka två ämnen använder cellen som bränsle vid cellandning?" Bara frågan. Bra.
- Intervju "motfråga": "Jag skulle gärna veta hur en vanlig arbetsdag ser ut …" sägs som en fråga, i jag-form. Bra.

## Till Kevin

1. **`WRAP_END` (`commands.ts:31`) stryker "för mig" före matchningen.** Det förstör "hur går det för mig" och alla framtida fraser som slutar på "för mig". Stryk "för mig" bara när det inte bär betydelse, eller matcha både med och utan wrappern.
2. **Ordningen i `FAMILIES`:** lägg `weak_areas` före `quiz_topic`, eller låt `quiz_topic` aldrig ta ett argument som börjar med "mina" ("mina sämsta …", "mina svaga …").
3. **Böjningar:** "göra det roligare" och "göra svaret bättre" (efter "kan du") bör matcha som "gör …". Tillåt `gör(?:a)?` i familjerna.
4. **Kontrollfråga efter `summary`:** bestäm om profilens kontrollfråga ska följa med en sammanfattning. Regeln säger "Nothing new".

## Inte gjort

- `catch_up` med `context.transcript` (Kevin har det bara i unit-test) och `careful` (Sonnet med tänkande, dyrt) testades inte live.
- Rizz-stilarna är testade offline, inte live (kräver en Rizz-session med 18+).
