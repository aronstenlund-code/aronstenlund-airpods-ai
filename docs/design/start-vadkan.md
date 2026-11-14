# Ny Start och "Vad kan Lumen?" (Kelly, Ke29, 2026-11-11)

D124 (Start-knappen överst), D125 (vad Lumen kan och vad som behöver ställas in), D126 ("Lumen kan allt", Provläget
"För dina prov"). Underlag till Angelas A50 (redan byggd 10:13, granskad här mot koden) och **A52** (inte byggd).
Skisser i `bilder/start2/` (ljust till vänster, mörkt till höger), källa `_src/start2.html`, rendera med
`node docs/design/_src/start2-render.js`. **Skisser, inget provat på telefon.**

## Bilder
| Bild | Skärm | Till |
|---|---|---|
| `start.png` | Start: Starta Lumen, läget med Byt, Lumen kan allt, provkortet | A50 (rättelser S1–S3) |
| `start-prov.png` | Start med Provläge valt: bara raden under knappen ändras | A50 |
| `start-se.png` | Start på iPhone SE: knappen, läget och exemplen syns utan att scrolla | A50 |
| `bytlage.png` | Välj läge (Byt): Standardläge, Provläge, sedan Fler lägen med Sov | A50 |
| `vadkan.png` | Vad kan Lumen?, överst | **A52** |
| `vadkan-hela.png` | Vad kan Lumen?, hela listan | **A52** |
| `efter-forsta.png` | Bladet efter första svaret: "Lumen kan mer än svara" | **A52** |

## Start (A50, granskad i koden, inte i skärmbilder)
A50 följer D124 och D126: en blå knapp "Starta Lumen", läget under med "· Byt", "Lumen kan allt" med exempel som byts
var fjärde sekund (står still med Reducera rörelse), provkortet med Förhör mig som grå knapp och ingen "Få A-svar" och
ingen instruktionsrad. Det är rätt. Rättelser:
- **S1 Väg till A52.** Rutan "Lumen kan allt" saknar en väg vidare. Lägg en textknapp "Allt Lumen kan ›" sist i rutan
  (blå, 16 semibold, minst 44 pt hög). Den öppnar "Vad kan Lumen?" som en vanlig push-skärm.
- **S2 Sant innan det är byggt.** Exemplet "Lumen, kör spellistan Plugg" lovar Spotify, som inte finns än (K36). Visa
  bara exempel för det som fungerar: byt ut Spotify-raden mot "Lumen, förhör mig på fotosyntes" tills Spotify fungerar
  i appen, och lägg tillbaka den då. Samma regel gäller "ring", som inte heller är byggt.
- **S3 Knappens storlek.** 64 pt räcker, men D124 säger "stor". Skissen har 72 pt, 21 bold och hörn 18. Ändra bara
  om Toby eller Aron säger att den inte syns direkt; viktigare är S1 och S2.

Granskningen görs om på skärmbilderna när de finns (PLAN 2c).

## Välj läge (Byt på Start)
Standardläge ("Svarar när någon frågar", frågetecken) och Provläge ("För dina prov", mössa) överst. Under FLER LÄGEN:
Intervju, Socialt, Rizz och Sov. **Få A-svar finns inte** (D124, blir Mina svar i Provläget, Ke30). Raden längst ner:
"Valet gäller Starta-knappen. Du kan också säga ”Lumen, byt till provläge”." Det valda läget har blå ikon och ✓.

## Vad kan Lumen? (A52)
En push-skärm från "Allt Lumen kan ›" på Start och från bladet efter första svaret. Grupperad iOS-lista.
- **Rubrik** (stor, 32 bold): "Vad kan Lumen?"
- **Ingress** (17): "Som Siri, fast den förstår vad du frågar och svarar direkt i dina AirPods." (D125; Deangelos
  "smartare" i stället för "starkare" är respekterad genom att inte jämföra styrka alls.)
- **Rad 2** (15, muted): "Säg ”Lumen” och sedan vad du vill. Det som behöver ställas in står på raden."
- **Varje rad:** ikon i en mjuk ruta (34 pt, `soft`, blå SF Symbol), namnet (17 semibold), vad man säger (15, ink),
  och en statusrad (13): "Inget att ställa in" (muted) eller vad som behövs (blå, semibold) med en liten knapp till
  höger. Bara det som behövs får en knapp.

