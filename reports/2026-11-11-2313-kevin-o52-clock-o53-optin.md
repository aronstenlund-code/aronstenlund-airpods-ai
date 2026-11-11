# Oscars O52 (prio 1, fel klockslag) och O53 (prio 2, opt_in) (Kevin, 2026-11-11 23:13)

**Status: driftsatt** (`b1e9305` 23:16). **Live 23:19:** "vad är klockan", "Lumen, vet du vad klockan är", "kan du säga vad klockan är", "hur mycket är klockan nu" och "vilken tid är det" gav alla "Klockan är nitton minuter över elva på kvällen, alltså tjugotre och nitton", vilket var rätt (5/5). "Vad är klockan i Tokyo" går som förut till zonklockan. Regression: 90,5 %.

## O52: "Vad är klockan?" gav fel tid
- **Fynd** (`reports/qa/2026-11-11-2058-oscar-o52-klockan-och-omtest.md`): Haiku läste "20:57" som "tjugo över åtta" eller "tjugo över nio". Svaren var rätt 0/5 gånger.
- **Ändring:** `answer/localclock.ts` svarar i kod, utan modellanrop, med svensk tid. Det gäller "vad är klockan", "hur mycket är klockan", "vet du vad klockan är", "kan du säga vad klockan är", "vilken tid är det" och "hur dags är det", med eller utan "Lumen" eller "nu".
  - **Format:** "Klockan är tre minuter i nio på kvällen, alltså tjugo och femtiosju."
  - **Vardagssvenska:** fem över, kvart över, tjugo över, fem i halv, halv, fem över halv, tjugo i, kvart i och fem i. Minuter som inte är jämna fem säger "tre minuter i".
  - **Dagsdelen** följer den faktiska timmen.
  - **Sommartid:** fungerar via `Intl` med Europe/Stockholm.
- "Vad är klockan i Tokyo" går som förut till `zoneClock`.
- **Tester:** 5 formuleringar × 3 klockslag (20:57, 08:15 och 14:30 sommartid) ger 15/15 i `k42_test.ts`. Det är mina egna formuleringar, inte Oscars skript.

## O53: `opt_in` krävde inte inloggning med e-postkod
- **Fynd** (`reports/qa/2026-11-11-2100-oscar-o53-k43-testljud.md`): testläget krävde bara ett konto som inte var anonymt och hade en e-postadress. En registrering med lösenord räckte alltså.
- **Ändring:** `opt_in` och flaggan kräver nu `amr` otp/magiclink, samma krav som ägarkontrollen. En användare som har loggat in med lösenord kan inte slå på testläget, och flaggan blir false även om användaren står i `debug_testers`.
- **Test:** ett nytt test i `debug-audio/handler_test.ts`.

## Tester
`deno task test`: **504 gröna**. `check` är ren.

## Till Oscar
Omtest av O52 och O53 när Deploy backend har kört `b1e9305`.

## Till Aron
Klockan är rätt igen.
