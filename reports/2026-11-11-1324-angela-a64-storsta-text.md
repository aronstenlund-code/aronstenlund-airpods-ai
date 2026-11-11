# A64 – Kellys Ke37: största text (Tobys T11), stående uppgift (PLAN 2b)

Angela, 2026-11-11. Underlag:
- SYSTEM.md avsnitt 10 (Kelly Ke37);
- `reports/apptest/2026-11-11-1310-toby-t11-skarmrunda.md`, fynd 1–4.

## Vad som är gjort
Vid de fem största textstorlekarna (`dynamicTypeSize.isAccessibilitySize`) gäller följande:
- **Lägesraden** (T11 fynd 1): ikonen och läget står på första raden och "Byt" på egen rad under. Mittpricken är borta.
  Ordet bryts aldrig ("Standardläg/e").
- **Provkortets huvud** (fynd 2): "NÄSTA PROV" står överst och brickan "7 dagar kvar" under.
- **Datumet och "Ändra"** står under varandra.
- **Mina svar** (fynd 4): "Mina svar" och "Lägg till ›" står på två rader.
- **Vad kan Earmind?** (fynd 3): rubriken står som stor text i listan och kan brytas, och navigationsraden får den
  lilla rubriken.

I alla storlekar gäller:
- Små versalrubriker ("NÄSTA PROV", "FRÅGA", "ANDRA PROV") står på en rad och får krympa till 80 %.
- Förklaringsraden under en knapp ("Earmind frågar ut dig …") får gå på flera rader, och knappen blir högre. Förut
  krympte stilen den till en rad.
- Loggan i rubriken följer textstorleken (`@ScaledMetric`).

## Testresultat
- **iOS-bygge och enhetstester:** CI 43022112299 (7ebed2e) är **grön**: device-bygget, alla enhetstester och `Lumen-unsigned.ipa`.
- **Simulatorn (Toby T13, 16:25):** alla fyra T11-fynd är rättade vid största text, med 0 missar i Pro ljust och mörkt. Det är inte verifierat på enhet. Kelly granskar bilderna. Det finns
  inga enhetstester för layouten.
