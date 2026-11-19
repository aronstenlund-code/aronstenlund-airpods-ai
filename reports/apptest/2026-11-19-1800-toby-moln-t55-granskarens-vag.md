# T55 (1) – Granskarens väg i Simulatorn från ny installation (D238)

Toby (moln), 2026-11-19 18:00. Simulatorn (iPhone 17 Pro, iOS 26, Xcode 26.6). Ny installation, nytt anonymt konto, riktig server med x-earmind-test (falskt ljud), 0 ElevenLabs. **Debug-bygge**: testläget och det falska ljudet finns bara där (D227). Release har dem inte, se release-kontrollen. Provtexten lades in med LUMEN_TEST_MATERIAL, eftersom XCUITest inte kan skriva i Skriv text. **Allt är verifierat i Simulator, inte på enhet.**

Körning: apptest-t55 44575920772 på toby/t55 (SayFlowTests, LUMEN_T36_REVIEW). Samma gren: T36 44575920846 grön.

## Vad granskaren ser, steg för steg
1. **Välkommen (ny installation):**
   - Rubrik "Välkommen till EarMind".
   - Tre rader: "Fota materialet – EarMind gör provfrågor med A-svar", "Lyssna i dina AirPods – Frågorna läses upp. Tryck för svaret" och "Plugga utan mobilen – Telefonen kan ligga i fickan".
   - Raden om integritet: "Fotona och texten skickas en gång för att göra frågorna och sparas inte. Starta prov använder aldrig mikrofonen."
   - Knapparna "Läs mer" och "Fortsätt".
2. **Efter Fortsätt öppnas Nytt prov direkt:**
   - "Börja med materialet till ditt nästa prov."
   - Material (Fota sidor, Välj bilder, Skriv text, Lägg till dokument), Vilken årskurs? och Antal frågor 20.
   - Knappen "Skapa frågor" och "Senare".
   - Granskaren kan trycka Senare.
3. **Start första gången:**
   - Säg-kortet med "Du kan låsa telefonen. Det hörs i AirPods ändå.", "Spela i 10 min", Hur länge och Tempo.
   - Kapseln "1,5k krediter kvar".
   - "Kom förberedd till provet", "Nytt prov" och "Hitta prov från din skola".
   - **Krediter: 1 500** (exakt, ur bladet).
4. **Säg i AirPods → Spela:**
   - Med text i fältet står "Kostar 94 krediter" och röstkapseln "Adam".
   - Spela ger kortet "Spelar i AirPods med Adam, 9 minuter kvar" med Pausa och Stoppa.
   - **Krediter efter: 1 406** (94 dragna, stämmer med kostnaden).
5. **Prov från en text (39 ord om fotosyntes):**
   - Nytt prov visar "Text · 39 ord" och "1,5k av 1,5k krediter kvar den här månaden."
   - Skapa frågor ger "Stämmer det här?" efter 21 s, med ämnet Biologi, en sammanfattning, fem frågor, "Gör om med rättelsen" och "Ser rätt ut".
   - På Start: **"Nästa prov, Biologiprovet, 5 frågor · Det här kostar 1 909 krediter"** med Starta prov.
   - **Starta prov gjorde ingenting synligt** på 120 s. Ingen spelare kom, och ingen rad om för få krediter eller "Fyll på" syntes på kortet. Provet kostar 1 909, och kontot har 1 500.
   - **Krediter efter: 1 500**, alltså samma som vid start, inte 1 406. Se fynd 2.
6. **Krediter:**
   - "1 500 krediter kvar".
   - Fyll på med "Paketen kunde inte hämtas från App Store just nu." och Försök igen (inga produkter i Simulator).
   - Bjud in ("Få 2 000 krediter").
   - "Så räknas det": 1 tecken nytt ljud = 1 kredit; ljud som redan finns, upprepning och delade prov = 0.
   - Villkor, Integritet och Återställ köp finns. Återställ köp svarar "Det gick inte att hämta köpen just nu. Försök igen om en stund." (inget Apple-konto i Simulator).
7. **Radera konto:**
   - Konto ligger sist i Inställningar.
   - Frågan "Radera kontot?" har Radera konto och Avbryt. Avbryt gör ingenting.
   - Utan nät står "… Inget är raderat …".
   - Med nät kommer "Kontot är raderat · EarMind börjar om som ny på den här telefonen." och Välkommen.
   - Efteråt finns inga prov och inga texter, och kontot har 1 500.

## Fynd
1. **En granskare med bara 1 500 krediter kan inte starta ett prov på 5 frågor från en kort text (1 909 krediter), och appen säger inte varför** (till Angela Schrute/Fable och Kevin, och Deangelo för D238 punkt 4):
   - Starta prov tycks inte göra något.
   - D238 räknar med 1 500 + 5 000 välkomstkrediter. De 5 000 kräver App Attest (A141), som inte finns i Simulator och inte heller i en Sideloadly-installation utan rättigheten.
   - En granskare med en riktig App Store-installation bör få dem (untested assumption).
2. **Kapseln gick från 1 406 tillbaka till 1 500** efter en omstart av appen (till Kevin):
   - Antingen räknade appen 94 lokalt utan att servern drog dem, eller så gav servern tillbaka dem.
   - Kevin skrev 2026-11-18 att testkonton dras ur sina egna 1 500.
3. Efter Fortsätt öppnas Nytt prov direkt, före Start. Det är som avsett (D-första starten), men det är bra att veta för granskarens anteckningar.

## Krediter längs vägen
1 500 (första Start) → 1 406 (efter Säg) → 1 500 (efter omstart och provet, som inte startade) → 1 500 (efter radering, nytt konto).

## Nästa
- T55 (2): när A153 är på main, T53 på iPhone 17 Pro och SE vid AX5. Spela ska nås utan att testet döljer tangentbordet.
- En körning med välkomstkrediterna kräver App Attest, alltså enhet och Kevins APPLE_TEAM_ID. Den kan inte göras i Simulator.
