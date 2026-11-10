# Enkel start i appen (Kelly, Ke9, utkast 2026-11-09)

Underlag till Angela (A18). Före = Tobys T3 och Angelas A13-bilder (simulator). Efter = mina skisser, ritade i
`docs/design/_src/enkel-start.html` med appens typsnitt (Familjen Grotesk, Kalam) och färger. Bilderna ligger i
`docs/design/bilder/`. **Ingenting är byggt eller provat på telefon.**

## Vägen i dag och förslaget (`bilder/flode-fore-efter.png`)
- **I dag:** Testa nu → Tillåt mikrofon → första svaret (2 tryck) → Fortsätt → Lägg till prov (19 val) → Dela historik → Start (5 tryck).
- **Förslag:** Testa nu → Tillåt → första svaret (2 tryck) → Fortsätt (visas först efter svaret) → "Har du prov snart?" (säg det, eller Inte nu) → Start (4 tryck, inget formulär).
- Vägen till första svaret håller redan målet (högst 3 tryck). Det som gör starten tung är det som kommer efter.

## Skärm för skärm
| Skärm | Bild | Förslag |
|---|---|---|
| Intro | `bilder/intro-fore-efter.png` | Elias i ett kort som på sidan. En mening under rubriken ("Telefonen stannar i fickan."). "Läs mer" inne i samtyckeskortet, så att knappen inte täcker den. Finstilt kortas till "Inget konto. Testa nu betyder att du godkänner punkterna ovan." |
| Fråga vad som helst | `bilder/fraga-fore-efter.png` | En exempelfråga, inte tre. Ingen blå knapp innan första svaret (bara en tyst "Hoppa över"); "Fortsätt" blir blå när svaret har kommit. Nivåmätaren från A13 i kortet. |
| Lägg till prov (första start) | `bilder/prov-fore-efter.png` | Rubrik "Har du prov snart?". Rösten först, och Lumen lyssnar redan. Tre rader: ämne (5 chips), datum, årskurs (en rad, minns valet). Delämne frågas i Provläget. "Inte nu" i stället för "Hoppa över". |
| Start | `bilder/start-fore-efter.png`, `-dark.png` | En blå knapp: **"Förhör mig"** (i dag "Få A-svar till provet", se Concerns). Andra prov som rader utan mikrofonknappar. Provläge-cirkeln tas bort när ett prov finns (den gör samma sak som den blå knappen); Frågor blir en liten knapp "Bara fråga" bredvid "Fler lägen". Raden "Byt läge utan att ta upp telefonen" flyttas till Lyssnar. |
| Lyssnar (Provläge, tomt) | `bilder/lyssnar-fore-efter.png`, `-dark.png` | "Förhör mig" är den enda blå knappen. Pausa och Klar lika tysta; rött bara för fel. Ett röstkommando åt gången. |
| Dela historik | (ingen bild) | Ut ur första starten: frågas en gång när första passet är slut. D57 säger "i onboarding", så det behöver ett ja (Till Aron). |
| Inställningar | (A13 är redan bra) | Prov-avsnittet kan tas bort ur Inställningar, eftersom proven hanteras på Start. |

## Ord som ska vara lika i appen och på sidan
Lumen · Fråga högt. Få svaret i örat. · Telefonen stannar i fickan. · Testa nu · Inget konto · Lägg till prov ·
Förhör mig · Provläge · Frågor · Lyssnar · Fler lägen. "Tryck på Starta" är borta från sidan (knappen finns inte i appen).

## Demosidan (Ke9 del 2, gjord 2026-11-10)
Sidan följer nu samma väg: demo → "Så kommer du igång" (Testa nu och fråga högt, säg vilket prov du har, säg "Lumen,
förhör mig") → en knapp. Resten ligger hopfällt under "Mer när du vill". Före/efter: `reports/2026-11-10-ke9-sida/`.
När Angela byggt A18 byts skärmbilderna i stegen mot de nya (samma tre steg).
