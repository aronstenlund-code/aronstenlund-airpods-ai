# Hjälp: så fungerar Earmind

Den här texten är kunskapen bakom **Fråga om Earmind** (`/help`, K57, D166). Hjälp-AI:n svarar bara utifrån den här texten och `Shared/capabilities.json`. **Uppdatera texten när en funktion ändras.** Servern läser en kopia i `backend/supabase/functions/_shared/hjalp.ts`, och ett test stoppar driftsättningen när de två skiljer sig.

Skriv med du-form och korta meningar. Använd knapparnas namn exakt som i appen. Lova bara det som finns.

## Vad Earmind är
Earmind hjälper dig att plugga inför prov med dina AirPods. Du fotar eller lägger till ditt material. Earmind gör provfrågor med svar och läser upp dem i örat. Du styr med tryck på AirPods, utan att röra telefonen och utan mikrofon. Det är huvudläget. Övriga lägen finns under **Fler lägen** och är i beta.

## Nytt prov
1. Tryck **Nytt prov** på startsidan.
2. Lägg till material:
   - **Fota sidor**: flera i följd.
   - **Välj bilder**: ur bildbiblioteket.
   - **Skriv text**: eller klistra in.
   - **Lägg till dokument**: PDF, Word eller text.
3. Ge provet ett namn, välj **Antal frågor** och gärna **Vilken årskurs?**.
4. Tryck **Skapa frågor**. Earmind läser materialet, tar reda på ämne och årskurs, gör frågor och skriver svar. Du kan lämna appen under tiden.
5. Under **Stämmer det här?** ser du ämne, årskurs och vad provet handlar om. Är något fel skriver du det i rutan, till exempel ”Det är åk 8”, och trycker **Gör om med rättelsen**. Stämmer det trycker du **Ser rätt ut**.

- **Hur många bilder:** upp till 40 bilder i ett prov.
- **Bra foton:** fota rakt ovanifrån i bra ljus. Går texten inte att läsa säger Earmind det. Fota då igen, eller klistra in texten.
- **Ditt material sparas inte:** foton, dokument och text skickas en gång för att göra frågorna, och sedan raderas de.
- **Varför det blev färre frågor:** Earmind gör aldrig fler frågor än materialet räcker till. Är texten kort blir det färre frågor än du valde, och appen säger hur många det blev, till exempel ”Materialet räckte till 12 frågor”.
- **Frågorna:** de är korta, helst högst fem ord. De flesta frågar varför och hur, inte bara vad något heter.

## Frågor och svar
- **Två svar per fråga:** varje fråga får ett kort svar och ett långt svar. Det korta svaret är första meningen i det långa och är ett fullgott svar i sig. Det långa svaret förklarar mer, med begrepp, samband och exempel.
- **Ändra en fråga eller ett svar:** öppna provet och tryck på frågan.
- **Ta bort en fråga:** svep frågan åt vänster i listan och tryck **Radera**. Det går också under **Ändra ordning**, med den röda knappen framför frågan. Inne i en fråga finns ingen knapp för att ta bort den.
- **Ändra ordning:** tryck på menyn med tre punkter uppe till höger i provet, välj **Ändra ordning**, dra frågorna och tryck **Klar**.
- **Menyn med tre punkter** i provet har bland annat **Ändra ordning**, **Publicera prov** och **Ta bort provet**. Där finns inget val för att ändra ämne eller årskurs.
- **Fel ämne eller årskurs:** det rättar du under **Stämmer det här?** innan du trycker **Ser rätt ut**. Skriv rättelsen i rutan, till exempel ”Det är åk 9”, och tryck **Gör om med rättelsen**.
- **Ny fråga:** tryck **Lägg till fråga** sist i listan. **Låt Earmind skriva svaret** skriver svar till den nya frågan.
- **Ljudet efter en ändring:** när du sparar en ändring görs nytt ljud bara för den frågan.
- **Svarens längd:** du ändrar den under Inställningar › Avancerat. Båda svaren görs alltid.

## Ljud och röst
- **Ljudet görs automatiskt** när frågorna är klara, i den ordning de spelas. Du ser förloppet som ”Ljud: 12 av 30 klara”. Den första frågan går att spela efter några sekunder.
- **Rösten:** du väljer bland tre röster innan ljudet görs, och du kan provlyssna först. När ljudet är gjort går rösten inte att byta för det provet. Vill du ha en annan röst gör du ett nytt prov.
- **Tempo:** du ändrar det under Inställningar, från 0,50 till 1,5. Det kostar inget och ändrar inte ljudfilerna. Långsammare än 0,70 spelas rösten i 0,70 med längre pauser mellan meningarna, så att den inte låter konstig.
- **Utan mikrofon:** repetitionsläget använder aldrig mikrofonen.

## Starta prov och styr med AirPods
Tryck **Starta prov**. Earmind läser en fråga, väntar en stund så att du kan tänka efter, och går sedan till nästa. Väntetiden är cirka 6 sekunder, och kortare i långa prov. När listan är slut börjar den om i samma ordning.

