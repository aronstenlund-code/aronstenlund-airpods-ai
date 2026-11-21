# A157 (D251, D253): iOS-appen på engelska, svenska väljs i Inställningar

Angela Fable (moln), 2026-11-21. Beställt av Deangelo 11:20 (D251) och 16:17 (D253, tillägget).

## Vad som är gjort

1. **Engelska är appens bas, svenska finns kvar.** Projektets basspråk är engelska (`project.yml`), och varje text
   i appen och widgeten finns i String Catalog på engelska och svenska: 1 671 nycklar i appen
   (`Lumen/Resources/Localizable.xcstrings`) och 32 i widgeten (`LumenControls/Localizable.xcstrings`).
2. **Appen startar alltid på engelska, också på en svensk telefon (D253).** Överst i Inställningar finns
   **Språk: English | Svenska**. Valet syns direkt (alla skärmar byggs om), sparas, följer med till widgeten och
   Live Activity, och går till servern som `lang` med nästa anrop.
3. **`lang` (en/sv) skickas** med varje anrop till answer, drill, exam och help (Kevins K114).
4. **Tal, datum och månader följer språket:** 1 236 · 1,2k · 1 december på svenska, 1,236 · 1.2k · December 1 på
   engelska.
5. **Info.plist-texterna** (mikrofon, taligenkänning, kamera, kalender, påminnelser, larm, kontakter, Apple Music,
   rörelse, appens namn) fanns redan på båda språken i `InfoPlist.xcstrings`; de är genomlästa och orörda.
6. **Verktyg** i `tools/l10n/` som hittar varje textsträng i koden och säger vad som saknar engelska
   (`check.py`). Alla mappar är klara: 0 fel.

## Hur det är byggt

- **De svenska texterna står kvar i koden som nycklar** (beslut D254). Katalogen har engelska som källspråk, och
  varje svensk nyckel har ett engelskt värde och sig själv som svenskt värde. Därför är svenskan exakt som förut
  (den är nyckeln), inga av de 1 000+ befintliga testerna behövde ändras för orden, och Tobys tester som söker på
  svenska etiketter fungerar som förut. De 239 äldre nycklarna, som var engelska, är kvar.
- **Vyernas egna texter** (`Text("…")`, `Button("…")`, etiketter för VoiceOver) slås upp av SwiftUI och behövde
  bara rader i katalogen. **Texter i vanlig kod** (1 030 ställen: rader från modellerna, sammansatta meningar,
  VoiceOver-rader) slås nu upp med `String(localized: "…")`.
- **Språkvalet (D253)**: `Shared/AppLanguage.swift` (`AppLanguage`, `LanguageChoice`) och
  `Lumen/Core/Language/LanguageSettings.swift`. Valet ligger i appens inställningar och i appgruppen (för widgeten).
  `String(localized:)` går i appen och widgeten genom en egen initierare som slår upp i det valda språkets tabell;
  SwiftUI:s texter får språket genom `\.locale` på roten, och roten får ny identitet när språket byts, så att allt
  ritas om. Texter som låg i `static let` (65 st) räknas nu fram varje gång, annars hade de stannat på det gamla
  språket.
- **Systemets egna ord** (Tillbaka, Klar, Klistra in, behörighetsfrågorna) väljs av iOS när appen startar. Appen
  ber därför om sitt eget språk hos systemet (`AppleLanguages`), vilket gäller från nästa start.
- **Körningar som själva anger språk** (enhetstesternas schema, Tobys tester och bildflödena, som alla startar med
  `-AppleLanguages`) får det språket, som före D253. Därför är inget av Tobys eller Kellys flöden ändrat.
- **Mina engelska texter är märkta för Kelly**: 1 472 nycklar har `needs_review` och en kommentar i katalogen.
  Hennes ordlista (`docs/design/engelska.md`) är följd (Quiz, Top up, Weekly pass, Say in AirPods, Play for …).
  Listan svenska → engelska står läsbart i `tools/l10n/en.json`.

## Det som medvetet INTE är översatt (1 606 strängar, var och en med skäl i `tools/l10n/skip.json`)

- **Röstkommandon och det appen lyssnar efter** (cirka 1 000): kommandona sägs på svenska, så exempel som
  ”Lumen, förhör mig” står kvar på svenska också i den engelska appen. Titlarna i listan över kommandon är översatta.
- **Det appen säger högt i lägena som lyssnar** (113): de följer språket man pratar (inställningen "Språk du
  pratar"), inte texternas språk. En del repliker finns bara på svenska.
- **Rader som skickas till servern** (provprofilen, minnet) och **ChatGPT-prompten** med sina markörer Fråga:/Svar:.
- **Skolämnen** som de lagras och söks på servern (Biologi, Matematik …).
- **Demodata för bilderna** (167, bara i Debug) och diagnostikens exportfiler.

## Test

- **Enhetstester** (`LumenTests/A157LanguageTests.swift`, 11 st): appen startar på engelska också på svensk
  telefon; valet sparas, syns direkt, når widgeten och ber systemet om samma språk; en körning som anger språk får
  det; Kellys ord finns i båda tabellerna; värden står rätt i engelska meningar också när ordningen ändras; tal
  och dagar per språk; `lang` i anropen; serverns ord läses på båda språken.
- KÖRNINGAR
- Simulatorn är ingen enhetsverifiering. Inget ElevenLabs har använts (D180).

## Kända brister och risker

- **Otestat på telefon.** Allt är verifierat i CI (Simulator).
- **Första starten på en svensk telefon**: appens texter är engelska direkt, men systemets egna knappar (Tillbaka,
  Klar, behörighetsfrågan) är svenska tills appen startats om en gång (otestat antagande om iOS; se ovan).
- **Byte av språk** bygger om skärmarna, så man hamnar på första skärmen. Rader som en modell redan har sparat
  (till exempel ett felmeddelande som står kvar) byter språk först när de skrivs nästa gång.
- **Serverns egna texter** (nekanden, `resets_day`) är svenska tills K114 är klar; appen skriver själv "December 1"
  på engelska och känner igen "krediter"/"credits".
- **Engelskan är min**, inte granskad av Kelly än. Lägenas namn (Provläge, Intervjuläge, Rizzläge, Socialt läge)
  är lämnade som de är på engelska.
- **Heltal i texter** skrivs nu med språkets tusentalstecken (12 000 → "12 000" på svenska, "12,000" på engelska).
- En engelsk användare ser svenska röstkommandon och hör svenska repliker i lägena som lyssnar: de lägena är byggda
  för svenska.

## Farhågor

Inga nya. Samtyckesskärmen, lyssnarbrickan och texterna om vad som skickas är översatta ord för ord, inget är
borttaget eller nedtonat.

## Kvar

- Kellys granskning av engelskan (Ke86) och hennes ändringar in i `tools/l10n/en.json` → `sync.py`.
- Engelska röstkommandon, engelska repliker och en engelsk ChatGPT-prompt (egen punkt om Aron vill ha lägena som
  lyssnar på engelska).
- Demodata på engelska för App Store-bilderna.
- Telefonprov: byta språk i Inställningar, låsskärmens widget, behörighetsfrågorna.

## Nästa session

`git pull`, läs den här rapporten och `tools/l10n/l10n.py` (översikten). Ny text i appen: skriv den som vanligt på
svenska, kör `python3 tools/l10n/todo.py /tmp/w.json <mapp>`, svara med engelskan (`apply.py`), kör `sync.py` och
`check.py`.
