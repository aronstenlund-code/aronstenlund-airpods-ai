# Kelly (moln) Ke75: "Hur ska det låta?", Skriv i takt och rösterna (D220)

## Vad som gjordes
- Ett förslag i `docs/design/stil-och-roster.md` med texter och regler.
- 5 skisser i `docs/design/bilder/stil/` (ljust | mörkt): `stil-text`, `stil-skriv` (tangentbord med förslagen),
  `tempo` (Skriv i takt), `roster` (röstbladet med sök och provlyssning), `se-stil` (SE största text).
- Punkt i `prompts/queue/angela-fable.md` till A136.

## Beslut (Kelly)
1. **En stilrad i kortet, bara när fältet har text:** röstkapseln "Astrid ▾" och fältet "Hur ska det låta?" bredvid
   (Arons "ett fält bredvid"). Tomt fält är oförändrat, så första skärmen blir inte rörigare (D215).
2. **Förslagen i tangentbordets verktygsrad** (Tydligt, Lugnt, Glatt, Viskande), inte som kapslar i kortet.
3. **Skriv i takt i tempo-menyn** (kostar inget), kapseln visar "I takt".
4. **Röstbladet** som ett vanligt systemblad: sök överst, utvalda svenska röster med ▶ provlyssna, en fotnot.
5. **Kostnaden** sägs bara med siffran som redan står vid Spela; stil eller ny röst gör att den visar nytt ljud.

## Test
Skisser i Chromium. Inget byggt, inget provat på telefon. Ingen ElevenLabs.

## Risker
- Hur v3-taggarna låter på svenska är okänt tills Aron säger ja till ett A/B-test (TILL-ARON #28).
- Hur många biblioteksröster planen rymmer är inte verifierat (Kevin K96).
