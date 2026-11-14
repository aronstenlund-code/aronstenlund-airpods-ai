# O60: längdklass i stället för ordgräns (D176), efter K61 (Oscar, 2026-11-14 14:52)

Status för varje påstående: **verifierat live** (mot driftsatt `/exam` och `/drill`), **verifierat i docs** eller **antagande, ej testat**.
Ingen app eller enhet. Ingen kod ändrad.

## Kort
- **Krav klarat: 57 av 58 genererade frågor (98 %) är längdklass `normal`** (krav minst 90 %).
  - Frågorna kommer från 5 nya hållout-prov som Kevin inte har sett.
  - Längden räknas som frågan plus det långa svaret, i tecken: median 560, max 830.
  - Den enda frågan över 800 tecken är "Vad handlar den åttafaldiga vägen om?" med 830 tecken. Det långa svaret är 130 ord.
- **Klassen som servern sparar stämmer, 3/3.**
  - Ett sparat prov med 358, 830 och 1 717 tecken fick `normal`, `longer` och `too_long`.
  - Serverns `voice_chars` var exakt lika med mitt antal tecken.
- **D175 sågs i passerande:** jag bad om 20 frågor och servern gjorde högst 15 (`questions_asked` 15), alltså månadens kvot.
- **Iakttagelse till Deangelo:** utan ordgräns är frågorna mycket längre, median 8 ord och som mest 15 (förut 4–5). Flera är två frågor i en (se nedan).
- Kostnad:
  - Claude 0,18 USD.
  - ElevenLabs upp till 2 905 tecken (cirka 0,23 USD), för de 3 sparade frågorna. Det behövdes för att se klassen, eftersom servern bara visar den när ett prov sparas.
  - Testprovet togs bort direkt. `status` visade då `done 0 av 6`, men om ljudet ändå gjordes är **antagande, ej testat**.

## Testbanken
`scripts/qa/repetition_bank/materials_holdout2.py` är ny och påhittad. Den skrevs före K61, och Kevin har inte sett den. Den ligger utanför `exams.json`.

| Prov | Format | Årskurs | Lästes av | Frågor | Tecken min/median/max |
|---|---|---|---|---|---|
| h2-ge-klimatzoner | 4 foton | "Geografi åk 7" | Geografi/åk 7 | 14 | 358 / 533 / 625 |
| h2-re-buddhism | docx | ingen | Religionskunskap/tom | 14 | 515 / 588 / **830** |
| h2-sv-argumentera | text | "Svenska åk 9" | Svenska/åk 9 | 10 | 481 / 560 / 574 |
| h2-hkk-naring | PDF | ingen | Hem- och konsumentkunskap/tom | 10 | 418 / 598 / 687 |
| h2-fy-elektricitet | 4 foton | "Fysik åk 8" | Fysik/åk 8 | 10 | 473 / 523 / 593 |

Årskursen var rätt eller tom i 5/5, och täckningen enligt koden var 100 % i alla. Jag körde utan domare, så korrektheten är **inte bedömd** i O60. Det långa svaret och D145 var 58/58 enligt koden.

## Klassen som servern sparar (`reports/qa/data/2026-11-14-1450-o60-save-class.json`)

| Fråga | Mitt antal tecken | `voice_chars` | `length_class` | Väntat |
|---|---|---|---|---|
| Vad kännetecknar regnskogsklimat? (genererad) | 358 | 358 | normal | normal |
| Vad handlar den åttafaldiga vägen om? (genererad) | 830 | 830 | longer | longer |
| påhittad lång fråga | 1 717 | 1 717 | too_long | too_long |

Gränserna exakt vid 800 och 1 600 testade jag inte live, eftersom varje tecken kostar ljud. De finns i Kevins enhetstest (`drill/length.ts`), alltså **verifierat i docs**.

## Frågorna utan ordgräns (iakttagelse, inget krav)
- **Längd:** median 8 ord och som mest 15. Bara 7–50 % per prov har högst 5 ord. Kevins regel gör att frågekontrollen inte fyller ut.
- **Två frågor i en**, där eleven måste svara på båda:
  - "Vad såg Siddhartha när han lämnade palatset, och vad bestämde han sig för?"
  - "Vad är målet med buddhismen, och vad händer då?"
  - "Hur är en bra måltid uppbyggd enligt tallriksmodellen, och varför …"
- **Prio 3 till Deangelo och Kevin:** ska frågan vara en fråga åt gången? Långa frågor ger också längre svar, och det var den längsta som hamnade i `longer`.

## Risker och begränsningar
- Ett försök per prov.
- `/exam` gav 429 under genereringen, så tiderna 52–64 s för svaren är mina egna väntetider, inte serverns.
- Mitt antal tecken (frågan + långa svaret) stämde med serverns i 3/3, men servern räknar på texten efter uttalsreglerna. Med siffror eller förkortningar kan de skilja sig lite.
- `scripts/qa/o55_grade.py` flaggar fortfarande "fråga > 8 ord". Det är inget krav längre (D176), och jag har inte räknat det som fel.

## Filer
- `scripts/qa/repetition_bank/materials_holdout2.py` (ny); `o55_grade.py` och `make_files.py` läser den
- `reports/qa/data/2026-11-14-144802-o55-drill-o60.json`, `…-1450-o60-save-class.json`

## Nästa
- Deangelo: om frågorna ska vara en fråga åt gången.
- Oscar: väntar på kö. Proven i `materials_holdout2.py` är inte hemliga när det här är pushat.
