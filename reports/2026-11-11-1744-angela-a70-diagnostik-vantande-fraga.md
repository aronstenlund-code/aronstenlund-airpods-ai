# A70 – Diagnostik för Tobys T14 fynd 2–3 (egen punkt, README 8)

Angela, 2026-11-11. Underlag: `reports/apptest/2026-11-11-1725-toby-t14-omtest-a67-a68.md`.

## Vad som är gjort
- En fråga som väntar i frågetimern i mer än 3 s loggar en gång raden "A question waits 3 s: …" (A70).
- Raden säger varför Lumen räknas som upptagen:
  - om ljud spelas;
  - om tal väntar på att läsas upp;
  - om ett svar strömmar, med när Lumen senast talade, när anropet gick och om det var ett svar i förväg.
- **Inget beteende är ändrat.** Det är underlag till nästa rättelse (överlämningen, "Nästa session börjar här").

## Testresultat
- **iOS-bygge och enhetstester:** CI 43057820636 (d5121e3) är **grön**: device-bygget, alla enhetstester och
  `Lumen-unsigned.ipa`.
- Nästa steg: Toby kör retest, och raden visar vad som håller frågan i 13–29 s.
