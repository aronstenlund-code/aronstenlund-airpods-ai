# Kelly Ke30: Mina svar och Lumen kan allt (2026-11-11 10:28)

D126. Underlag till Angelas A53 (beror på Kevins K37).

## Vad som gjordes
- `docs/design/mina-svar.md` med åtta skisser i `docs/design/bilder/start2/minasvar-*.png`, ljust och mörkt
  (samma källa som Ke29, `docs/design/_src/start2.html`):
  första gången, listan per prov, **Lumens förslag → ditt svar**, inspelningen med **Klar**, svaret efter inspelningen,
  tidigare versioner med Återställ och Radera, brytaren "Säg mina svar" i Inställningar › Provläge, och brickan
  **"Ditt svar"** när Lumen säger det sparade svaret i Provläget.
- **Ke29 uppdaterad:** provkortet på Start har raden "Mina svar · 4 sparade ›". "Lumen kan allt" med exempelfraser
  under Start-knappen ritades redan i Ke29 (`start.png`), med rättelsen att Spotify-exemplet väntar tills Spotify
  fungerar.
- Flödet steg för steg (förslag medan man skriver, stavningsrättning som syns, versioner som aldrig försvinner,
  inspelning som inte bearbetas före Klar, av = Lumen svarar själv och inget raderas).

## Till Aron (och Deangelo)
- **Längsta inspelning:** jag föreslår högst 10 minuter ("02:14 av 10:00"), eftersom Scribe kostar krediter (D120).
- **Samtycket:** inspelningen skickar ljud till Scribe. Det och att ljudet raderas efteråt måste stå i samtyckestexten
  före A53, annars blir "Ljud sparas inte" fel (samma fråga som för sömnläget).
- **Andras röster:** lärarens genomgång är andras ord; kontrollera att samtyckets rad om andras ord täcker inspelning.

## Concerns
Inspelning av en lärare är inte dold (röd punkt och tid syns hela tiden, skyddet i RESTRIKTIONER del B), men den
spelar in andra. Inget i skisserna döljer att Lumen spelar in.

## Test
Bara skisser, renderade i Chromium. **Ej provat på telefon.** Kostnad: API 0 USD, ElevenLabs 0 tecken.

## Nästa
Ke32 (Earmind på sajten), sedan granska A50 och A54 när skärmbilderna finns.
