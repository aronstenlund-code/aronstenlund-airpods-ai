# T49 – Utan nät och dåligt nät (A135, D219) och T52 – A138-grenen

Toby (moln), 2026-11-18 04:45. Simulatorn (iPhone 17, iOS 26, Xcode 26.6), falskt ljud (`LUMEN_TEST_HEADER`), 0 ElevenLabs (D180). **Allt nedan är verifierat i Simulator, inte på enhet.**

## T49: vad som gjordes
- Ny del i T36-testet (`SayFlowTests.swift`): "Utan nät: samma text spelas, en ny säger till efter 10 s (A135)".
  - Nätet stängs av med t36.sh:s nätbrytare (`t36-net-off/on.request`, runnerns nätverkstjänster).
  - Sedan spelas texten som redan har spelats (via kapseln i Senaste), och därefter en ny text.
- `playFromCard` trycker på Försök igen en gång om Spela säger "Ljudet kunde inte hämtas …", och skriver det i loggen.
- T49-raderna kommer med i sammanfattningen från t36.sh.

## T49: resultat (körning 44235040986 på toby/t49, alla elva delar OK)
- **Samma text utan nät:** "Spelar i AirPods · Adam" efter 1,8 s. Ljudet på telefonen räcker.
- **Ny text utan nät:** "Ingen internetanslutning. Försök igen när du är uppkopplad." efter 1,9 s. Knappen heter kvar "Spela i 10 min", och det kommer ingen "Försök igen".
  - Telefonen vet att den är utan nät (NWPathMonitor), så den väntar inte på servern.
  - "Ljudet kunde inte hämtas …" med "Försök igen" är för ett nät som finns men inte svarar.
  - Testet godtar båda. Skillnaden mot uppdraget är skriven till Angela Fable.
- **Senaste:** texten står en gång efter försöken utan nät, alltså inga dubbletter.
- **Nät som finns men inte svarar:** 20 s efter att nätet kom tillbaka sa första Spela "Ljudet kunde inte hämtas. Kolla nätet.", och då fanns "Försök igen". Ett tryck på den spelade texten.
  - Raden är kortare än i uppdraget ("Kolla nätet." i stället för "Kontrollera nätet och försök igen.").
  - Långsamt nät går inte att ställa in på runnern. Snurrans 10 s är därför inte mätt (untested assumption).
- **Ett prov vars ljud har hämtats spelas utan nät:** täcks av T27 ("Utan nät: Starta prov"), som är grön i nattflödet.

## T52 (A138-grenen ea75cd1a = main 634b3f37 plus A138)
Nattflödet 44228343323 med mains tester: alla sex gröna (T24, T27, T28, T29, T30, T36). A138 flyttar testläget, telefonverktygen, den fotade sidan och blädderkorten till egna delar. Inget av dem har ett eget flöde, så det här är en vakt för att resten beter sig som förut.

## Kända saker
- "no cost by Spela" en gång. Kostnaden kommer cirka 0,7 s efter sista tangenten (A132 punkt 8), och testet läser efter 1 s. Inte rött.
- I spelaren finns ingen "Mening N av M", så två tryck kan inte mätas.
- Kapseln går inte ner med x-earmind-test (1500 → 1500). Frågan ligger hos Kevin (T44).

## Nästa session
- T50 (A136/A140: stil, röster, Skriv i takt) och T48 (A134/A141: köp).
