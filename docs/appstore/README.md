# App Store: bilder och text (Kelly, Ke56, D160, 2026-11-13)

**Förberedelse. Inget är inlagt i App Store Connect och inget skickas in.** Att publicera eller skicka in görs bara
efter Arons ja (CLAUDE.md). Ersätter utkastet i `docs/marketing/appstore/` (Ke25), som beskrev lyssningen före D142.

## Bilder (6,9 tum, 1320 × 2868)
| # | Fil | Rubrik | Rad under | Scen i appen |
|---|---|---|---|---|
| 1 | `69-1.jpg` | Fota materialet. | Sidor ur boken, bilder, PDF eller text. | `repMaterial` |
| 2 | `69-2.jpg` | Frågor med A-svar. | Ett kort och ett långt svar på varje fråga. | `repList` |
| 3 | `69-3.jpg` | Starta prov. | Frågorna läses upp i dina AirPods. | `repHome` |
| 4 | `69-4.jpg` | Tryck för svaret. | 1 gång för A-svaret. 2 för ett kort. 3 för paus. | `repControlsDone` |
| 5 | `69-5.jpg` | Dela med klassen. | Lägg till prov som kompisarna har gjort. | `repSchools` |

- **Skärmbilderna är exakta:** CI "Simulator screenshots" **43578038498** på **iPhone 17 Pro Max** (1320 × 2868,
  main 508aeb2, efter A87, A83 och A92), inte uppskalade. **Rubrikerna är fortfarande Segoe UI**, eftersom SF Pro
  inte finns i Windows. Gör om dem med SF Pro Display på en Mac före inskickning (kommandot nedan).
- Bild 5 visar Prov från din skola i stället för Dela-scenen, eftersom Dela bara syns som en symbol i verktygsraden.
- Gör om dem med `python -I docs/appstore/_src/appstore.py <mapp> <SF-Pro-Display-Bold.otf> <SF-Pro-Display-Regular.otf>`.
- Apple-stil: grå bakgrund (#F5F5F7), rubrik och en rad, telefonen i en enkel mörk ram och ingen skugga eller gradient.
  Varje bild är en oförändrad skärmbild ur appen.
- Rad 4 bygger på Arons text (A90). Hela meningen står i beskrivningen.
- Bild 1–3 syns i sökresultatet och berättar hela idén: fota → frågor → starta.

## Texter (tecken räknade med Python)
| Fält | Gräns | Text | Tecken |
|---|---|---|---|
| Namn | 30 | EarMind | 7 |
| Underrubrik | 30 | Plugga utan att röra mobilen | 28 |
| Reklamtext | 170 | Fota materialet och få provfrågor med A-svar. Frågorna läses upp i dina hörlurar, och du styr med tryck. Telefonen kan ligga i fickan. | 134 |
| Nyckelord | 100 | `prov,plugga,förhör,provfrågor,instudering,repetition,läxor,glosor,hörlurar,quiz,skola,gymnasiet` | 95 |

"AirPods" står inte i namnet, underrubriken eller nyckelorden (D122, Apples riktlinjer för varumärken). Det används
bara i beskrivningen och på bild 3, som "fungerar med" och "i dina AirPods".

**Beskrivning** (1536 av 4 000 tecken):

> Plugga med AirPods utan att röra mobilen. Fota materialet till ditt prov, så gör EarMind korta provfrågor med A-svar och läser upp dem i dina hörlurar. Du styr med tryck och kan ha telefonen i fickan.
>
> FOTA MATERIALET
> • Fota sidor ur boken, välj bilder, lägg till en PDF eller Word-fil eller klistra in text.
> • EarMind gör en sammanfattning av vad provet handlar om. Stämmer den inte, skriver du en rad så rättas den.
> • Fotona och dokumenten används en gång för att göra frågorna och sparas inte.
>
> FRÅGOR MED A-SVAR
> • Korta frågor som testar att du förstår, inte bara att du minns.
> • Varje fråga får ett kort svar och ett långt A-svar.
> • Ändra, ta bort eller lägg till egna frågor och svar.
>
> STARTA PROV
> • Frågorna läses upp i dina hörlurar, med betänketid efter varje.
> • Medan frågan spelas: tryck 1 gång för frågans A-svar. Tryck 2 gånger för ett kort A-svar på en till två meningar. Tryck 3 gånger för att pausa. Tryck igen för att fortsätta.
> • Listan börjar om i samma ordning tills du avslutar.
> • Starta prov använder aldrig mikrofonen.
>
> DELA MED KLASSEN
> • Dela provet med en länk. Kompisarna får samma frågor, svar och ljud.
> • Fotona och dokumenten delas aldrig.
>
> FLER LÄGEN (BETA)
> EarMind har också lägen som lyssnar på vad du säger och svarar i örat, till exempel förhör med rösten och intervjuträning. De är i beta och frågar om mikrofonen först när du startar dem.
>
> Fungerar med AirPods och andra Bluetooth-hörlurar. EarMind är inte gjord av eller kopplad till Apple. Svar från AI kan vara fel, så kontrollera mot din kursbok.

## Måste stämma innan inskickning (kontrolleras på telefon)
| Påstående | Kontroll |
|---|---|
| "Starta prov använder aldrig mikrofonen." | R9 på telefon (Toby T18) |
| "Listan börjar om i samma ordning" | R5d |
| Tryckens text | A90 på telefon, alla AirPods-modeller i beta (R11) |
| "Dela provet med en länk" | A81/K47 på telefon. Universal links kräver domänen |
| "Fungerar med … andra Bluetooth-hörlurar" | **Ej verifierat:** tryck på andra hörlurar. Stryk det om det inte är provat |
| "Fotona … sparas inte" | B4, K53 (bucket `drill_material` ska tömmas efter att frågorna gjorts: Kevin bekräftar) |
| Lägen i beta | Namnen följer `Shared/capabilities.json` |

## Kvar
Integritetspolicy (krävs, saknas sedan Ke25), åldersgräns (Ke25 föreslog 13+), integritetsetiketter efter D149 (publicerade
prov) och D151 (röstval), skärmbilder från A87 på 17 Pro Max och Arons ja.
