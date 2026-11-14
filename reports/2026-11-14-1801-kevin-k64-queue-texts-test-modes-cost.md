# K64: kön, texten om frågor kvar, testlägen för "ljudet kan inte göras" och förslag på billigare prov (Kevin, 2026-11-14 18:01)

## Kort
- **(1) O61 fynd 2: klart, driftsatt och verifierat i test.**
  - Ljudkön gör aldrig en fil som ingen fråga använder. Sådana filer markeras `unused` och skickas aldrig till ElevenLabs.
  - När ett prov tas bort tas dess väntande filer ur kön, om ingen annan fråga använder dem.
- **(2) Texten om kvoten: klar och verifierad live.** "Köp ett abonnemang" är borta. Spara ger nu: "Du har gjort 15 av 15 frågor med ljud den här månaden. Nya frågor går att göra från den 1 december. Andras prov är gratis." Det är Kellys text (repetition-texter §6) och det HJALP.md säger: abonnemang kommer senare. Samma ord finns i `/exam` och `/help try`.
- **(3) Testa "ljudet kan inte göras": klart och verifierat live**, med 0 riktiga anrop:
  - `x-earmind-test: unavailable`: provets filer blir `failed` med `audio_unavailable`, och `/tts` svarar 503 `tts_unavailable`.
  - `x-earmind-test: slow`: filerna står kvar som väntande, alltså "Ljud: 0 av 2 klara".
- **(4) Förslag på billigare prov:** se nedan. Inget är byggt.
- **0 riktiga ElevenLabs-anrop:** verifierat i loggen efter 16:30 UTC.

## (1) Kön (`drill/handler.ts`)
- **Före varje fil** frågar kön databasen om någon rad i `drill_items` använder filen (`referenced`).
  - Om ingen gör det blir filen `failed` med felet "unused: no question uses this file (K64)" och 3 försök, och den görs aldrig.
  - **Undantag:** ljudsignaler (`seq < 0`), som alla prov använder.
  - **Undantag:** en fil som köades de senaste 2 minuterna. Den kan höra till ett prov som sparas just nu, eftersom filerna köas före provets rader. Den läggs tillbaka i kön, och rundan stannar när bara sådana filer är kvar, så att kön inte snurrar.
- **`delete`:** provets filer som väntar eller har fallerat, och som ingen annan fråga använder, får "unused: the drill was deleted (K64)".
- **Test:** `drill/handler_test.ts` "K64 (Oscar O61 fynd 2)".
  - en gammal oanvänd fil skickas aldrig
  - en ny väntar
  - ett borttaget provs filer lämnar kön

## (3) Testlägen (för Oscar och Toby, och Angelas skärmar)
`x-earmind-test` tar nu ett läge. Vilket värde som helst gör anropet till test, och orden `unavailable` och `slow` ändrar vad det falska ljudet gör.

| Huvud | `/drill` save eller status | `/tts` |
|---|---|---|
| `x-earmind-test: oscar-qa` (vad som helst) | tysta filer, klara direkt | 1 s tystnad |
| `x-earmind-test: oscar-qa unavailable` | filerna blir `failed` med `error: "audio_unavailable"` | 503 `{"error":{"code":"tts_unavailable"}}` |
| `x-earmind-test: oscar-qa slow` | filerna står kvar som väntande, och `status` gör dem inte | 1 s tystnad |

**Live med nytt testkonto:**
- `unavailable` gav `failed` och `audio_unavailable`, och `/tts` gav 503.
- `slow` gav done 0 av 2.
- 15 sparade frågor och sedan en till gav 402 med den nya texten.

## (4) Förslag: ett prov på 15 frågor med betydligt färre krediter (inget byggt)

**I dag** (mätt i databasen, Multilingual v2, 0,40 krediter per tecken, mätt med `character-cost`):

