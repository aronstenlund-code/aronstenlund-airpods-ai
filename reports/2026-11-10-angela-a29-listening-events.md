# A29 – Händelser för mikrofonen och Mer?-fönstret, Tobys T7 (Angela, 2026-11-10)

Det här är en stående uppgift enligt `docs/PLAN.md` 2b och har en egen punkt i kön. Underlaget är Tobys T7, fynd 3
(`reports/apptest/2026-11-10-0815-toby-t7-more.md`): han vill ha en händelse för "fönstret öppet" och "mikrofonen
öppen", eftersom det är stabilare än att läsa loggtext. **Ändringen är kod och enhetstester. Inget är provat på
telefon.**

## Vad som gjordes
`ListeningModel.listeningEventObserver` är en ny observatör som får fyra händelser med tid:

| Händelse | När | Samma tillfälle som loggraden |
|---|---|---|
| `micGated` | igenkänningen stängs medan Lumen talar (D82) | "STT input gated (own speech)" |
| `micOpen` | igenkänningen öppnas igen | "STT input open" |
| `moreWindowOpen` | Mer?-fönstret öppnas (A15) | "More? window open (A15)" |
| `moreWindowClosed` | Mer?-fönstret stängs (tyst, skakning, tryck, ja) | "More? window closed (…)" |

- Mikrofonhändelserna kommer från en ny krok, `TranscriptionCoordinator.onInputGate`. De gäller därför alla vägar som
  öppnar mikrofonen, även säkerhetsspärren från A21.
- Observatören är **separat** från `sessionObserver`. Tobys `AudioChainE2ETests` och studieinspelningen går igenom
  `SessionEvent` i en `switch` utan `default`. En ny `case` där hade gjort att hans test inte kompilerade, och hans
  filer rör jag inte.

## Tester
`LumenTests/A29Tests.swift`:
- igenkänningen stängs för svaret och öppnas efter det (`micGated` före `micOpen`);
- händelsernas namn är samma ord som loggraderna.

## Till Toby
Byt loggläsningen i T7b mot det här:

```swift
model.listeningEventObserver = { event, date in
    // .micGated, .micOpen, .moreWindowOpen, .moreWindowClosed
}
```

Fönstret ska öppnas efter `micOpen` (A21, rättat i `6133e6c`).

## CI
Grönt i CI: iOS build 42807652449 (`2115a3d`, med A28, A29 och A30). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna. Det första testet väntade på `micOpen` efter ett riktigt svar. Det föll i 42803935391, eftersom testernas falska uppspelning aldrig säger att den är klar: den riktiga vägen väntar på det i upp till 30 s. Testet styr nu spärren direkt.
