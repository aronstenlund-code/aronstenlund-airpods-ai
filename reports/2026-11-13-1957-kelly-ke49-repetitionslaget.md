# Kelly Ke49: design för repetitionsläget (D142–D146)

Datum: 2026-11-13 19:57. Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke49, spec
`docs/design/repetitionslage.md`.

## Vad som gjordes
- **Designunderlag** till Angela (A79, A80, A81): `docs/design/repetition.md`. Det innehåller en jämförelse med
  Quizlet, Anki, StudySmarter och poddappar, flödet, 18 skärmar med det viktigaste för varje, regler för hela läget,
  sidans text och frågor till Deangelo och Angela.
- **18 skisser**, ljust och mörkt, i `docs/design/bilder/repetition/`: `hem`, `hem-tom`, `material`, `analys`,
  `sammanfattning`, `fragor`, `fragor-andra`, `redigera`, `kontroller`, `kontroller-klar`, `kontroller-saknas`,
  `spelar-tank`, `spelar-svar`, `spelar-paus`, `lasskarm`, `fortsatt`, `dela` och `fler-lagen`. Källan är
  `docs/design/_src/repetition.html`, som renderas med `docs/design/_src/repetition-render.js`.
- **SYSTEM.md §11:** BETA-märket, färgerna `ok`/`okSoft` (bara för klara bockar), tryckprickarna ●/●●/●●● och Avsluta
  på uppspelningen.
- **DECISIONS:** raden Ke49 (design inom D142–D146).

## Designbeslut (mina, inom Arons ram)
1. **Hem:** Starta prov är den enda blå knappen, på provkortet. Fler lägen (BETA) ligger längst ner. Hemskärmen har
   ingen mikrofon och inget "Starta Earmind".
2. **Kort svar redigeras inte som ett eget fält.** Det är den markerade första meningen i det långa svaret (D145), så
   de två svaren kan aldrig säga emot varandra.
3. **Kontrollskärmen visar en sak i taget** ("Tryck två gånger nu") med en grön bock per tryck som kommit fram. Ett
   tryck som saknas är grått med "Kom inte fram", inte rött. Därefter visas instruktionen för lurar med dubbeltryck per
   lur. Användaren får ingen fråga om modell.
4. **Uppspelningen har inga svarsknappar på skärmen.** Man styr med AirPods. Frågan visas stort, betänketiden som en
   ring och trycken som en tyst rad. Avsluta är stor och neutral och frågar inte "Är du säker?", eftersom platsen sparas
   och "Fortsätt där du var?" kommer nästa gång.
5. **Låsskärmen:** titeln är frågan, artisten är "Earmind · provet · 7 av 20" och bilden är appikonen.
6. **BETA** är en grå kontur, alltså märkning och ingen varning.
7. **Demosidan ändras inte nu.** Specen §7 säger "efter A81", och sajtens regel är att inget visas som inte är provat
   på telefon. Texten ("Plugga med AirPods utan att röra mobilen. …") står klar i `repetition.md` §5.

## Testresultat
- Skisserna är renderade i Chromium (playwright-core med lokal chromium-1243) och kontrollerade visuellt. Ett fel
  rättades: knappen i tomt läge fick ikonrutans stil.
- **Inget är byggt eller provat på telefon.** Allt i appen är **untested assumption** tills A79–A81 finns och Toby kört
  T18.
- Jämförelsen med andra appar är **ej verifierad** mot dagens App Store-versioner.

## Kända problem och risker
- **Specen räknar 3 × N ljudfiler** (R5b, §3 "54 av 90"). Med D145 är det 2 × N (fråga och långt svar). Skisserna
  använder 2 × N ("36 av 40"). Deangelo bör rätta specen.
- **Inställningsvägen för AirPods 1/2** ("Inställningar › Bluetooth › ⓘ › Dubbeltryck") är **ej verifierad i iOS 26**.
- **"Kom inte fram" efter 8 s** är ett förslag. Hur länge iOS väntar för att skilja trycken åt är ej verifierat.
- **Låsskärmens knappar** (⏮ ▶ ⏭) är ej verifierade. iOS ritar spelaren efter de kommandon som är på.

## Kvar
- Granska A79–A81 när skärmbilderna finns (scenerna står i `repetition.md` §7).
- Demosidan efter T18 (text i §5). Demorutan byts mot en ljudspelare med tre exempelfrågor (ljudet görs av Kevin i K48
  eller efter T18).

## Nästa session
Kön har inget mer till Kelly. Väntar på A79–A81 för granskning.
