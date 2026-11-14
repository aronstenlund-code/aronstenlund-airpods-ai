# Kelly Ke61: granskning av A102 (siffror och formler) på bild

Datum: 2026-11-14 21:43. Bilder: CI "Simulator screenshots" **43632631870** (iPhone 17 Pro, ljust och mörkt) och **43637825188**
(iPhone SE, största text, `screens: repNumbers repNumbersEdit`, som jag startade). Kontaktblad: `reports/2026-11-14-a102-granskning/`.
Underlag: `reports/2026-11-14-2116-angela-a102-visningstext.md`.

## Bedömning
**A102 godkänd med två låga fynd.** Visningstexten fungerar: upphöjda tal ("a² + b² = c²", "r²"), multiplikationspunkt
("π · r²"), decimalkomma ("3,14") och årtal ("1856"), både i frågelistan (`repNumbers`) och i redigeringen
(`repNumbersEdit`). Det håller i ljust, mörkt och största text på SE. Inga tecken faller bort eller ersätts med rutor.

## Fynd
| # | Var | Fynd | Ska vara | Nivå |
|---|---|---|---|---|
| F1 | Frågelistan, korta svar | Ett svar som bara är ett tal eller en formel slutar med punkt: "1856.", "a² + b² = c².", "A = π · r²." | Ingen punkt när det korta svaret bara är ett tal eller en formel ("1856", "a² + b² = c²"). Den visas inte heller i matteböcker. Hela meningar behåller sin punkt. Gäller visningstexten, inte uppläsningen. | Låg |
| F2 | Redigeringen, fråga 2 | "A = π · r². π är ungefär 3,14." Punkten efter r² står direkt före π, så det är svårt att se var meningen slutar, särskilt vid största text. | Skriv om i svaret (servern, Kevin): "A = π · r², där π är ungefär 3,14." Undvik att en mening börjar med en symbol. | Låg |

## Till Angela och Kevin
F1 gäller appens visning (Angela). F2 gäller hur servern skriver svaret (Kevin, en regel i K-prompten: en mening börjar
aldrig med en symbol eller en siffra).

## Test
Simulatorbilder, inte telefon. Uppläsningen (talen som ord) har jag inte lyssnat på.

## Tillägg: F1 stängd (CI 43640282082, `reports/2026-11-14-a99-a100-bilder/a102-f1.jpg`)
Korta svar som bara är tal eller formel visas utan punkt ("a² + b² = c²", "A = π · r²", "1856"), också i redigeringens fotnot, och hela meningar behåller sin punkt. F2 (hur servern skriver svaret) ligger kvar hos Kevin.
