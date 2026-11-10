# A46 vändkort – Vändkort i tyst läge (N6) (Angela, 2026-11-10)

Underlag: Deangelos punkt i kön (`063f03f`). Numret A46 användes redan i dag för Kellys Ke18-fynd
(`reports/2026-11-10-angela-a46-kelly-ke18.md`). Den här punkten kallas därför **"A46 vändkort"** i DECISIONS.

**Det här är kod, enhetstester och simulatorbilder. Inget är provat på telefon** (untested assumption för känslan i
vändningen och knapparna på en riktig skärm).

## Vad som gjordes
1. **Knappen:** provkortet på Start har nu "Öva med N vändkort" (ikon med två kort). Den syns bara när provet har
   studiekort. Studiekort är det Provläget sparar och det `/study-cards` gör (D81). Ett kort utan ämne räknas till alla
   prov. Knappen står mellan "Fota sidan du pluggar" och "Minitest, 5 frågor".
2. **Skärmen** (helskärm, inget ljud och ingen mikrofon):
   - **Överst:** stängknapp, "Vändkort" med provets namn, "3 av 12" och en tunn framstegslinje.
   - **Kortet:** ett kort enligt SYSTEM.md (`raised`, hörn 20, skugga). Det har "FRÅGA" och frågan i 24 semibold.
     - Ett tryck på kortet eller på "Vänd kortet" vänder det: en halv vändning, sedan byts sidan, sedan resten.
       Vändningen tar 0,3 s, och kortet kan inte tryckas under tiden.
     - Med "Minska rörelse" byts sidan på stället.
     - Svaret står i 20 regular under "SVAR". Ett nytt tryck visar frågan igen.
     - Ett långt svar med den största textstorleken rullar inne i kortet. Knapparna stannar längst ner.
   - **Knapparna:** före vändningen finns bara "Vänd kortet" (blå). Efter den finns "Kunde inte" (sekundär) och
     "Kunde" (blå). Det är en huvudknapp per läge, som SYSTEM.md säger. Ett lätt tryck känns i handen för varje
     kort.
   - **Sist:** "Du kunde 8 av 12." och "Det räknas in i din plan." Därefter "Öva på de 4 igen" (en ny runda med de
     missade) och "Klar".
3. **Ordningen:** högst 20 kort. De som oftast blivit fel kommer först, sedan de äldsta (samma regel som minitestet).
4. **Resultatet räknas som förhörssvar**, och varje svar sparas direkt, så det som gjorts finns kvar om man stänger
   halvvägs:
   - kortets egna rätt/fel, som "Öva mer på" och minitestet redan läser;
   - begreppsstatistiken som tutorn får med varje fråga (`concept_stats`, A16);
   - studieplanens historik per prov och begrepp (A19). När skärmen stängs hämtas dagens pass på nytt.
   - **Begreppet:** korten har inget eget begrepp än. Därför används provets ämnesord om kortet nämner det
     ("fotosyntes" i "Vad behöver fotosyntesen?"), annars själva frågan (högst 60 tecken).

**Kod:**
- `Lumen/Core/Study/FlipDeck.swift` är ny: korten, ordningen, vändningen, markeringen, sammanfattningen, den nya
  rundan och begreppet.
- `Lumen/Features/Listening/FlipCardsView.swift` är ny: skärmen.
- `ListeningModel.flipDeck(for:)` och `recordFlip(_:knew:for:)` är nya.
- I `HomeView` finns knappen och helskärmen (`FlipSession`).
- `ScreenshotStage` har nya scener: `flipCards`, `flipCardsBack` och `flipCardsDone`. Start visar "Öva med 3 vändkort",
  eftersom demon nu har tre biologikort.

## Tester
`LumenTests/FlipCardsTests.swift`:
- provets kort kommer först, med de oftast missade först och sedan de äldsta;
- andra ämnens kort kommer inte med, och det är högst 20 kort;
- ett kort kan bara markeras efter att svaret visats;
- vändning fram och tillbaka och "3 av 12" fungerar;
- slutet och sammanfattningen stämmer;
- den nya rundan har bara de missade;
- begreppet blir provets ämnesord eller frågan.

## CI
Grönt i CI: iOS build 42876606748 (`f6f777e`). Bygget för enhet räknar varningar som fel, och alla LumenTests är
gröna, FlipCardsTests inräknade.

## Bilder
Simulatorbilder från iPhone SE (den minsta skärmen) ligger i `reports/2026-11-10-a46-vandkort-skarmbilder/`:
- `flipCards`: frågan;
- `flipCardsBack`: svaret med Kunde och Kunde inte;
- `flipCardsDone`: slutet;
- `home`: knappen på provkortet.

## Kända begränsningar
- Ett kort kan inte ångras efter "Kunde" eller "Kunde inte".
- Inget svep. Knapparna gör det, och svep kan komma om Kelly vill.
- Begreppet är en gissning tills korten får ett eget begrepp. Det kan bli via Kevins `done.concept` (A19) eller ett
  `concept` i `/study-cards`.

## Till Kelly
Granska de fyra bilderna:
- knappens text "Öva med N vändkort";
- kortet med "FRÅGA" och "SVAR";
- de två knapparna efter vändningen;
- slutet.

Säg till om du vill ha svep i stället för eller utöver knapparna.

## Till Kevin
Om `/study-cards` kan ge varje kort ett `concept` (samma ord som i `/study-plan`) räknas vändkorten på rätt begrepp i
planen. Säg till, så läser appen fältet (det är inte byggt än).
