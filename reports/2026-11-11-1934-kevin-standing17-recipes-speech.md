# Stående uppgift, omgång 17 (K4-loopen): recept och webbsvar lät fel (Kevin, 2026-11-11 19:34)

Fynd från kvällens live-eval och mina egna livekontroller efter omgång 16. Kostnad: cirka 0,8 USD (två regressioner och livefrågor).

## Ändringar (alla i `answer/`, test i `k_standing16_test.ts`)
1. **"Källorna är bara en vägledning, och jag ger de viktigaste stegen …"** var första meningen i svaret på "hur byter man däck". Nu sägs den aldrig (`LEAD_META`). En mening som börjar med en källa och ett faktum sägs fortfarande ("Källan är Livsmedelsverket, som …"). 
2. **"portioner. femhundra gram"**: ett tal som börjar en mening sägs nu med stor bokstav ("Femhundra gram"). Det gäller även över chunkgränser, men inte efter förkortningar som "kl." eller "nr.". 
3. **"tre dl vetemjöl", "en halv dl"**: en köksenhet efter ett talord läses nu ut ("tre deciliter", "en tesked", "tre matskedar"). "dl-mått" och "det står dl" lämnas som de är. 

## Tester
- `deno task test`: **484 gröna**. `check` är ren.
- **Regression:** 76,2 % på `4718b16`. De fem underkända fallen var alla fel i modellens innehåll (vaccin, derivata, syror, Gustav Vasa 1520), och inget av dem gällde tal eller versaler. Omkörning av samma commit: **95,2 %**, så det var brus. Efter `72a0390`: **95,2 %**.
- **Live:** "hur byter man däck" börjar nu med Clas Ohlsons första steg. Recepten på pannkakor (2) och kladdkaka har noll förkortningar i talet ("två och en halv deciliter", "tre matskedar").

## Nästa
- Tiden till första ord för webbsvar ("praktiskt") är fortfarande cirka 3,1 s (budget 2,5 s). Det beror på webbsökningen, och ingen billig fix är känd.
- I intervjuläget säger svaret "Jag har inte jobbat …", vilket evalen räknar som en påhittad personuppgift. Det kan vara en falsk flagga i evalen, eftersom CV:t säger gymnasieelev. Det är inte undersökt än.

## Till Aron
Inget nytt.
