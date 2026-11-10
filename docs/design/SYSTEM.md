# Designsystem: Lumen som en riktig pluggapp (Kelly, Ke12, 2026-11-10)

Aron 2026-11-10: appen ska se ut som andra pluggappar, inte som en vibe-kodad app. Det här ersätter D86:s skollook
(rutpapper, handstil, röd lärarpenna). Angela bygger det i A18. Sidan följer efter. `designspec.md` visar hur appen och
sidan ser ut i dag; den här filen visar hur de ska se ut.

Skisser: `bilder/system/` (fem skärmar, före och efter, ljust och mörkt, plus `logo.png`), källa
`_src/system.html`. **Skisser, inget byggt, inget provat på telefon.**

## 1. Vad gör de andra proffsiga?
Jämförelsen bygger på vad jag vet om apparna, inte på dagens versioner. Den är **ej verifierad mot App Store**, och inga
bilder därifrån ligger i repot.

| App | Det som gör den proffsig | Vi tar |
|---|---|---|
| Quizlet | Vita kort med mjuk skugga, en blå accent och mycket luft. Inga mönster bakom texten. | Kort i stället för rutpapper, en accent. |
| Speak | En stor sak per skärm (frågan, mikrofonen). Rösten står i centrum och knapparna är få och stora. | En huvudknapp per skärm, och ett tydligt läge för "Lyssnar". |
| Duolingo | En egen figur i en enda stil som återkommer överallt. Korta, vänliga texter. | Elias som återkommande figur, i en stil. Ton i texterna. |
| Apple Anteckningar / Fitness | Systemets listor, typografi som bär allt och ett fåtal färger. Allt avancerat ligger en nivå ner. | Vanliga iOS-listor i Inställningar. Rubriker i stort och fett. |

Det gemensamma är luft, typografi och en accentfärg. Illustrationer ligger i en enda stil, och det finns inga gimmickar.

## 2. Grunder
**Färger** (ljust / mörkt). En accent. Rött bara vid fel.
| Token | Ljust | Mörkt | Används till |
|---|---|---|---|
| `background` | #FFFFFF | #0F1218 | skärmar |
| `surface` | #F4F6FA | #181C26 | grupperade listor, sekundära knappar, brunnar i kort |
| `raised` | #FFFFFF | #1D2230 | kort |
| `ink` | #141A2E | #EEF1F7 | text |
| `muted` | #5E6779 | #9AA3B5 | hjälptext, frågan ovanför svaret |
| `line` | #E4E8EF | #272D3B | avdelare, kortkant i ljust |
| `blue` (accent) | #2346C8 | #7F9BFF | huvudknapp, länkar, Lyssnar-brickan |
| `soft` | #EAF0FF | #1E2A4F | brickor ("5 dagar kvar", "Lyssnar") |
| `red` | #D9342B | #FF6F61 | **bara** fel och "radera" |

Lägesfärgerna (grön, orange, magenta, grafit) tas bort ur gränssnittet. Rutpappret tas bort helt i appen.

**Typsnitt:** Familjen Grotesk, en familj. **Ingen handstil** (Kalam används inte längre i gränssnittet).
| Stil | Storlek / vikt | Exempel |
|---|---|---|
| Stor rubrik | 34 / bold, spärr −2 % | "Fråga högt. Få svaret i örat." |
| Rubrik | 28 / bold | "Biologiprovet" |
| Brödtext | 17 / regular, radavstånd 1,4 | |
| Svar | 20 / regular, radavstånd 1,4 | svaret på Lyssnar |
| Frågan | 15 / semibold, `muted` | "Vad är fotosyntes?" ovanför svaret |
| Knapp | 17 / semibold | |
| Fotnot | 13 / regular, `muted` | "Inget konto." |
| Sektionsrubrik | 13 / semibold, versaler, `muted` | "ANDRA PROV" |

Alla storlekar följer Dynamic Type (`relativeTo:`).

**Avstånd:** 4, 8, 12, 16, 20 (skärmkant), 24, 32. **Hörn:** knappar 14, kort 20, brickor och chips helt runda, listgrupper
16, ikonknappar 12. **Skugga:** kort i ljust läge `0 1 2 / 6 %` plus `0 6 20 / 7 %`. Mörkt läge har ingen skugga och
använder `raised` i stället. **Ikoner:** SF Symbols i vikt regular, 20–22 pt (på sidan: SVG med 1,8 px streck och rundade
ändar). Inga egna ikoner utom loggan.