**Trycken** (ordagrant): ”Medan frågan spelas: 1 tryck = det långa A-svaret. 2 tryck = det korta A-svaret, en till två meningar. 3 tryck = paus. Tryck igen för att fortsätta.”
- **Långa och korta svaret:** det långa A-svaret får du med 1 tryck. Det korta A-svaret, en till två meningar, får du med 2 tryck. Trycken fungerar både medan frågan spelas och under betänketiden efter den. Svaren läses bara upp när du trycker, aldrig av sig själva. Trycker du inte går Earmind vidare till nästa fråga.

- **Under paus:** vilket tryck som helst fortsätter från början av meningen där du slutade. Du behöver inte telefonen.
- **Avsluta:** provet tar slut först när du trycker **Avsluta** på telefonen. Annars börjar listan om.
- **Låsskärmen:** knapparna på låsskärmen gör samma sak som trycken.
- **Kontrollskärmen Styr med dina AirPods:** där provar du trycken innan du börjar. Den visar vilka tryck som kommer fram.
- **AirPods med dubbeltryck per lur:** gäller äldre AirPods. Ställ in vänster lur på Nästa spår (kort svar) och höger på Spela/pausa (långt svar och paus), under Inställningar › Bluetooth › ⓘ vid dina AirPods.
- **Om ett tryck inte kommer fram:** kolla att båda AirPods sitter i öronen och är anslutna. Knapparna på låsskärmen fungerar alltid.
- **Avbrott:** ett samtal eller Siri pausar provet. Provet fortsätter inte av sig självt när samtalet är slut, utan när du trycker igen.
- **Spelar en annan app musik, till exempel Spotify:** då går trycken till den appen i stället för till Earmind. Starta Earmind igen från låsskärmen eller appen, så går trycken till Earmind igen.

## Hur många frågor du kan göra
- **Gräns:** du kan göra 15 frågor med ljud per kalendermånad, och gränsen börjar om den första i varje månad. Appen visar hur många du har kvar den här månaden.
- **Det som inte räknas:** prov som andra har delat eller publicerat, och som du lägger till hos dig.
- **Abonnemang, premium och priser:** ett abonnemang kommer senare. Priser finns inte än, och det går inte att köpa något i appen i dag.
- **När frågorna är slut:** lägg till andras prov, som är gratis, eller vänta till nästa månad.

## Dela ett prov
- Tryck på **Dela** (symbolen med pilen uppåt) uppe till höger i provet och skicka länken med till exempel Meddelanden.
- Dela går först när allt ljud är klart, så att din vän inte behöver göra samma ljud igen. Innan dess står det ”Delas när ljudet är klart”.
- Din vän får en egen kopia med samma frågor, svar och ljud. Det räknas inte mot din väns frågor.
- Ändrar din vän något i sin kopia påverkas inte ditt prov.
- Foton och dokument delas aldrig, bara frågor, svar och ljud.

## Publicera prov
- Med **Publicera prov** kan alla som söker på din skola plugga på ditt prov.
- Du väljer skola, ämne och provdatum. Skolan väljer du ur en lista, och ljudet måste vara klart.
- Ditt användarnamn visas bara om du slår på **Visa ett användarnamn**. Skriv inte ditt riktiga namn.
- Du hittar andras prov under **Prov från din skola**. Prov från din egen skola visas först. Tryck **Lägg till i mina prov** för att få en egen kopia.
- Är något fel med ett publicerat prov trycker du **Rapportera** längst ner i provet. Efter tre rapporter döljs provet tills det har granskats.
- Du kan när som helst ta bort din publicering. De som redan har lagt till provet behåller sin kopia.

## Fler lägen (beta)
De här lägena lyssnar med mikrofonen och är i beta:
- **Standardläge:** frågor och svar med rösten.
- **Provläge (förhör med rösten):** Earmind förhör dig, och du svarar högt.
- **Intervju:** öva på en anställningsintervju.
- **Socialt och Rizz:** förslag på vad du kan säga.
- **Sömn:** sömnprat, snarkning och ljud under natten.

I Standardläget kan Earmind också sätta en timer eller ett larm, lägga in i kalendern eller påminnelser, göra anteckningar, ringa, öppna musik, översätta och söka på webben. Vissa saker kräver att du tillåter dem i appen först. Att styra Spotify kommer snart.

## Det här finns inte i Earmind
- Egna påminnelser om att plugga. (I Standardläget, som är i beta, kan du be Earmind lägga in en påminnelse i appen Påminnelser.)
- Flervalsfrågor, svårighetsgrad, att hoppa över en fråga eller gå tillbaka till förra frågan.
- Export till andra appar eller som PDF, inloggning med Google, en egen röst till svaren och Earmind för Android.
Frågar du om något som inte står här svarar hjälpen ”Det vet jag inte” och hänvisar till Inställningar › Om Earmind.

## Integritet
- Ditt material (foton, dokument, text) sparas inte efter att frågorna är gjorda.
- Repetitionsläget använder aldrig mikrofonen.
- Frågor, svar och ljud sparas på ditt konto, så att de finns kvar på en ny telefon.

## Om något inte fungerar
- **Felmeddelande:** de flesta fel säger vad du kan göra, till exempel ”Fotografera rakt ovanifrån i bra ljus”.
- **Ingen internetanslutning:** kolla att telefonen har nät.
- **Annat:** skriv till oss under Inställningar › Om Earmind.
