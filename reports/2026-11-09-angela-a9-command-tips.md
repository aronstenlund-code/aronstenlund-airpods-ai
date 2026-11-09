# A9 punkt 1 – Tips om kommandon (Angela, 2026-11-09)

Kort:
- **Klart:** punkt 1. Lyssnarskärmen visar de tre viktigaste kommandona för läget, hämtade ur kommandotabellen.
  Ibland, högst en gång per pass och dygn, ger Lumen ett kort tips i örat och på skärmen om ett kommando användaren
  inte har använt.
- **Väntar:** punkt 2 (`meta.app_command` med ångra) och punkt 3 (inlärda inställningar i Minne) väntar på Kevins
  K10. Där finns inget kontrakt än.
- **Status:** grönt i CI (körning 42661012831). **Ej verifierat på enhet.**

## Vad som byggdes
**`CommandTips`**
- **De tre på skärmen per läge:**
  - Provläge: förhör mig, svara kortare, pausa.
  - Frågor: byt läge, upprepa, pausa.
  - Intervju: hjälp mig svara, jag fastnar, avsluta.
  - Socialt: vad ska jag svara, tre alternativ, pausa.
  - Rizz: lite rizz, rädda mig, tre alternativ.
- Frasen hämtas ur `CommandRegistry`. Ändrar användaren sina fraser syns de egna.
- **Tipsens ordning per läge:**
  - Provläge: kortare, upprepa, utveckla, exempel, snabbförhör …
  - Frågor: kortare, upprepa, spara …
- **Tipsens form:** "Tips: säg ”Lumen, svara kortare” om svaren är för långa."

**`CommandTipStore` (UserDefaults)**
- Sparar använda kommandon, tiden för senaste tipset och en av/på-inställning.

**Regler**
- Högst ett tips per pass och ett per dygn, även efter omstart.
- Bara i en naturlig paus: 4 s efter ett uppläst svar, ingen har pratat på 4 s, och inget svar eller ingen fråga
  väntar.
- Aldrig under en provsession, ett minitest eller när Lumen pratar.
- Aldrig ett kommando som redan har använts. Varje röstkommando markeras som använt, och ett tipsat kommando tipsas
  inte igen.
- Inställningar › Röstkommandon › "Tips om kommandon" stänger av.
- Alla kommandon finns där med sökning (A6/A7).

## Tester (`LumenTests/A9Tests.swift`, gröna i 42661012831)
- Ett tips per pass och per dygn, och dygnet följer med en omstart.
- Aldrig när det är upptaget eller avstängt.
- Ett använt kommando tipsas aldrig.
- Skärmraden och tipset använder tabellens fraser, även egna.

## Ändrade texter (Toby)
Lyssnarskärmens rad har ändrats:
- **Provläge:** var "Säg ”Lumen, förhör mig”, ”Lumen, pausa” eller ”Lumen, avsluta”." och är nu "Säg ”Lumen, förhör
  mig”, ”Lumen, svara kortare” eller ”Lumen, pausa”."
- **Frågor:** är nu "Säg ”Lumen, byt till provläge”, ”Lumen, upprepa” eller ”Lumen, pausa”."
- Tipset visas i blått under raden.

## Kvar (väntar på K10)
- **Punkt 2:** när `meta.app_command` kommer med hög säkerhet utför appen kommandot och bekräftar. Ett "nej",
  "ångra" eller "fel" inom 5 s går tillbaka. Utom Prov och Frågor krävs "Lumen".
- **Punkt 3:** inlärda inställningar som läsbara rader i Minne, som går att ändra och ta bort. Sammanhang (läge,
  ämne, prov, svarstyp) skickas med varje rättelse till /memory.

## Concerns
Inga.
