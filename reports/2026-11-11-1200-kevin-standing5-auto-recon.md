# Stående uppgift, omgång 5: Auto byter inte ämne när frågan har egna (felhörda) ord (Kevin, 2026-11-11 12:00)

Fynd: Tobys T5b c1, till Kevin (`reports/apptest/2026-11-11-1045-toby-t5b-t7b.md` fynd 4).
- Eleven sa "Vilka är de största? Bargern i världen." (felhört "bergen"), och förra svaret handlade om solsystemet.
- Auto skrev om frågan till "Vilka är de största planeterna i solsystemet?" och svarade om planeter.

**Kostnad:** cirka 0,34 USD.
- Regressionen för `e2b21f5`: 0,32 USD, resultat räcker **95.2 %**.
- 18 anrop i Auto med Haiku: cirka 0,01 USD.
- ElevenLabs: 0.

## Ändring (`answer/prompt.ts`, Auto-promptens `reconstructed_question`)
- recent_qa fyller bara i ett ämne som **saknas**.
- Har fragmentet egna ämnesord, även felhörda, rättas de till närmaste riktiga ord som passar resten av fragmentet och byts aldrig mot förra ämnet.
- **Första versionen hade ett exempel** ("Bargern i världen" = bergen), och exemplet läckte. "Vilka är de största?" ensamt efter en fråga om öknar blev "de största bergen". Exemplet är borttaget.
- Prompten är 15 621 tecken. Längdtestets gräns är höjd från 15 500 till 15 650. Prompten cachas, så det kostar nästan inget.

## Mätt live (Auto, ett förra svar om något annat ämne i `recent_qa`)
| | Före | Med exempel | **Utan exempel** |
|---|---|---|---|
| Tobys fall "Bargern i världen" | planeter (fel) | bergen | **bergen** |
| Floderna i Afrika, stan i Sverige, benen i kroppen | 3/3 | 3/3 | **3/3** |
| Riktiga följdfrågor ("Vilka är de största?" ensamt, "Och den minsta då?") fyller i från förra svaret | 2/2 | 1/2 (läckte) | **2/2** |
| **Summa** | 5/6 | 5/6 | **6/6** |

Rådata: `reports/eval/2026-11-11-1154-k-standing5-recon-before.json`, `…-1158-…-after.json` och `…-1200-…-after2.json`.

## Ej verifierat
Scribes felhörningar i appen, och tiden till anropet (12–22 s i Tobys körning). Tiden är Angelas fynd (A21).
