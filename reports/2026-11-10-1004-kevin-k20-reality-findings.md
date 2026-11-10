# Kevin K20: Fynd från Deangelos verklighetstest

Datum 2026-11-10 · Uppgift: `prompts/queue/kevin.md` K20 · Underlag: `reports/qa/2026-11-10-0815-deangelo-reality.md` och `…-0840-deangelo-reality2.md` · Driftsatt (Deploy backend 42787338415, commit f0b5f96, pushat med `[skip eval]` eftersom dagens API-tak var nått) · **Verified live** på fem frågor (`reports/eval/k20-2026-11-10.json`), resten i unit-test. **Inte testat på telefon.**

## Resultat
| Fynd | Nu | Hur det är kontrollerat |
|---|---|---|
| (1) "Lumen är du en robot" | "Jag är Lumen, en AI-assistent, alltså ingen människa. Frågor och svar går via Lumens server till en AI-modell." | live |
| (6) "Lyssnar du hela tiden?" (var tyst i Frågor) | i Auto: "Lumen lyssnar bara när du har startat den, du ser alltid när den lyssnar, och ljud sparas inte." (ordagrant ur Om appen) | live |
| (6) "Sparar du det jag säger?" (nämnde inte servern eller AI-modellen) | "Ljud sparas inte. Frågor och svar går via Lumens server till en AI-modell. Röstprofilen och dina inställningar ligger bara på den här telefonen." (ordagrant ur Om appen) | live |
| (3) "jag vet inte ens vad jag ska fråga" i Provläge (var tyst) | "Börja med tre saker om cellen: först vad som finns i en cell … Sedan skillnaden mellan växtcell och djurcell …", följt av en lätt första fråga | live |
| (5) Kungars nummer ("Erik den fjorton", "Johan den tre") | "Erik den fjortonde var kung av Sverige …". "Erik 14" och "Johan den tre" blir också ordningstal. "Karl är 12 år" lämnas | live och unit-test |
| (2) "ge mig en svår fråga" ska följa profilens ämne (Biologi gav matte) | regeln säger nu att frågan gäller profilens ämne och prov när inget har pluggats än, och aldrig ett annat ämne | unit-test (inte live) |
| (4)/(7) Väder och resultat ("hur gick El Clásico", "vem vann matchen", "hur blir vädret", "regnar det i morgon") och statsministern | söker i Frågor med tryck för att fråga och text | unit-test (inte live). **Auto söker fortfarande aldrig** (D46, K8: sökning i Auto gav tomma svar). Deangelos statsministerfråga ställdes i Auto |
| (5) Skämt på svenska | regel i prompten: svenska ordvitsar, aldrig översatta engelska ordvitsar | inte mätt |

Fallen ligger i `scripts/live-eval-cases.json` (k20-01 till k20-07), som körs varje natt.

## Ändrat
- `answer/self.ts` (ny): frågor om Lumen själv besvaras i kod med orden från `AboutView.swift`, i alla lägen. I Socialt, Rizz och Intervju gäller det bara när yttrandet börjar med "Lumen".
- `answer/speechsym.ts`: kungars och drottningars nummer efter namnet är ordningstal, även som siffra eller grundtal i ord.
- `answer/commands.ts`: ny familj `get_started`, och `harder_question` följer profilens ämne.
- `answer/web.ts`: resultat och väder söker.
- `answer/prompt.ts`: skämtregeln.

## Kvar och risker
- **Aktuella frågor i Auto:** de söker inte (D46). Statsministern i Auto besvaras ur minnet. Att låta Auto söka kräver att metasteget inte kallar frågan "inte en fråga" (K8 W1). Det är ett eget arbete och behöver mätas när budgeten finns.
- "Om appen" ändras av Angela. Ändras texten där måste `self.ts` ändras samtidigt. **Till Angela:** säg till, eller låt testet `k20_test.ts` jämföra.
- "grundare av den vasatiden" och "yttre hinn" (språkfel): sannolikt färre med Sonnet i demon (K5) och förebilderna (K4). Inte mätt särskilt.

## Kostnad
Under 0,02 USD.
