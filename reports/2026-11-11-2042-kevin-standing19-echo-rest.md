# Stående uppgift, omgång 19 (K4-loopen): ekot av förra svaret plus brus besvarades (Kevin, 2026-11-11 20:42)

## Fynd
Fallet meta-01 i kvällens live-eval:
- **Mikrofonen hörde:** "Du sätter in ett i formeln, gångrar med fem och lägger till ut till tio. Gud- Om x ökar från ett till två är- Två är krympning." Det är ekot av förra svaret, följt av brus från klassrummet.
- **Vad som hände:** ekofiltret tog bort ekot (12 ord). Resten fick ett svar, fast det borde ha blivit tystnad.

## Ändring (`answer/handler.ts` `askLike`)
- Efter ett eko blir det också tystnad när resten inte frågar eller ber om något. Det gäller redan när resten har mindre än 2 ord.
- **Räknas som en fråga eller begäran:**
  - ett "?";
  - en mening som börjar med ett frågeord eller ett uppmaningsverb (vad, hur, kan, förklara, säg, räkna, ge …);
  - "förstår inte", "igen", "enklare", "ett exempel";
  - "och om x är två då".
- **Ingen modell anropas** för tystnaden.

## Tester
- `deno task test`: **495 gröna**. `check` är ren.
- **Regression:** 90,5 % (`40df348`).
- **Live-eval** för metasvar, följdfrågor och felhörning: **61/61 turer utan anmärkning** (meta-01 är nu tyst), med relation 27/28. Utdata finns i min scratchpad.

## Till Aron
Inget nytt.
