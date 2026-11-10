# Överlämning: Angela (app), 2026-11-10 eftermiddag

Den här sessionen har gjort 11 punkter i dag: A21, A18, A20, A22, A23, A24, A25, A26, A16, A19 och A27. Alla är
gröna i CI, men ingen är provad på telefon. Rapporterna finns i `reports/2026-11-10-angela-a*.md`. I kön återstår
bara A3 (röstlistan), som väntar på Kevins K6 (ElevenLabs-krediter). Det mesta av A3 finns redan i A26:s röstsida.

## Det här står inte i rapporterna
- **Ingen Mac.** CI (`ios-build.yml`) är kompilatorn och tar cirka 15–20 minuter. Hjälpskripten heter `ghapi.sh`,
  `waitsha.sh` och `waitrun.sh` (se minnet `lumen-project-setup`).
  - Varje push som rör app-kod avbryter körningen som pågår, också när någon annan pushar. Samla ändringarna innan du
    pushar.
  - Skärmbilder tas med `screenshots.yml` (workflow_dispatch med `device`). Scenerna `voice` och `practice` är nya.
  - Den första bilden i en körning kan bli hemskärmen. Det hände med SE och intro i ljust läge.
- **Swift-fällor som har kostat CI-rundor:**
  - Tester anropar vyernas statiska hjälpfunktioner från en nonisolated kontext. Märk funktionerna `nonisolated` eller
    testsviten `@MainActor`.
  - Ett muterande anrop får inte stå inne i `#require` eller `#expect`. Lägg resultatet i en `let` först.
  - `switch` som implicit returvärde efter en `if` kräver `return switch`.
- **Delat index:** andra sessioner får ibland med dina ostagade ändringar i sina commits. Oscars `310a7c0` tog till
  exempel med min STATUS-rad.
  - Committa med `git commit -- <filer>`.
  - Synka med `git fetch origin main && git rebase --autostash origin/main`.
- **Python-patchar:** skriv skriptet till scratchpad med Write-verktyget och kör det med `python -I`. Heredocs med `'''`
  och `\(` bryter i bash.

## Öppna trådar
- **A16, övningsprovet:**
  - Navigeringen är en Swift-port av Kevins `practice.ts` (`PracticeNav`). Ändrar Kevin `practice.ts` måste porten
    ändras också.
  - Toby kan göra ett E2E-test när ElevenLabs-kvoten är påfylld.
- **A19:**
  - Påminnelsen kommer kl. 16 tills Aron väljer en annan tid.
  - Förhörssvar fyller inte planens historik. Det kräver ett begrepp per fråga från Kevin (`done.concept`).
  - "Länk när eleven kört fast" behöver att appen skickar `stuck: true` (K19). Det är nästa steg.
- **A26:** Kevin kan lägga till `description` i `/voices`. Loggan (U5) väntar på Arons val.
- **A27:** serverns och appens listor över känsliga ord bör bli en enda lista (Kevin).
- **Toby:** kör om T3 och T8. Introt har nya ord ("Lyssnar bara när du har startat den" och "Inget konto. Testa nu
  betyder …"), och Första frågan har "Pausad" och "Lyssna igen".
- **Möjliga stående uppgifter:**
  - `stuck: true` för K19;
  - Oscars O30: ett ekofilter som räknar med när uppläsningen slutade;
  - Tobys `SessionEvent` för "fönstret öppet" och "mikrofonen öppen" (T7).
