# A8 – BLOCKER: Frågor svarar inte på frågor (Angela, 2026-11-09)

Kort: jag hittade fyra vägar där appen tyst kastade en fråga i Frågor och tog bort alla fyra. Provläge delar nu upp
flera frågor i ett andetag i egna turer. Scribe tar inte längre emot keyterms över 20 tecken. Diagnostik-exporten har
en rad per tur. Grönt i CI (körning 42647623603). **Inget är verifierat på enhet.**

## Vad som var fel (från koden, inte från Arons logg)
Backendloggen visar 7 `not_question` och sedan 4 `ok` som troligen inte lästes upp. Fyra vägar i appen förklarar det:

1. **5 s-spärren kastade frågan.**
   - Före: en fråga mindre än 5 s efter förra auto-frågan kastades tyst (`cooldown`), även när förra var ett
     `not_question`.
   - Arons mönster: halva frågan → `not_question`, ny fråga 2–4 s senare → kastad.
   - Ett `ok`-svar i förväg (D80) slängdes också då ("no question when the pause came"). Det passar med de 4 `ok`
     som aldrig hördes.
2. **Röstprofilen (D81): "Auto svarar aldrig bäraren".**
   - Har Aron gjort "Lär dig min röst" svarar Frågor aldrig på hans egna frågor.
   - Svar i förväg gick ändå till backend innan rösten var känd, och kastades sedan.
   - **Untested assumption:** att Aron har en röstprofil. Exporten visar det nästa gång.
3. **Halva meningar.**
   - Scribe committar vid en andningspaus. Första halvan ("vilka är de största") går iväg och får `not_question`.
   - Resten ("bergen i världen") är ingen fråga för grinden och kastades.
4. **Fråga medan Lumen pratar eller timern slår.** En väntande fråga raderades om Lumen pratade när den var klar.

## Vad som ändrades (A8 i DECISIONS)
- **Ingen tyst kastning i Frågor.**
  - Inom 5 s-spärren väntar frågan tills spärren gått ut.
  - Medan Lumen pratar väntar den till svaret är slut.
- **Fortsättningar (punkt 2).**
  - Villkor: orden kommer inom 5 s, är ingen fråga själva, och frågan före har inte fått något svar än.
  - Då skickas hela frågan ("vilka är de största bergen i världen").
  - En väntande fråga som fortsätter skickas hel, och backend avgör.
- **Röstprofilen styr inte längre Frågor.**
  - Bärarens egna frågor besvaras. Detta ändrar D81 för Frågor.
  - Intervju, Socialt och Rizz behåller D81.
- **Flera frågor i ett andetag (punkt 4).** `QuestionSplitter` delar ett yttrande:
  - vid `?`, `!` och `.`;
  - före ett frågeord som börjar en ny fråga, men inte efter "förklara", "vet du", "undrar", "och", "att" …, och
    aldrig vid "var", "när" eller "vilket";
  - före ett stående önskemål: "i framtiden", "kom ihåg att", "från och med nu", "fortsätt att" …
  - Varje del har minst 3 ord.
  - Arons block blir tre turer: "vilka är de största bergen i världen" / "fortsätt att du i framtiden … det är
    minnet" / "vad är 250×250".
  - I Provläge skickas varje del som en egen tur, en i taget.
  - I Frågor ställs de frågor som går igenom grinden en i taget. Önskemålet är ingen fråga där och syns som
    "dropped" i exporten.
- **Scribe-keyterms (punkt 5).**
  - Varje term delas i hela ord upp till 20 tecken: "Kristendomens införande" → "Kristendomens", "införande".
  - Utfyllnadsord ("och", "av" …) tas bort, och ett ensamt längre ord kortas till 20 tecken.
  - Dubbletter tas bort, och högst 20 termer skickas.
  - Det sker på ett enda ställe (`ScribeToken.url`), så ingen väg kan skicka en för lång term.
  - Stänger Scribe ändå sessionen (`invalid_request`/1008, eller direkt med keyterms) öppnas den en gång utan
    keyterms i stället för att byta till iPhonens igenkänning.
- **Diagnostik-exporten (punkt 3).** Ny tabell "Turns" med en rad per tur och dessa kolumner:
  - tid, läge, trigger, i förväg ja/nej;
  - `fragment`, `is_question`, status (`ok`/`not_question`/`retract`/fel);
  - utfall (answered / silent / discarded / dropped / failed / interrupted), varför, och slutet av `transcript` som
    skickades.
  - Det räcker att Aron exporterar nästa gång.
