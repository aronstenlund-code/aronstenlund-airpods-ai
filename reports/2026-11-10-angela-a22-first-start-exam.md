# A22 – "Har du prov snart?" i första starten (Angela, 2026-11-10)

Stående uppgift enligt `docs/PLAN.md` 2b ("Gör appen enklare: kortare väg från start till första svar, färre
knappar per skärm"), som egen punkt i kön. Underlag: Kellys `docs/design/enkel-start.md` (Ke9),
bilden `docs/design/bilder/prov-fore-efter.png`. **Simulator/CI, inget provat på telefon.**

## Vad som gjordes
- `AddExamView` har två former:
  - **I första starten** (inget prov som ändras): "Har du prov snart?" och "Säg det, så förhör Lumen dig inför
    provet.". Under det:
    - Ett röstkort med lyssnarringarna och "Jag har prov i biologi på fredag". Lumen lyssnar redan när skärmen
      visas (`listenForExamStatement`), och ett sagt prov sparas och stänger skärmen.
    - "Eller välj ämne" som en rad: Matte, NO, SO, Språk, Annat. Delämnet (Biologi, Fysik …) visas efter valet men
      är frivilligt. Utan delämne heter provet efter området ("NO").
    - Datum och Årskurs på en rad var. Årskursen förifylls från profilen.
    - "Spara prov" (blå, aktiv först när ett ämne är valt) och "Inte nu" (tyst).
  - **Från Start ("Lägg till prov") och vid ändring:** hela formuläret som förut.
- Före: 8 årskurser, 6 områden och 4–5 delämnen på en gång, alltså 19 val innan Start. Efter: 5 val och två rader,
  eller en mening.

## Testresultat
- CI: se "CI". Ingen ny logik utanför vyn (samma `save()` och `ExamPlan`), så inga nya enhetstester.
- Skärmbilder: följer med A18:s körning av `screenshots.yml` om första starten är med i scenerna; annars Tobys T3/T8.

## Kända begränsningar
- **Ett prov som bara heter "NO"** får ämnesorden för hela området, inte för Biologi. Kellys förslag är att
  Provläge frågar efter delämnet. Det är inte byggt; Provläge pratar om NO tills eleven säger det.
- **Lyssnar direkt:** samtycket gavs på introt ("Testa nu"), och lyssningsindikatorn syns. **Untested assumption**
  att det inte överraskar.

## Kvar
- Provläge frågar efter delämnet när provet bara har ett område (förslag till nästa stående uppgift).
- Toby (T8, förstagångsanvändaren): steget "Lägg till prov" har nya ord ("Har du prov snart?", "Inte nu").

## CI
Grönt i CI: iOS build run 42773767993 (commit bda589a): bygget för enhet (varningar = fel) och alla LumenTests gröna.
