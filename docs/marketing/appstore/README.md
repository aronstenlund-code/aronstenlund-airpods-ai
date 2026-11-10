# App Store-sidan: utkast (Ke25, N5, fas 3)

Kelly, 2026-11-10. **Utkast, inget är inlagt i App Store Connect.** Att publicera eller skicka in görs aldrig utan Aron
(CLAUDE.md). Namnet är inte beslutat (D117, `docs/design/namn.md`), så **[NAMN]** står där det ska in. I appen heter
den fortfarande Lumen.

## Skärmbilder

| # | Rubrik | Rad under | Skärm i appen (CI-bild) |
|---|---|---|---|
| 1 | AI i örat för hela vardagen | Telefonen stannar i fickan. | Intro med Elias (`intro`) |
| 2 | Förhör mig inför provet | Eller få A-svar på dina egna frågor. | Start med provkortet, D97:s två knappar (`home`) |
| 3 | Svaret hörs i örat och syns här | Lyssnarbrickan visar när Lumen lyssnar. | Provläget lyssnar (`listeningProv`) |
| 4 | Plugg, intervju, socialt och Rizz | Byt läge med rösten när du vill. | Byt läge-bladet (`switch`) |
| 5 | Övningsprov med rösten | Svara högt, eller säg nästa. | Övningsprovet (`practice`) |
| 6 | Öva inför intervjun | En kompis frågar, du hör ett färdigt svar. | Intervjuläget (`interview`) |

- **6,9"** `69-1.jpg` … `69-6.jpg`, 1320×2868. **6,1"** `61-1.jpg` … `61-6.jpg`, 1179×2556. JPEG q88.
- Källa: simulatorbilder från CI-körningen "Simulator screenshots" på iPhone 17 Pro Max. Run-id och artefakt står i
  rapporten. Bilderna har inte retuscherats: de är skalade, har rundade hörn och en rubrik ovanför. Demodata
  ("Biologiprovet") som i alla CI-bilder.
- Görs om med `_src/appstore.py` (instruktion överst). Byt bilder när loggan (Ke24) och namnet är klara, eftersom
  "Lumen" och radiovågssymbolen syns i bild 1 och 2.
- Ordningen: bild 1–3 syns i sökresultatet. Bild 1 säger vad appen gör (allmänt, D118), bild 2 visar plugget, och
  bild 4 visar att det är mer än plugg.

## Texter

Antal tecken är räknade med Python (`len`). Apples gränser står inom parentes.

**Namn** (30): `[NAMN] – AI i örat`. Med Proviska blir det `Proviska – AI i örat` (20).

**Underrubrik** (30): `Fråga högt. Få svaret i örat.` (29)

**Reklamtext** (170, kan bytas utan ny granskning; 142):
> Plugga till provet, öva inför en intervju eller få en replik när samtalet står still. Starta appen, fråga högt och hör svaret i dina hörlurar.

**Beskrivning** (4 000; 1 430 med Proviska):
> Fråga högt. Få svaret i örat. [NAMN] är en AI som lyssnar genom dina hörlurar när du har startat den och svarar med en röst i örat. Telefonen kan ligga kvar i fickan.
>
> PLUGGA TILL PROVET
> • Förhör mig: [NAMN] ställer frågor i ämnet och svarar på dina egna frågor.
> • Få A-svar till provet: [NAMN] svarar bara när du frågar och förhör dig aldrig.
> • Övningsprov med rösten: svara högt, få rättning med förklaring och säg "nästa" för nästa fråga.
> • Fota sidan du pluggar på, så utgår förhöret från den. Bilden läses på telefonen och skickas inte.
> • En plan för dagen och en påminnelse när det är dags att plugga, om du vill ha den.
>
> MER ÄN PLUGG
> • Intervju: öva inför intervjun och förbered frågor och svar.
> • Socialt: ett förslag på vad du kan säga när samtalet står still.
> • Rizz: en flörtig wingman som ger dig en replik.
> • Standardläge: fråga vad du vill, när du vill.
>
> ALLT MED RÖSTEN
> Byt läge, pausa och gå vidare med rösten, till exempel "[NAMN], upprepa". Gör egna kommandon och välj vilken röst som svarar.
>
> DU BESTÄMMER
> • [NAMN] lyssnar bara när du har startat den. En blå lyssnarbricka visar när mikrofonen är på.
> • Ljud sparas aldrig.
> • Frågor och svar skickas till oss så att vi kan göra [NAMN] bättre, och raderas när vi har läst dem.
> • Berätta för dem runt dig att du använder [NAMN], och använd den inte där inspelning inte är tillåten, till exempel på prov.
>
> Fungerar med AirPods. Svaren kräver internet.

**Nyckelord** (100, kommatecken utan mellanslag; namn och underrubrik räknas redan, så de upprepas inte):
`plugga,förhör,läxhjälp,glosor,nationella prov,studier,hörlurar,röstassistent,intervju,skola` (91 tecken, 97 byte; å/ä/ö kan räknas som två, så håll under 100 byte)

Inga varumärken (AirPods, ChatGPT) i nyckelorden, eftersom Apple avvisar det (riktlinje 2.3.7).

**Kategori:** Utbildning som första kategori och Produktivitet som andra (förslag; D118 säger "mer än plugg", men
eleverna letar under Utbildning).

**Webbadress för support:** demosidan. **Integritetspolicy (krävs): finns inte än.** Se "Saknas" nedan.