## 3. Komponenter
- **Huvudknapp:** blå, höjd 54, hörn 14. **Högst en per skärm.**
- **Knapp med förklaring** (D97): två rader, rubrik 17 semibold och en rad 13 under, höjd 64. Används på provkortet,
  där "Förhör mig" (blå) och "Få A-svar till provet" (sekundär) står ihop och raden under säger skillnaden.
- **Lägesväljare (bara sidan, Ke19):** iOS-segmentkontroll, ränna i `surface` (hörn 14), vald del i `seg-on`
  (#FFFFFF ljust, #2B3245 mörkt) med liten skugga, text 16 semibold. Används i demorutan för D97:s två val, "Förhör mig"
  och "Få A-svar till provet", med appens rad under. Den räknas inte som huvudknapp.
- **Sekundär knapp:** `surface`-yta, bläck-text. Används för Pausa, Avsluta, Bara fråga och Fler lägen.
- **Textknapp:** blå text, för "Hoppa över", "+ Lägg till prov" och "Läs mer".
- **Fara:** röd text, bara i bekräftelser ("Radera minnet"). Aldrig för Avsluta.
- **Kort:** `raised`, hörn 20, skugga. Provkortet: liten rubrik "NÄSTA PROV", bricka med dagar kvar, rubrik, datum,
  en brunn med "Öva mer på", och sist **"Förhör mig"** ("Lumen frågar ut dig och svarar på dina frågor") och **"Få A-svar
  till provet"** ("Lumen svarar bara när du frågar"). Namnen är Arons beslut (D97) och ändras inte.
- **Bricka:** `soft` och blå text, helt rund. "5 dagar kvar" ersätter den röda handstilsringen.
- **Lyssnar-bricka:** blå punkt med en mjuk ring, texten och nivåmätaren i en rund bricka mitt på skärmen. Texterna:
  "Lyssnar", "Hör inte, försöker igen", "Pausad" och "Svarar".
- **Lista:** vanlig iOS-lista (`insetGrouped`), rad med värde och pil. Inga chips eller reglage med siffror i listan.
- **Elias:** alltid i ett ljust kort (vit bakgrund, hörn 24, skugga), också i mörkt läge, som ett foto. Ringarna från
  hörluren är loggans rörelse.

## 4. Ton i texterna
- Du-form. Korta meningar. Verbet först på knappar: "Förhör mig", "Lägg till prov", "Testa nu".
- Samma ord på knappen som det man säger till Lumen.
- Aldrig: utvecklartext (licenser, modellnamn, "1.00×", röstnamn som "Adam"), dubbla negationer ("Inget prov just
  nu" på en brytare), utropstecken, ständiga instruktionsrader ("Säg 'Lumen, byt till …'").
- Röstkommandon visas en gång, när de behövs (tips efter första svaret, under Röstkommandon), inte på varje skärm.
- **Klar eller Stäng (Ke28, 2026-11-10):** ett blad som glider upp (Byt läge, Kommandon) har **"Klar"** uppe till
  höger, som iOS. Ett kort inuti en skärm (resultatkortet i övningsprovet, felkort) har **"Stäng"**.
- Citat och exempel på svenska skrivs med ”…” (samma tecken på båda sidor), inte med raka "…".

## 5. Logga och appikon: symbol 4, bock med ljudvågor (Aron 2026-11-10 21:18, Ke24)
Aron valde nummer 4 bland sina sex ChatGPT-förslag (`logo/chatgpt-forslag-2026-11-10.jpg`). A/B/C från Ke12 är avvisade.
Kontroll i alla storlekar: `logo/symbol4-kontroll.png`. Källa: `logo/_src/symbol4.py` (ändra bara där).

**Filer**
| Fil | Till |
|---|---|
| `logo/lumen-ikon-ljus-1024.png` (+ `.svg`) | AppIcon, vanlig. Fyrkantig, utan genomskinlighet; iOS rundar hörnen |
| `logo/lumen-ikon-mork-1024.png` | AppIcon, mörk variant (iOS 18+) |
| `logo/lumen-ikon-tonad-1024.png` | AppIcon, tonad variant (iOS 18+), gråskala |
| `logo/lumen-symbol.svg` | Symbolen ensam, `currentColor`, ruta 89 × 56 |
| `site/favicon.svg`, `favicon-32.png`, `apple-touch-icon.png` | Demosidan (bytta i Ke24) |

**Geometri** (ruta 100 × 100, runda ändar och hörn, ingen fyllning):
- Bock: linje 13,51 → 31,68 → 53,42, bredd 12.
- Våg 1: båge med centrum 59,55, radie 18, från −46° till +46° (0° = rakt åt höger), bredd 10.
- Våg 2: samma centrum, radie 32, samma vinklar, bredd 10.
- Symbolens yta är x 7–96, y 27–83 (89 × 56). Ska den stå i en kvadrat: centrera ytan och låt bredden styra.
- **I SwiftUI (`LumenLogo`)**: tre `Shape` i en ruta med bredden `size` och höjden `size × 56/89`; skala
  `size / 89` och flytta −7, −27. Bocken som `Path` med `addLines`, vågorna med `addArc` (center 59,55,
  `startAngle: -46°`, `endAngle: 46°`, `clockwise: false` i SwiftUI:s koordinater där y går nedåt). Färg
  `LumenColor.blue`, båda vågorna i full färg (inte 50 % som de gamla radiovågorna).

**Färger:** ljus ikon med toning #3D62E6 → #1D34AE (uppe till vänster → nere till höger) och vit symbol. Mörk ikon
#1A2030 → #0B0E15 med symbolen #A9BCFF → #7F9BFF. Utanför ikonen har symbolen alltid accentfärgen (#2346C8 / #7F9BFF).

Symbolen ersätter radiovågorna överallt: appikonen, introt, Start, kontrollen/Live Activity och demosidan.
Namnet är inte beslutat (D117/D122), så ordmärket säger fortfarande "Lumen".

## 6. Skärmarna (före → efter)
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Intro | `bilder/system/intro.png`, `-dark` | Elias-kortet i stället för grå hörlurar på rutpapper. En mening under rubriken. Löftena som en lugn lista. Samtyckesmeningen står kvar under Testa nu. |
| Första frågan | `fraga.png`, `-dark` | Ingen handstil: frågan i 15 semibold grå, svaret i 20. Lyssnar-brickan i kortet. Fortsätt syns först efter svaret. |
| Start | `start.png`, `-dark` | Provkortet med brickan "5 dagar kvar" och D97:s två knappar, "Förhör mig" och "Få A-svar till provet", med en rad under varje. Andra prov i en lista utan mikrofoner. "Bara fråga" och "Fler lägen" som sekundära knappar. Inga lägescirklar och ingen instruktionsrad. |
| Lyssnar | `lyssnar.png`, `-dark` | Titeln i mitten, "Byt läge" under ⋯. Lyssnar-brickan i mitten. Pausa och Avsluta är neutrala (Avsluta är rösternas ord, och "klar" betyder redan något i Intervjuläget, D72); Pausa blir blå "Lyssna igen" när det är pausat. Tummen ned (D57) står kvar. |
| Inställningar | `inst.png`, `-dark` | iOS-lista i fyra grupper. Rösten beskrivs, och provlyssning och hastighet ligger på Röst-sidan. Prov tas bort (hanteras på Start). Licenser bara under Om Lumen › Licenser. |

## 7. Ersätter
Det här ersätter handstilen, rutpappret och den röda pennan i `enkel-start.md` (Ke9/Ke10). Flödet och "en knapp per
skärm" därifrån gäller fortfarande.

## 8. Fler skärmar (Ke14)
Bilder i `bilder/system/`, ljust till vänster och mörkt till höger.
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Har du prov snart? (A22) | `prov2.png` | Lumen lyssnar redan, och brickan "Lyssnar" sitter i kortet med exemplet. Tre val (ämne som runda chips, datum, årskurs), "Spara prov" blå och "Inte nu" tyst. Delämnet frågas i första förhöret. |
| Röst | `rost.png` | Rösterna beskrivs ("Mansröst, lugn"), ▶ på varje rad för att provlyssna och ✓ på den valda. Talhastighet i tre steg (Lugn, Normal, Snabb). Beskrivningarna är exempel och sätts efter de röster som finns. |
| Byt läge (blad) | `bytlage.png` | Förhör mig, Få A-svar till provet och Bara fråga överst, och under dem FLER LÄGEN. Ikonerna är grå SF Symbols; det valda läget har blå ikon och ✓. Röstkommandot står en gång, längst ner. |
| Kommandon (blad) | `kommandon.png` | "Säg till Lumen" med fem kommandon och vad som händer, plus "Alla kommandon ›". |
| Lumen hör dig inte | `nekad2.png` | En ikon i en mjuk cirkel, tre numrerade steg i en brunn, "Öppna Inställningar" blå och "Hoppa över" tyst. |