- **Ord som sägs medan Scribe kopplar upp (Tobys fynd 1).**
  - Före: ljudet före token och websocket gick förlorat.
  - Nu prenumererar `TranscriptionCoordinator` på ljudet innan den hämtar token. Det som sägs under uppkopplingen
    väntar i strömmen (upp till 10 s) och skickas när Scribe är öppen.
  - Det gäller också vid återanslutning.
  - En fråga direkt vid Start, eller efter "Hej Siri, starta Lumen", ska därför höras.
  - **Untested assumption** tills Tobys `theFirstWordsRightAfterStartAreHeard` har körts igen.
- **Även:** `asked` rapporteras nu på svar-i-förväg-vägen (Tobys T1 fynd 3), och `AppTests/**` och
  `apptest-*.yml` startar inte iOS-bygget (Tobys önskemål).

## Före och efter
| Mätning | Före | Efter |
|---|---|---|
| Arons telefontest (Deangelos backendlogg) | 11 anrop, 0 svar hörda | **ej testat på enhet** |
| Tobys kedjetest i simulatorn, Frågor (`say`-röst, 4 s tystnad) | 5 av 5 frågor, 0 påståenden besvarade (T1, 42505228884) | 5 av 5 frågor, 0 påståenden besvarade (42651010939) |
| Tobys kedjetest, Provläge | 4 av 4 | 4 av 4, på svenska |
| Tobys kedjetest, `asked` på svar i förväg | 0 av 9 | 9 av 9 rapporterade |
| Tobys kedjetest, fråga direkt vid start | 0 av 1 (hörde "Tack.") | 0 av 1 i 42651010939 (hörde "Ja."); rättat efter körningen, se nedan |
| Enhetstest: fråga inom 5 s | kastad | ställs när spärren gått ut |
| Enhetstest: "vilka är de största" + "bergen i världen" | halvan skickad, resten kastad | hela frågan skickad och besvarad |
| Enhetstest: Arons block | 1 tur | 3 delar, 2 frågor ställda |
| Enhetstest: keyterm "Kristendomens införande" | skickad, Scribe stänger | "Kristendomens" + "införande" |

Tobys kedjetest återskapar inte Arons fel: tydliga frågor med tystnad emellan, ingen röstprofil, rösten av. Siffran
visar bara att inget gått sönder. Skillnaden mot telefonen är just paus mitt i frågan, frågor tätt efter varandra och
röstprofilen.

## Tester
- Nya: `LumenTests/A8Tests.swift` (splitter, turtabell, Frågor-flödet), `ScribeKeytermTests`, refusal-testet i
  `ScribeFallbackTests` och fyra nya fall i `ActivationControllerTests`.
- Ändrade: 5 s-testet, "fortsätter → skickas hel" och D81-testet, som nu kräver att bäraren får svar.
- Alla gröna i CI-körning 42647623603 (iOS 26.5-simulator). **Verified in CI only.**

## Kända risker
- **Uppdelningen kan dela fel.** Exempel: "det är intressant hur …" blir två turer. Konjunktioner och "som/var/när"
  delar inte, men det är regler och inte förståelse. Oftast blir det en extra fråga, inte en tappad.
- **Fortsättningar kan ersätta ett svar.** Säger någon något annat inom 5 s efter en fråga som inte har fått svar, går
  frågan och orden iväg tillsammans. Backend avgör, och det kostar ett extra anrop.
- **Frågor svarar nu bäraren.** Den som pratar mycket själv i ett klassrum får fler svar. Det står kvar som en fråga
  till Deangelo/Aron om det ska bli en inställning.
- Röstfunktionerna är **ej verifierade på enhet**.

## Till Toby
Lägg gärna in tre fall i `cases.tsv`/`chain.sh`, för de återskapar Arons fel:
1. En fråga med 1,2 s paus mitt i ("Vilka är de största … bergen i världen?").
2. Två frågor med 2 s mellanrum.
3. Arons Provläge-block i ett svep: fråga, önskemål, fråga.

Kör också med en röstprofil om det går, och läs den nya tabellen "Turns" i exporten (`controller.turns`).

## Concerns
Att Frågor svarar bärarens röst är ett ägarkrav, men det ändrar D81. Deangelo får bekräfta det i nästa uppdrag.

## Nästa
- Aron: telefontest i Frågor med 5 frågor, gärna med en paus mitt i och två tätt efter varandra. Exportera sedan
  Diagnostik.
- Jag: A6.
