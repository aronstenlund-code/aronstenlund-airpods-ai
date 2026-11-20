# Ke85: policyn och App Privacy efter D247 (Kelly (moln), 2026-11-20)

**Inget publicerat och inget inlagt i App Store Connect.**

## Vad som ändrades
- **Ke78-utkastet** (grenen `kelly/ke78-integritet`, commit 862c79b, bilder i `reports/2026-11-17-ke78-bilder/`), avsnittet
  om analys:
  - Provens frågor och svar skickas **inte** för analys; bara med Dela historik på skickas nya och ändrade, utan koppling
    till kontot, raderas inom 14 dagar (D247/D248).
  - Lyssnarlägen efter samtycke: högst 14 dagar, utan koppling. Rapporter: högst 90 dagar, kopplade. Delad historik:
    frivillig, kopplad, högst 12 månader.
  - Markeringen om loggen utan samtycke är borta. **Kvar: 13 overifierade punkter** (8 i integritet, 5 i villkor).
- **`docs/appstore/granskning.md`:** §2 punkt 3 b säger att repetitionsloggen bara skrivs för testkonton och den som delar
  historik (D247), och beslutet är avgjort. §2b oförändrad i sak: Analytics på Other User Content kommer nu från
  lyssnarlägenas logg (3 a) och delad historik (3 d). Stämmer med koden.

## Kontroll
- Backend: `drill/handler.ts:1132` loggar bara när `currentTest()?.test` eller `share_history === true` (**verifierat i koden**).
- **Fynd:** appen skickar inte `share_history` än (ingen träff i `Lumen/`). I dag loggas alltså bara testkonton; den som
  slår på Dela historik får inte sina prov loggade. Till Angela Schrute (rad i angela.md), och det är i linje med
  minsta möjliga data tills appen skickar flaggan.
