# Testläget: ljud skickas för felsökning (Kelly, Ke45, 2026-11-11)

D140 (Aron 20:41): i testläget skickas allt ljud till oss, så att vi kan höra om frågan urskildes rätt. Underlag till
Angelas **A76**. Skisser i `bilder/start2/ke45-*.png` (ljust till vänster, mörkt till höger), källa `_src/start2.html`.
**Skisser, inget byggt, inget provat på telefon.**

## Färg (ny token i SYSTEM.md avsnitt 2)
| Token | Ljust | Mörkt | Används till |
|---|---|---|---|
| `test` | #B45309 | #FBBF6A | Testlägets bricka, prick och knapp |
| `testsoft` | #FEF3E2 | #3A2A12 | Brickans bakgrund |
| `ontest` | #FFFFFF | #2A1A05 | Text på testlägets knapp |
Orange, för att synas direkt utan att se ut som ett fel (rött) eller som vanliga Lyssnar (blått). Används bara för
testläget.

## Skärmarna
| Bild | Var | Det viktigaste |
|---|---|---|
| `ke45-lyssnar-test.png` | Lyssnar | Lyssnar-brickan blir **"Testläge · ljud skickas"** i `test`/`testsoft`, med pulserande prick (samma rörelse som vanliga brickan, stilla med Reducera rörelse). Så länge ljud skickas, i alla lägen. |
| `ke45-start-test.png` | Start | En liten bricka **"Testläge"** bredvid kugghjulet så länge testläget är på, också när Earmind inte lyssnar. Tryck → Inställningar › Felsökning. |
| `ke45-bekrafta.png` | Blad när brytaren slås på | "Slå på testläget?" och vad som händer: **allt ljud**, också andras röster och bakgrundsljud, skickas till oss; sparas i 14 dagar; brickan syns; hur man stänger av. Knappen "Slå på testläget" (`test`), "Inte nu". För konton där testläget slås på automatiskt (Arons) visas bladet en gång, med knappen "Okej" i stället. |
| `ke45-inst.png` | Inställningar › Felsökning | Raden "Skicka ljud för felsökning" med brytare (`test` när den är på) och en fotnot som säger nuläget. |

## Texten om ljud (D138) när testläget är på
D138-meningen ("Ljudet blir text och sparas inte av Earmind. Sömnläget sparar klippen bara på din telefon.") är **inte
sann** när testläget är på. Byt den då, på samma ställen (Om appen, Första frågan, samtycket om det visas):
> **"Testläget är på: ljudet skickas till oss och sparas i 14 dagar. Sömnläget sparar klippen bara på din telefon."**
Introt för nya användare berörs inte (testläget är av för dem).

## Skydden (RESTRIKTIONER del B)
Testläget är synligt hela tiden det pågår (brickan), avstängt från början för alla utom Aron, och slås bara på av
användaren själv efter bladet. Inget i designen döljer att ljud skickas.
