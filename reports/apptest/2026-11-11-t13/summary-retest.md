# T5: omtest efter A8 och A11 i simulatorn (inte verifierat på enhet)

## Frågor: 10 frågor, 3 med fortsättning efter paus

**7 av 10 rätt.** Ställda 9, fall med svar 8, fall med uppläst svar 8.

- Läget när sessionen avslutades: `answering=false speaking=false listening=true`

| Fall | Sagt | Hört | Ställt | Svar | Uppläst | Utfall |
|---|---|---|---|---|---|---|
| q1 | Vad är huvudstaden i Australien? | Vad är huvudstaden i Australien? | Vad är huvudstaden i Australien? | 1 | 1 | ok |
| q2 | Hur många planeter finns det i solsystemet? | Hur många planeter finns det i solsystemet? | Hur många planeter finns det i solsystemet? | 1 | 2 | ok |
| c1 | Vilka är de största | bergen i världen? | Bara en i världen. | – | 0 | 0 | not asked |
| q3 | Vem skrev Röda rummet? | Vem skrev Röda rummet? | Vem skrev Röda rummet? | 1 | 1 | ok |
| q4 | Vad är tjugotre gånger fyra? | Vad är 23 gånger 4? | Vad är 23 gånger 4? | 1 | 1 | ok |
| c2 | Hur många invånare har | Sverige ungefär? | Hur många invånare har... / Sverige ungefär. | Hur många invånare har... / Hur många invånare har... Sverige ungefär. | 1 | 1 | ok (asked whole) |
| q5 | Vilken är världens längsta flod? | Vilken är världens längsta flod? | Vilken är världens längsta flod? | 1 | 2 | ok |
| q6 | Hur långt är ett maraton? | Hur långt är ett maraton? | Hur långt är ett maraton? | 1 | 1 | ok |
| c3 | Vad är skillnaden mellan ett virus | och en bakterie? | Vad är skillnaden mellan ett virus? | Vad är skillnaden mellan ett virus? | 1 | 2 | asked without the continuation |
| q7 | Vad betyder ordet empati? | – | – | 0 | 0 | not heard |

## Provläge: 3 frågor och ett önskemål i ett andetag

**1 av 2 rätt.** Ställda 9, fall med svar 2, fall med uppläst svar 0.

- Läget när sessionen avslutades: `answering=false speaking=false listening=true`

| Fall | Sagt | Hört | Ställt | Svar | Uppläst | Utfall |
|---|---|---|---|---|---|---|
| b1 | Vad är fotosyntes? Vad gör klorofyllet i bladen? Hur fungerar cellandningen? I framtiden ska du svara kortare. | Vad är fotosyntes? / Vad gör klorofyll i bladen? / Hur fungerar cellandningen? / I framtiden ska du svara kortare. | Vad är fotosyntes? / Vad gör klorofyll i bladen? / Hur fungerar cellandningen? / I framtiden ska du svara kortare. | 4 | 0 | ok (4 turns) |
| b2 | vad är fotosyntes vad gör klorofyllet i bladen hur fungerar cellandningen i framtiden ska du svara kortare | Vad är fotosyntes? / Vad gör klorofyll i bladen? / Hur fungerar cellandningen? / I framtiden ska du svara kortare. | Vad är fotosyntes? / Vad gör klorofyll i bladen? / Hur fungerar cellandningen? / I framtiden ska du svara kortare. / avsluta | 4 | 0 | 5 turns |

