# Kelly Ke56: App Store-bilder och text (förberedelse, inget publicerat)

Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke56.

## Vad som gjordes
- `docs/appstore/README.md`: fem bilder i 6,9 tum (1320 × 2868) med rubrik och rad i Apple-stil (Fota materialet,
  Frågor med A-svar, Starta prov, Tryck för svaret och Dela med klassen), underrubriken "Plugga utan att röra mobilen"
  (28/30), reklamtext (134/170), nyckelord (95/100) och beskrivningen (1 536/4 000) med Arons trycktext (A90)
  ordagrant. Tecknen är räknade med Python.
- `docs/appstore/_src/appstore.py` gör bilderna ur en skärmbildsartefakt. Bilderna är oförändrade skärmbilder i en
  enkel ram, utan skugga eller gradient.
- En tabell över påståenden som måste provas på telefon före inskickning (mikrofonen, ordningen, trycken, delningen,
  andra hörlurar och att foton inte sparas).

## Begränsningar
- **Bilderna är förhandsvisningar:** de visar appen före A87 (CI 43514517449, iPhone 17 Pro, uppskalade) och har
  rubrikerna i Segoe UI. De görs om med A87:s bilder från iPhone 17 Pro Max och SF Pro på en Mac.
- Integritetspolicy, åldersgräns och integritetsetiketter saknas (står under "Kvar").
- Inget är inlagt i App Store Connect.
