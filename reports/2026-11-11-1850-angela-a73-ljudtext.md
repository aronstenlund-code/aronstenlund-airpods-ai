# A73 – Rätt text om ljud (G3, D138)

Angela, 2026-11-11. Kö: `prompts/queue/angela.md` A73 (Deangelo, D138).

## Vad som är gjort
"Ljud sparas inte" och "Earmind sparar aldrig ljud" var osanna, eftersom sömnläget sparar klipp på telefonen. Överallt
där appen säger något om ljud står nu: **"Ljudet blir text och sparas inte av Earmind. Sömnläget sparar klippen bara
på din telefon."**

Texten är bytt på de här ställena:
- **Introt:** punkten i listan ovanför "Testa nu".
- **Första frågan:** raden längst ner.
- **Om appen:** första stycket och stycket om analys.
- **Samtycket (fullständig text):** punkten om ElevenLabs och punkten "Frågor och svar skickas till oss".
- **iOS fråga om mikrofonen** (`NSMicrophoneUsageDescription`, sv och en).

**Samtycket har version 6** (`ConsentPolicy.currentVersion`). Innehållet har ändrats, så alla, också Aron, får se
samtycket en gång till innan nästa session. `qa_log` (D116) gäller fortfarande, eftersom version 6 ≥ 5.

Om appens rad om ElevenLabs Scribe ("Ljudet skickas för att skrivas ut och sparas inte") handlar om ElevenLabs, inte
om Earmind. Den är inte ändrad.

## Testresultat
- **Enhetstester:** `LumenTests/A73Tests.swift` har 1 test, för versionen och `qa_log`.
- **iOS-bygge och enhetstester:** CI 43071994761 (8afb5bc) är **grön**: device-bygget, alla enhetstester och `Lumen-unsigned.ipa`.
- **Ej verifierat på enhet.**
- Kelly granskar texterna i introt och på Första frågan. Punkten i introt är nu två meningar.

## Till Aron
- Samtycket visas en gång till när du öppnar appen. Det är avsiktligt, eftersom texten om ljud har ändrats.

## Till Toby
- E2E-testerna som letar efter "Ljud sparas inte" behöver den nya texten.
