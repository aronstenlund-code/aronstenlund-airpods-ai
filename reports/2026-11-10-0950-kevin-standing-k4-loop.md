# Kevin, stående uppgift (K4-loopen), omgång 1, och Oscars O20/O13

Datum 2026-11-10 09:50 · Stående uppgift enligt `docs/PLAN.md` 2b: kör eval, rätta det sämsta fallet, mät igen · Driftsatt (Deploy backend 42785006211, commit 9c207d8) · **Verified live** genom regressionsjobbet (K4.1). **Inte testat på telefon.**

## Det sämsta fallet och vad som rättades
- **D87 pl-127 "sannolikhet" (åk 9)** föll på språket. Modellen skrev "en 5:a" och "1/6", och vår siffror-till-ord läste det som **"en femte"** och **"ett/sex"**.
  - Rättat i `svnum.ts`: "en 5:a" läses "en femma" (efter en, ett, någon, varje, slår, fick …).
  - Bråk upp till tiondelar läses som ord: "en sjättedel", "två femtedelar".
  - "5:e plats" är fortfarande "femte".
- **Oscars O20** (webbstyrningen, offline):
  - partikelverb räknas som instruktioner ("hur stänger man av …", "hur laddar man ner …", "hur tar man en skärmdump");
  - "får man cykla på trottoaren" är en regelfråga, men "får man en kram" och "får jag fråga en sak" är det inte;
  - recept och instruktioner söker **bara** i sina egna källor (inte SVT);
  - webbtaket är 5 per minut, så att ett recept och två följdfrågor ryms.
- **Oscars O13:** tabellstreck och engelska fältnamn från en sökning ("| Arjeplog |", "Nickname: …") läses aldrig upp.

## Mätt igen
Regressionen (21 fall ur D87, Sonnet svarar och bedömer, commitkommentar på 9c207d8): **första svaret räcker 21/21 (100 %)**, språk 100 %, första text p50 1 029 ms. Förra körningen var 95,2 % (cff70e7), alltså samma 21 fall före rättningarna och före förebilderna.

## Tester
Nya fall i `answer/k16_test.ts`: tal som substantiv, bråk, O20:s fyra frågor och tre falska regelträffar, domänlistorna och tabellstreck. Hela `answer` är 293 gröna. Actions är grönt.

## Kostnad i dag och vad som väntar
- **API i dag: cirka 6,1 USD.** Det är något över riktmärket 6 USD, eftersom regressionsjobben körde på varje driftsättning (cirka 0,3 USD var). Jag kör inga fler betalda mätningar i dag.
- **Väntar:**
  - K18 del 2 (uttalet) väntar på ElevenLabs-krediterna (slut sedan 07:45).
  - K6 (roliga röster, lägst prioritet) behöver också ElevenLabs.
  - K4.3 natten väntar på hemligheten `SUPABASE_SERVICE_ROLE_KEY`.
