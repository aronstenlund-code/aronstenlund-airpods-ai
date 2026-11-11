# Stående uppgift, omgång 11: rättelser och appkommandon med egna ord (Oscars O22) (Kevin, 2026-11-11 13:36)

Fynd: Oscars O22 från i går (`reports/qa/2026-11-10-0852-oscar-o22-rattelser-kommandon.md`). Det blev aldrig en punkt.
- Rättelser med egna ord fångades **4/20**.
- Appkommandon fångades **3/10**.
- Inga falska träffar.

**Kostnad:** 0 USD (offline).

## Gjort
**Rättelser** (`memory/settings.ts` `detectCorrection`):
- Fler former av varje rättelse: "snackar/babblar för mycket", "säg det på en mening", "orka lyssna på så långa svar", "gå in på djupet", "hänger inte med", "fattar ingenting", "som om jag var tio", "för avancerat/komplicerat", "exempel hade varit nice", "du sa fel".
- Mönstren är **förankrade** som förut: hela yttrandet ska vara rättelsen. Därför blir "det var för långt att cykla till skolan" ingen rättelse.
- Fyllnadsord ("asså", "typ", "ju", "liksom") tas bort var som helst i meningen.

**Appkommandon** (`answer/appcommand.ts`):
- **Läget heter Standardläge sedan A37**, men kommandona kände bara igen de gamla namnen. Nu fungerar "standardläge(t)", liksom "byt/växla till frågor" (bara med ett uttryckligt bytesverb).
- Nya former: "paus", "vänta lite", "du kan sluta (nu)", "sluta nu", "nu ska jag plugga" och "jag ska på / har en intervju, kan vi öva".
- "stäng av" i Socialt utan "Lumen" är medvetet inget kommando (A7/A9: där pratar andra människor).

## Resultat (offline)
| | Före | Efter |
|---|---|---|
| Oscars O22, rättelser | 4/20 | **20/20** |
| Oscars O22, vanliga meningar (får inte bli rättelser) | 15/15 | **15/15** |
| Oscars O22, kommandon | 3/10 | **9/10** (det sista avstås medvetet) |
| Oscars O22, vanliga meningar (får inte bli kommandon) | 10/10 | **10/10** |
| Kevins hållout (nya fraser, skrivna efter ändringen): rättelser | – | 15/16 ("det blev väldigt långt" utan "för" missas) |
| Kevins hållout: falska rättelser | – | 0/10 |
| Kevins hållout: kommandon | – | 6/6, och 0 falska av 4 |
| Oscars O10 (gamla fall) | 20/20 överallt | 20/20 överallt |

## Tester
`deno task test`: **473 gröna**, ny `memory/o22_test.ts` med både Oscars fall och hållouten. `deno task check` är ren.

## Till Oscar
Ett nytt O22-varv med andra fraser vore bra. Jag har lagt dina fall i testerna, så de är inte längre oberoende.
