# T8c – Förstagångsanvändaren efter Angelas A60, och skärmturen på A60 (Toby, 2026-11-11 14:55)

**Simulatorn räknas aldrig som verifiering på enhet.** Uppställningen är samma som i T8b
(`reports/apptest/2026-11-11-1200-toby-t8b-a50-forstagang.md`):
- raderad iPhone 17 Pro-simulator;
- två frågor i slinga;
- live Scribe och `/answer` med ElevenLabs-rösten;
- appens logg sparad.

Bygget är main med A60 (1667961 + 1f39214).

**Körningar:**
- **Förstagångstestet, grön:** [43029452998](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43029452998).
  - Två röda försök före den gick på testfel, nu rättade:
  - [43017251148](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43017251148): bladen kom i en annan ordning.
  - [43020070387](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43020070387): Provläge utan prov öppnar ett formulär.
- **Skärmturen, grön** (ljust, mörkt med största text, SE): [43020070474](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43020070474). 0 missar i alla tre lägena.
- **Bilder och loggar:** `reports/apptest/2026-11-11-t8c-a60/`.
  - `t8-skip-*` är den gröna körningen och `forsok1-*` är försök 2.
  - `tur-*` är skärmturen.
- **Kostnad (D120):** tre förstagångskörningar med cirka 3–4 korta svar var, och ElevenLabs-rösten.

## Kort: A60 rättade T8b fynd 1, 3, 4 och 7
| T8b-fynd | Nu |
|---|---|
| 1. Fråga blev "röstprofil" vid Avsluta, och Lumen pratade efteråt | Ingen `Profile by voice` och inget tal efter `Session deactivated` i de tre körningarna. Det exakta fallet (en fråga en stund efter ett svar) uppstod inte, eftersom sessionerna nu är korta. **Delvis verifierat.** |
| 3. Lyssnar visade förra sessionens svar | **Rättat.** Lyssnar börjar tom med "Fråga vad du vill. / Svaret kommer i örat och här." (`t8-skip-11`) |
| 4. Starta gjorde ingenting när igenkänningen inte startade | **Rättat.** Skärmturen med Apples igenkänning öppnar nu Lyssnar i Standardläge i alla tre lägena (`tur-*-lyssnar-fragor`). |
| 5. Första passet slutade i Lyssnar | **Rättat.** Sessionen avslutas efter första passet, och Start visar "Här startar du Earmind" vid knappen (`t8-skip-08`). |
| 6. Provläge frågade 5 saker | **Rättat.** Utan prov kommer ett formulär, se fynd 2 nedan. |
| 7. Dubbla knappar för lägesraden | **Rättat.** Bara "Läge: Standardläge. Byt läge" finns i trädet. |

## Siffror (sekunder från att appen öppnats)
| Steg | T8b (12:00) | **T8c** |
|---|---|---|
| Intro → Lyssnar | 16,5 s, 2 tryck | **12,5 s, 2 tryck** |
| Första svaret i Frågor | 46 s | 44 s (slingans tid) |
| Efter första starten | Lyssnar | **Start med "Här startar du Earmind"**, efter två blad |
| Starta → Lyssnar | 2,5 s | **2,3 s** |
| Start → Provläge lyssnar | 8 tryck | **4 tryck** (Byt, Provläge, Starta, Avbryt) |
| Hela vägen till svar i Provläge | 16 tryck, 215 s | **13 tryck, 239 s** |

## Fynd till Angela
1. **Tre blad under första användningen, inom 93 s:**
   - "Earmind kan mer än svara" (A52) vid 91 s;
   - delningsfrågan vid 100 s;
   - "Hjälp oss välja logga" (A54) vid 184 s, alltså direkt efter första Avsluta i samma körning.
   - Det stämmer inte med A54-rapporten ("Röstningen kommer nästa gång appen öppnas"). Det blir fyra beslut
     (tillsammans med provsteget) innan användaren har tryckt Starta en enda gång.
   - Förslag: delningsfrågan och röstningen väntar till ett senare appöppnande, och högst ett blad per öppning
     (Ke35/D127).
   - Bilder: `t8-skip-06`, `-07`, `-13`.
2. **Provläge utan prov öppnar formuläret "Lägg till prov"** (Spara prov / Avbryt / Säg det i stället), inte A60:s
   "Har du prov snart?" med "Inte nu" (`t8-skip-15`).
   - **Avbryt startar ändå Provläge**, och Lyssnar kom efter 9 s. Men ordet "Avbryt" säger att man avbryter.
   - Förslag: "Inte nu" eller "Starta utan prov" i stället för Avbryt.
3. **Säkerhetsspärren öppnade igenkänningen en gång** efter första svaret (`no end of Lumen's speech after 5 s
   (playback speaking false, speaker speaking false)`). Det är samma fel som T12 punkt 2, men kortare.
4. **Första frågan går ibland vidare av sig själv efter svaret** (1 av 3 körningar: provsteget kom utan "Fortsätt").
   I de andra två stod "Fortsätt" kvar. Om det är meningen att den ska gå vidare, gör den det inte varje gång.
   **Untested assumption** om orsaken.
5. **Största text** (skärmturen, `tur-pro-dark-storsta-text-11`):
   - "Här startar du Earmind" tar halva skärmen, men Starta syns ändå.
   - Lägesraden ("Standardläg/e") och "NÄSTA PROV" bryts fortfarande mitt i ord (T11 fynd 1–2).

## Ändrat i testerna
- `AppTests/E2E/Screens/FirstUserTests.swift`:
  - Klarar Earmind-namnen.
  - Tar bladen efter första starten i den ordning de kommer (A52, dela, A54), och skriver `FINDING` när fler än ett kommer i rad.
  - Fotograferar "Här startar du".
  - Trycker Fortsätt bara om första frågan står kvar.
  - Provläge utan prov: Inte nu eller Avbryt.
- `ScreenTourTests.swift`: Earmind-namnen, Vad kan … (A52), Mina svar (A53). Grenen kör tre lägen.
- Flyttat till main, så att nattens tur (alla sju lägen) klarar A50–A60.

## Kvar
- T10: telefonsteget (Aron).
- Fynd 1 (en fråga efter ett svar) kan bara prövas med en längre session. Det täcks av T5-retesten.
