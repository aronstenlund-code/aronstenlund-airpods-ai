# Kevin – D53: ämnesrelation avgörs av modellen (ersätter ordräkningsspärren)

## Gjort
- `isNewTopic()`/`topicGuard` borttagna. Sammanhanget slängs aldrig i förväg: de senaste turerna (4–6) och `<active_topic>` skickas alltid.
- Modellen avgör `relation: continues | refines | new_topic` i samma anrop. Header-läge (`auto`): fält i JSON-headern → `meta.relation`. Övriga flöden med historik: första raden `[[REL x]]` (före svaret, så `new_topic` besvaras fristående); `RelationTap` i `speech.ts` klipper bort den, den läses aldrig upp. Alltid i `done.relation` (`null` om modellen inte angav, saknas historik, eller för persona-/socialrutter).
- Regeln i prompten: kort fragment / uppräkning / namn / begrepp / egen fråga som rimligen hör till aktivt ämne = `refines` (svaras inom ämnet); `new_topic` bara när det tydligt gäller något annat; osäker → `refines`; följdfrågor kopplas bara till senaste turen; DupGuard oförändrad.
- Kostnad: ca +150 promptokens (cachade) och +12 utdatatokens/tur med historik. Beslut: D53. README (Context) uppdaterad.

## Test (verified live, answer v31, Haiku 5.5; domare Opus 5.5, 1–5 "rätt sammanhang")
Egna samtal K1–K13 (65 turer: strålning, filosofi, energi, växt, historia, språk, socialt, samhälle, konst, batteri, ekonomi, ljud; ägarens garanti→bankkort från `reports/external/` som data, ingen specialregel) + 8 "seedade" fall S1–S8 med förskriven kort historik (reproducerar grundorsaken). Data: `testdata/context-conversations.json`, `testdata/context-seeded.json`.

| | Före (v27) | Efter (v31) |
|---|---|---|
| K1–K13, snittpoäng (65 turer) | 4,89 (1 tur <4) | 4,89 (3 turer <4; 4,92 i ett tidigare körningstillfälle) |
| Seedade S1–S8 (11 turer) | **4,60** – `alfa, beta och gamma` efter strålning besvarades som grekiska bokstäver (1/5) | **5,00** |
| Relation rapporterad / rätt när rapporterad | – | 37 / 37 (K) och 10 / 10 (S) |
| Svarstid första ord, snitt (p50) | 914 ms (863) | 940 ms (913) → **+26 ms** (K); S: 880 → 873 ms |

K-samtalen var redan nära tak före (modellens egna svar delade ofta ord med uppräkningen, så spärren slog sällan till); skillnaden syns i de seedade fallen. Poängspridningen mellan körningar (±0,03) är domarbrus. Enda lägre poäng efter: K7 "hon skrev hej" (socialroutern svarar med hälsning – oförändrat sedan före, ej en del av D53) och en "mer detaljer" (domaren ansåg att den ignorerade senaste turen; svaret handlade om impressionismen men inte om de tre namnen).

## Begränsningar / risker
- **Taggen utelämnas ibland**: relation rapporterades på ca 75 % av turerna med historik, nästan bara saknad på `new_topic`-turer (och korta/översättningar). Alla rapporterade var rätt, och svaren var rätt även utan tagg, så `done.relation` är bäst-effort (`null` = okänt). Prompten gjordes "mandatory" (v31) utan att täcka allt. Möjlig åtgärd: prefill/strukturerad utdata – ej gjort.
- Persona-/socialrutter (`socialline`, rizz) och turer utan historik har ingen relation.
- Mätningen är på mina egna samtal; ej testat på iPhone/AirPods.
- Driftproblem: deploy-agent trunkerade en version (v30) i några minuter innan v31 (komplett, verifierad byte för byte) – inga mätningar gjordes på den.

## Städning
`rizzlab`, `ctxlab`, `ctxlab2` ersatta med 410-stubbar (som `bench`/`ttsab`/`probe`). Tester: 163 gröna, `deno task check` ren.

## Nästa
Angela/appen kan läsa `done.relation` (valfritt; t.ex. för att nollställa lokal historik vid `new_topic`). Ingen appändring krävs.
