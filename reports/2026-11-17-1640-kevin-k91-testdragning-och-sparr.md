# Tobys "krediterna går inte ner", Oscars testspärr och K90-livetestet igen (Kevin, moln)

2026-11-17 16:40 UTC. 0 ElevenLabs (D180).

## 1. Dras riktiga konton? Ja. Testhuvudet dras också.
- **Testtrafik dras precis som riktiga konton.** Det finns ingen gren för testhuvudet i räkningen
  (`saveDrill`: `cost` → `useQuota`). Live med `x-earmind-test`: mitt K90-test drog 72 av 72 (körning 44095203779),
  och Oscars O76 drog 700, 150 och 500 och gav sedan tillbaka 500 (**verified live**).
- **Riktiga konton** går samma väg, utan något villkor på testläge (**verified in code**).
- **Varför Tobys kapsel stod på 1 500:** T36 använder samma texter i varje körning. Ljud med teströsten för exakt
  samma text finns redan sedan förra körningen, och ljud som redan finns kostar 0 (D213, D144). Starten svarade
  därför `cost: 0`. Raden "Kostar 78/234 krediter" är appens egen uppskattning medan man skriver, innan servern har
  svarat (Angela Fable A131). Det är den som skiljer sig, inte dragningen. **Untested assumption** för just
  44107271098: jag fick inte läsa Tobys rader i databasen den här gången (frågan nekades). Det stämmer med koden och
  med både mitt och Oscars livetest. Samma sak förklarar 15 → 15 i 44064540048 och 44073770999 (före K90, i frågor).
- **Så ser testet dragningen:** lägg en unik bit (körningens nummer eller tid) i texten. Då räknas den som nytt ljud.
  Läs sedan `cost` i svaret på save och start (vad det kostar och vad som drogs) och `used`/`remaining` i
  `/drill quota` före och efter. `audio.cost` i get och status säger vad Starta prov skulle kosta nu.

## 2. Oscars testspärr (K91, rättat)
**Orsak:** O76 tar bort sina prov. Vid `delete` markerades provets filer som inte användes längre som
`unused: the drill was deleted (K64)`, också filerna som hade fallerat på kvotfel. Då försvann `audio_unavailable`, så
`creditsOut()` inte längre såg kvotfelet och spärren släpptes. Det förklarar varför konto B drogs 30 s efter A.
**Rättat:** en fil som fallerat på kvotfel behåller sin felkod när ett prov tas bort. Nytt test: "K91 deleting a drill
keeps the out-of-credits mark". Det gäller riktiga användare också: förut kunde en borttagning släppa spärren tidigt,
vilket gav ett onödigt anrop till ElevenLabs som ändå skulle ha fått kvotfel. Ingen kostnad för användaren, för
återbetalningen fanns redan.

## 3. Kellys text (redan gjort 15:10)
"Nya krediter den 1 december." och tusental med hårt mellanslag (`thousands`).

## Tester
- `deno task test`: 672 av 672 gröna.
- **K90-livetestet igen, grönt 6 av 6** (körning 44119951267, efter deploy 44099460813 med texten och 44119539732 med K91),
  med en ny kontroll av att 402-raden slutar på "Nya krediter den 1 december." och har hårt mellanslag i tusentalen.
