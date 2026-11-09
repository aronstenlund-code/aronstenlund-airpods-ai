# Kevin K9: Kommandon nivå 2 i /answer

Datum 2026-11-09 · Uppgift: `prompts/queue/kevin.md` K9 (hör ihop med Angelas A7) · Driftsatt i tre omgångar (deploy-runs 42658467801, 42659615838, 42660411151, alla gröna med `deno task test` och typkontroll). Allt nedan är **verified live** (anrop mot driftsatt backend) där inget annat står. Inget är testat på telefon eller AirPods.

## Kort
- Det finns nu en regeltabell, `answer/commands.ts`, med 31 uttrycksfamiljer. Den översätter "Lumen, …"-instruktioner till `task` utan något extra modellanrop. Tabellen står i `docs/COMMANDS.md` › Backend.
- Stående regler i Provläge och Frågor: "i framtiden ska du …", "från och med nu …", "svara alltid …" och "… det är minnet" blir en D80-regel med kort bekräftelse. Aron sa 21:20: "fortsätt att du i framtiden bara ska ställa korta svar under en mening alltså det är minnet". Den meningen ger nu "Okej, korta svar." och regeln "Regel: Bara ska ställa korta svar under en mening." (ordföljden är kvar från talet; modellen läser den rätt)
- Live-eval, kategorin `kommando` (57 turer: 3 varianter per task i Provläge och Intervju, 3 regler, 6 negativa fall):
  - **52 av 57 utan anmärkning** i sista hela körningen.
  - 4 anmärkningar gällde bara tiden: 2,5–2,9 s mot budgeten 2,5 s, på förhörsuppgifter.
  - 1 var ett tomt svar på intervjuns "ge mig en motfråga". Det är rättat efteråt och verifierat live 3 av 3 med en sparad session. En ny hel körning stoppades av Supabases gräns för anonyma inloggningar (429).
  - Negativa fall: 6 av 6 besvarades som vanliga frågor ("ge ett exempel på en exoterm reaktion", "vad menade Marx med klasskamp" …).
  - Regler: 3 av 3 bekräftade lokalt.
- Unit-tester: 3 varianter per familj för alla 31 familjer, 11 negativa meningar, 5 negativa regelfall och 6 handler-tester (`answer/k9_test.ts`). Lokalt är 242 av 242 tester gröna, och Actions är grönt.

## Teknik
**Matchning.**
- Texten normaliseras: små bokstäver, ingen interpunktion, inget "Lumen", inga artighetsord ("kan du", "snälla", "tack").
- Varje familj matchar hela yttrandet (`^(?:…)$`), så ord mitt i en mening räknas aldrig.
- Familjerna har räckvidd: `study` (Provläge och Frågor), `interview` (frågeturen i Intervju) och `social` (`social.calibrate` i Socialt och Rizz).
- `continue_more` och `continue_simpler` kommer som förut från D35.

**Studie-uppgifter.**
- Uppgiften och dess regel (`<task>`, `<task_arg>`, `<task_rule>`, för `weak_areas`/`self_assessment` även `<concept_stats>`) läggs i användarmeddelandet, så den cachade systemprompten är oförändrad.
- En uppgift är aldrig tystnad. Den räknas inte som svar på en kontrollfråga, och svarstypen är `study` (`brief_style` är `fact`).
- Förhörsuppgifterna (`harder_question`, `quick_quiz`, `yes_no_quiz`, `quiz_topic`, `weak_areas`) säger bara frågan, som "förhör mig" (D86). De stoppas inte längre av Provläges krav på korta kontrollfrågor. Det kravet tömde först de svåra frågorna: 4 tomma svar i första körningen, rättat.
- `careful` använder Sonnet med adaptivt tänkande för det svaret, också i Frågor (där svaren annars går på Haiku). Kostnaden loggas som vanligt per svar.
- `catch_up` sammanfattar `context.transcript`. Den testas inte i live-eval (live-eval skickar inget transkript) utan bara i unit-test av regeln. **untested assumption** live.

**Intervju.**
- `interview_help:*` lägger uppgiften i persona-meddelandet.
- Motfrågan sägs som en fråga (förut togs den bort).

**Socialt och Rizz.**
- "Vad ska jag svara", "byt ämne", "smart följdfråga", "vad menade hon", "mer rizz", "rädda mig" och "tre alternativ" räknas som önskemål om nya repliker. De ger 1 replik, eller 3 för "tre alternativ" (`requestedCount`), och `<request>` får betydelsen tillsammans med användarens ord.
- Stilorden ("roligare", "kaxigare", "mindre cringe" …) är kalibreringar som förut (D69), med betydelsen tillagd.
- Unit-testat. **Inte kört live:** live-evalens Rizz-fall skickar inga nya kalibreringar.

**Nya valfria fält i kontraktet.**
- `context.concept_stats: [{concept, right, wrong}]`, högst 30.
- `voice_instruction: boolean`. Är det sant och ingen familj passar, får modellen texten som en instruktion att utföra på senaste svaret (aldrig tystnad).

**Regler.**
- `detectRule` kräver ett tidsord ("i framtiden", "från och med nu", "alltid", "det är minnet" …), att det gäller Lumen eller svaren ("du …", "svara …") och ett ord om svaren ("kort", "exempel", "enklare", "engelska" …). En mening som slutar med frågetecken är aldrig en regel.
- Svaret är lokalt (0 token), med `done.memory_add` = "Regel: …". Appen lagrar redan `memory_add` och skickar det tillbaka som minne, så det fungerar utan ändring i appen.
- Dessutom finns `done.rule_add`, regeltexten, så att appen kan lägga den under Minne › Regler.
- Prompten följer "Regel:"-rader i varje svar. De går före längd och stil, men inte före säkerheten.

## Till Angela (A7)
1. Skicka `voice_instruction: true` när `VoiceChannel` ger `.instruction(text)`. Då får ord som tabellen inte känner till ändå rätt behandling.
2. Valfritt: lägg `done.rule_add` som `.rule` i Minne (i dag blir det ett faktum som börjar med "Regel:", och det fungerar också).
3. Valfritt: skicka `context.concept_stats` från förhörsresultaten per begrepp, för "testa mina svagaste områden" och "hur bra kan jag det här". Utan fältet frågar Lumen om ett kärnbegrepp, och lägesbilden säger att det inte finns några resultat än.

## Begränsningar och risker
- Förhörsuppgifterna väntar tills hela svaret är klart (bara frågan sägs), så första ord kommer efter 2,5–2,9 s på Sonnet.
- Fraser utanför familjerna går som förut. Med `voice_instruction` tolkar modellen dem fritt, utan tabellens regel.
- I svaren hittade jag en dålig fråga: "Vilket ämne i klorofyllet tar upp ljuset" (klorofyll är ämnet). Det är svarskvalitet, inget fel i tabellen.
- Live-eval får göra ungefär 5 körningar i timmen (anonyma inloggningar). Den tredje körningen gav 429.

## Kostnad
Ungefär 0,55 USD (två live-eval-körningar på 0,28 och 0,25 USD, plus några enskilda anrop).

## Nästa
K10 (kommandon med egna ord, `app_command` och inlärda inställningar). Den bygger på den här tabellen.
