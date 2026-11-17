# "Hur ska det låta?", Skriv i takt och rösterna (Kelly (moln), Ke75, D220, 2026-11-17)

Ett förslag till Angela Fable (A136). Bygger på första skärmen i `forsta-skarmen.md` (Ke72, D215). Skisser i
`bilder/stil/<id>.png` (ljust | mörkt), källa `_src/stil.html`, render `node docs/design/_src/stil-render.js`.
**Skisser, inget byggt, inget provat på telefon.**

## Idén
Allt som handlar om **hur** texten låter samlas på **en rad i kortet**, och raden finns bara **när fältet har text**.
Tomt fält ser ut exakt som i Ke72. Rösten och stilen hör ihop (det är båda "hur det låter"), så de står bredvid varandra:
rösten som en kapsel, stilen som en fri rad. Tempo och Skriv i takt ligger kvar i tempo-kapseln, eftersom de är gratis och
spelas på telefonen (D151).

## 1. Kortet med text (`stil-text.png`)
Uppifrån: fältet · **stilraden** · kostnaden · knappraden (`+` · ⏱ · tempo · **Spela i 10 min**).

**Stilraden** (hårfin linje ovanför, 10 pt luft):
| Del | Utseende | Gör |
|---|---|---|
| Röstkapseln | **"{Astrid} ▾"**, samma kapsel som tempo | Öppnar bladet Röst (avsnitt 4) |
| Stilfältet | En rad, platshållare **"Hur ska det låta?"**, 15 pt | Fri text. Tom = ingen stil |

## 2. Skriva stil (`stil-skriv.png`)
Tryck på stilfältet: tangentbordet kommer med fyra förslag ovanför (systemets `toolbar` i tangentbordet):
**Tydligt · Lugnt · Glatt · Viskande**. Ett tryck skriver ordet (läggs till efter ett kommatecken om det redan finns
text). Fältet tar fri text, t.ex. "Lugnt, som en lärare". Inga andra förklaringar.

**Kostnaden:** stil eller ny röst ger nytt ljud (eleven_v3 med taggar, D220.2), så kostnadsraden räknas om från servern
och visar t.ex. **"120 krediter"** även för en text som redan hade ljud. Det räcker som besked; ingen extra mening.

## 3. Tempo och Skriv i takt (`tempo.png`)
Tempo-kapselns meny får ett val överst:
| Val | Kapseln visar | Kostnad |
|---|---|---|
| **Skriv i takt** (0,85× och en paus efter varje fras på 3–6 ord, D220.1) | **I takt** | 0 |
| 0,5× · 0,75× · 1,0× · 1,5× | 0,5× … 1,5× | 0 |
Förvalt är 1,0×. Valet sparas till nästa gång.

## 4. Välj röst (`roster.png`)
Ett vanligt blad, rubrik **Röst**, knapp **Klar**:
- Sökfält överst: **"Sök bland alla röster"** (ElevenLabs röstbibliotek, K96).
- Avsnittet **SVENSKA RÖSTER**: 12–20 utvalda röster. Varje rad: ▶ till vänster (provlyssnar, blir ⏸ medan den spelar),
  namnet, en kort beskrivning under (t.ex. "Lugn, rikssvenska", "Skånska"), bock på vald röst. Tryck på raden väljer.
- Fotnot: **"Provlyssning kostar inget. En ny röst blir nytt ljud."**
- Dialekt (skånska m.fl.) görs med en röst som har dialekten, inte med stil (D220.3). Beskrivningen säger dialekten.

## 5. Största text (`se-stil.png`)
Stilraden staplas: röstkapseln på en rad, "Hur ska det låta?" under, i full bredd. Knapparna som i Ke72.

## 6. Texter
| Ställe | Text |
|---|---|
| Röstkapseln | {Astrid} ▾ |
| Stilfältet, platshållare | Hur ska det låta? |
| Förslag | Tydligt · Lugnt · Glatt · Viskande |
| Tempo-menyn, överst | Skriv i takt |
| Tempo-kapseln med Skriv i takt | I takt |
| Röstbladet, rubrik | Röst · *knapp:* Klar |
| Sökfält | Sök bland alla röster |
| Avsnitt | SVENSKA RÖSTER |
| Fotnot | Provlyssning kostar inget. En ny röst blir nytt ljud. |
| VoiceOver röstkapseln | Röst, {Astrid} |
| VoiceOver ▶ | Provlyssna {Astrid} |
| VoiceOver stilfältet | Hur ska det låta?, textfält |

## 7. Regler
1. Stilraden visas bara när fältet har text. Tomt fält är oförändrat (D215).
2. Rösten och stilen gäller den här texten. Byter man efter att ljudet gjorts blir det nytt ljud, och kostnaden visar det.
3. Senaste (Ke72) sparar texten **med** röst och stil, så ett tryck lägger tillbaka alla tre.
4. Ingen stil i tester mot ElevenLabs (D180). Förhandsvisning av kostnaden från servern (K92).
