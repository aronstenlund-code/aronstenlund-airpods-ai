# T9: Skärmrunda efter A18 och A22 (Toby, 2026-11-10 17:10)

**Allt här kommer från simulatorn (iOS 26.5, iPhone 17 Pro och iPhone SE 3) och är aldrig verifierat på en enhet.** Inga
AirPods och ingen riktig telefon. Inget ljud: ElevenLabs-kvoten är slut, så Scribe svarar `quota_exceeded`.

## Vad som kördes
Det blev två körningar med samma sju lägen som T3: Pro ljust och mörkt, Pro med största text i ljust och mörkt, SE
ljust och mörkt, samt Pro ljust med mikrofonen nekad.

| Körning | Appens kod | Resultat |
|---|---|---|
| [42813110549](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42813110549) | main med A18, A22 och A25, före A33, A35, A37, A41 och A42 | **6 av 7 gröna**, 0 missar. "Pro ljust, största text" föll i turen (ett tryck på "Röstkommandon" missade, och det är rättat i turen) |
| [42825475351](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42825475351) | main `f557d2a` (A33, A35, A37, A40, A41, A42) | **0 av 7 gröna**. Allt rött berodde på turen, se nedan. "Pro ljust" fick ingen simulator i CI (`Unable to find a device`) |

Turens röda punkter i den andra körningen, och hur de är rättade:
- **"Rizz 18+" hittades inte.** A35 tog bort 18+, och raden heter nu "Rizz". Turen söker nu efter båda namnen.
- **"Bara fråga" och "Få A-svar till provet" öppnade inte Lyssnar.** Efter A33 går första startens Frågor-session
  vidare bakom Start. T8 såg det på samma bygge: "a Frågor session is still on (Lyssnar) after the first start". Turen
  avslutar nu den sessionen först. **Oklart om det också är ett appfel:** knappen ger ingen respons medan en session
  går (bild 10). Det står under "Till Angela".
- **Inställningsraden "Studiekort" hittades inte** på SE. Raden finns i koden, så det är troligen rullningen i
  turen. **Untested assumption.**

Rättningarna ligger på grenen `toby/t9b-screens`. De mergas till main med den här rapporten. En kort körning på push
startades 17:06, men fullrundan om 80 minuter hinns inte före 18:00. **Nästa session kör fullrundan på main** och
lägger till bilderna efter Rizz.

**Obs:** Angelas A47 (`eab30d1`) kom efter båda körningarna och gör om "Lägg till prov" från Start till det korta
formuläret. Fynden om det arket (nytt fynd 4 och T3:7 för Lägg till prov) ska därför kontrolleras igen i nästa runda.

## T3:s tolv fynd, nu
| T3 | Nu | Bild |
|---|---|---|
| 1 Rizz-åldersgränsen kapad | **Rättat** (SE och största text visar hela texten). Efter A35 finns ingen spärr alls | 14 |
| 2 SE: samtyckespunkterna syns inte | **Rättat** för punkterna. Men efter A41:s fjärde punkt ligger "Läs mer" halvt under Testa nu igen på SE | 04 |
| 3 Mikrofon nekad: Frågor och Provläge gör inget | **Rättat.** Start visar det röda kortet "Lumen hör dig inte" med "Öppna Inställningar", och båda lägena visar det | 13 |
| 4 Största text kapar ord | **Delvis.** Pausa och Avsluta rättade. Kvar: dela-frågan ("förbättra Lu…", "Lumens svar…"), ämneschipsen "Mat…", "Spr…", "Pra…", "Ann…" | 03, 06 |
| 5 Ord bryts mitt i | **Kvar, nya ställen:** "NÄ / STA / PR / OV", "Biologiprove / t", "Komman / don", "Röstkomman / don", och "Datum" en bokstav per rad | 07, 08, 09 |
| 6 Språkväljaren växer inte | Ej kontrollerad i dag | – |
| 7 Nederkanten täcker innehåll | **Kvar:** Intervju och Socialt vid största text. Lägg till prov: "Spara prov" täcker Datum, och på SE syns Datum inte alls | 05, 12 |
| 8 Mörkt läge | Fortfarande bra, ingen oläsbar text | – |
| 9 Dela historik, kontrast i mörkt | Oförändrat, inte uppmätt | – |
| 10 Läs mer under Testa nu | Se 2: tillbaka på SE efter A41 | 04 |
| 11 Provläge-raden utan provets namn | **Kvar** ("Pluggar till provet" i Byt läge och Fler lägen) | 11 |
| 12 Standardstil i Läs mer och Inställningar | Oförändrat (Kellys beslut) | – |

