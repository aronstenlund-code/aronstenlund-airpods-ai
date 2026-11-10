# Ke21 del 2 – Granskning av A28–A30 och Ke18 klar (Kelly, 2026-11-10 12:49)

Angela pushade samma bilder under arbetet (`reports/2026-11-10-a30-skarmbilder/`, kontrollerat byte för byte för
`addExamFirst`, `listeningProv` och `practice`).

Underlag: Angelas `reports/2026-11-10-angela-a30-kelly-ke20.md` och simulatorbilderna från CI-körningarna 42807653076
(iPhone 17 Pro, 1206 × 2622) och 42807657706 (iPhone SE, 750 × 1334), båda gröna. Jag hämtade bilderna direkt ur
körningarna, eftersom de inte var pushade än. Kontaktark: `reports/2026-11-10-ke21-granskning-a30/`.
**Bara skärmbilder från simulatorn, inget på telefon.**

A28 (ekot efter tiden) och A29 (händelser för mikrofonen) ändrar inte utseendet, så de har inga bilder att granska.

## Dom: **A30 godkänd.** Alla fyra fynden från Ke20 är rättade i bild.
| # | Fynd (Ke20) | I bilderna |
|---|---|---|
| 1 | Övningsprovet saknar lyssnarbricka (skyddsräcke) | **Rättat.** `practice` och `practiceResult` visar Lyssnar i Provläge med brickan "Lyssnar", på Pro och SE och i ljust och mörkt (bild 1–3). |
| 2 | "Klar" på resultatkortet | **Rättat.** Knappen heter "Stäng" (bild 2). |
| 3 | "Lumen sparar aldrig ljud" | **Rättat.** Första frågan säger "Ljud sparas inte.", samma ord som introt (bild 2). |
| 4 | Ingen ✓ på röstsidan i mörkt | **Rättat.** Den valda rösten har ✓ i ljust och mörkt (bild 2). |
| R2 | SE ljust intro saknades | **Rättat.** Alla tre löftena och "Ljud sparas inte · Läs mer" syns ovanför Testa nu på SE i ljust (bild 3). |

Kontrast: knapparna i mörkt läge har mörk text (#0E1630) på #7F9BFF, alltså 7,2:1, samma som sidan (**mätt i bilden**).

## Nya fynd (till Angela via Deangelo, alla mindre)
1. **"Har du prov snart?" (`addExamFirst`) visar "Startar …"**, eftersom simulatorn saknar mikrofon. `listeningProv` visar
   redan "Lyssnar" via `screenshotShows`; gör samma sak här, så att skissen `prov2.png` och sidans steg 2 stämmer.
2. **Ämnena på "Har du prov snart?"** är rundade rutor. Enligt SYSTEM.md §3 är chips helt runda.
3. **Instruktionsraden "Säg "Lumen, förhör mig"" står längst ner på Lyssnar** (även i A26, som jag missade). SYSTEM.md §4
   säger att röstkommandon ska visas en gång, inte på varje skärm. Kommandon-länken räcker.
4. **Demodatan i övningsprovet blandar ämnen:** "Biologiprovet" med en fråga om första världskriget, återkoppling om en
   ekvation ("x är fem") och "Att öva på: ekvationer". Det syns bara i skärmbilderna, men bilderna kan hamna på sidan och i
   App Store. Använd biologifrågor.
5. **Röstsidan:** "iPhonens röst" och "Alva, iPhonens röst" ser ut som samma sak två gånger, och "Saga, Svensk röst"
   och "Max, Svensk röst" säger inget om skillnaden. SYSTEM.md §8 beskriver rösten ("Mansröst, lugn") i stället för att
   ge den namn.
6. **"Lägg till prov" (`addExam`)** har fortfarande 19 val (årskurs, ämne, delämne). Det följer inte Ke14:s tre val, men
   "Har du prov snart?" gör det. Det är ett gammalt fynd, och jag tar det bara med här för att inte tappa det.

## Ke18 klar: sidans tre steg i appens nya system
| Steg | Bild | Källa |
|---|---|---|
| 1. Tryck Testa nu och fråga högt | `site/img/fraga-*.webp` | `first` (nu med "Ljud sparas inte.") |
| 2. Säg vilket prov du har | `site/img/steg1-*.webp` | `addExamFirst`, "Har du prov snart?" |
| 3. Säg "Lumen, förhör mig" | `site/img/steg3-*.webp` | `listeningProv`, Provläget med brickan "Lyssnar" |

- 300 × 652 WebP, 9–14 kB per bild. Sidan är 1,5 MB (gräns 2 MB).
- Steg 2 och 3 har nya alt-texter som beskriver det som syns.
- Steg 2 visar "Startar …" (fynd 1). Det är sant mot appen när den startar. Bilden byts när Angela har tagit om den.
- Kontrollerat i Chromium på 1280 px i ljust och mörkt (bild 4–5) och på 375 px. Lighthouse 99/100/100/100, med Supabase
  blockerat. **Inte provat i Safari eller på iPhone.**

## Till Aron
- Välj ett av de sex ChatGPT-förslagen till loggan (`docs/design/logo/chatgpt-forslag-2026-11-10.jpg`, Ke24). Den behövs på
  sidan, i appen och i delningsbilden.
