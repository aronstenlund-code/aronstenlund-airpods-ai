# Kevin K18 (del 1): ämnesord i svaren. Uttalet väntar på ElevenLabs-krediter

Datum 2026-11-10 09:25 · Uppgift: `prompts/queue/kevin.md` K18 · Driftsatt (Deploy backend 42781600527, commit 4ac345b) · **Verified live** där inget annat står. **Inte testat på telefon.**

## Resultat
| Del | Resultat |
|---|---|
| Svaren använder kursens egna ämnesord, även när eleven frågar med vardagsord (10 Provläge-frågor, Åk 8, `scripts/k18-subject-terms.py`) | Före: **9/10** ("varför blir vatten till is" gav inget "fryspunkt" eller "stelnar"). Efter regeln i Provläge-prompten: **10/10** |
| Uttal av ämnesord i TTS: Scribe räknar fel på 30 ämnesord före och efter (`scripts/k18-pronunciation.py`, klart) | **Inte körd.** ElevenLabs-krediterna är slut sedan 07:45 (`/tts` svarar `503 provider_quota`, och Scribe är också nere). Oscar har meddelat Aron |

Filer: `reports/eval/k18-terms-before-2026-11-10.json` och `k18-terms-after-2026-11-10.json`.

## Ändrat
`answer/prompt.ts` (Provläge): "Subject terms (K18): use the course's own terms … also when the student asks in everyday words; the everyday word may be said once next to the term."

## Kvar (när krediterna finns)
1. Kör `python -X utf8 -I scripts/k18-pronunciation.py --tokens … --tag before`. Den läser upp 30 meningar med ämnesord, som Ohms lag, Pythagoras sats, cellandning, DNA, pH-värde, Westfaliska freden och Shakespeare, och kör dem genom Scribe.
2. För ord som blir fel: lägg alias i `/tts` (en lista ämnesord → uttalsstavning, som ElevenLabs "alias rules" men i vår kod, så att inget behöver ändras i kontot). Gäller också ämnesorden från provprofilen som appen skickar (`terms`).
3. Mät igen (`--tag after`) och skriv in siffrorna.
- Att ElevenLabs uttalslexikon fungerar med v4 Turbo är **inte verifierat** i deras dokumentation. Det behövs inte om alias i vår kod räcker.

## Till Aron
- **ElevenLabs-krediterna är slut** (sedan 07:45 enligt Oscar). Utan dem har appen ingen molnröst och ingen Scribe-taligenkänning, och demon läser inte upp något. Fyll på i ElevenLabs → Subscription. K18:s uttalsmätning, O16 del 2 och O13 del 3 väntar på det.

## Kostnad
Ungefär 0,2 USD (20 Sonnet-svar).
