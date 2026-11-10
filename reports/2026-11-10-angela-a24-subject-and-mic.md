# A24 – Delämnet frågas i Provläge, och "Lumen hör dig inte" från Start (Angela, 2026-11-10)

Stående uppgift enligt `docs/PLAN.md` 2b, som egen punkt i kön. Följer av A22 (ett prov kan sparas som bara "NO")
och Kellys Ke10. **CI och simulatorlogik, inget provat på telefon.**

## Vad som gjordes
1. **Delämnet:** startar Provläge för ett prov som bara heter efter området (NO, SO, Språk, Praktiskt), frågar Lumen en
   gång "Vilket ämne i NO är provet i? Säg till exempel biologi eller fysik."
   - Ett kort svar ("biologi", "det är fysik", "kemi tror jag", högst 5 ord) gör provet till Biologiprovet, med rätt
     ämnesord och rätt namn. Lumen bekräftar med "Bra, biologiprovet."
   - Trycker eleven på "Förhör mig" väntar förhöret tills ämnet är sagt.
   - Är svaret något annat blir orden en vanlig tur, och förhöret startar ändå.
   - Kod: `Lumen/Core/Study/SubjectQuestion.swift` och `ListeningModel.askSubjectIfOnlyArea` / `subjectAnswered`.
2. **Mikrofonen avstängd från Start:** när ett tryck på Start ger `microphoneDenied` visas skärmen "Lumen hör dig
   inte" som ett blad. Den har tre steg, "Öppna Inställningar" och "Hoppa över". Felkortet på Start finns kvar när
   bladet är stängt.

## Tester
- `LumenTests/A24Tests.swift`: vilka prov som får frågan (NO, Språk ja; Biologi, Matematik nej), frågans text,
  och svaren ("Biologi", "det är fysik", "kemi tror jag", en fråga som råkar innehålla "biologi" räknas inte).
- **CI:** grönt, run 42777600963.

## Kända begränsningar
- Frågan ställs med rösten. Hörs den inte, till exempel i tyst läge, blir provet kvar som "NO" tills eleven säger
  ämnet på något annat sätt. Provet kan också ändras på Start.
- **Untested assumption:** att en elev svarar med bara ämnet. Längre svar än 5 ord tolkas som en fråga.

## CI
Grönt i CI: iOS build 42777600963 (commit `8333362`, som innehåller A24:s `ddec2ad`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna, A24Tests inräknade.
