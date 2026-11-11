# A77: funktionslistan delas med servern (K44) (Angela)

## Gjort
1. **Vad kan Earmind? läser `Shared/capabilities.json`** (`CapabilityList`), samma fil som servern läser i K44.
   - Raderna, deras ordning, namn, fraser och status kommer från filen. Status "kommer" ger "Kommer snart" utan knapp, och `permission` ger tillåtelsens rad med knappen.
   - Appen lägger bara till två saker per id: symbolen och platsen för rader som görs i appen (Mina svar "I Provläget", Intervju och Socialt "Byt läge", Öppna musik "Öppnar Spotify med sökningen").
   - Nya rader från listan: **Översätta**, **Söka på webben** och **Socialt och Rizz**.
   - Om filen saknas i paketet används den gamla listan (`fallback`).
   - "Lumen, …" i fraserna skrivs med `WakeWord.name` (A75). Byts väckningsordet följer skärmen med.
2. **`context.capabilities`** följer med varje `/answer`. Det är de tillåtelser som är givna på telefonen: `calendar`, `reminders`, `alarms`, `contacts`, i K44:s format, en lista med namn. Då svarar servern "Ja, säg: Lumen, sätt en timer …" när tillåtelsen finns och "du behöver tillåta … först" när den saknas, precis som skärmen. "Kan du sätta en timer …?" och "Sätt en timer …" går sedan samma väg, och den vägen är K44:s på servern.
3. **Rättat från A74:** servern läser `context.utterance_ms` i millisekunder (K42.5). Appen skickade `utterance_seconds` på översta nivån, och servern läste det aldrig. Nu går det som `context.utterance_ms`, så Kevins kontroll av ensamma kommandoord får längden.

## Tester
- `LumenTests/A77Tests.swift`:
  - filen finns i appen, skärmen har listans rader i listans ordning, och timern kräver alarm med frasen och väckningsordet;
  - Spotify står som Kommer snart, Intervju som Byt läge, och varje id har en symbol;
  - en okänd grupp tas inte med;
  - tillåtelserna hamnar i `context.capabilities` och i `clamped`, och utan lista skickas inget.
- `A74Tests`: `context.utterance_ms` = 420.
- `A52Tests` är oförändrade och ska fortfarande hålla.
- CI 43110609458 (8d91f5a): device-bygge och enhetstester gröna. Skärmbilder: körning 43098721442 (`canDo` visar listan). **Inte provat på telefon.**

## Till Kelly
- Vad kan Earmind? har nu Översätta, Söka på webben och Socialt och Rizz. Symbolerna är `character.bubble`, `globe` och `person.2.wave.2`. Raderna har listans ordning: Svar på frågor före Förhör.
- Granska gärna, med scenen `canDo`.
- Efter skärmbilden (körning 43098721442): Mina svar fick ingen egen plats, eftersom listans text redan säger "i Provläget". Raden säger nu "Inget att ställa in".
