# Designspec: appen och demosidan som en produkt (Kelly, Ke12b, 2026-11-10)

Ett ställe där appens och sidans värden står bredvid varandra. Appen: `Shared/LumenStyle.swift` och
`Lumen/Features/Design/Theme.swift`. Sidan: `:root` och `.pill`/`.chip` i `site/index.html`. Värdena är lästa ur koden
(**verifierat i koden**, inte på telefon).

## Färger (ljust / mörkt)
| Token | Appen (`LumenColor`) | Sidan (`--…`) | Läge |
|---|---|---|---|
| bakgrund | `background` #FFFFFF / #11151F | `--bg` samma | lika |
| papper | `paper` #F5F8FC / #161C2A | `--paper` samma | lika |
| rutor | `grid` #D9E3F0 / #232B3D | `--grid` samma | lika |
| bläck | `ink` #18213A / #EEF1F7 | `--ink` samma | lika |
| dämpad text | `muted` #5A6478 / #9AA3B5 | `--mut` samma | lika |
| blå | `blue` #2346C8 / #7F9BFF | `--blue` samma | lika |
| på blå | `onBlue` #FFFFFF / #0E1630 | `--on-blue` samma | lika |
| röd | `red` #D9342B / #FF6F61 | `--red` samma | lika |
| på röd | `onRed` #FFFFFF / #2A0B07 | `--on-red` samma | lika |
| knappyta | `chip` #F1F4F9 / #1B2131 | `--chip` samma | lika |
| linje | `line` #E2E7EF / #2A3247 | `--line` samma | lika |
| mjuk blå | `soft` #EAF0FF / #1E2A4F | finns inte | behövs inte på sidan |
| röd text | (använder `red`) | `--bad` #B8261E / #FF8A7E | sidan mörkare röd för kontrast i felrader (WCAG AA på papper) |
| lägesfärger | graphite, green, orange, magenta | finns inte | sidan visar inga lägescirklar (Ke9) |

## Typsnitt
| | Appen | Sidan | Läge |
|---|---|---|---|
| Text | Familjen Grotesk, 17 pt bas | Familjen Grotesk, 17 px bas (1.0625rem) | lika |
| Handstil | Kalam Regular för frågor, Kalam Bold för röda pennan | Kalam Regular för frågor | lika (sidan har ingen röd penna) |
| Knapptext | 18 pt semibold | 18 px 600 i väntelistan (Ke12), 17 px i små knappar | lika där det räknas |

## Knappar
| | Appen (`LumenButtonStyle`) | Sidan (`.pill`) | Läge |
|---|---|---|---|
| Huvudknapp | blå, hörn 10, höjd 56 (54 på Start) | blå, hörn 10, höjd 54 (väntelistan), 50 i demon | lika |
| Sekundär | `chip`-yta, bläck-text | `.pill.quiet`/`.stop`: `--chip`, bläck, tunn kant (Ke12) | lika; sidan har en kant eftersom knappen står på rutpapper |
| Fara | röd (`danger`), används för Avsluta | används inte längre (Ke12: Stoppa var röd) | **appen:** rött bara för fel, se `enkel-start.md` (Lyssnar) |
| Ikonknapp | 44×44, `chip`, hörn 10 | `.send` 52×52 blå | olika uppgift (skicka), ok |
| Tryck | skala 0,97, ut 80 ms, tillbaka 160 ms | skala 0,97 (140 ms) | lika i känsla |

## Kort och papper
| | Appen | Sidan | Läge |
|---|---|---|---|
| Rutpapper | rutor var 18:e pt, linje 1, hörn 6 | rutor 18 px (mobil), 22 px (dator ≥ 960 px) | lika på telefon |
| Provkort | `gridPaper()` hörn 6, streckad när tomt | `.paper` hörn 6 | lika |
| Elias | `IntroHeroView`: frilagd bild på rutpapper | kort med vit bakgrund, hörn 18, skugga (Ke8) | **olika**, se nedan |

## Till Angela (bara appen kan ändra)
1. **Röd Avsluta → tyst Klar** på Lyssnar (rött bara för fel). Bild: `bilder/lyssnar-fore-efter.png`, `bilder/pass-fore-efter.png`.
2. **Elias i introt:** sidan visar honom i ett kort (vit bakgrund, hörn 18, skugga, rutpapper runt), eftersom friläggningen
   gav fladdrande kanter i sekvensen. Appen använder den frilagda stillbilden, som ser bra ut. Behåll den. Ett kort i
   introt skulle bara behövas om stillbilden byts mot en bildruta ur sekvensen. Bild: `bilder/intro-fore-efter.png`.
3. Samma ord: se listan i `enkel-start.md` ("Förhör mig", "Lägg till prov", "Testa nu", "Inget konto").
