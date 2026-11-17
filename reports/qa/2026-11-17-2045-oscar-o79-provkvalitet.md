# O79: provkvalitet på fem nya material (D206, D207), Oscar (moln)

**Resultat:** Svaren stämmer mot materialet, och **inga sakfel** hittades i 66 frågor med korta och långa svar. Högst hälften av frågorna kom från en del i alla fem proven, och foto/OCR-vägen fungerade. Tre fynd till Kevin: **täckningen räknar delar efter längd och inte efter rubrikerna**, så ett avsnitt fick 0 frågor; **nästan likadana frågor** finns i fyra av fem prov; och **varför-frågor får påhittade orsaker** när texten inte ger någon. Ett litet fynd till: årtal skrivs ut med ord med olika mellanrum. Claude 0,224 USD, 0 ElevenLabs (inget save, inget ljud). Actions 44160154026, 19:35–19:37 UTC.

## Hur
- Fem nya material som jag skrev för O79 och som inte finns i någon bank eller i Kevins testdata: `scripts/qa/o79/o79_materials.py`. Varje material har 3–5 delar med rubrik.

  | Material | Ämne | Språk | Form | Tecken | Delar |
  |---|---|---|---|---|---|
  | o79-bi-ekosystem | Biologi | svenska | text | 1 519 | 4 |
  | o79-en-printing | Engelska | engelska | text | 1 687 | 4 |
  | o79-fy-ljud | Fysik | svenska | text | 1 072 | 3 |
  | o79-hi-vasa-foto | Historia | svenska | **foto** (3 sidor, Pillow-foto som i banken, OCR i `exam drill`) | 1 171 | 3 |
  | o79-sh-inflation | Samhällskunskap | svenska | text | 1 925 | 5 |

- Appens väg utan ljud: `exam drill` och sedan `drill_answers`, ett nytt testkonto per material, inget `save`. Skriptet är `scripts/qa/o79_quality.py`. Skriptet räknar frågor per del (TF-IDF) och nästan lika frågor. Jag läste sedan alla 66 frågor med korta och långa svar mot materialet.

## Siffrorna (**verifierat live**)

| Material | Frågor | Per del | Störst andel | Delar utan fråga | Förståelsefrågor (varför/hur/why/how) | Nästan lika (mina ögon) | USD |
|---|---|---|---|---|---|---|---|
| ekosystem | 12 | 3 / 3 / 3 / 3 | 0,25 | 0 | 7/12 | 2, 3 och 4 (samma fakta om en tiondel av energin) | 0,047 |
| printing (en) | 14 | 4 / 4 / 3 / 3 | 0,29 | 0 | 11/14 | 6 och 8 (och delvis 1) | 0,035 |
| ljud | 12 | 3 / 5 / 4 | 0,42 | 0 | 9/12 | 2 och 3 (gitarrsträngen och luften) | 0,047 |
| Vasa (foto) | 14 | 5 / 6 / 3 | 0,43 | 0 | 10/14 | – | 0,049 |
| inflation | 14 | 4 / 3 / 3 / 4 / **0** | 0,29 | **1 (del 5, "2022 och efteråt")** | 11/14 | 6 och 14 (köpkraft), 11 och 13 (fast inkomst/fast pension) | 0,046 |

Kraven, punkt för punkt:
- **Högst hälften från en del:** uppfyllt i alla fem.
- **Täckning över hela materialet:** inte uppfyllt för inflation. Del 5 fick inga frågor, och KPI/SCB i del 1 fick inte heller någon. Övriga fyra material täcks helt.
- **Inga upprepade frågor:** inte uppfyllt. Det finns 5 par i 4 av 5 prov (se fynd 2).
- **Korrekta svar:** uppfyllt. Årtal, siffror och namn stämmer: 1520, 1523 och Strängnäs, Västerås 1527, 1541, 1542–1543, 1544, 2 procent KPIF, 340 m/s, 20–20 000 Hz, 85 dB, 200 städer inom 50 år och Luther 1517. Utökningar som "ljus, vatten och koldioxid" och "omkring 1 400 m/s i vatten" är rätt.
- **Frågor som testar förståelse:** till största delen uppfyllt, med 48 av 66 varför-, hur- och why-frågor. Men se fynd 3.
- **OCR:** fotovägen fungerade. Svaren innehåller detaljer som bara finns på fotona, som Strängnäs, Lübeck, 1541 och Dackefejden 1542–1543. Svaret på `exam drill` har inget fält med OCR-texten, så jag kunde inte jämföra den tecken för tecken (**otestat**).

