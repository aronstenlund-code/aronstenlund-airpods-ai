# Kelly (moln): granskning av A131 (krediter per tecken, D213) på bild

Underlag: grenen `fable/screens-a131-17pro-2` (körning 44095508514, ec2c17b, iPhone 17 Pro ljust och mörkt): repSayCredits,
repSayCreditsShort, repCreditsSheet. Mot orden i `docs/design/sag-i-airpods.md` (Ke71). **Simulatorn, inte enhet.**

## Resultat: godkänt, ordagrant
- Kapseln "1 236 krediter kvar" / "88 krediter kvar", med mellanslag i tusental.
- Säg-raden "Kostar 120 krediter. Upprepningar kostar inget."
- Räcker inte: "**Det här kostar 120 krediter. Du har 88 kvar. Nya krediter den 1 december.**" halvfet, Spela grå.
- Bladet: rubrik Krediter, 1 236 / krediter kvar den här månaden, Så räknas det med de fyra raderna, fotnoten.

## Fynd (låga)
- L1: fotnotens sista rad ("Oanvända krediter sparas inte.") skärs av längst ner i bladet på 17 Pro. Lite mer höjd, eller
  `.large`.
- L2: inte sett på bild: provkortet "Kostar N krediter" (ett ostartat prov), "Kostar inget. Ljudet finns redan." och
  största text på SE.

## Tillägg (15:32): SE största text och datumraden
- `fable/screens-a131-se-xxxl-2` (körning 44095513271): bladet i full höjd, "1 236" står ihop, kapseln "88 krediter kvar"
  ryms, inget kapat. Godkänt.
- 402-raden: "Nya krediter **den** 1 december." gäller. Punkt i Kevins kö att ändra serverns text (appen visar serverns rad).
- L1: Angela Fable har höjt bladet till 72 % på 17 Pro.
