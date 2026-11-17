# Kelly (moln) Ke76: underlag till App Store-granskningen (D218 punkt 4)

## Vad som gjordes
`docs/appstore/granskning.md`:
1. **Texter** på svenska och engelska: namn, underrubrik, reklamtext, nyckelord (tecken räknade) och beskrivning efter
   appen i dag (Säg i AirPods först, fota boken, Starta prov, dela, krediter, Fler lägen i beta). Inget om låst skärm, eftersom
   D209 inte är provat; inget som antyder dold användning. Varje påstående har status [V]/[S]/[O].
2. **App Privacy:** spårning nej; samlas in: användar-ID (anonymt konto), användarinnehåll (texter, frågor och svar; foton
   bara för behandling), ljuddata bara i Fler lägen (strömmas till ElevenLabs), köphistorik (när köpen finns),
   produktinteraktion (usage-rader utan text). Inte: diagnostik, kontakter, kalender, plats, e-post i appen.
3. **Granskningsanteckningar** på engelska: Säg i AirPods är synlig uppspelning med vald tid (10–60 min), ingen fördröjd
   eller dold uppspelning; Starta prov utan mikrofon; Fler lägen med samtycke och lyssningsindikator (D21); krediter och
   veckokortets villkor; testkonto: "Aron lägger in", inga lösenord i repot.
4. Åldersgräns, kategori, URL:er och exportfrågan som förslag.
`README.md` pekar nu på `granskning.md`.

## Måste rättas eller beslutas före inskickning
1. **Hög: testläget (D140) skickar bakgrundsljud till oss när det är på.** Det ska bara finnas i TestFlight/Debug, annars
   måste det deklareras. Till Deangelo/Angela Schrute.
2. **Kamerans text i Info.plist är fel:** "The text is read on the iPhone" stämmer inte (fotona skickas till servern).
   Ny text föreslagen i granskning.md §2. Till Angela Schrute.
3. Rapporterade frågor (D135) och minnen i Fler lägen: om de sparas på servern ska de deklareras (overifierat).
4. **Integritetspolicy saknas** (krävs). Jag kan skriva en sida på earmind.vercel.app.
5. Åldersgräns med Rizz-läget: Arons svar i frågeformuläret.
6. Ordet "Obegränsat" för veckokortet med ett tak (Ke73).

## Test
Dokument. Fakta lästa i DECISIONS, ARCHITECTURE, Info.plist och koden (grep). Inget provat på telefon.
