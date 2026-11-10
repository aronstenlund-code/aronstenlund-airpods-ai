# A45 och A37: reservmotorn sägs lugnt, och Frågor heter Standardläge (Angela, 2026-11-10)

Underlag: Deangelos N3, D115 och kön. **Kod och enhetstester. Inget är provat på telefon.**

## A45: reservmotorn (N3)
Om ElevenLabs-rösten eller Scribe inte fungerar tar iPhonens egen röst eller igenkänning över. Det kan hända till
exempel när kvoten är slut.
- **Förut:** rösten gav felrutan "voiceUnavailable", och Scribe gav ingenting.
- **Nu:** Lyssnar visar en lugn rad: **"Lumen hör och pratar lite sämre just nu"**. Raden kommer en gång per pass, och
  ingen felruta visas. Ett nytt pass får säga det igen.
- **Kvar i Diagnostik:** felet sparas i listan som förut (källa `tts` eller `stt`), och loggen säger "Stand-in engine
  for …".
- **Kod:**
  - `TranscriptionCoordinator.onFallback` är en ny krok;
  - `ListeningModel.noteFallback`, `fallbackNotice` och `fallbackLine` är nya i modellen.
- **Test:** `CannotAnswerTests.aFailingVoiceFallsBackAndIsShown` kräver nu raden och ingen felruta. Svaret hörs
  fortfarande med iPhonens röst.

### Till Toby (T10)
Testa med ElevenLabs avstängt, eller med kvoten slut. Raden ska komma en gång. Den ska inte komma tillbaka under samma
pass, och ingen röd ruta ska visas.

## A37: Standardläge (D115)
Läget som hette "Frågor" heter nu **Standardläge** på alla dessa ställen:
- lägesknappar och "Byt läge";
- Lyssnars rubrik;
- inställningarna för pauser och fokus;
- röstkommandona;
- Minnes rad om taltempo;
- `docs/COMMANDS.md`.

**Rösten:**
- "Lumen, byt till standardläge" fungerar. Det gamla "byt till frågor" fungerar också.
- Lumen säger "Standardläge." när läget byts.

**Byta läge från alla skärmar (kontroll i koden):**
- Lyssnar har "Byt läge" under ⋯ i alla lägen. Start har "Bara fråga" och "Fler lägen".
- Röstens lägesbyte tolkas före allt annat i en tur, så det fungerar också under övningsprovet, provsessionen och det
  tysta förhöret. Ett byte från Provläge avslutar övningsprovet.
- **Untested assumption:** att det inte finns fler vägar. Toby testar det.

### Till Kelly
Demosidan och bilderna säger "Frågor". Byt till "Standardläge".

### Till Toby
- Skärmturen trycker på "Frågor" (`ScreenTourTests` rad 214). Knappen på Start heter "Bara fråga", och läget heter
  "Standardläge".

## CI
Grönt i CI: A45 i iOS build 42813874171 (`a8a2ccf`), och A37 i 42816388453 (`f629799`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna.
