# Stående uppgift, omgång 18 (K4-loopen): intervjuläget hittade på arbetserfarenhet (Kevin, 2026-11-11 19:37)

## Fynd
I kvällens live-eval gällde fallet cv-04: bara en jobbannons, inget CV.
- Frågan var "har du jobbat med kassa förut".
- Svaret blev "Jag har inte jobbat med kassa tidigare …".
- Det är en påstådd personuppgift åt eleven, och CV:t säger ingenting om saken. Det strider mot regeln från K1.5 (Oscar D81–D84), som redan gäller körkort, ålder, alkohol och pendling.

## Ändring
- `answer/interviewfacts.ts` har ett nytt ämne: **arbetserfarenhet**. Det gäller frågor som "har du jobbat/arbetat …", "vad har du för erfarenhet …" och "har du haft något extrajobb".
- Om CV:t eller minnena inte nämner arbete (Arbete:, extrajobb, sommarjobb, praktik, ledare, tränare …) händer två saker:
  - Modellen får anteckningen "svara aldrig ja eller nej".
  - Meningar som påstår något åt något håll sägs inte ("jag har (inte) jobbat", "jag har ingen erfarenhet", "när jag jobbade").
- Frågor om alkohol fångas fortfarande av sitt eget ämne först.

## Tester
- `deno task test`: **485 gröna** (`k_standing16_test.ts`, standing18). `check` är ren.
- **Live** (`cbea4e5`, persona interview):
  - Utan CV, "har du jobbat med kassa förut" 2/2 och "vad har du för erfarenhet av kundservice" 1/1: svaret börjar med "Det jag tar med mig …" och påstår inget om tidigare jobb.
  - Med CV (kafé i Lund): "Ja, jag har jobbat med kassan på ett kafé i Lund …", alltså rätt.
  - "Varför vill du jobba här" påverkas inte.
- Ingen D87-regression, eftersom intervjuläget inte ingår i provbanken (`[skip eval]`).

## Kvar
Fallet intervju-06 har en setup utan "Jobbannons:"-prefix. Där räknas hela setup-texten som elevens fakta (gammalt format), så regeln slår inte till. Fallet är oförändrat.

## Till Aron
Inget nytt.
