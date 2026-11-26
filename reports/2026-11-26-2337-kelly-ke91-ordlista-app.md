# Ke91: ordgenomgång av appen, engelska först (Kelly (moln))

## Gjort
- **`docs/design/ordlista-app.md`:**
  - en tabell med ett ord per sak;
  - de tio viktigaste ändringarna, nuvarande → förslag;
  - tabeller per skärm: första starten, Start, Säg i AirPods, Nytt prov, provet, krediter, Spela in själv, lyssnarvyn, Hem och Inställningar.
- **Underlag:** alla 1 728 texter i String Catalog, kopplade till de Swift-filer som visar dem (132 filer), ord räknade över alla engelska texter, och bilderna från A164–A166 och Ke90.
- **De tio viktigaste står i köerna:** (1)–(3), (8)–(10) hos Angela Schrute; (4)–(10) hos Angela Fable.
  1. Svenska röstkommandon i den engelska appen (25 texter).
  2. "Lumen" står i 32 engelska texter där appen menas.
  3. "EarMind can do anything" lovar för mycket.
  4. sound och audio blandas.
  5. Två enheter syns: frågor kvar och krediter.
  6. Kostnaden skrivs på fyra sätt.
  7. Make och Create blandas.
  8. Stavning: practise, BETA, "Privacy & consent".
  9. "Photograph" i stället för "Snap your textbook".
  10. Tempo i stället för Speed.
- **Rättat på min sida:**
  - Sajten (`/`): "Press once …" i stället för "Tap once …", och "new audio" i stället för "new sound".
  - App Store-bild 7 heter nu "Press for the answer." (README och `appstore.py`).

## Påståenden
- **Verifierat i dokument:** orden och antalen i String Catalog.
- **Untested assumption:** att utvecklarraderna i Inställningar syns i Release. Det har jag inte kontrollerat, så jag ber Angela Schrute kontrollera.
- En sanningsfråga, inte en ordfråga, till Fable: "You can lock your phone. You'll still hear it in your AirPods." är inte provad på telefon (D209).

## Nästa
- Fable och Angela ändrar sina texter.
- Kelly läser A167:s bilder när de kommer.
- Ingen appkod är ändrad. 0 ElevenLabs.

## Sajten live: väntar på Vercel (inte på mig)
- Ändringen (Press, audio) ligger på main (`2a0d6ef4`). Grenen `kelly/ke66-earmind-site` ger nu bara förhandsversioner: **Vercels produktion byggs från `main`** (verifierat i Vercel, deploy `dpl_E8ECy9…` från main `ddf41012`).
- **Vercel har inte byggt något main-commit sedan 22:33 UTC**, trots flera pushar efter det. Kontrollerat med kelly-site-check 45905958105, 45906029389, 45906360145 och 45907030714: alla visar den gamla `/` på 42 235 byte, och den nya är 42 237.
- **Untested assumption:** Vercels gräns på antal byggen per dag. Med Hobby-planen 100 per dag, och varje push till main bygger.
- Sajten är oförändrad och fungerar: 200 och 393 px på alla tre adresserna. Ändringen kommer ut vid nästa bygge från main.
- Till Deangelo: om gränsen slår till ofta kan Vercel få en "Ignored Build Step" som bara bygger när `site/` har ändrats (`git diff --quiet HEAD^ HEAD -- site/`). Det är en inställning i projektet, så den görs av Aron eller med hans ja.
