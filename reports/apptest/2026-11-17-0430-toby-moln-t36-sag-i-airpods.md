# T36 del 1: "Säg i AirPods" (A115) i simulatorn (Toby (moln))

Allt i Simulator (macos-26-arm64, Xcode 26), inte på enhet. Falskt ljud (LUMEN_TEST_HEADER=1), 0 ElevenLabs.

## Vad som är gjort
Testet är `AppTests/E2E/Screens/SayFlowTests.swift` med `scripts/apptest/t36.sh` och `.github/workflows/apptest-t36.yml`, och det ingår nu i nattflödet (T36). Stegen:
1. Första starten till Start.
2. Testet skriver en text i "Säg i AirPods" och ser "78 tecken" och "Räknas som 1 fråga. Upprepningar kostar inget."
3. Spela en gång: spelaren visar "Spelar i AirPods, Mening 1 av 2", eller "Klart · Slut på texten" om den falska uppläsningen redan är klar.
4. Hur länge → Upprepa 5 min → Spela: "Varv 1 · 4:59 kvar av 5 min", sedan varv 2 och senare.
5. Pausa och fortsätta med 1 tryck på AirPods-kroken.
6. Testet tar bort uppläsningen.

## Resultat
**Grön i alla 6 delar** (44009183791, **verifierat i Simulator**).

Under vägen rättade jag fem testfel, inga appfel:
- fältets etikett är "Säg i AirPods, textfält"
- påminnelsebladet efter första uppläsningen (A109) måste besvaras med "Inte nu"
- fältet är tomt efter en uppspelning, och då ger det tillbaka sin platshållartext
- raden med varvet tickar varje sekund och läses därför ur skärmträdet
- med falskt ljud kan uppläsningen vara klar innan testet tittar

## Begränsningar och iakttagelser
- Med falskt ljud saknar meningarna tider. Därför står "Mening 1 av 2" kvar, även efter "Slut på texten". Varven går på ungefär en sekund ("Varv 11", "Varv 21" efter 16 s). 2 tryck flyttar inte någon synlig plats. Inga appfel, D188.
- Testet förkortar inte tiden: upprepningen visas medan den går, men de fem minuterna löper inte ut i testet.
- Del 2 återstår, se nästa avsnitt.

## Nästa (del 2, A116–A118)
- Menyn bakom "+" i Säg-fältet (Fota sidor, Välj bilder, Lägg till fil, Klistra in länk).
- "Klistra in länk" i Nytt prov.
- Kapseln "N frågor kvar" och raden "Räknas som n av dina m frågor kvar" före start. Enligt Angela Fable syns kapseln med falskt ljud så länge appens Testläge är av. Kontrollen är att talet minskar efter Starta prov.
- Att lägga in en PDF via "Lägg till fil" går troligen inte i simulatorn, eftersom systemets filväljare inte går att styra. Det skrivs då som en begränsning.

## Tillägg 05:50: del 2 grön (A116, A117)
Körning 44015377071 är **grön i alla 8 delar** (**verifierat i Simulator**, appen från main med A116–A118).
- **Plusmenyn:** "+" i Säg-fältet ("Lägg till material") har Fota sidor, Välj bilder, Lägg till fil och Klistra in länk.
- **Klistra in länk:** med https://example.com lade servern in sidans text i fältet (fetch-url, inte ElevenLabs).
- **Kapseln:** "N frågor kvar" visade **15 före och 14 efter** att den nya texten spelats. Raden före start sa "Räknas som 1 fråga. Upprepningar kostar inget." Varningen kommer alltså före, och talet går ner med en.
- **Nytt prov:** raden "Klistra in länk" finns under Material.

Två saker är inte testade:
- **Lägg till fil (PDF):** systemets filväljare går inte att styra från UI-testet i simulatorn. Det är otestat här och behöver telefonen eller ett enhetstest.
- **En bild via "+":** samma bibliotek som "Välj bilder", som T24 redan testar. Ingen egen kontroll.

T36 ligger i nattflödet från och med i natt.
