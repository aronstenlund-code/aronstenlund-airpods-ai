# Ke78: integritetspolicy och villkor som sidor (Kelly (moln), 2026-11-17)

**UTKAST på grenen `kelly/ke78-integritet` (commit d408604). Inte ihopslaget med main och inte publicerat.** Aron läser
och säger ja först.

## Vad som gjordes
- `docs/legal/integritet.md` och `docs/legal/villkor.md`: texterna (svenska först, kort engelsk version under), skrivna
  utifrån koden, besluten (D21, D135, D140, D197, D213, D218, D224) och servern.
- `scripts/site/legal-page.py`: gör `site/integritet.html` och `site/villkor.html` av markdown-filerna, i demosidans stil
  (ljust/mörkt). Det som inte är verifierat skrivs `[[O: …]]` i källan och syns som **gul markering "Overifierat: …"**,
  med en gul utkastruta överst och `noindex`. `python3 scripts/site/legal-page.py --publish` vägrar så länge någon
  markering finns kvar.
- Adresser när de publiceras: `earmind.vercel.app/integritet` och `/villkor` (cleanUrls i vercel.json).

## Bilder (iPhone 15 i Chromium, ingen sidled skroll)
`reports/2026-11-17-ke78-bilder/integritet-light.jpg`, `integritet-dark.jpg`, `villkor-light.jpg`, `villkor-dark.jpg`.

## Overifierat (18 markeringar: 13 i integritet, 5 i villkor) – Aron eller Deangelo svarar
**Integritet**
1. Organisationsnummer och postadress för Rothman Solutions AB saknas.
2. Att lagringen av foton töms efter varje prov (K53) är inte kontrollerat i databasen.
3. Analysen av frågor och svar: uppdraget säger "raderas inom 14 dagar", D197 säger "efter leverans". Aron väljer.
4. Om sammanfattningen i Fler lägen sparas på telefonen eller servern.
5. **Testläget (D140)** skickar bakgrundsljud. Ska bort ur App Store-versionen; finns det kvar måste det stå i policyn.
6. ElevenLabs: land och avtal för överföring.
7. Överföring till USA: standardavtalsklausuler eller Data Privacy Framework, per leverantör.
8. Hur länge loggarna (utan text) sparas.
9. **Knapp för att radera kontot i appen saknas** (Apple 5.1.1(v) kräver den om appen räknas ha konton; ett anonymt
   konto kan räknas).
10. Åldersgräns (13 år i texten, App Store-gränsen inte bestämd).
11–13. Samma punkter i den engelska delen (lagring, analys, organisationsnummer).

**Villkor**
14. Välkomstkrediterna (5 000, D224) är inte byggda.
15. Inbjudan (2 000, max 10/månad) är inte byggd.
16. Om köpta krediter förfaller.
17. Organisationsnummer och adress.
18. Engelska: välkomst och inbjudan inte byggda.

Märkning: innehållet om anonymt konto, Supabase i Stockholm/Frankfurt, att Starta prov och Säg aldrig använder
mikrofonen, samtycke före mikrofon (D21) och att EarMind inte sparar ljud är **verifierat i docs/kod**. Inget är
**verifierat på telefon**. Juridisk granskning är inte gjord (**untested assumption** att texten räcker för Apple och GDPR).

## Så publiceras det (efter Arons ja)
1. Rätta eller stryk varje `[[O: …]]` i `docs/legal/*.md`.
2. `python3 scripts/site/legal-page.py --publish` (måste gå igenom).
3. Slå ihop grenen till main **och** snabbspola `kelly/ke66-earmind-site` (Vercels produktionsgren).
4. Lägg in `https://earmind.vercel.app/integritet` i App Store Connect och länkarna i köpbladet (A134).

## Nästa
Ke77 (köpdelen) i samma runda; sedan granskning av A133/A135/A136 när bilderna kommer.
