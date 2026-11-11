# T5: omtest efter A8 och A11 i simulatorn (inte verifierat på enhet)

No T5 results found.
# T15: den väntande frågan (simulator, inte enhet)

Besvarade 8 av 12. Sessionen: 464 s, `answering=false speaking=false listening=true`.

## Fallen

| Fall | Sagt | Ställt | Svar | Utfall |
|---|---|---|---|---|
| q4a | Vad är tjugotre gånger fyra? | – | 0 | not heard |
| c1a | Vilka är de största | bergen i världen? | – | 0 | not asked |
| c3a | Vad är skillnaden mellan ett virus | och en bakterie? | – | 0 | not asked |
| q4b | Vad är tjugotre gånger fyra? | – | 0 | not heard |
| c1b | Vilka är de största | bergen i världen? | Vilka är de största? Barien i världen. | 1 | asked without the continuation |
| c3b | Vad är skillnaden mellan ett virus | och en bakterie? | Vad är skillnaden mellan ett virus? | 1 | asked without the continuation |
| q4c | Vad är tjugotre gånger fyra? | Tre gånger fyra. | 1 | ok |
| c1c | Vilka är de största | bergen i världen? | Vilka är de största? Barierna i världen. | 1 | asked without the continuation |
| c3c | Vad är skillnaden mellan ett virus | och en bakterie? | Vad är skillnaden mellan ett virus... | 1 | asked without the continuation |
| q4d | Vad är tjugotre gånger fyra? | Vad är 23 gånger 4? | 1 | ok |
| c1d | Vilka är de största | bergen i världen? | Vilka är de största? Bärjen i världen. | 1 | asked without the continuation |
| c3d | Vad är skillnaden mellan ett virus | och en bakterie? | Vad är skillnaden mellan ett virus? | 1 | asked without the continuation |

## Hört → anrop per tur (appens `Turn timing`)

| t (s) | hört → anrop (ms) | väg |
|---|---|---|
| 148.7 | 1443 | answered at the pause |
| 191.4 | 20135 | answered at the pause |
| 219.5 | 0 | answered ahead |
| 272.5 | 26274 | answered at the pause |
| 313.1 | 15336 | answered at the pause |
| 339.0 | 0 | answered ahead |
| 383.0 | 14690 | answered at the pause |
| 425.9 | 19131 | answered at the pause |

**5 av 8 turer väntade över 4 s.**

## A70: "A question waits 3 s" (ordagrant)

Ingen rad.


## Röstens slut → mikrofonen öppen

| röst slut (s) | STT input open (s) | skillnad (s) |
|---|---|---|
| 164.5 | 165.2 | 0.7 |
| 205.8 | 206.5 | 0.6 |
| 215.4 | 216.1 | 0.7 |
| 221.4 | 222.1 | 0.7 |
| 284.5 | 285.2 | 0.7 |
| 324.6 | 325.2 | 0.7 |
| 341.6 | 342.2 | 0.7 |
| 396.2 | 396.9 | 0.7 |
| 437.3 | 438.0 | 0.8 |

**0 av 9 öppnades mer än 1 s efter rösten.**