## Fynd (till kevin.md)

**F1 (medel): täckningen delar texten efter längd, inte efter rubrikerna, så ett avsnitt kan bli utan frågor.** `partCount` ger 1 del per cirka 1 200 tecken (`exam/coverage.ts:19`), och `splitParts` delar på längd (**verifierat i kod**). Servern rapporterade `coverage.parts: 2` för inflation (1 925 tecken, 5 rubriker) och för printing (1 687 tecken, 4 rubriker). Inflationens sista avsnitt "2022 och efteråt" (cirka 330 tecken) låg i serverns del 2, som redan hade frågor, så det räknades som täckt fast det fick 0 av 14 frågor. Samtidigt fick del 4 (vem vinner och förlorar) 4 frågor, varav två är samma fråga. Förslag: när texten har rubriker eller tydliga stycken, använd dem som delar (minst en fråga per rubrikavsnitt när antalet frågor räcker), och dela på längd bara som reserv.

**F2 (medel): nästan likadana frågor slinker igenom.** `nearDuplicate` (75 % gemensamma ordstammar) fångar inte omskrivningar:
- inflation 6 "Hur påverkar inflation hushållens köpkraft?" och 14 "Vad händer med köpkraften när inflationen stiger?", som har nästan samma svar
- inflation 11 "Varför får personer med fasta inkomster det sämre när inflationen stiger?" och 13 "Varför får personer med fast pension det sämre när priserna stiger?"
- printing 6 "Why was it difficult for most people to learn to read before the printing press?" och 8 "Why did most people in Europe have little reason to learn to read before printing?"
- ljud 2 "Hur sprids ett ljud genom luften från en gitarrsträng?" och 3 "Vad händer med luften omkring en svängande gitarrsträng?"
- ekosystem 2, 3 och 4, där alla tre svaras med "bara ungefär en tiondel av energin följer med"

Förslag: jämför också de korta svaren (samma svar betyder samma fråga), eller be modellen i samma anrop slå ihop frågor med samma svar.

**F3 (låg–medel): varför-frågor där texten inte ger orsaken får påhittade orsaker.** Exempel ur Vasa-provet:
- 3 "Varför fick Gustav Vasa med sig bönder i sitt uppror?" fick svaret "de, liksom han, var missnöjda med danskarnas styre". Det står inte i texten.
- 14 "...varför infördes det?" fick "för att göra makten säker för Gustav Vasas släkt". Det står inte heller i texten.
- 7 "Varför hade kronan stora skulder till Lübeck" fick "kriget mot Danmark". Texten säger bara "efter kriget".
- 1 "Varför dog omkring åttio svenska adelsmän …?" besvaras med vem som lät avrätta dem, inte varför.

Svaren är rimliga historiskt men står inte i materialet. I ett övningsprov lär eleven sig då saker som läraren inte gett, och fel orsak kan smyga in i andra ämnen. Förslag: ställ varför-frågor bara när texten anger orsaken; annars en hur- eller vad-fråga.

**F4 (låg): årtal skrivs med ord och med olika mellanrum** i de skrivna svaren: "femton hundra tjugosju" och "femtonhundratjugosju", "femton hundra fyrtioett" och "femtonhundrafyrtioett". På svenska skrivs räkneord ihop. Om svaren ska visas som text är siffror (1527) lättare att läsa. Rösttexten (D196) gör ändå orden.

## Inte testat
- Svaren i appen och uppläsningen (0 ElevenLabs, inget save).
- Längre material (över 2 000 tecken). De fem är 1 072–1 925 tecken. O74 täckte längre material.
- `summary.grade` kom tomt och `questions_possible` null i alla fem. Jag har inte kontrollerat om det är avsikten.

## Kostnad
Claude 0,224 USD (5 × exam drill + drill_answers). ElevenLabs 0.
