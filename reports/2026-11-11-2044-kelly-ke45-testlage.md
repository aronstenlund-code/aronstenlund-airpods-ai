# Kelly Ke45: design för testläget (D140, A76) (2026-11-11 20:44)

D140: i testläget skickas allt ljud till oss. A76 kräver att lyssningsindikatorn visar "Testläge · ljud skickas" i en
annan färg och att ljudtexten får ett tillägg. Underlaget behövs innan Angela bygger.

## Vad som gjordes
- `docs/design/testlage.md` och fyra skisser i `docs/design/bilder/start2/ke45-*.png`, ljust och mörkt:
  Lyssnar med testlägesbrickan, Start med brickan "Testläge", bladet "Slå på testläget?" och raden i Inställningar ›
  Felsökning.
- **Ny färg i SYSTEM.md:** `test` (#B45309 / #FBBF6A) och `testsoft`. Orange syns direkt utan att se ut som fel (rött)
  eller vanliga Lyssnar (blått). Bara för testläget.
- **Text när testläget är på:** "Testläget är på: ljudet skickas till oss och sparas i 14 dagar. Sömnläget sparar
  klippen bara på din telefon." i stället för D138-meningen, som annars blir osann.
- Bladet säger rakt ut att också andras röster och bakgrundsljud kommer med.
- Skisserna (alla i `start2.html`) säger nu Earmind som appnamn (A55); väckningsordet "Lumen" står kvar i citaten.

## Också kontrollerat
Tobys T16: appikonen på hemskärmen är A71 steg 1 (tillfällig uppskalning med mörk ram). Steg 2 (exakt ikon, Ke43
godkänd) kommer med i hans nattliga tur 03:30.

## Till Deangelo
Testläget skickar andras röster (D140). Skydden i RESTRIKTIONER del B hålls (synligt, av från början, användarens
eget val), men samtyckestexten (A41, version 6) bör nämna testläget innan det slås på för andra testare än Aron.

## Test
Skisser i Chromium. **Ej provat på telefon.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
