# A165 (D263): Spela in själv – helt gratis, vyerna

Angela Fable (moln), 2026-11-26. Beställt av Deangelo 08:46 (Aron 08:24). iOS-appen på main. Kärnan är Angela
Schrutes (A164), designunderlaget Kellys (Ke89, `docs/design/spela-in-sjalv.md`).

## Vad som är gjort

1. **Ingången på Start.** En rad i kortet under proven: mikrofonsymbolen, **Spela in själv**, kapseln **Helt gratis**
   och raden "Skriv frågor och svar och läs in dem med din röst." Utan prov står "Spela in själv – helt gratis" som
   en knapp direkt under Nytt prov. Ett tryck öppnar skärmen för en ny samling direkt, med första kortet att skriva i.
2. **Skärmen för en samling** (ett blad, Klar stänger): fältet Namn ("T.ex. Glosor vecka 12"), ett kort per fråga
   med **Fråga** och **Svar** och under vart och ett sin inspelning: **● Spela in** och "Inte inspelad"; medan det
   spelas in röd punkt, tiden som räknar upp, nivån och **Stoppa**; sedan **▶ 0:04** och **↻ Spela in igen**. Svep åt
   vänster: **Ta bort**. **Lägg till fråga** under korten. Längst ner den enda fyllda knappen, **Öva**, med "Helt
   gratis. Ljudet stannar på din telefon." under. Innan iOS har frågat om mikrofonen står "Mikrofonen används bara
   medan du spelar in."
3. **Allt sparas medan man skriver.** Det som aldrig fylldes i städas när skärmen stängs: tomma kort tas bort, och
   en samling utan kort som aldrig fick ett namn tas bort helt, så ett tryck på ingången lämnar inget skräp.
4. **Egna samlingar ligger bland proven** under Andra prov, med raden "Egen inspelning · 5 frågor". Raden öppnar
   samlingen, ▶ övar den direkt. Har man inga prov men egna samlingar visas listan (inte tomläget), och Nytt prov
   finns kvar i raden längst ner.
5. **Öva** går genom samma spelare och samma spelarskärm som ett sparat prov (`RepetitionModel.start(own:)`, kärnan).
   Spelarskärmens huvud säger **Egen inspelning** i stället för provets namn.
6. **Bladet när servern säger nej.** Vid serverns nej för krediter (402) eller när modellen är nere (`provider_*`)
   kommer ett halvhögt blad: **Slut på krediter?** respektive **Kan inte skapa prov just nu?**, texten "Spela in
   dina egna frågor och svar – helt gratis.", den fyllda knappen **Spela in själv** och **Inte nu**. Det stängs med
   ett tryck eller ett drag. **En gång per tillfälle:** har bladet visats för ett skäl kommer det inte igen för det
   skälet förrän servern har sagt ja emellan (påfyllning, ny månad, modellen svarar igen). Knappen öppnar en ny
   samling. Bladet kommer där användaren är: på Start, eller över Nytt prov (som då stängs när man väljer knappen).
7. **Svenska och engelska** enligt Kellys tabell ("Record it yourself", "Completely free", "Your recording",
   "Practice", "Out of credits?", "Can't create quizzes right now?" …).
8. **Kellys ändring i A160** (2026-11-26): raden när telefonen rättar säger nu "Rättat på telefonen: Rätt." /
   "Checked on your phone: Right." i stället för "Telefonens modell: …".

## Teknik

- `Lumen/Core/Repetition/OwnDecks.swift` (ny): `OwnDeckOffer` (bladet, en gång per tillfälle), `OwnDeckTidy`
  (`newDeck`, `afterEditing`, namnfältets förval "Mina frågor" / "My questions" som räknas som "inte namngiven"),
  `OwnDeckText` (alla ord), `OwnCard.isBlank`.
- `Lumen/Features/Repetition/OwnDeckViews.swift` (ny): `OwnDeckEntryRow`, `OwnFreeCapsule`, `OwnDeckView`,
  `OwnTakeRow`, `OwnDeckOfferSheet`, `OwnDeckOfferPresenter`, `OwnDeckOnStart` (Starts blad för samlingen och
  bladet om den fria vägen i en modifierare; Starts `body` blev annars för stor för kompilatorn).
- `RepetitionModel`: `ownOffer`, `serverRefused(_:)`. Servern noteras på fyra ställen: Nytt prov (`make`:
  `.modelDown` och `.tooFewCredits`), Läs upp texten (`readText`), Starta prov och Säg i AirPods (`startAudio`:
  `quota_exceeded` eller `provider_*`) och sparandet i bakgrunden (`prepareAudio`). Ett lyckat anrop avslutar
  tillfället.
- `RepetitionHomeSection`: raden, `ownDeckRow`, `hasList` (listan visas när det finns prov eller egna samlingar),
  `otherExams` utbruten. `NewDrillView`: bladet visas över Nytt prov och knappen stänger Nytt prov.
  `RepetitionPlayerView`: "Egen inspelning" i huvudet när spelarens `Drill` är en samling.
