# Kevin K10: Lumen förstår vad man menar och lär sig användaren

Datum 2026-11-09 · Uppgift: `prompts/queue/kevin.md` K10 (ägarkrav, Aron 2026-11-08 21:26) · Hör ihop med Angelas A9 · Driftsatt (deploy-runs 42662420099, 42664626580, 42666459881, 42667698417; alla gröna med typkontroll). Allt nedan är **verified live** (anrop mot driftsatt backend) där inget annat står. Inget är testat på telefon eller AirPods.

## Kort
| Krav | Mätt |
|---|---|
| K10.1: kommandon med egna ord, minst 95 % rätt, högst 1 falsk träff | Unit-test: **30 av 30 rätt, 0 falska** (av 30 negativa). Live-eval: **28 av 28 rätt, 0 falska** av 29 (`reports/eval/k10-appkommando-live-eval-2026-11-09.md`; de 3 Socialt-fallen bara i unit-test) |
| K10.4: andra rättelsen behövs inte i minst 90 % | **20 av 20** (kortare 6/6, längre 4/4, fler exempel 5/5, enklare 5/5), `reports/eval/k10-learning-2026-11-09.*` |
| K10.2: rättelse → inställning med räckvidd, vidgas | Unit-testat (ämne → läge → globalt, matte per svarstyp, motsatt värde ersätts). Live via /memory i mätserien |
| K10.3: profil ≤ 300 tecken i cachad del | `<user_profile>` i ett eget cachat systemblock efter den gemensamma prompten. Unit-testat; i live används den i mätserien |

Första mätningen gav 11 av 20: "kortare" 0 av 6, eftersom provprofilens längdregel vann över en rad i prompten. Efter två rättningar (se nedan) gav den 20 av 20.

## Teknik
**K10.1 `answer/appcommand.ts`:**
- En begäran om att styra appen med egna ord känns igen i kod, före modellanropet. Exempel: "kan vi köra vanliga frågor nu", "jag vill öva inför provet", "sluta lyssna en stund", "nu kör vi provläget", "vi är klara för idag".
- Det kräver ett begäransled ("kan vi", "ska vi", "jag vill", "låt oss", "nu kör vi" eller en imperativ) och ett lägesnamn eller ett lyssnaverb. Hela yttrandet får vara högst 12 ord.
- Frågor om appen ("vad är provläget") räknas aldrig. "Frågor" ensamt räcker inte ("kan vi köra frågor" i Provläge kan betyda förhör), utan det krävs "vanliga frågor" eller lägets namn.
- Ett byte till läget man redan är i ger ingenting ("jag vill öva inför provet" i Provläge).
- I Intervju, Socialt och Rizz krävs "Lumen" först.

Svaret, på samma sätt som "kom ihåg" (D49):
- Säkerhet ≥ 0,8: inget modellanrop och inget svar. `meta.app_command` och `done.app_command` = `{action: switch_mode|pause|stop|resume, mode?: fragor|prov|intervju|socialt|rizz, confidence}`. Appen utför kommandot och bekräftar.
- Lägre säkerhet (bara ett lägesnamn, 0,7): fältet kommer i `meta` och svaret ges som vanligt.

**K10.2 `memory/settings.ts`, `POST /memory` med `correction` (bara kod, inget modellanrop, inget sparas):**
- `{"correction": {"text": "kortare", "context": {mode, subject?, exam?, answer_type: fact|explanation|math}}, "settings": [...]}` ger `{settings, setting: {..., text: "Kortare svar i geografi"}, widened, profile}`.
- Rättelser känns igen med eller utan "Lumen": kortare, för långt, längre, mer detaljer, enklare, för svårt, jag förstår inte, mer exempel, det där var fel och liknande. Vanliga frågor räknas inte ("vad är kortare än en meter").
- Räckvidd gissas från svaret som rättades: matte gäller per svarstyp, annars ämnet, annars provet, annars läget.
- Samma rättelse i ett annat ämne i samma läge vidgar räckvidden till läget, och i ett annat läge till globalt. "Längre" ersätter "kortare" och tvärtom.
- `describe()` ger raderna för Minne ("Kortare svar i matte", "Fler exempel inför Geografiprovet").

**`/answer`, nya valfria fält:**
- `preferences` (hela listan), `pref_profile` och `pref_context: {subject?, exam?}`.
- Bara inställningar vars räckvidd täcker sammanhanget (läge, ämne från profilen, prov, svarstyp) går till modellen, som `<preferences>`-rader med vad de betyder. Allt annat utelämnas, så antalet token hålls lågt.
- En längdinställning styr de riktiga reglagen: i Provläge byts profilens "Förklaringar: …" till korta eller utförliga, och i Frågor sätts `length`. Det var den rättningen som tog "kortare" från 0 av 6 till 6 av 6.
- "Enklare" betyder meningar på högst 12 ord. Den rättningen tog "enklare" från 3 av 5 till 5 av 5.

**K10.3:**
- `profileOf()` sammanfattar inställningarna, de oftast givna först, i högst 300 tecken.
- `/answer` lägger profilen i ett eget systemblock med cache efter den gemensamma cachade prompten (`LLMRequest.systemTail`), så den gemensamma prefixen är cachad för alla.
- Profilen bygger bara på inställningarna, så inga känsliga kategorier kan komma in.
- Svåra ämnen ingår inte än, eftersom det inte finns någon datakälla för dem. `concept_stats` (K9) kan bli den källan.

## Mätserien (K10.4), `scripts/k10-learning.py`
För var och en av 20 scenarier, i Provläge och Frågor över 9 ämnen:
1. Fråga 1 ställs.
2. Rättelsen skickas till /memory med svarets sammanhang.
3. En liknande fråga 2 ställs, både med inställningarna och profilen och, som kontroll, utan.

Kriterier, kontrollerade i kod mot kontrollsvaret:
- **Kortare:** högst 75 % av kontrollens ord, eller redan på inställningens eget mål (≤ 3 meningar, ≤ 45 ord). I sista körningen klarade alla 6 det första villkoret.
- **Längre:** minst 125 % av kontrollens ord.
- **Exempel:** minst ett exempelord och minst lika många som i kontrollen. Kriteriet är svagt: det godtar 1 mot 1.
- **Enklare:** minst 10 % kortare meningar eller 20 % färre långa ord.

Bedömningen är grov. Ingen modell har bedömt om svaren faktiskt blev enklare.

## Till Angela (A9)
1. Utför `app_command` med ångra inom 5 s, enligt A9.2. När `done.app_command` kommer har backend inte svarat, så bekräftelsen är appens.
2. Skicka rättelser ("kortare" och liknande direkt efter ett svar) till `/memory` med `correction.context`: läge, ämne, prov och svarstyp (`breakdown.answer_type`: study = explanation, fact = fact; matte = math).
3. Spara listan som `settings` och visa raderna (`setting.text`) i Minne.
4. Skicka `preferences`, `pref_profile` och `pref_context` med varje `/answer`.

## Begränsningar och risker
- Appkommandona är reguljära uttryck: fraser som är långt från familjerna missas. De 60 fallen skrev jag själv, så risken för överanpassning finns. Oscar bör pröva egna formuleringar.
- `accuracy:careful` ("det där var fel") ger bara en extra noggrannhetsrad och mäts inte.
- Profilen ändrar den per-användarcachade delen när en inställning läggs till (en cache-skrivning, sedan träff).

## Kostnad
Ungefär 1,3 USD (tre mätserier på cirka 0,4 USD, två live-eval-körningar på 0,10 USD).

## Nästa
K8 (färre onödiga begränsningar, beror på Oscars O7, som är klar).
