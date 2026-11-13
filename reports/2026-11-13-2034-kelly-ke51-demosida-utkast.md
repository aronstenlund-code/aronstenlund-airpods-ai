# Kelly Ke51: utkast till demosidan för repetitionsläget (inte publicerat)

Datum: 2026-11-13 20:34. Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke51.

## Vad som gjordes
- Utkastet ligger i `drafts/site-repetition/` (README där). Det ligger **utanför `site/`**, så Pages publicerar det
  inte, och sidan har `noindex`. `build.py` bygger `index.html` av dagens `site/index.html` plus fyra delar: hero,
  steg, css och js.
- Budskapet är "Plugga med AirPods utan att röra mobilen". Demorutan är en repetitionsdemo utan server med tre
  påhittade frågor: 1 tryck = långt svar, 2 = kort (första meningen, D145), 3 = paus, och under paus fortsätter vilket
  tryck som helst. Tre steg: Fota → Kolla frågorna → Starta prov. "Vad kan Earmind?" blir "Mer i Earmind" med märket
  Beta (D142).
- Skärmbilder: `drafts/site-repetition/bilder/` (mobil och dator, ljust och mörkt, samt långt svar, paus och steg).

## Test
- Chromium (playwright-core, chromium-1243) via en lokal http-server: **inga fel i konsolen**, i mobil 390 och dator
  1280, ljust och mörkt. Trycken provades med klick: långt svar, paus och fortsätt.
- Inte provat i Safari eller på iPhone. Lighthouse är inte körd (utkast). Utkastet är 88 kB HTML och använder
  sajtens bilder och typsnitt, och `site/` är oförändrad.

## Kvar innan publicering
T18 godkänt och Arons ja, ljud för de tre exempelfrågorna (efter K48), skärmbilder från A82, en FAQ-fråga och ny
delningsbild (README "Innan det publiceras").

## Annat
- **Delad checkout:** min `git pull --rebase --autostash` 20:30 tog med andra sessioners ocommittade ändringar
  (Angelas Lumen-filer, Kevins backend) och fick en konflikt i `docs/DECISIONS.md` när de lades tillbaka. Jag
  behöll båda raderna och tog bort konfliktmarkeringarna. Allt deras ligger kvar ocommittat i arbetskopian, och
  stashen `stash@{0}` finns kvar som säkerhet. **Två rader heter D149:** Deangelos (Publicera prov) och Kevins
  ocommittade (repetitionslägets server). Kevin bör byta nummer på sin innan han committar.
- **Granskningen av Angelas skärmbilder** väntar fortfarande. Ingen grön körning av "Simulator screenshots" finns
  efter A82, och bevakningen i bakgrunden står kvar.