### Varje påstående mot appen
| Påstående | Var det finns | Status |
|---|---|---|
| Lyssnar bara när startad, blå bricka, ljud sparas aldrig, frågor skickas och raderas | `ConsentView.swift` (A41) | i CI/simulator, ej verifierat på enhet |
| Förhör mig / Få A-svar | D97, Start | i simulator |
| Övningsprov, rättning, "nästa" | A16 | i simulator |
| Fota sidan, bilden skickas inte | A36 (Vision på telefonen) | i CI, ej verifierat på enhet |
| Plan för dagen, påminnelse | A19 | i CI |
| Intervju, Socialt, Rizz, Standardläge | Byt läge-bladet, D115, A37 | i simulator |
| Egna kommandon, välj röst | A7/K9, A26 | i simulator |
| Svaren kräver internet | samtyckestexten | stämmer inte helt: A40 svarar kort utan nät på telefoner med Apple Intelligence. Texten följer samtycket tills Angela ändrat det |

Inga sekunder, inga betygslöften, inget om användning under prov, ingen Apple-lik hörlur och "fungerar med AirPods"
i stället för något som antyder att Apple står bakom appen.

## Åldersgräns (förslag: 13+, ej verifierat)

Apple räknar fram åldersgränsen ur svaren i App Store Connect (4+, 9+, 13+, 16+ eller 18+). Förslag på svar:

| Fråga | Svar | Varför |
|---|---|---|
| Mogna eller suggestiva teman | Sällan/milt | Rizz är flörtigt. D119: inga egna innehållsregler utöver de åtta skydden, så modellens egna spärrar gäller |
| Sexuellt innehåll eller nakenhet | Nej | Inget i appen; texten kommer bara från modellen |
| Svordomar och grov humor | Sällan/milt | Modellen kan svara med det man ber om |
| Medicinsk information | Sällan/milt | Frågor om hälsa besvaras; kris hanteras (K23) |
| Våld, skräck, droger, spel om pengar | Nej | |
| Obegränsad webbåtkomst | Nej | Länkar under svaret öppnas utanför appen med SwiftUI `Link` (`ListeningScreen.swift:595`), och appen har ingen egen webbläsare (kontrollerat i koden) |
| Användargenererat innehåll eller meddelanden mellan användare | Nej | |
| Dejting och relationer (ny fråga från 16 nov 2026, svar senast 12 jan 2027) | **Nej, men osäkert** | Frågan gäller appar som kopplar ihop riktiga människor eller en virtuell partner med romantiskt innehåll, och båda ger minst 18+. Rizz ger repliker till riktiga samtal och är ingen partner. Enligt en artikel (iGeeksBlog) har Apple inte sagt hur en chattbot som kan styras till romantik bedöms. **Aron avgör** |
| AI-assistent (kapacitet) | Ja | |

Förväntat resultat: **13+** (ej verifierat; Apple räknar fram det). Rizz är den största osäkerheten. Om Apple
bedömer Rizz som romantiskt blir det 18+, och då når appen inte högstadiet. Tas Rizz bort ur det som syns i
App Store ändras inte svaret, för frågorna gäller funktionen i appen.

## Integritetsetiketter (förslag, ska stämma med samtyckestexten A41)

**Spårning:** Nej (ingen reklam-SDK, ingen tredjepartsanalys).

| Datatyp (Apples namn) | Samlas in | Syfte | Kopplad till dig | Varför |
|---|---|---|---|---|
| Ljuddata | Ja | Appens funktion | Nej | Ljudet går till ElevenLabs för utskrift och sparas aldrig av oss. Apple räknar data som "insamlad" när den lämnar telefonen och sparas längre än begäran. Vi sparar inte ljudet, men ElevenLabs villkor kan göra det. Säkrast att deklarera |
| Annat användarinnehåll (frågor, svar, provets ämne och årskurs, text från Fota sidan) | Ja | Appens funktion, Analys (D116: skickas till oss för att förbättra appen) | **Ja, troligen** | Frågorna går till servern med den anonyma inloggningens id. Om frågeloggen sparar id:t räknas de som kopplade. **Kevin bekräftar** |
| Användar-id (anonym Supabase-inloggning) | Ja | Appens funktion | Ja | Ett id per installation, inget namn eller mejl |
| Kontaktuppgifter, plats, hälsa, foton, kontakter, köp, webbhistorik | Nej | | | Fota sidan läses på telefonen och bilden skickas aldrig (A36) |
| Diagnostik (krascher, prestanda) | Nej | | | Diagnostik visas bara i appen. Om servern loggar fel med id: Kevin bekräftar |

Väntelistans mejladress hör till demosidan och inte till appen, så den deklareras inte här.

## Saknas innan något kan skickas in
1. **Integritetspolicy på en webbadress** (krävs av Apple). Den ska säga samma sak som samtyckestexten, plus D116
   (frågor till Aron, radering) och GDPR (13 år för samtycke i Sverige, ej verifierat). Förslag: en sida
   `site/integritet.html` som Kelly skriver när Aron godkänt texten.
2. Namn (D117) och logga (Ke24), sedan nya bilder 1 och 2.
3. Kevin bekräftar om frågeloggen och felloggarna sparar inloggningens id (styr "Kopplad till dig").
4. Aron avgör Dejting och relationer för Rizz.
5. Developer-konto och TestFlight (fas 3, Aron).
