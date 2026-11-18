# T50 – Skriv i takt, stil och röster i appen (A136, A140, D220)

Toby (moln), 2026-11-18 06:25. Simulatorn (iPhone 17, iOS 26, Xcode 26.6), falskt ljud (`LUMEN_TEST_HEADER`), 0 ElevenLabs (D180). **Allt nedan är verifierat i Simulator, inte på enhet.**

## Vad som gjordes
- Ny del i T36-testet: "Stil och Skriv i takt (A136, A140)".
  - Stilraden kontrolleras när fältet har text, med förslagen ovanför tangentbordet. Testet trycker på Lugnt.
  - Kostnaden läses före och efter stilen, och testet kontrollerar om röstkapseln finns.
  - "Skriv i takt" väljs i tempomenyn. Sedan spelas texten i takt i 25 s, och tempot och stilen sätts tillbaka.
- t36.sh räknar appens pausrader ("Reading: pace: …") och skriver ut dem.
- Borttagningen i Senaste tar bort alla kapslar för testtexten. Med en stil sparas samma text två gånger (A136), och Senaste visar en text en gång (A135). När den ena tas bort syns den andra.

## Resultat (körningar 44241367646 och 44245785236 på toby/t50)
- Stilraden "Hur ska det låta?" syns när fältet har text. Förslagen Tydligt, Lugnt, Glatt och Viskande står ovanför tangentbordet, och Lugnt skriver "Lugnt".
- Kostnaden vid Spela: "78 krediter" i den första körningen. I den andra stod "0 krediter" före och efter, eftersom texten redan hade ljud.
- Röstkapseln syns inte, eftersom /voices inte har någon katalog i dag. Röstbladet och provlyssningen kan därför inte testas (untested assumption).
- "Skriv i takt" står först i tempomenyn. Kapseln blir "Tempo, Skriv i takt", och det spelar ("Spelar i AirPods · Adam").
- Appens logg har 9 pauser på 25 s ("pace: 5 words, pause 4.0 s", "4 words, 3.4 s", "3 words, 2.8 s"). Pauserna kommer alltså efter fraser på 3–5 ord.
- Ta bort i Senaste: 2 kapslar togs bort, och ingen fanns kvar efter 10 s.

## Fynd och frågor
1. **"Ljudet kunde inte hämtas. Kolla nätet." när nätet är bra** (till Angela Fable och Kevin):
   - Med falskt ljud kom raden i tre av fyra körningar sedan A135, och efter Försök igen "Det gick inte att spela just nu. Försök igen om en stund.".
     - 44245785236: första Spela på ett nytt konto cirka 05:47 UTC. Ljudet startade först 05:49:26, efter tre tryck.
     - 44241367646: länktexten cirka 05:24 UTC.
     - 44235040986: 20 s efter att nätet kom tillbaka.
   - Nätet var på. Det ser ut som att servern ibland behöver mer än A135:s 10 s för att göra ljudet, och att raden då skyller på nätet.
   - Kevin: hur lång tid tar /drill-ljudet med x-earmind-test på ett kallt anrop?
   - Fable: är "Kolla nätet." rätt ord när nätet är uppe?
2. **Dragning med testljud** (Kevin, T44): i 44241367646 gick kapseln från 1 500 till 1 400 efter texten med stil. Tidigare har den aldrig gått ner med x-earmind-test. Därför går det inte att visa här att Skriv i takt inte drar något, eftersom stil och takt kördes ihop.
3. "Stilfältet skickar style" syns inte i appens logg. Bara kostnaden ändras (untested assumption: att style går med i save och cost).

## Nästa session
- T48 (köp, A134/A141): köpdelen finns bara med riktig server. Ett köp i Simulator nekas av servern, och då ska raden "Köpet är gjort men kunde inte läggas in just nu …" stå och kapseln stå still.
