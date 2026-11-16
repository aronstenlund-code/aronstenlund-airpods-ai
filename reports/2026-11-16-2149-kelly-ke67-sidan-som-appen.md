# Kelly (moln) Ke67: demosidan och appen som samma produkt

Jämfört: demosidan på grenen `kelly/ke66-earmind-site` mot appens skärmar A106–A112 (grenarna `fable/screens-*`).

## Det som skilde och är rättat på sidan (grenen, 79b725d, inte publicerat)
| Vad | Sidan förut | Appen | Sidan nu |
|---|---|---|---|
| Typsnitt | Familjen Grotesk (webbtypsnitt) | SF Pro, systemets (D160) | Systemets typsnitt (`-apple-system`, SF Pro). Webbtypsnittet och dess förladdning är borttagna. |
| Färger | Accent #2346C8 / #7F9BFF | Samma | Oförändrat, stämmer redan. |
| Namn | EarMind (Ke66) | EarMind | Stämmer. |
| Rubrik och huvudbudskap | "Fråga högt. Få svaret i örat." (lyssnande läget) | Hem: "Kom förberedd till provet", repetitionsläget först, lyssnande lägen BETA (D142) | "Kom förberedd till provet." + "Fota ditt material. EarMind gör frågor och svar och läser upp dem i dina AirPods." + "Du styr med tryck på AirPods, utan mikrofon." Titel, beskrivning och delningstext efter samma. |
| Stegen | Fråga högt → Har du prov snart? → "Lumen, förhör mig" (gamla Provläget, gamla bilder) | Nytt prov → frågelistan → Starta prov, och Läs upp texten | **Så fungerar det** i fyra steg med appens bilder i ljust och mörkt: Nytt prov (Frågor eller Läs upp texten), Kolla frågorna och svaren, Starta prov (1/2/3 tryck), Eller lyssna på texten (1 paus, 2 nästa, 3 förra). |
| Knappnamn | Förhör mig | Förhör med rösten (Fler lägen) | Förhör med rösten. |
| Lyssnande lägen | "Vad kan EarMind?" högt upp, som huvudsak | Fler lägen, BETA | Avsnittet heter **Fler lägen** med BETA-märket (grå kontur, versaler, som appen) och ligger efter stegen. Demorutan heter "Prova Fler lägen här BETA". Siri-raden borttagen. |
| FAQ | Om "Lumen, förhör mig" | – | Om repetitionsläget, Läs upp texten och att svaren kan ändras. JSON-LD samma. "Lägg in ditt material i förväg" (Förberedelser) ersatt av "Dela och publicera prov". |

## Test
Chromium (Playwright), lokal server från grenens `site/`: mobil (iPhone 15) och dator (1280), ljust och mörkt, inga
JavaScript-fel, ingen vågrät rullning på mobil (scrollWidth 393). Stegen i fyra kolumner från 1180 px, två från 900.
Bilder: `reports/2026-11-16-ke67-bilder/`. **Inte provat i Safari eller på iPhone.** `site/` är 1,6 MB.

## Kvar och frågor
- **Elias** (illustrationen i heron och delningsbilden) finns inte i appen sedan Ke55. Ska han vara kvar på sidan? Det är
  Arons val; jag har inte rört honom.
- **Livedemon** är fortfarande de lyssnande lägena, eftersom repetitionsläget behöver ett eget prov. Utkastet i
  `drafts/site-repetition/` har en tryckdemo utan server som kan ersätta den när Aron vill.
- Sidans regel (Ke1) är att inget påstås som inte är provat på telefon. Repetitionsläget och läsläget är inte provade på
  telefon av Aron än (`docs/TEST-ARON-REPETITION.md`); sidan publiceras först efter hans ja, så det hinner bli det.

## Förslag till appen (angela-fable.md)
1. Hem utan prov: nämn läsläget i raden: "Fota ditt material. EarMind gör frågor och svar, eller läser upp texten, i
   dina AirPods." (samma som sidans steg 1).

## Nästa steg
Aron (#18): ja → slå ihop `kelly/ke66-earmind-site` med main. Kelly: granska A112b när Angela Fable är klar.
