# Kelly Ke46: granskning av A76, testläget (2026-11-11 21:16)

Underlag: Angelas A76 (25d7b59, `reports/2026-11-11-2100-angela-a76-testlage.md`), granskat **i koden** (inga
skärmbilder än), mot `docs/design/testlage.md` (Ke45). A76 byggdes samtidigt som underlaget (Ke45 pushades 20:44,
A76 klar 21:00), så avvikelserna är väntade.

## Omdöme: **godkänd med rättelser T1–T4** (T2 före testläget slås på för andra än Aron)
Rätt: av från början, på för testkonton via K43, raden "Testläge: skicka ljud för felsökning" i Inställningar,
miniraden "Lyssnar · Testläge, ljud skickas", texten i Om appen bara när testläget är på, bitarna raderas.

## Fynd
| # | Var | I dag | Enligt Ke45 | Prio |
|---|---|---|---|---|
| T2 | Brytaren i Inställningar | Slår på direkt, inget blad | Bladet "Slå på testläget?": **allt ljud, också andras röster och bakgrundsljud**, sparas 14 dagar, brickan syns, hur man stänger av; "Slå på testläget" / "Inte nu". Testkonton (Aron) ser det en gång med "Okej" | **Hög** (samtycke, RESTRIKTIONER del B) |
| T4 | Om appen | D138-meningen står kvar och testlägesmeningen läggs till efter: "…sparas inte av Earmind." + "Testläget är på: allt ljud … skickas till oss" | **Ersätt** D138-meningen medan testläget är på: "Testläget är på: ljudet skickas till oss och sparas i 14 dagar. Sömnläget sparar klippen bara på din telefon." | Medel |
| T1 | Lyssnar | En extra rad "Testläge · ljud skickas" i systemets `.orange`, 13 pt, utöver Lyssnar-brickan | Lyssnar-brickan **själv** blir "Testläge · ljud skickas" i `test` (#B45309 / #FBBF6A) på `testsoft` (#FEF3E2 / #3A2A12). En indikator, inte två; färg från systemet, inte `.orange` | Medel |
| T3 | Start | Inget | Liten bricka "Testläge" bredvid kugghjulet så länge testläget är på; tryck → Inställningar | Låg |

Skisser: `docs/design/bilder/start2/ke45-*.png`.

**Ej verifierat på enhet** (koden läst). Kostnad: API 0 USD, ElevenLabs 0 tecken.