## Nya fynd (simulator)
1. **Första frågan vid största text har inget lyssnarkort** (bild 01). Rubrik, text och "Hoppa över" syns, men inte
   kortet med "Lyssnar" som syns på alla andra storlekar. **Viktigt:** CLAUDE.md kräver att man alltid ser när appen
   lyssnar. Om kortet bara ligger utanför bilden är det inte bevisat. **Untested assumption.**
2. **På SE ljust visar första frågan "Pausad" och "Lyssna igen"** i stället för "Lyssnar" (bild 02, A33-bygget). Pro
   visade "Lyssnar". Det kan bero på simulatorn och den uteblivna Scribe-kvoten. **Untested assumption.**
3. **Provsteget vid första start står kvar på "Startar …"** så fort taligenkänningen inte kommer igång. Det syns med
   mikrofonen nekad och på A33-bygget. Ingen text säger att Lumen inte hör.
4. **"Lägg till prov" från Start väljer fortfarande NO och Biologi i förväg** (bild 05). Första startens formulär
   väljer inget (A22, rätt). Samma val ger alltså "Biologiprovet" från Start och "Noprovet" vid första start (T8b).
5. **Röstkommandon blandar svenska och engelska** fraser i listan ("quiz me", "tell me more"). Det är kanske avsiktligt,
   men en svensk elev läser det som ett fel.
6. **SE: Byt läge och Fler lägen** visar inte Rizz utan att man rullar. Arket stannar på halv höjd.

## T8b del 1 och svaren
- **A25 håller:** "Lyssnar" syns 0,5 s (hoppa över) och 1,0 s (prov) efter mikrofonfrågan, på A33-bygget (körning
  [42825446414](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/42825446414)).
- Provläge lyssnar efter 9 tryck (prov) och 13 tryck (hoppa över).
- **Inga svar kom, varken i Frågor eller i Provläge.** Skärmen visar "Jag hör inte just nu / Taligenkänningen gick
  ner", och båda vägarna blev röda på grund av det. Orsaken är kvoten, inte appen. **Untested assumption** tills
  kvoten är tillbaka.
- **"Noprovet" finns kvar på A33-bygget** (bild från T8: "Noprovet, Provläge, tis 17 nov").

## T5b och T7b
De står fortfarande. Båda kräver Scribe, och kvoten är slut (`quota_exceeded` / HTTP 429 i dag). Inget nytt test
körts sedan förmiddagen.

## Till Angela
- **Fynd 1:** lyssnarkortet saknas vid största text på första frågan. Det gäller riktlinjen om synlig lyssning.
- Dela-frågans text kapas vid största text. Det är samtyckestext, så den måste gå att läsa i sin helhet.
- Ord bryts mitt i (Datum, NÄSTA PROV, Kommandon, Röstkommandon) och chips kapas. `minimumScaleFactor` eller radbrytning
  per ord skulle räcka. **Untested assumption.**
- "Spara prov" täcker Datum i Lägg till prov från Start, och NO + Biologi är förvalt där.
- **"Noprovet":** ett prov som sparas med bara ämnet NO får namnet "Noprovet".
- Efter första starten går Frågor-sessionen vidare bakom Start, och "Bara fråga" ger då ingen respons. Visa bannern
  tydligt, eller låt knappen byta läge.

## Till Kelly
- "Läs mer" under Testa nu på SE efter den fjärde punkten (bild 04).
- Provläge-raden i Fler lägen och Byt läge säger fortfarande inte provets namn.

## Till Aron
- **ElevenLabs-krediterna** behöver fyllas på för T5b, T7b och svarsdelen av T8b. Det står i STATUS sedan i morse.
- **Ett test på telefonen:** installera om och gå igenom första starten med största text (Inställningar >
  Tillgänglighet > Skärm och textstorlek > Större text). Syns lyssnarkortet?

## Filer
- Turen: `AppTests/E2E/Screens/ScreenTourTests.swift`. Den har nya knappord för A18, A22, A33 och A35, viker ut
  "Avancerat" och gör om missade tryck. Ett nytt steg tar bild på A33:s formulär bakom "Skriv i stället".
- `AppTests/E2E/Screens/FirstUserTests.swift`: provvägen trycker "Skriv i stället".
- `scripts/apptest/screens_index.py`: tar bort `"` och andra otillåtna tecken ur bilagornas filnamn.
- Bilder: `reports/apptest/2026-11-10-t9-skarmbilder/` (halv storlek).
