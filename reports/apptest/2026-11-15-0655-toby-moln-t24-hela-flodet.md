# T24: hela repetitionsflödet som ny användare, grön körning

Toby (moln), 2026-11-15 03:20–06:55. Tar över efter Toby 2 (`reports/apptest/2026-11-15-0250-toby2-t24-hela-flodet.md`, fynd
L1–L6 och V1–V4). Simulatorn i GitHub Actions, två simulatorer (iPhone 17 Pro och iPhone 17, iOS 26). **Inte verifierat på
enhet.** Falskt ljud via `LUMEN_TEST_HEADER` (x-earmind-test, D180). **0 ElevenLabs.**

## Resultat: körning 43678600052, grön (toby/t24 8b2d10d = b903f59 + main e06d0d8, med Angela Schrutes 8a521b1)
**Fas a** (konto A), 39 tryck, 22 skärmar:

| Steg | Tid | Tryck |
|---|---|---|
| Första starten → Fota sidor → Välj bilder → Skapa frågor → Ser rätt ut → Starta prov → första frågan | 169 s | 10 |
| Frågor och svar och en fråga | 12 s | 3 |
| Gör med ChatGPT | 32 s | 5 |
| Dela | 107 s | 2 |
| Publicera prov (Central insamlingsenhet, Kiruna) | 83 s | 10 |
| Mina svar (se fynd T24-M1) | 58 s | 3 |
| Väntar på att konto B hittar provet | 10 s | 0 |
| Ta bort publiceringen och provet | 55 s | 6 |

**Fas b** (konto B), 17 tryck:

| Steg | Tid | Tryck |
|---|---|---|
| Första starten utan prov | 10 s | 2 |
| Prov från din skola → A:s prov → Lägg till i mina prov | 152 s | 5 |
| Läget `slow` | 132 s | 5 |
| Läget `unavailable` | 104 s | 5 |
| Proven finns kvar efter två omstarter (D183) | 82 s | 0 |

- **Städningen fungerar.** "Publiceringen är borttagen." och provet borta. `drill_publications` för skola 35374123 har
  efter körningen bara Toby 2:s två kända rader (36a3f569…, 49e29092…), som väntar på Arons besked (Till Aron #21).
  *Verifierat i databasen.*
- Tidigare röda körningar var simulatorn ("Failed to get background assertion", 43664448952) och testet: larmet Okej
  efter Ta bort publiceringen täckte Mer, och Mina svar fanns inte. Båda är rättade i testet.

## Omtest av Angela Schrutes 8a521b1 (L2, L3, L5, L6)
- **L2 rättad:** ett prov från Gör med ChatGPT heter efter första frågan ("Vad behöver växter för fotosyntesen"), inte
  "Nytt prov". Sett i 43674540972.
- **L3:** ingen rad om "1 rad kunde inte läsas" i stegloggen. Hittade 3 frågor med ChatGPTs inledning. *Bara loggen, inte
  bilden.*
- **L5 inte rättad i testet:** i läget `unavailable` syns "Ljudet kan inte göras just nu" inte på Start inom 40 s, i tre
  körningar av tre (43674540972, 43678600052 och 43664448952 före rättningen). Till Angela Schrute med frågan i
  hennes rapport: testet läser Start i 40 s efter en omstart. Raden kanske bara visas på provets skärm eller i spelaren.
- **L6:** i läget `slow` såg testet en rad om ljudet på Start. Testet skriver ingen anteckning när en rad finns, men
  ordalydelsen står bara i hela stegloggen (artefakten). *Untested assumption* att det är "Ljudet dröjer".

## Fynd (nya)
| Id | Vad | Till |
|---|---|---|
| T24-M1 | **Mina svar och repetitionsprovet hänger inte ihop.** Efter ett prov i repetitionsflödet visar Provläge (Fler lägen) ändå "Har du prov snart? Lägg till prov", och Mina svar (Spela in eget svar) finns först när ett prov har lagts till där. En ny användare som har gjort ett prov hittar inte Mina svar. Samma sak som V4 från logiksidan. | Angela Schrute (logik), Angela Fable (V4) |
| T24-V2b | V2 kvar och nu två larm: "Publicerat." **och** "Publiceringen är borttagen." med Okej. Sidan säger det redan i en rad. | Angela Fable |

## Kvar sedan Toby 2 (inte omtestat här)
- V1, V3, V4 (Angela Fable, A104 pågår).
- "Dela" visar inget delningsblad med Kopiera i simulatorn. Sannolikt simulatorn, *untested assumption*.
- "Provdatum: dagen 22 november hittades inte i kalendern." Sannolikt testets sätt att leta i kalendern, inte appen (*untested assumption*); provet publicerades ändå med ett datum.
- 1, 2 och 3 tryck går inte att skicka från ett UI-test. Krok begärd av Angela Schrute (se T27-rapporten).

## Nästa
- Kör `apptest-fullflow` igen efter A104 (V1–V4) och efter Angela Schrutes svar om L5. Testet är på main nu; en push till
  `toby/**` som rör de tre filerna startar det.
