# A148: tillgängligheten på de nya skärmarna (D218 punkt 4, Kellys Ke79)

Angela Schrute (moln, Fable 5.2), 2026-11-18 12:55–19:05. Main, sammanslagning 53850ae9 (grenen
`claude/fervent-fermi-34hrer`, 4a3be488 till 8773b368).

## 1. Hur det granskades
- **XCTests tillgänglighetsgranskning** (samma kontroller som Accessibility Inspector: kontrast, klippt text,
  etiketter, tryckytor, Dynamic Type) på 22 scener: Säg-kortet tomt, med text, med stil, medan det spelar och väntar,
  Senaste, röstbladet, kreditbladet, köpdelen i fem lägen, spelaren för text och för prov, och tre nya scener för
  Radera konto.
- **Två inställningar:** iPhone 17 Pro med standardtext, och iPhone SE med största texten (AX5).
- **Ny körning** `.github/workflows/a11y-pictures.yml` (startas för hand): kör Tobys `scripts/apptest/a11y.sh`,
  skriver ut fynden och VoiceOver-trädet i loggen och skickar bilder, fynd och träd till en egen gren.
  Molnsessionerna kan inte hämta artefakter, så grenen är sättet att se bilderna.
- **Fyra omgångar:** 44298706992 (före), 44304438552, 44319799570 (efter) och en avbruten däremellan.
- Simulator, demodata, inget nät, 0 ElevenLabs. **Inget är provat med VoiceOver på en riktig telefon.**

## 2. Fynd före och efter
| Typ | 17 Pro före | 17 Pro efter | SE AX5 före | SE AX5 efter |
|---|---|---|---|---|
| Kontrast | 114 (5 underkända, 109 "nästan") | 17 (6 + 11) | 12 | 6 |
| Tryckyta under 44 punkter | 15 | 0 | 0 | 0 |
| Text kan klippas | 6 | 6 | 7 | 7 |
| Dynamic Type delvis | 151 | 158 | 73 | 73 |

Första omgången på 17 Pro saknar scenen `repSayText` (körningen avbröts i den), så summorna är inte exakt jämförbara.

**Det som står kvar är inte fel i appen:**
- **Kontrast, 17 Pro:** 6 gäller raden "Prov från din skola", som i bilden ligger bakom den fasta knappraden längst
  ned. 11 är "nästan godkänd" utan angivet element. På SE gäller alla 6 text bakom knappraden.
- **Text kan klippas:** rubriker som bryts på flera rader, kortets förhandsvisning av texten som spelas (tre rader med
  avsikt, ett tryck öppnar spelaren) och sökfältet i röstbladet. Inget är klippt på bilderna jag har sett.
- **Dynamic Type delvis:** texten på Säg-kortet har ett tak (AX1 till AX3) och växer inte hela vägen till AX5. Det är
  Kellys och Angela Fables val för att kortet ska få plats på en liten skärm. **Inte ändrat**; Kelly har bilderna.

