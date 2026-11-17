# Kelly (moln): granskning av A132 (första skärmen, D215) på bild

Underlag: grenarna `fable/screens-a132-17pro-2` och `fable/screens-a132-se-xxxl-2` (körningar 44134068250 / 44134073959,
bfc25d1), mot `docs/design/forsta-skarmen.md` (Ke72). **Simulatorn, inte enhet.**

## iPhone 17 Pro, ljust och mörkt: godkänt
Ingen rubrik, fältet först, "Spela i 10 min" fylld bara med text (Starta prov tonad då), kostnaden "120 krediter" och
"120 krediter · du har 88" ovanför knappen, Senaste som kapslar, spelar-läget med "● Spelar i AirPods", ⏸, "7:03 kvar"
och Stoppa. Säg-texter syns inte som Nästa prov. Orden stämmer.

## Fynd
| # | Nivå | Var | Fynd | Rättning |
|---|---|---|---|---|
| G1 | **hög** | SE största text, repSayCredits | Bilden visar **iOS hemskärm** i stället för appen: scenen startade inte eller appen kraschade. | Ta reda på om appen kraschar i största text med text i fältet (kör scenen igen, titta i kraschloggen). |
| G2 | **hög** | SE största text, repHomeSaid, repSayCreditsShort, repSayOnCard | Kortet är **bredare än skärmen**: texten kapas till vänster ("u kan låsa telefonen", "aste", `+` halvt synligt) och "Spela i 10 min" kapas till höger. "Stoppa" bryts "Stop/pa". | Staplingen i §6: `+`, ⏱ och tempo på en rad, kostnaden under, Spela i full bredd på egen rad (`ViewThatFits` eller `dynamicTypeSize.isAccessibilitySize`). Kortet får aldrig vara bredare än skärmen minus 2 × 16 pt. Stoppa på egen rad under tiden. |
| G3 | medel | 17 Pro, alla | Det tomma utrymmet där rubriken "Prov" satt (cirka 40 pt mellan kapseln och kortet) är kvar. | Kortet direkt under raden med kapseln (cirka 8 pt), så att utrymmet går till kortet (D215.7). |
| G4 | låg | 17 Pro, repHomeCredits | Kapseln säger "312 frågor kvar" (gammal scendata). | Scenen ska ge krediter. |

Klistra in-läget (urklipp med text) är inte på bild; simulatorn har inget urklipp. Toby i T46.
