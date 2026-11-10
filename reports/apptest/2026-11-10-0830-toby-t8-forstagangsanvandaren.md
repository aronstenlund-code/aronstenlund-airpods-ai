# T8 – Förstagångsanvändaren i simulatorn (Toby, 2026-11-10)

Kort: en ny användare når **aldrig det första svaret**.
- **Blockerare:** efter iOS-frågan om mikrofonen står första frågan kvar på **"Startar …"** i 60 s (3 av 3 körningar).
  Med mikrofonen tillåten i förväg (T3) står där "Lyssnar".
- **Provläge** nåddes med **1 tryck** från start när man lagt till ett prov, och med **6 tryck och 6 skärmar** utan
  prov (5 frågor som upprepar provsteget man nyss hoppade över).
- **Inga svar i Provläge:** första körningen före 07:45 fick Lyssnar men inget svar inom 90 s. Senare körningar
  stoppades av att ElevenLabs-kvoten tog slut (Scribe `quota_exceeded`).
- **Simulatorn, inte enhet.** Skärmbilder och loggar: `reports/apptest/2026-11-10-t8-forstagang/`.

## Hur testet gick till
- `AppTests/E2E/Screens/FirstUserTests.swift` (UI-test i `LumenScreenTour`), `scripts/apptest/firstuser.sh`,
  `.github/workflows/apptest-firstuser.yml`. Körs inte i T3-turen (hoppar över sig själv utan `LUMEN_T8_PATH`).
- Raderad simulator (iPhone 17 Pro, iOS 26, ljust läge), inga behörigheter i förväg, appens språk svenska.
- Frågan "Vad är huvudstaden i Australien?" spelas via appens WAV-krok (`LUMEN_AUDIO_FILES`, loopad med 20 s paus).
- Testet trycker bara på det som syns, den uppenbara knappen, och skriver ner varje text och knapp på varje skärm.
- Två vägar: **med prov** (lägger till prov i förstagångssteget) och **utan prov** ("Hoppa över", sedan Provläge
  från start).
- Körningar: 42768774733 försök 1 (07:28–07:35, med prov fullständig; utan prov: simulatorn startade inte appen) och
  försök 2 (08:00–08:10, efter kvotstoppet).

## Siffror (sekunder från att appen öppnats; testet läser och trycker fortare än en människa)
| Steg | Med prov | Utan prov |
|---|---|---|
| Intro → "Fråga vad som helst" | 2 tryck (Testa nu, Tillåt), 3 skärmar, 15 s | 2 tryck, 3 skärmar, 15 s |
| Första svaret i Frågor | **nåddes inte** ("Startar …" i 60 s) | **nåddes inte** |
| Till startskärmen | 6 tryck, 8 skärmar | 5 tryck, 7 skärmar |
| Provläge lyssnar | **7 tryck, 9 skärmar** (+1: "Få A-svar till provet") | **11 tryck, 13 skärmar** (+6: Provläge, 5 × Hoppa över)* |
| Första svaret i Provläge | inget inom 90 s (Scribe föll: "Hör inte, försöker igen") | inget (kvoten) |

\* Testet tryckte "Fler lägen" först (12 tryck). En människa ser Provläge-knappen direkt, så jag räknar 11.

## Fynd till Angela
1. **"Startar …" efter mikrofonfrågan (blockerare för första intrycket).**
   - 3/3 körningar: Testa nu → Tillåt → "Fråga vad som helst" visar "Startar …" i 60 s och svarar aldrig.
   - T3 (mikrofonen tillåten i förväg): "Lyssnar" på samma skärm.
   - Gissning: `FirstStartView.startListening()` väntar på `requestRecordPermission()`, men sessionen startar inte
     efter att frågan besvarats. Det kan också vara simulatorn. **Untested assumption** tills Aron gör en ny
     installation på telefon (se Till Aron).
   - Testkrok: inte nödvändig. En `SessionEvent` eller logg i UI-testet vore bra, för UI-testet ser bara skärmen.
2. **"Fortsätt" gjorde ingenting** en gång (1/3, med prov försök 2): skärmen stod kvar på "Fråga vad som helst" 17 s
   efter trycket (`med-prov-fortsatt-gjorde-inget.jpg`). Kan vara simulatorn. **Untested assumption.**
3. **Provsteget har NO och Biologi förvalda** innan användaren valt något (`utan-prov-05-prov-steget.jpg`). Den som
   trycker "Spara prov" direkt får "Biologiprovet" om 7 dagar. Förslag: inget förval, eller spara inget utan val.
4. **"Spara prov" täcker datumraden.** Rubriken "Datum" syns, väljaren ligger under knappen. Användaren måste skrolla
   för att se datumet som sparas.
5. **Provläge utan prov frågar 5 saker** (när, årskurs, ämne, kontrollfrågor, förklaringslängd) direkt efter att
   användaren hoppat över provsteget. Samma sak frågas två gånger med olika val: "Gy 1" mot "Gymnasiet 1", "NO" mot
   "Biologi/Fysik/Kemi". Förslag: starta Provläge direkt och fråga en sak åt gången med rösten, eller använd samma
   provark.
6. **Två vägar till Provläge** på start med prov: "Få A-svar till provet" och runda knappen "Provläge". Det är oklart
   om de gör olika saker.
7. **Delningsfrågan kommer direkt efter första starten** (beslut nummer fyra innan man fått ett svar). Förslag: fråga
   efter några sessioner.
8. **Lyssnar i Provläge har tre instruktioner samtidigt:** "Ställ en fråga när du vill", "Ställ en fråga om det du
   pluggar. Svaret hörs i örat." och "Säg 'Lumen, förhör mig', 'Lumen, svara kortare' eller 'Lumen, pausa'.", plus
   knappen "Förhör mig". Med prov kommer också 8 ämnesord som användaren aldrig skrivit (cell, ribosom …).
9. **Rubriken skiljer sig** på startskärmen: "Andra lägen" med prov och "Eller börja direkt" utan prov, för samma rad.
10. **Bra:** introt (tre punkter, en knapp), "Fråga vad som helst" med exempel och "Jag hör inte just nu" med
    förklaring är tydliga.

## Till Kelly (Ke9)
Fynd 3–9 är design: färre val i provsteget, en väg till Provläge, ingen delningsfråga första gången, en instruktion
per skärm. Skärmbilderna ligger i `reports/apptest/2026-11-10-t8-forstagang/`.

## Till Aron
- ElevenLabs-kvoten är slut (Oscar O12). Den stoppar alla ljudtest i simulatorn.
- När du har telefonen: radera Lumen, installera igen, tryck "Testa nu" och "Tillåt". Står det "Startar …" mer än
  5 s, eller blir det "Lyssnar"? Det avgör om fynd 1 bara gäller simulatorn.

## Kända begränsningar
- iOS-frågan om mikrofonen är på engelska i simulatorn, för att simulatorns systemspråk är engelska. Appens svenska
  text finns (`InfoPlist.xcstrings`). Inget fel.
- UI-testet ser inte om svaret lästes upp, bara om det visas.
- Tiderna är testets, inte en människas: en människa läser introt längre.

## Kvar
- Kör om `apptest-firstuser` när kvoten är påfylld och Angela har tittat på fynd 1: då mäts tiden till första svaret.
  Det är T8b i min kö.

## Nästa session
T5b när A21 är klar, T7b och T8b när kvoten och rättelserna finns. Annars stående uppgift (omtest av senaste A-punkt).
