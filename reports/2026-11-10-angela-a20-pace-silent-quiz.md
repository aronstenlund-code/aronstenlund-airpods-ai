# A20 – Talet anpassar sig och tyst förhör (Angela, 2026-11-10)

Godkänt av Aron. **Inget är verifierat på enhet; head tracking går inte att prova i simulatorn.**

## Vad som gjordes
### 1. Taltempo (`Lumen/Core/Voice/SpeechPace.swift`)
- Tempot gäller per sammanhang: läge + ämne (Provläge med provets ämne, annars läget). Stegen är 1,0 → 0,9 → 0,85
  och multipliceras med användarens egen hastighet (Inställningar › Röst), så att valet där gäller som förut.
- **Sänks av sig självt** (Provläge och Frågor):
  - 2 gånger "igen"/"va?" (A17) inom 10 minuter;
  - 3 långa tystnader (≥ 20 s) efter långa svar (≥ 25 ord) i Provläge, alltså när eleven antecknar. Tystnaden
    räknas inte om eleven har sagt något, eller om ett nytt svar har kommit.
- **På begäran:** "långsammare", "lugnare", "prata lite långsammare" (hela yttrandet, med eller utan "Lumen", bara
  bärarens röst). "Snabbare"/"fortare" höjer igen.
  - Vid fullt tempo är "snabbare" fortfarande "kortare" (A7), så det beslutet ändras inte.
  - Lumen bekräftar kort: "Jag pratar lite långsammare." / "Jag pratar snabbare igen."
- **Sparas** (`SpeechPaceStore`, UserDefaults) och syns i **Minne › Inlärda inställningar** som "Långsammare tal i
  Biologi" eller "Lite långsammare tal i Frågor". Svep bort en rad, så går tempot tillbaka till 1,0.
- `Speaker.paceFactor` ger uppspelningshastigheten (samma tidsstretch utan tonhöjdsändring som hastighetsreglaget).

### 2. Tyst förhör (`Lumen/Core/Study/SilentQuiz.swift`)
- **Start:** "Lumen, tyst förhör" (även "förhör mig tyst") i Provläge, eller länken "Tyst förhör: svara genom att
  nicka" på lyssnarskärmens tomma läge.
- **Början:** Lumen säger "Tyst förhör. Nicka för ja, skaka på huvudet för nej. Säg Lumen, sluta när du vill sluta."
  Saknar AirPods huvudrörelser: "Dina AirPods känner inte av huvudrörelser. Svara ja eller nej med rösten."
- **Under förhöret:** frågorna kommer som en instruktion till backend (nivå 2: en ja-eller-nej-fråga; efter svaret
  "Rätt"/"Fel", en mening och nästa fråga). Efter varje fråga lyssnar appen 10 s efter en nick eller skakning
  (`HeadMotionListener`, D86). Den blir "Ja"/"Nej" som en vanlig Provläge-tur, och "ja"/"nej" med rösten fungerar
  också. Utan svar: "Nicka för ja eller skaka för nej." en gång, sedan slut.
- **Slut:** efter 10 rättade frågor, efter 2 frågor i rad utan svar, eller när eleven säger "Lumen, sluta" (det
  första "sluta" avslutar förhöret, nästa avslutar Provläge). Lumen säger "Tyst förhör klart. N av M rätt."
  Poängen räknas från svar som börjar med "Rätt"/"Fel"/"Inte riktigt".
- **Skärmen:** "Tyst förhör, fråga 3 av 10. Nicka för ja, skaka för nej." och raden "Säg ”Lumen, sluta” för att
  avsluta förhöret". "Mer?" (A15) och D83:s egna ja/nej-lyssning är avstängda under förhöret.
- `docs/COMMANDS.md`: två nya rader (Taltempo, Tyst förhör).

## Tester
- `LumenTests/A20Tests.swift`:
  - stegen upp och ner;
  - talade önskemål, 5 + 3 positiva fall och 3 negativa ("hon sprang snabbare än han");
  - 2 "igen" inom 10 min jämfört med längre isär;
  - 3 antecknings-pauser;
  - Minne-raderna;
  - lagret (en rad per sammanhang, sparas, 1,0 sparas inte);
  - förhörets bokföring (frågor, rätt/fel, sammanfattning, två missar, startfraser).
- **CI:** grönt, run 42773767993.

## Kända begränsningar
- **Rätt/fel-räkningen** bygger på att backend börjar med "Rätt"/"Fel". Gör den inte det blir sammanfattningen
  "Tyst förhör klart." utan siffror. Kevin får gärna låsa formatet för `Tyst förhör:`-instruktionen (Till Kevin via
  Deangelo).
- **Anteckningsregeln är en gissning** (20 s, 25 ord, 3 gånger). **Untested assumption**; Aron får säga om den
  slår till för ofta.
- **Huvudrörelser** mäts bara på riktiga AirPods (Pro, 3 och 4, Max).

## Till Aron
- Prova tyst förhör på bussen: säg "Lumen, tyst förhör" i Provläge och svara genom att nicka eller skaka.

## Kvar
- Toby: lägg till taltempo och tyst förhör i snabbtestet (`docs/DEVICE-TEST-QUICK.md`).

## CI
Grönt i CI: iOS build run 42773767993 (commit bda589a): bygget för enhet (varningar = fel) och alla LumenTests gröna.
