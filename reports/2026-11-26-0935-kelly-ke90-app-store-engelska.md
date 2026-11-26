# Ke90: App Store-sidan på engelska först, med det nya (Kelly (moln), 2026-11-26)

## Gjort
- **`docs/appstore/README.md` omskriven:** engelska är primärt språk (English (U.S.) i App Store Connect, D253) och svenska är lokalisering.
  Båda har namn, undertitel, reklamtext (plus en rad för lanseringsveckan, "Launch week: 65% off everything…", som kan bytas utan ny granskning), nyckelord (98/99 tecken) och beskrivning (2 209 / 2 212 av 4 000).
  Nytt i texten: **Komprimera** (D262), **egna aktiveringsord** (D259, A162), **telefonens egen modell** när servern inte kan svara (D258/D260, med villkor). **Spela in själv** (D263) är skrivet men läggs till först när A165 är på main.
- **9 bilder per språk** (`docs/appstore/en/1–9.jpg`, `sv/1–9.jpg`, 1320 × 2868) i samma Apple-stil.
  Nya är bild 5 "Make it shorter. / Gör det kortare." (`repSayCompressed`) och bild 8 "Say your words. / Säg dina ord." med Arons mening (`listening`). Bild 10 (Spela in själv) väntar på A165. De gamla `69-*.jpg` är borttagna, men de finns kvar i historiken.
- **Bildflödet** `kelly-appstore-shots.yml` har fått valet `languages` ("en sv"); de engelska filerna heter `en-<scen>.png`. Körning 45780064217 från main `fb76a577`, rådata på `kelly/appstore-shots-ke90`.
  `appstore.py` tar språket som argument och bryter raden under rubriken på två rader med samma höjd för alla bilder.
- **`granskning.md`:** kontrolltabellen har nya rader för de fyra nyheterna. Granskningsanteckningarna har fått punkt 7 (Komprimera), 8 (aktiveringsord) och 9 (telefonens modell). Punkt 10 (Spela in själv) är klar att klistra in när A165 finns.
  Under App Privacy finns en ny not: svaren ändras inte, eftersom Komprimera inte sparar någon text, orden bara följer med som nyckelord till taligenkänningen och inspelningarna stannar på telefonen. **Verifierat i koden.**

## Lovar inte mer än appen gör
- Komprimera: **verifierat i koden** och live (K120/O98); sett i Simulatorn (A163).
- Aktiveringsord: **verifierat i koden** (A162-testerna). Att orden hörs i riktigt tal är en **untested assumption**.
- Telefonens modell: **verifierat i koden**, men bara med låtsasmodell i CI. **Untested assumption på telefon.** Därför står det i README §3 punkt 4 att stycket och punkt 9 ska strykas om Arons prov inte går igenom.
- Spela in själv: inte med, eftersom vyerna (A165) inte är på main.
- Inget om låst skärm (D209), inget om 5 000 välkomstkrediter (D239).

## Brister (utkast)
1. De **engelska bilderna visar svensk demodata**: Biologiprovet, fotosyntes, "Swedish voices" och priser i kr. Engelska demodata är beställd av Fable i `angela-fable.md`.
2. **Bild 8** visar lyssnarvyn med "Paused" och tomt ordfält. En scen med orden ifyllda och "● Listening" är beställd av Angela Schrute i `angela.md`.
3. Ke78-sidorna (integritet och villkor) finns bara på svenska. Den engelska sidan behöver en engelsk version, och den publiceras bara efter Arons ja.

## Nästa
När scenerna och A165 finns: kör flödet igen (kommandot står sist i README), lägg till bild 10 och stycket om Spela in själv, och gör om bilderna.
Inget är uppladdat, inget anropar ElevenLabs.
