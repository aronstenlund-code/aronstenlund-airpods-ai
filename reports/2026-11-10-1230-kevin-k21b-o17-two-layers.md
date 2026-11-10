# Kevin K21b: krisfilter i två lager efter Oscars O17

Datum 2026-11-10 · Underlag: `reports/qa/2026-11-10-0848-oscar-o17-k21-kris.md` (K21 fångade 16/30 av Oscars fall, och de missade var tysta i Auto; 12/30 falska larm) · Driftsatt (Deploy backend 42779845847, commit 34f9a49) · **Verified live** (`scripts/k21-eval.py`, Oscars 30 + 30 fall i Auto och mina 20 + 20 fördelade på lägen). **Inte testat på telefon.**

## Resultat
| | Före (O17) | Efter |
|---|---|---|
| Oscars 30 krisfall (i Auto) | 16/30 | **30/30** |
| Oscars 30 vardagsfall | 12/30 falska larm | **0/30** |
| Mina 20 krisfall (Auto, Frågor, Provläge, Socialt) | 20/20 | **20/20** |
| Mina 20 vardagsfall | 0/20 | **0/20** |
| Tysta svar eller fel | 14 tysta | **0** |

**Viktigt:** Oscars 60 fall finns nu i testerna (`scripts/k21-crisis-cases.json`, `k21_test.ts`), som han bad om. De är alltså inte längre ett oberoende test. **Till Oscar:** gör gärna en ny uppsättning (O17b) med fall jag inte har sett.

## Hur det fungerar nu (tillägg till D101)
1. **Starka träffar i kod** ger svaret direkt, utan modellanrop. Täcker:
   - fyllnadsord ("jag vill typ inte leva", "orkar inte ens leva");
   - talspråk och hörfel ("ja orka inte leva", "läva");
   - omvänd ordföljd;
   - självskada i alla tempus ("skadar mig själv", "har skurit mig igen");
   - "aldrig vakna" och "slippa vakna";
   - "ingen skulle sakna mig om jag dog", "trött på att leva", "göra slut på allt";
   - "självmord" med "utväg", "tänker" eller "vill";
   - engelska och slang.
2. **Vardagsuttryck tas bort först:**
   - "inte leva i/på/som …";
   - "kan inte leva med att ha fel";
   - "dö av skam", "dör om jag inte får mat", "dog i spelet";
   - "skära mig en skiva", "när jag rakar mig";
   - "låten heter …";
   - "självmordstankar hos ungdomar";
   - "kms lol".

   Finns en tydlig signal kvar efteråt är det en stark träff.
3. **Svaga träffar** är jag-form med ett ord om liv, död, att vakna, att försvinna eller skada, eller ett starkt mönster som bara ett vardagsuttryck förklarar. De ger först en ja/nej-fråga till Haiku (5 token, tidsgräns 4 s). "ja" ger svaret och "nej" den vanliga vägen. **Felar frågan ges svaret**, aldrig tystnad.
4. "min kompis säger att han inte vill leva längre" ger raden om hur man hjälper en annan person.

## Kostnad och tid
- Starka träffar och vanliga meningar kostar inget extra.
- En svag träff kostar ett litet Haiku-anrop (under 0,0001 USD) och cirka 0,3–0,8 s innan svaret börjar. Det gäller bara meningar med jag-form och sådana ord, till exempel "jag vill leva länge".
- Mätningen kostade under 0,05 USD.

## Risker
- Mönster och en liten modell kan fortfarande missa nya formuleringar. Varje miss ska in i fallfilen.
- Är Haiku nere eller långsam får svaga träffar krissvaret (säkert, men det kan kännas fel i en vardagsmening).
- Taligenkänningen är inte provad med riktigt ljud. Dessutom är ElevenLabs-krediterna slut i dag, så Scribe går inte.
