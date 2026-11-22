# O97 – när modellens krediter är slut: appens och webbens egna ord (Angela Schrute, moln, 2026-11-22 12:50)

Uppdrag: Deangelo 12:40, Kevins rad (deploy 370). När modellen bakom EarMind har slut på krediter, är upptagen eller
nere svarar `/answer`, `/exam` och `/drill` 503 (eller 502) med en `provider_*`-kod och `fallback: true`.

Märkning: **[CI]** = verifierat i GitHub Actions eller huvudlös Chromium här · **[kod]** = läst i koden ·
**[antagande]** = otestat. Låtsasserver i alla tester, 0 ElevenLabs. Inget provat på telefon.

## 1. Vad som är gjort

**Webbetan (`web/`, byggd till `site/beta/`):**
- För alla `provider_*`-koder visar sidan sin egen korta text på valt språk: **"EarMind can't answer right now. Try
  again in a while."** / **"EarMind kan inte svara just nu. Försök igen om en stund."** – aldrig serverns `message`.
  Gäller Spela, Nytt prov (frågorna och svaren), Starta prov, Open link och lyssnarläget, också när modellen ger upp
  mitt i ett svar (felhändelsen i svarsströmmen).
- Efter ett sådant nej startas och sparas ingenting, och raden om köp ("Purchases come with the iOS app.") visas inte:
  det är inte användarens krediter som är slut.

**iOS-appen:**
- Ett nekat nytt prov (`/exam`) och ett nekat sparande eller startande (`/drill`) säger nu **"EarMind kan inte svara
  just nu. Försök igen om en stund."** (engelska: "EarMind can't answer right now. Try again in a while.") i stället
  för serverns text respektive "Det gick inte att skapa frågorna. Försök igen.".
- **Fel jag hittade på vägen:** provets kort sa "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt." för
  varje 503 från `/drill`. Den raden handlar om rösten. Är det modellen som är nere säger kortet nu den nya raden
  (`CloudDrillAudio.problemLine`).
- **Valt språk skickas med** som `x-earmind-lang` (A157:s val i Inställningar) i `/answer`, `/exam`, `/drill`, `/help`
  och `/purchase`, så att serverns övriga ord (gränser, nej) följer valet och inte telefonens språk.
- De upplästa svaren gick redan på koden ("Jag kan inte svara just nu …", `ListeningModel.problem`); inget ändrat där.

## 2. Krediter för misslyckade svar

Varken appen eller webben räknar krediter själva; servern räknar tecken nytt ljud när ljudet görs **[kod]**. Det jag
kan visa från klienterna: efter ett `provider_*`-nej gör de inga fler anrop som skulle göra ljud (webben: testerna
kontrollerar att varken `save`, `start` eller `status` följer; appen: ett nekat prov sparas inte). Att servern inte
drar något när modellen nekar före ljudet är Kevins sida; hans O97-rapport säger inget uttryckligt om det, så jag har
bett honom bekräfta (rad i hans kö).

## 3. Test

- **Webben, test först:** 6 nya tester kördes röda (6 failed | 102 passed) och sedan gröna (108 passed). Provkörningen i
  Chromium har ett nytt scenario med en låtsasserver vars modell är nere (serverns text är med flit teknisk): Spela och
  Nytt prov visar den egna raden, på svenska efter SV, och inget startas efteråt. 66 kontroller gröna. **[CI]** Web beta
  45019046787 grön på grenen; webbdelen ligger på main (e740b985).
- **Appen, test först:** tre tester mot koden som den var gick ensamma till grenen `angela/o97-test-rod`
  (iOS build 45018951753, väntat rött: **pågår när detta skrivs**). Med rättningen och tre tester till (kortets rad,
  språkhuvudet, koderna): iOS build 45019046853, **pågår när detta skrivs**. Appdelen ligger på grenen
  `claude/fervent-fermi-34hrer` och går till main först när bygget är grönt; resultaten fylls i då. Testerna körs på svenska, som resten av sviten.
- **Inte testat:** på telefon; mot riktiga servern (Kevin har visat 503 `provider_quota` live, Oscar kan prova sidan).

## 4. Kvar

- Kelly publicerar den nya `site/beta/` (rad i hennes kö).
- Grenen `angela/o97-test-rod` behövs inte mer; jag tar bort den om du säger till (jag raderar inget på eget bevåg).
- A149 väntar på Arons telefonprov.
