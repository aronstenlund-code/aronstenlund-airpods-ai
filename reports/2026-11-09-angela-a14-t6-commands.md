# A14 – Tobys T6-fynd, röstkommandon (Angela, 2026-11-09)

Kort: alla sex punkter är gjorda i den ordning Deangelo bad om. Grönt i CI (körning 42690189387). **Ej verifierat på
enhet.** Toby kör om T6.

## Vad som ändrades
1. **"Lumen" är bara tilltal i början.** Namnet räknas bara som tilltal:
   - först i yttrandet;
   - efter ett meningsslut ("Ja precis. Lumen, …");
   - efter en hälsning ensam ("Hej Lumen", "Okej Lumen").
   "Jag berättade om Lumen för min kompis igår" ger ingen instruktion längre (Tobys 5 falska träffar).
2. **Ett ensamt "Lumen."-segment.** Appen väntar på nästa segment i upp till 4 s och läser det som "Lumen, …".
   - Loggen säger "Name alone: waiting for the command".
   - Provlägets tur töms, så "Lumen." blir ingen egen tur.
3. **Tolerant matchning för nivå 1** (gäller hela yttrandet):
   - verbändelserna -ar, -er, -a och -e tas bort, så "skippar låten" = "skippa låten" och "pausar musiken" =
     "pausa musiken";
   - "by till" läses som "byt till";
   - en bokstav fel godtas för fraser med minst två ord och 8 tecken ("Föra låten" = "förra låten");
   - enskilda ord måste stämma exakt, så "kortare" kan aldrig bli "högre";
   - om två åtgärder ligger lika nära blir det ingenting;
   - klagomålen ingår inte ("det var fem" ligger en bokstav från "det var fel").
4. **Keyterms till Scribe:**
   - Provläge och Frågor: "kortare", "upprepa", "viska", "högre".
   - Socialt och Rizz: "rizz", "cringe", "flirtig", "flirtigare".
   - De läggs efter provets termer och före resten.
5. **A10:s tvingade slutresultat** körs nu bara när andras tal har tystats inom 1,5 s, och först 0,4 s efter lägets
   paus.
   - Förut kom det 38 gånger i Frågor, även i ett tyst rum, där Scribe själv hör pausen. Det kapade troligen sista
     ordet (**untested assumption**, som Toby skrev).
6. **Loggrad för namnlösa musikkommandon:** "Voice: music nextTrack (unnamed)". Kommandot räknas också som använt för
   tipsen.

## Tester (`LumenTests/A14Tests.swift`, gröna i 42690189387)
- **Namnet mitt i en mening** (4 meningar) ger ingen intent. Hälsning och meningsslut fungerar.
- **Felhörda former** fungerar: "skippar låten", "pausar musiken", "Föra låten", "by till provläge".
- **Korta ord sträcks aldrig:** "kortar" ger ingenting, och inte heller "hoppa där".
- **0 falska träffar** på 11 vanliga meningar nära kommandona:
  - "hörde du låten", "förra veckan", "spelar roll", "det var fem" …
- **Ett ensamt "Lumen."** + "Spara det." blir kommandot spara.
- A6- och A7-testerna med negativa fall är fortfarande gröna.

## Till Toby
Kör om T6. Förväntat:
- 0 falska träffar på "Lumen" mitt i en mening;
- "Lumen." följt av kommandot fungerar;
- "skippar låten" och "by till provläge" fungerar;
- färre A10-rader i ett tyst rum.

## Kvar
- **429 i Socialt och Rizz** (fynd 7) är Kevins och Oscars att avgöra.
- **Om keytermerna hjälper** de korta orden är **untested assumption**, tills T6 körts igen.

## Concerns
Inga.