## 3. Vad som rättades
**Kontrast**
- **Grå text:** ny färg `LumenColor.secondaryText` (#5C5C63 ljust, #ABABB3 mörkt): 6,6:1 på vitt, 5,9:1 på den
  grupperade bakgrunden och 7,5:1 på de mörka korten. Systemets grå är 3,4:1. Den används för all grå text på Start,
  i röstbladet, kreditbladet, köpdelen, båda spelarna och Radera konto, också sektionsrubriker och fotnoter.
- **Röd text:** `LumenColor.redText` (5,9:1 på vitt) på "Radera konto". Systemets röda är 3,6:1.
- **Spela-knappen när den inte går att trycka på** hade svart text på nedtonad fyllning och gick inte att läsa. Nu
  har den kortets egen textfärg.
- **Platshållarna** "Skriv här" och "Hur ska det låta?" på det mörka kortet: 6:1 (var 3,8:1).
- **Medan kontot raderas** står "Raderar kontot …" som vanlig text med snurra, inte en grå knapp.

**Tryckytor (44 punkter)**
- Villkor, Integritet och Återställ köp i köpdelen (var 16 punkter höga).
- Raden "120 krediter · du har 88 · Fyll på" (var 32).
- Fältet "Hur ska det låta?": själva fältet är en rad högt, men de 44 punkterna runt det tar trycket och sätter
  markören i fältet. Säg-kortet blir cirka 24 punkter högre när stilfältet visas.

**VoiceOver-ord (Kellys Ke79)**
| Kellys punkt | Nu |
|---|---|
| 2. Fältets etikett | "Säg i AirPods" (VoiceOver säger själv "textfält") |
| 3. Kostnaden | "Kostar 120 krediter", "Kostar 120 krediter, du har 88. Fyll på" |
| 4. Senaste-kapslarna | hela texten och dess stil eller röst, inte den avklippta med "…" |
| 5. Tryckraden i provet | en gång, som en mening: "Långt svar: 1 tryck. Kort svar: 2 tryck. Paus: 3 tryck." |
| 6. Svaret i provet | "Långt svar: …" före svarstexten |
| 7. Köpknappen | "Köp 2 000 krediter för 149,00 kr, bäst värde" |
| 8. Tempot | "Tempo, normal" (1,0×), annars "Tempo, 1,25 gånger" |
| 9. Kortet som spelar | en mening: "Spelar i AirPods med Astrid, 7 minuter kvar" |
| Sökvägen till Prenumerationer | läses med komman i stället för pilar |

**Inte ändrat av Kellys punkter, med skäl**
- **Punkt 1, "›" i fältet:** tecknet är redan dolt för VoiceOver i koden. Granskningens träd visar också dolda
  element, och därför syns det där.
- **"krediter kvar den här månaden" i kreditbladet:** med köpdelen står det "krediter kvar", som i kop.md. Scenen
  `repCreditsSheet` har ingen butik och visar därför den äldre raden. Appen har alltid butiken när molnet finns.
- **"Kolla att grå hjälptexter är `.secondary`":** de är nu en egen färg som klarar AA utan att användaren slår på
  Öka kontrast. Vill Kelly hellre ha systemets färg är det en rad att byta tillbaka.

## 4. Testresultat
- **CI:** iOS build 44356376829 grön på 8773b368 (Debug, enhetstester, Release utan testläge). `A148AccessibilityTests` körde och gick igenom. Bygget på main efter sammanslagningen (44362825304) körde när rapporten skrevs. **Verifierat i CI, inte på enhet.**
- **Nya tester** (`A148AccessibilityTests`): orden VoiceOver säger (kostnad, tempo, kapsel, kortet som spelar), och att
  den grå texten, den röda texten och platshållarna klarar 4,5:1 mot de bakgrunder de står på, i ljust och mörkt.
- **Granskningen efter Kellys ord är inte körd.** Sista omgången (44319799570) kördes före dem. Orden är provade i
  enhetstester, inte med VoiceOver.
- 0 ElevenLabs.

## 5. Bilder till Kelly (Ke79)
- **Före:** grenarna `angela/a11y-a148-1-17pro` och `angela/a11y-a148-1-se-ax5`.
- **Efter:** `angela/a11y-a148-4-17pro` och `angela/a11y-a148-4-se-ax5`.
- I varje gren: `a11y-<scen>.png`, `a11y-<scen>.audit.txt` (fynden) och `a11y-<scen>.tree.txt` (VoiceOver-trädet).
- Hämta med `git fetch origin angela/a11y-a148-4-se-ax5` och läs filerna ur `FETCH_HEAD`.

## 6. Kända begränsningar
- **Ingen riktig VoiceOver-körning.** Ordning och etiketter är lästa ur trädet. Hur det låter, och om fokus hamnar
  rätt efter ett blad, kräver en telefon.
- **Varningsrutor och systemets egna knappar** (till exempel rutan "Radera kontot?") har systemets färger.
- **Mörkt läge** är inte granskat i den här omgången; färgerna är räknade för båda men bilderna är ljusa.
- **Angela Fables gren** (A150) ändrar i samma vyfiler. Hon slår ihop main i sin gren och löser konflikterna.

## 7. Vad Aron kan prova på telefon
1. Slå på VoiceOver (Inställningar › Hjälpmedel). Svep igenom Start: varje knapp ska säga vad den gör på svenska.
2. Sätt textstorleken till den största (Hjälpmedel › Skärm och textstorlek › Större text). Start, kreditbladet,
   köpdelen och Inställningar › Konto ska gå att läsa och trycka på utan att något hamnar utanför skärmen.
3. Tryck på Villkor, Integritet och Återställ köp i köpdelen. De ska vara lätta att träffa.

## 8. Kvar
- Kellys granskning av bilderna (Ke79), särskilt taken för textstorlek på Säg-kortet.
- En granskning i mörkt läge, om Deangelo vill ha den.

## Tillägg 23:03: omgång 5 och 6
- **Omgång 5** (44363450625, main 9b8c9dcf, med Kellys ord): Kelly godkände orden. Nytt fynd i fem scener: "för liten
  tryckyta" på de två rader som slogs ihop till en VoiceOver-mening (tryckraden i spelarna, raden på kortet som
  spelar). Kontrasten på 17 Pro var oförändrat 17.
- **Rättat (main eaa7279f):** raderna är märkta som text. VoiceOver säger klockans minuter (7:07 är "7 minuter kvar",
  sista minuten "under en minut kvar").
- **Omgång 6** (44369572808, de fem scenerna): 0 fynd om tryckyta på 17 Pro och på SE med AX5. **Verifierat i
  Simulatorns granskning, inte med VoiceOver på telefon.**