- **Öva startas först när samlingens blad har stängts** (bladets `onDismiss`): spelaren är ett helskärmsblad från
  appens rot och kan inte komma upp medan ett blad från Start ligger kvar.
- Identifierare för Toby (T58): `home.ownDecks`, `home.ownDeck`, `ownDeck.name`, `ownDeck.addCard`, `ownDeck.done`,
  `ownDeck.practise`, `ownCard.question`, `ownCard.answer`, `ownCard.recordQuestion` / `ownCard.recordAnswer`
  (med `.stop` och `.play`), `ownDecks.offer`, `ownDecks.offer.open`.
- Bildscener: `repOwnHome`, `repOwnHomeFirst`, `repOwnHomeEmpty`, `repOwnDeck`, `repOwnDeckNew`, `repOwnRecording`,
  `repOwnOffer`, `repOwnOfferDown`. De bygger den riktiga kärnan i en egen tillfällig mapp, med tyst röst, tysta
  filer för det som är "inspelat" (`stageRecorded`) och en inspelare som inte spelar in. **Alla Start-scener har nu
  kärnan** (tom), så raden Spela in själv syns på dem som i appen.

## Vägen dit (för den som undrar över historiken på grenen)

Jag började, som beställt, mot ett eget protokoll innan kärnan fanns. Kellys underlag och Angela Schrutes
gränssnitt kom en halvtimme senare och skilde sig från mitt (en skärm i stället för lista + redigerare; hennes
typer i stället för mina). Jag skrev om vyerna efter underlaget och byggde mot en låtsasvariant med hennes exakta
signaturer på min gren tills kärnan låg på main; därefter togs låtsasvarianten bort. Inget av det mellanliggande
har legat på main.

## Test

RADER_TEST

## Val jag har gjort (säg till om något ska vara annorlunda)

- **Öva tar alla kort med fråga och svar; det som inte är inspelat läses av telefonens röst.** Det är vad A164
  säger. Kellys underlag säger att Öva bara ska gå när minst en fråga är inspelad och hoppa över kort utan
  inspelad fråga. Kärnan kan båda (`onlyRecorded`); Angela Schrute har bett Deangelo och Kelly bestämma. Byte är en
  rad i vyn.
- **Bladets rubrik när modellen är nere** är Kellys "Kan inte skapa prov just nu?". Bladet kommer också när en
  uppläsning eller ett ljud inte kan göras av samma skäl; rubriken säger då "prov" fast det gällde en text. Jag
  har inte lagt till en tredje rubrik.
- **Ingången ligger under Andra prov** (Kellys plats). Med tre prov eller fler hamnar den under skärmens kant och
  syns först när man rullar. Utan prov står den direkt under Nytt prov.
- **Namnet.** En samling föds med namnet "Mina frågor" (fältet visar platshållaren). Kärnans egen reserv "Egen
  inspelning" hade gett raden "Egen inspelning / Egen inspelning · 3 frågor" på Start.
- Bladet kommer inte för nej i hjälpchatten eller i Fler lägen (provsessionen); bara i repetitionen.

## Kända brister och risker

- **Inget är provat på telefon.** Mikrofonen, AirPods-mikrofonen, uppspelningen och övningen i AirPods är kärnans
  och måste provas på en riktig iPhone med AirPods (CLAUDE.md). Mina bilder visar vyerna med tysta filer.
- Bilderna är tagna i Simulator, där iOS inte har frågat om mikrofonen: raden "Mikrofonen används bara medan du
  spelar in." syns därför på alla bilder av samlingen. På en telefon som redan har svarat syns den inte.
- Två blad efter varandra (bladet → ny samling) bygger på att det andra öppnas i det förstas `onDismiss`. Verifierat
  i kod, inte på bild eller telefon (**otestat antagande** att övergången ser lugn ut).
- Demodata på bilderna är svenska också på de engelska bilderna (som i övriga scener; Kelly har bett om engelska
  demodata för App Store-bilderna, Ke90).
- Tobys E2E för A160 (`AppTests/E2E/ModelDown/ModelDownE2ETests.swift` rad 275) väntar på orden "Telefonens modell:
  Rätt." och blir röd tills han byter till "Rättat på telefonen: Rätt." / "Checked on your phone: Right." (rad i
  hans kö).

## Farhågor

Inga nya. Inspelningen följer skyddsräckena: den startar bara på ett tryck, den röda punkten och tiden syns hela
tiden medan mikrofonen är på (utöver iOS egen orange prick), ljudet stannar på telefonen och inget laddas upp.
Inget i vyerna döljer att appen spelar in.

## Kvar / nästa session

- Prov på telefon med AirPods: spela in fråga och svar, lyssna, öva, lås telefonen under övningen.
- Deangelos/Kellys besked om `onlyRecorded`.
- Kellys Ke90: engelska demodata i repetitionsscenerna (inte påbörjat); scenen för App Store-bild 10 finns
  (`repOwnDeck`).