| Del | Tecken per fråga | Krediter per fråga | Per prov (15 frågor) |
|---|---|---|---|
| Frågan | 33 (median 34) | 13 | 198 |
| Långa svaret, som också är det korta (D145) | 498 (median 520) | 199 | 2 988 |
| **Summa** | 531 | 212 | **cirka 3 190** |

- **Vad det betyder:** 65 000 krediter räcker till cirka 20 nya prov i månaden.
- **Var kostnaden ligger:** långa svaret står för 94 %. Det korta svaret kostar redan inget extra (D145).
- **Redan gratis:** delade och publicerade prov kostar mottagaren 0 (D144), och en ändring gör bara nytt ljud för den frågan.

**Förslag 1: långa svaret när det behövs.** Samma röst, samma text och samma kvalitet. **Kräver Deangelos ja**, eftersom det ändrar när ljudet görs.
- **Vid spara:** bara frågornas ljud görs, alltså 198 krediter per prov.
- **Under uppspelning:** långa svaret görs i förväg för de 3 frågorna som kommer härnäst. Tryck 1 eller 2 ger då ljudet direkt, som i dag. Att göra en fil tar cirka 2 s (mätt K55, första ljud 2,0 s), och en fråga plus betänketid tar cirka 8 s, så förhandsgörandet hinner med.
- **Besparing för ett prov som spelas klart:** ingen. Alla långa svar behövs ändå i förväg, eftersom eleven kan trycka på vilken fråga som helst.
- **Besparing för ett prov som sparas och aldrig spelas, eller tas bort:** nästan allt, upp till 94 %. Hur vanligt det är vet vi inte. `drills` saknar uppgift om spelningar, och D178 sa nej till `last_played_at`. Det kan mätas utan att lagra något nytt per prov, till exempel en räknare per dag.

**Förslag 2: långa svaret görs först vid första trycket.** Samma röst och samma kvalitet, men cirka 2 s väntan första gången ett svar begärs. Därefter sparas filen och delas. **Kräver Deangelos ja**, eftersom det ändrar upplevelsen. Om eleven trycker på 40 % av frågorna (**otestad antagelse**, inte mätt):

| | Krediter per prov |
|---|---|
| Frågorna | 198 |
| 6 långa svar | 6 × 199 = 1 194 |
| **Summa** | **cirka 1 390 (−56 %)** |

**Förslag 3: kortare långa svar.** `long_words` 90 → 70 ord gör långa svaret cirka 390 tecken. Det ger 15 × (13 + 156) = **cirka 2 540 krediter (−20 %)**. **Kräver Deangelos ja**, eftersom det ändrar innehållet och A-svarets djup. D176 visar redan längden per fråga.

**Förslag 1 och 2 tillsammans med 3:** 198 + 6 × 156 = **cirka 1 130 krediter (−65 %)**.

**Inte föreslaget, eftersom det ändrar rösten:** Flash v2.5 kostar hälften (0,20, mätt) men låter annorlunda. Valet D151 gäller, och Flash finns redan som röst C.

**Min rekommendation:** förslag 1 först. Det ändrar varken röst, text eller väntetid, och det tar bort kostnaden för prov som aldrig spelas. Mät sedan, utan att lagra något per prov, hur ofta tryck 1 eller 2 används, innan förslag 2 eller 3 prövas.

## Tester och kostnad
- **Tester:** 608 gröna, `check` ren. Nya tester: kön (O61 fynd 2) och testlägena. Texttesterna är uppdaterade.
- **Kostnad ElevenLabs:** 0 krediter.
- **Kostnad Claude:** 0.
- **Användarbehörighet (User Read):** Aron lägger till den själv. Morgonrapporten läser saldot så fort nyckeln får det.

## Till andra
- **Oscar och Toby:** lägena `unavailable` och `slow` i `x-earmind-test`. Oscars o56-fall "nekas när ljudet inte är klart" går nu att köra med `slow`.
- **Angela:** texten i 402 är Kellys. Appen kan visa `error.message` som den är.
- **Deangelo:** ja eller nej till förslag 1, 2 och 3.
