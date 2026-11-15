# Skärmturen (T3) efter A94/A100: var den fastnar

Toby (moln), 2026-11-15 07:20–14:35. Grenen `toby/screens-a94`. Simulatorn, **inte enhet**. Falskt ljud (`LUMEN_TEST_HEADER`), 0 ElevenLabs.

## Utgångsläget
Nattens tur på main (`apptest-screens.yml`, 03:30) är röd sedan A94 (2026-11-14). Den letar efter det gamla introt
("Testa nu", "Fråga vad som helst"), och varje senare steg missar därför också.

## Vad som är rättat på grenen
- **A94:** första starten Välkommen → Fortsätt → Nytt prov → Senare. *Verifierat i 43684803165:* inga missar i introt.
- **A101:** "EarMind" med stort M i alla etiketter (gamla stavningar finns kvar som alternativ).
- **D180:** `LUMEN_TEST_HEADER=1` för allt turen gör.
- **A100:** turen gör först ett prov (Gör med ChatGPT → Spara frågorna → Starta prov → Avsluta), så att Fler lägen finns.
  Lägena och Provläge öppnas från Fler lägen-sidan, och inställningarna från Start.

## Var den fastnar (43711820117, avbruten efter 85 min på Deangelos begäran)
- **pro-light** blev klar på 37 min. Kvar:
  - "APP: A50 'Fler lägen' is still on Start": en gammal kontroll från A50 som A100 vänder på. Den ska bort.
  - Fler lägen-raden hittades inte en gång, 8 svep.
  - Inställningsraderna Avancerat, Röstkommandon, Minne, Historik, Studiekort, Egna kommandon, Feedback och förslag,
    Om appen och Diagnostik hittades inte, och inte heller Klar. Turen läser troligen fel blad eller sida.
  - "Lyssnar did not open" för Frågor och Provläge: samtyckesbladet (`ConsentView`) och mikrofonfrågan kommer nu
    när ett lyssnande läge startas första gången (A94). Turen svarar inte på dem där.
- **pro-dark-storsta-text** hängde i över 45 min utan utdata och avbröts. Var den hängde syns inte: loggen kommer
  bara per läge, och artefakterna går inte att hämta härifrån (proxyn nekar blob-värden).

## Bedömning
Turen är byggd för appen före D142/A94/A100, när lyssningen var Start. Att få den grön kräver en omskrivning av
lägesdelen och inställningsdelen. Det är BETA-sidan och ska enligt prioriteringen göras sist. Repetitionsflödets
skärmar täcks under tiden av Angela Schrutes Debug-scener (`apptest-states.yml`) och av T24 och T27.

- Grenen förs **inte** till main: där tar turen cirka 60 min, här kan den hänga.
- A94 och A101 i kön får stå kvar som "delvis" tills turen är omskriven.

## Nästa
- Ta bort A50-kontrollen "Fler lägen still on Start".
- Svara på `ConsentView` ("Jag förstår, starta EarMind") och mikrofonfrågan när ett läge startas.
- Läs inställningarna efter A87:s systemstil.
- Kör ett läge i taget (pro-light) tills det är grönt.
