# O89 del 1: evalen och QA inom testtaket (D234), förberedelse före K105, Oscar (moln)

**Läge:** K105 är **inte live** än. Det finns inget `web_cap_test` i `answer/handler.ts` på main kl. 18:11. Live-eval och mina skript är ändå klara för fältet:
- en tur med `done.web_cap_test` räknas som **överhoppad**, inte som fel, och rapporten skriver hur många som hoppades över och vilka fall det gällde;
- live-eval skickar nu `x-earmind-test`, så att nattens webbsvar hamnar på testtaket och inte på användarnas.

**Beräkning:** nattens eval drar **cirka 21 enheter** av webbtaket per körning, räknat med serverns egna regler på alla 367 frågor. Det ryms under 50. Utrymmet för QA och Kevin blir då cirka 29 per dygn. Förslag nedan. 0 ElevenLabs, 0 Claude (allt offline).

## Ändringar
- `scripts/live-eval.py`:
  - **`x-earmind-test: live-eval`** på alla anrop. Med ett tak som styrs av huvudet skulle nattens eval annars räknas mot användarnas 100. Se också obs 1.
  - En tur med `done.web_cap_test: true` blir en rad med `skipped: "web_cap_test"` och `problems: []`, alltså aldrig "långsamt" eller "källrad saknas".
  - Rapportens rubrikrad får "N överhoppade (testtrafikens webbtak fullt, D234): fall …".
- `scripts/test_live_eval.py`: 2 nya kontroller med en falsk backend ("web_cap_test = överhoppad" och "rapporten räknar överhoppade"). **47/47 gröna.**
- `scripts/qa/o86_eval_reproduce.py`, som jag använder för omkörningar: varje rad visar `skipped`, och slutraden räknar överhoppade.
- **Inget annat ändrades.** `scripts/qa/o87_eval_rules_diff.py` gav 0 ändrade turer av 388 mellan live-eval före och efter O89 (**verifierat i test**). Överhoppningen gäller bara när servern skickar fältet.

## Hur många enheter nattens eval drar (**verifierat i kod**, `scripts/qa/o89_web_need.ts`)
`answer/handler.ts` drar en enhet av `answer-web` **före** svaret i fyra lägen:
- när frågan är en text (sång, dikt, citat: `needsText`);
- när den behöver webben (`needsWeb`);
- vid en följdfråga till ett svar med källa;
- vid ett andra försök med sökning (K16.1).

Enheten dras alltså **även när modellen sedan inte söker**. Därför underskattar `usage.web_searches` förbrukningen.

Serverns egna `needsText` och `needsWeb` på alla 367 frågor i `scripts/live-eval-cases.json` (utom provläge, intervju och Rizz, som inte når den vägen):

| Regel | Turer | Fall |
|---|---|---|
| text (`needsText`) | 5 | symboler-08, text-01, text-02, text-03, text-04 |
| webb (`needsWeb`) | 16 | webb-01…05, k20-07, praktiskt-01, -03, -04, -05, ämnesbyte-01, -06, -09 (tur 2), beräkning-08, k10-pos-22, k10-neg-09 |
| **totalt** | **21** | plus några följdfrågor till svar med källa och andra försök (uppskattat 0–4) |

**Det ger cirka 21–25 per natt, alltså under 50.** Problemet de senaste dygnen var omkörningarna. Mina O86/O88-körningar i dag använde runt 40 enheter, och Kevins K103-mätningar tog ungefär lika mycket.

## Förslag: så håller sig evalen och QA under 50 per dygn
1. **Natten kör som i dag, en omgång, cirka 21 enheter.** Ingen rotation behövs för natten.
2. **Omkörningar under dagen (QA och Kevin) delar resten, cirka 29.** Regel: de 21 webb- och textfallen körs **en** omgång per omkörning, och bara när webbfallen är det som testas. Andra omkörningar hoppar över dem. Jag lägger till `--no-web` i mitt omkörningsskript inför O89 del 2.
3. **Webbomtest efter 00:00 UTC, och före natten (02:17 UTC) eller efter den**, så att natten alltid har sina 21 kvar. En webbomtest på 21 fall i 2 omgångar tar 42, och då ryms inte natten samma dygn. Alltså en omgång, eller två omgångar fördelade på två dygn.
4. **Rotation bara om fallen blir fler än cirka 40.** Då delas de i två halvor som körs varannan natt.

## Obs
1. **Till Kevin (K105):** om testtaket styrs bara av huvudet `x-earmind-test` räknas skript utan huvudet mot användarnas tak, fast servern redan vet att de är testtrafik. Det gäller anrop med skriptens user-agent och från GitHubs IP-intervall (`detectTest`: `reason: "script"` och `"ci"`). Förslag: räkna allt där `currentTest()?.test` är sant mot testtaket. Live-eval skickar ändå huvudet nu, men skript utan huvudet kan fortfarande tömma användarnas 100.
2. Taket per användare är 20 om dygnet (`webLimits.perDay`). Live-eval använder 12 konton, så det räcker.

## Kvar (O89 del 2, när K105 är live)
- En livekörning som visar `web_cap_test` som överhoppat när testtaket är fullt, och att användartaket inte rörs.
- O88:s webbdel efter 00:00 UTC: de sökta fallen fakta-05, fakta-09, praktiskt-03, praktiskt-04, text-03 och k9-neg-5, en omgång.
