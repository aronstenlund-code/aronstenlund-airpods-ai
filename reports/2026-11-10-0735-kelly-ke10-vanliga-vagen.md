# Ke10 (stående uppgift): resten av appens vanliga väg i samma enkla stil (Kelly, 2026-11-10)

Kort: designunderlaget i `docs/design/enkel-start.md` har nu också Start utan prov, Lyssnar (pausat och lyssnar) och
Mikrofon nekad, med fem nya före/efter-bilder i `docs/design/bilder/`. Allt är skisser till Angela (A18).
**Ingen appkod är ändrad och inget är provat på telefon.**

## Vad som gjorts
- `bilder/tom-fore-efter.png` (+ mörkt): Start utan prov.
  - Samma kort som Start med prov, med "Lägg till prov" som enda blå knapp.
  - "Bara fråga" och "Fler lägen" är tysta.
- `bilder/pass-fore-efter.png` (+ mörkt): Lyssnar, pausat.
  - Rubriken "Pausad" och en blå Fortsätt.
  - "Klar för nu" är tyst text.
  - Tummen ned (D57) är kvar.
- `bilder/nekad-fore-efter.png`: Mikrofon nekad som egen skärm, med en blå knapp "Öppna Inställningar".
- Skisserna ligger i `docs/design/_src/enkel-start.html` (`?s=tom|pass|nekad`, `&dark=1`).

## Fynd i dagens app (från bilderna, verifierat i koden där det står)
1. **Pausat läge visar "Startar …".** A13-bilden visar "Startar …" och knappen Fortsätt samtidigt.
   - `ListeningScreen.swift:115` visar "Startar …" för `.idle` och `.error`.
   - Bilden är troligen tagen i `.idle` med en pausad session.
   - Det är **ej verifierat** vilket tillstånd skärmbildsscenen har.
2. **Mikrofon nekad:** den knapp som löser problemet är grå, och den blå "Fortsätt" leder vidare utan mikrofon. Fyndet
   kommer från T3 avvikelse 3.
3. **Röd Avsluta** är det starkaste på Lyssnar, fast det inte är ett fel.

## Till Aron
Inga nya beslut. D57 och "Förhör mig" står i Ke9-rapporten.

## Concerns
Inga.

## Nästa
- Ke9 och Ke10 är underlag till A18. När A18 är byggd tar Toby nya bilder, och sidans tre steg byts mot dem.
- Stående uppgift fortsätter: Ke11.
