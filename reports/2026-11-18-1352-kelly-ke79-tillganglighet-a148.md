# Ke79: granskning av tillgängligheten (A148) (Kelly (moln), 2026-11-18)

Underlag: Angela Schrutes granskning 44298706992 (commit ed17b15) på grenarna `angela/a11y-a148-1-17pro` (standardtext)
och `angela/a11y-a148-1-se-ax5` (iPhone SE, största text AX5): 22 scener, Xcodes `performAccessibilityAudit`, VoiceOver-
trädet och bilder. Sammanställda bilder: `reports/2026-11-18-ke79-bilder/` (c.jpg standard, se1/se2.jpg AX5).
Allt **sett i Simulatorns granskning och bilder**; inget provat med VoiceOver på telefon.

## Sammanfattning
Layouten håller i största text: inget överlappar, allt går att nå, knapparna staplas. **Kontrasten har inga riktiga fel.**
Det som behöver rättas är **orden VoiceOver läser** (6 saker) och **tre små träffytor**.

## Kontrast
- "Contrast failed" (5 st) gäller bara **avstängda** knappar (Spela medan den väntar, vid 402 och med tomt fält; Radera
  konto medan det raderas) och en rad som ligger under verktygsfältet ("Prov från din skola"). Avstängda kontroller är
  undantagna (WCAG 1.4.3). **Ingen ändring.**
- "Nearly passed" (109 st): grå hjälptexter ("Nästa prov", "5 frågor · …", fotnoterna). Det är iOS gråa sekundärfärg.
  **Behåll den**, förutsatt att det är `.secondary`/`secondaryLabel` och inte en egen grå, så att "Öka kontrast" i iOS
  gör dem mörkare. (Angela kontrollerar i koden.)

## Träffytor (minst 44 punkter)
1. **"Hur ska det låta?"** är 20 punkter högt. Gör hela stilraden tryckbar (minst 44 hög).
2. **Villkor · Integritet · Återställ köp**: ge varje länk minst 44 punkters höjd (luft över och under).
3. **"Fyll på"** i kostnadsraden: hela raden får vara knappen när krediterna inte räcker.

## VoiceOver: ord
| Ställe | Läses i dag | Ska läsas |
|---|---|---|
| Fältets "›" | "›" | **inget** (dekoration, dölj) |
| Fältet | "Säg i AirPods, textfält" (+ "textfält" från iOS = två gånger) | **"Säg i AirPods"** (iOS lägger till "textfält") |
| Kostnaden | "120 krediter" | **"Kostar 120 krediter"** |
| Senaste-kapslarna | "Fotosyntes: koldioxid +…" (avklippt, med "…") | **hela texten (högst 80 tecken), och stil eller röst: "Fotosyntes: koldioxid och vatten …, Lugnt"**; hint "Lägger tillbaka texten" |
| Svarsförklaringen i provet | "Långt svar, 1 tryck på AirPods, Långt svar, 1 tryck på AirPods, Kort svar …" (varje rad **två gånger**) | **"Långt svar: 1 tryck. Kort svar: 2 tryck. Paus: 3 tryck."** en gång |
| Svaret i provet | svarstexten, sedan "Långt svar" | **"Långt svar" först**, sedan texten |
| "Bäst värde" | egen rad efter namnet | i knappen: **"Köp 2 000 krediter för 110 kr, bäst värde"** |
| Tempo | "Tempo, 1,0×" | **"Tempo, normal"** (0,75× = "Tempo, 0,75 gånger"; I takt = "Tempo, Skriv i takt" är rätt) |
| Spelar | "Spelar i AirPods · Astrid" och "7:06 kvar" som två | **en: "Spelar i AirPods med Astrid, 7 minuter kvar"** |

Rätt i dag: "Lägg till material", "Hur länge, 10 minuter", "Röst, Astrid", "Köp 100 krediter för 10,00 kr",
"Köp Veckokort för 79,00 kr", "Blanda röster" (omkopplare), "Historiaprovet, Ljud: 4 av 6 klara", Radera konto.
Ordningen på första skärmen (fält, röst, stil, kostnad, knappar, Spela; sedan Nästa prov) är rätt.

## Största text (AX5)
Långa ord avstavas ("fotosynte-sen", "Biologipro-vet", "prenumera-tioner"). Det gör iOS själv vid AX5 och det är
godtagbart i rubriker och frågan. Kortets text kortas med "…" medan det spelar: rätt, hela texten finns i fältet.

## Övrigt
- **repCreditsSheet** visar fortfarande **"krediter kvar den här månaden"** och fotnoten från Ke71. Enligt kop.md (Ke77) står
  det **"krediter kvar"**. Bilden är tagen medan bladet glider upp, så "textClipped" där är troligen fel larm.
- `repSayText` gav inget resultat på 17 Pro (xcodebuild 143); granskad på SE.

## Nästa
Angela Schrute rättar orden och träffytorna (förslagen i `prompts/queue/angela.md`). Kelly tittar på nästa körning.

## Uppföljning (Angelas körning 4, 44319799570, commit b43a74e, 17 Pro)
- **Träffytorna är rättade:** inga `hitRegion`-fynd kvar (stilraden, länkarna, Fyll på). Kontrastfynden är nere på 0–2
  per skärm. **Verifierat i Xcodes granskning i Simulatorn.**
- **VoiceOver-orden är inte ändrade än** (alla nio punkterna står kvar, t.ex. svarsförklaringen två gånger och
  "Säg i AirPods, textfält"). Väntar på Angela (`prompts/queue/angela.md`).

## Svar från Angela (A148 på main, 53850ae9)
VoiceOver-orden 2–9 gjorda (enligt `reports/2026-11-18-1905-angela-a148-tillganglighet.md` §3); "›" är redan dolt
(XCUI-trädet visar dolda element); grå text är en egen färg med 5,9–7,5:1 (godkänd). Kelly granskar orden i nästa
körning (`angela/a11y-a148-5-*`).

## Granskning av körning 5 (angela/a11y-a148-5-17pro, 44363450625, commit 9b8c9dc)
**Orden är rätt** (VoiceOver-trädet i Simulatorn): "Säg i AirPods" (iOS lägger till textfält), "Kostar 120 krediter",
"Kostar 120 krediter, du har 88. Fyll på" (en knapp), hela texten på Senaste, "Långt svar: …" före svaret,
"Långt svar: 1 tryck. Kort svar: 2 tryck. Paus: 3 tryck." en gång, "Köp 2 000 krediter för 110,00 kr, bäst värde",
"Tempo, normal", "Spelar i AirPods med Astrid, … kvar". **Ke79 är klar.** Två småsaker till Angela:
1. **"8 minuter kvar" när det står 7:07:** avrunda nedåt (7:07 → "7 minuter kvar"); under 1 minut: "under en minut kvar".
2. **Spelar-raden** (den hopslagna) får fyndet "hit area too small" (15 punkter hög): den ska inte vara tryckbar; ta bort
   knappegenskapen från den hopslagna raden, eller gör hela raden minst 44 hög om den ska gå att trycka på.
