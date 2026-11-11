# Kelly Ke38: granskning av Tobys T8c, första användningen efter Ke35 (2026-11-11 14:57)

Underlag: `reports/apptest/2026-11-11-1455-toby-t8c-forstagang-a60.md` och bilderna i
`reports/apptest/2026-11-11-t8c-a60/` (simulatorn, iPhone 17 Pro, ljust). Plus Angelas A66 (46c5978), i koden.

## Omdöme: Ke35 fungerar
- **Första passet slutar på Start** med "Här startar du Earmind" ovanför knappen (`t8-skip-08`). Rutan är tre rader
  och Starta syns direkt; den tar inte för mycket plats i den här bilden.
- **Provläge:** 8 → 4 tryck från Start (Toby). Utan prov kommer en fråga. A66 ändrar rubriken till "Har du prov
  snart?" och "Avbryt" till "Inte nu", som i Ke35.
- **Bladen:** A66 visar högst ett blad per gång appen öppnas: delningsfrågan första gången, sedan "Earmind kan mer än
  svara" och röstningen vid senare öppningar. Det stämmer med Ke35 och A54 ("efter introt och första svaret").
- **Röstningen** (`t8-skip-13`): ordningen är slumpad (C, B, A här), och "Rösta" är grå tills man valt.

## Fynd
| # | Var | Fynd | Förslag | Prio |
|---|---|---|---|---|
| K1 | "Vill du hjälpa till att förbättra Earmind?" | "Dela historik" har ljuslila yta (`soft`) och blå text. Sekundära knappar är `surface` med bläck (SYSTEM.md avsnitt 3). "Dela inte" blå är rätt (det skyddande valet är huvudknappen) | `surface` + bläck | Låg |

Kvar sedan tidigare: G3 "Ljud sparas inte" (Ke36) och största text (A64), som saknar nya bilder.

**Ej verifierat på enhet.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