| Grupp | Rad | Vad man säger | Status | Knapp |
|---|---|---|---|---|
| PLUGG | Förhör | ”Lumen, förhör mig på fotosyntes” | Inget att ställa in | – |
| | Svar på frågor | ”Lumen, vad betyder ambivalent?” | Inget att ställa in | – |
| | Mina svar | Dina egna svar på provfrågor, i örat | I Provläget | – (efter A53) |
| VARDAG | Kalender | ”Lumen, vad har jag i dag?” | Behöver tillgång till Kalender / ✓ Tillåtet | Tillåt |
| | Påminnelser | ”Lumen, påminn mig om träningen kl. 18” | Behöver tillgång till Påminnelser / ✓ Tillåtet | Tillåt |
| | Timer | ”Lumen, sätt en timer på 10 minuter” | Inget att ställa in | – |
| | Larm | ”Lumen, väck mig kvart i sju” | Frågar första gången | – |
| | Anteckningar | ”Lumen, spara det” | Inget att ställa in | – |
| | Träning | ”Lumen, ge mig ett styrkepass på 20 minuter” | Inget att ställa in | – |
| MUSIK OCH SAMTAL | Spotify | ”Lumen, kör spellistan Plugg” | Behöver ditt Spotify-konto | Koppla |
| | Ring | ”Lumen, ring mamma” | Kommer snart | – |
| MER | Intervju | Färdiga svar på intervjufrågor | Byt läge | – |
| | Sömn | Tryck Sov på kvällen. Morgonrapport när du vaknar | Inget att ställa in | – |

Regler:
- **Status är verklig:** "✓ Tillåtet" och "Tillåt" kommer från behörigheten (EventKit), inte från en flagga. "Tillåt"
  ber om behörigheten direkt; nekad tidigare öppnar Inställningar.
- **Det som inte är byggt** står som "Kommer snart" utan knapp, och raden kan inte tryckas. Spotify får "Koppla"
  först när K36 och appens del fungerar; fram till dess "Kommer snart". Raden flyttas inte och döljs inte.
- Ett tryck på en rad utan knapp gör inget (ingen tom skärm). Ingen rad startar Lumen.
- Inga utropstecken, inga modellnamn.

## Efter första svaret (A52)
Ett blad som kommer **en gång**, efter att första svaret är uppläst och Lumen lyssnar igen (inte mitt i svaret).
Rubrik "Lumen kan mer än svara", Klar uppe till höger, raden "Säg ”Lumen” och vad du vill, när du vill.", tre exempel
(förhör, kalender, timer: det som fungerar utan att kopplas), och en blå knapp "Visa allt Lumen kan" som öppnar
listan. Klar eller svep ned stänger, och bladet kommer aldrig igen. Med VoiceOver: fokus på rubriken.

## Sajten (samma budskap, D125)
Ny sektion "Vad kan Lumen?" mellan heron och "Så kommer du igång", med Siri-raden och åtta rader. Det som inte är
provat på telefon har brickan "Kommer snart" (Kalender, Timer och påminnelser, Spotify, Sömn); den tas bort per rad
när Aron har provat. Fotnot: "Siri är ett varumärke som tillhör Apple Inc. Lumen är inte gjord av eller kopplad till
Apple." Demorutans val heter nu **Standardläge** och **Förhör mig** (D124 tog bort Få A-svar).

## Öppet
- **Namnet (D128):** appen heter EarMind, väckningsordet är fortfarande "Lumen". Skisserna säger Lumen, som appen gör
  i dag; A55 byter visningsnamnet med en konstant. Efter A55 står det "EarMind kan allt" ovanför "Säg ”Lumen” och vad
  du vill", vilket är begripligt men konstigt. Aron avgör om väckningsordet också blir EarMind.
- **Siri i appen:** att nämna Siri i appen kan ge en fråga i App Store-granskningen (Apples varumärke). Det är en
  **ej verifierad bedömning**. På sajten har texten en fotnot. I appen föreslår jag ingressen utan ordet Siri om
  granskningen klagar: "Förstår vad du frågar och svarar direkt i dina AirPods."
