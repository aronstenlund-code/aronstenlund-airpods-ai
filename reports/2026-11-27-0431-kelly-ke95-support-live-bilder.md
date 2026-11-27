# Ke95: /support live, bilderna från D271/D273 och Ke93, nya App Store-bilder (Kelly (moln))

## 1. /support live
`earmind.vercel.app/support` och `/sv/support` svarar 200 och fungerar vid 393 px, utan platshållare (kelly-site-check 45932270267, efter Vercels bygge 03:05 UTC). **Verifierat i Actions.**

## 2. Bilderna, rader i köerna
- **Angela Schrute** (D271 `fable/screens-historik`, D273 `fable/screens-ke93-lyssnarfel`), fyra rader:
  1. Historiklistan blandar fråga och svar som rubrik. Frågan bör alltid vara rubrik.
  2. Svaret i historiken visar inte frågan.
  3. Svar på hennes fråga: AirPods-kortets knapp "Keep listening" tas bort, eftersom fotens "Listen again" gör samma sak.
  4. Kortare rader under brickan ("No AirPods – answers play on the speaker.").
  
  Annars ser det rent ut: aktiveringsblocket, första lyssnandet, Välkommens nya rad och felkortet med en "Try again".
- **Angela Fable** (`fable/screens-ke93`): alla fem från Ke93 är gjorda. Hennes fråga är besvarad: bilden med vit text var från före rättningen. Inget nytt.

## 3. App Store
- **Nya bilder** (10 per språk, `docs/appstore/en/`, `sv/`) från main `4aed5848` (körning 45932431120). Appens nya ord syns nu: "Voices" / "Röster", "Create", "Audio: 4 of 6 ready" och aktiveringsblocket med fältet under. Alla tio scener kommer från en körning.
- **Historiken och "Try again" blir inga bilder:** de hör till Fler lägen (beta) och felfall, och sidan säljer Säg i AirPods, prov och Spela in själv. Historiken fick i stället en rad i beskrivningen under MORE MODES ("Questions and answers are saved in History on your phone, where you can search and play them again."), och raden finns i kontrolltabellen. Beskrivningen är nu 2 508 / 2 473 av 4 000 tecken.

Inget är uppladdat. Allt är sett i Simulatorn, inget på telefon. 0 ElevenLabs.
