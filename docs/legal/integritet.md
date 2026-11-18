# Integritet

Senast ändrad den 17 november 2026. [In English](#in-english)

## Kort
- Du behöver inget konto med namn eller e-post. Appen skapar ett anonymt konto på din telefon.
- Det du skriver eller fotar skickas till oss och till våra AI-leverantörer för att göra ljud, frågor och svar.
- Foton och dokument sparas inte. Texter, frågor, svar och ljud sparas på ditt konto så att du kan spela dem igen.
- Starta prov och Säg i AirPods använder aldrig mikrofonen.
- Lägena som lyssnar (Fler lägen, beta) frågar först, visar hela tiden att de lyssnar, och vi sparar inget ljud.
- Vi säljer inga uppgifter och har ingen reklam och ingen spårning.

## Vem som ansvarar
EarMind görs av Rothman Solutions AB [[O: organisationsnummer och postadress saknas]]. Frågor om dina uppgifter: [stenlundaron@gmail.com](mailto:stenlundaron@gmail.com).

## Ditt konto
När du öppnar appen första gången skapas ett anonymt konto hos vår databasleverantör Supabase. Kontot har ett id men inget namn, ingen e-post och inget telefonnummer. Id:t knyter dina prov, texter, ljud och krediter till din telefon.

## Det du skriver, fotar och lägger till
- **Säg i AirPods och Läs upp texten:** texten skickas till vår server. Ljudet görs av ElevenLabs. Texten och ljudet sparas på ditt konto och på telefonen. Samma text som redan har ljud återanvänds.
- **Frågor och svar:** foton, dokument, länkar och text skickas till vår server och till Anthropic (Claude), som läser materialet och skriver frågor och svar. Fotona och dokumenten används en gång. De raderas direkt när frågorna är gjorda, också om det misslyckas, och det som ändå blir kvar tas bort inom en timme.
- **Hur ska det låta?:** texten du skriver där skickas till Anthropic, som lägger till tecken för hur rösten ska låta. Själva texten ändras inte.
- **Publicera och dela:** ett prov du delar eller publicerar kan ses av andra. Foton och dokument följer aldrig med. Ditt användarnamn visas bara om du själv slår på det.

## Analys av frågor och svar
För att göra frågor och svar bättre skickas de frågor och svar som skapas eller ändras i appen till utvecklaren för analys. Foton och dokument skickas inte. Uppgifterna raderas när de har lämnats över [[O: "raderas inom 14 dagar" står i uppdraget, men beslutet D197 säger "efter leverans"; Aron bekräftar tiden]]. De delas inte med någon annan.

## Lägena som lyssnar (Fler lägen, beta)
- Innan ett läge som lyssnar startar första gången visar appen vad som händer och frågar om lov. Först därefter frågar iPhone om mikrofonen.
- Så länge appen lyssnar syns en rad överst på varje skärm, med en knapp för att stoppa.
- Ljudet strömmas till ElevenLabs för att bli text. EarMind sparar inte ljudet. ElevenLabs kan behålla det enligt sina egna villkor; vi ber om att det inte loggas, men det gäller bara vissa av deras avtal.
- Texten skickas till Anthropic för att få ett svar. Det som sparas är en kort sammanfattning [[O: om sammanfattningen sparas på telefonen eller på servern]].
- Det du ber appen komma ihåg sparas på telefonen.
- Sömnläget sparar sina ljudklipp bara på telefonen.

## Kalender, påminnelser och kontakter
I lägena som lyssnar kan du be appen lägga in händelser och påminnelser, berätta vad som finns i kalendern eller ringa en kontakt. Appen frågar om lov först.
- **Kalendern:** när du frågar vad som finns skickas de händelser du frågar om (titel, tid och plats, högst 20) till vår server och till Anthropic, för att svaret ska kunna skrivas. De sparas inte [[O: att servern inte loggar eller sparar verktygens svar är inte kontrollerat]].
- **Kontakter:** numret stannar på telefonen. Passar flera kontakter namnet du säger skickas deras namn (högst fyra) till vår server, så att appen kan fråga vem du menar.
- **Påminnelser:** appen lägger bara till dem och läser inget.

## Köp
Betalningen sköts av Apple. Vi får uppgifter om köpet (vilken produkt och när) för att ge dig krediter eller veckokortet, men aldrig ditt kort eller ditt namn.

## Loggar
Servern sparar för varje anrop vilken funktion som användes, hur lång tid det tog och vad det kostade, men ingen text. På webbsidan räknas demons frågor per anonym inloggning och per nätverk med en förvrängd (hashad) IP-adress.

## Webbsidan
Om du skriver upp dig på väntelistan på earmind.vercel.app sparar vi din e-post, när du gav samtycke och vilken länk du kom från, bara för att berätta när appen finns.

## Leverantörer
- Supabase (databas och server), med databasen i Stockholm och funktionerna i Frankfurt.
- Anthropic (Claude), USA.
- ElevenLabs (röst och taligenkänning) [[O: land och avtal för dataöverföring]].
- Apple (köp), Vercel (webbsidan).
Överföring till USA sker med de skydd som leverantörerna erbjuder [[O: standardavtalsklausuler eller Data Privacy Framework per leverantör]].

## Hur länge
Texter, prov och ljud finns kvar tills du tar bort dem eller ber oss radera ditt konto. Loggar utan text sparas [[O: hur länge]].

## Dina rättigheter
Du kan be om att få se, rätta eller radera dina uppgifter, och du kan klaga hos Integritetsskyddsmyndigheten (IMY). Du raderar kontot och allt som hör till det, på telefonen och hos oss, i appen: **Inställningar › Konto › Radera konto**. Det går inte att ångra. Veckokortet avslutas inte av det; säg upp det i Inställningar › ditt namn › Prenumerationer. Du kan också mejla oss.

## Barn
EarMind är gjord för elever från 13 år [[O: åldersgränsen i App Store är inte bestämd]].

## Ändringar
Ändras något viktigt säger vi det i appen.

---

## In English
Last updated 17 November 2026.

- **Account:** the app creates an anonymous account on your phone, with no name, email or phone number.
- **What you type, snap or add** is sent to our server and to our AI providers to make audio (ElevenLabs) and questions and answers (Anthropic, Claude). Photos and documents are used once and deleted right after; anything left over is removed within an hour. Texts, questions, answers and audio are stored on your account so you can play them again.
- **Analysis:** questions and answers created or edited in the app are sent to the developer for analysis and deleted once delivered [[O: retention period]]. Photos and documents are never sent.
- **Start quiz and Say in AirPods never use the microphone.**
- **Calendar and contacts (listening modes only):** when you ask what is in your calendar, the events you ask about (up to 20) are sent to our server to write the answer; if several contacts match a name, up to four names are sent so the app can ask which one. Phone numbers are never sent.
- **Listening modes (More modes, beta)** ask for permission first and always show a bar while listening. Audio is streamed to ElevenLabs for speech recognition and is not stored by EarMind; ElevenLabs may keep it under its own terms.
- **Purchases** are handled by Apple. We receive the purchase details needed to give you credits or the weekly pass, never your card or name.
- **No ads, no tracking, no selling of data.**
- **Providers:** Supabase (Stockholm, Frankfurt), Anthropic (USA), ElevenLabs, Apple, Vercel.
- **Delete your account** and everything on our server in the app: Settings › Account › Delete account. It cannot be undone, and it does not cancel the weekly pass.
- **Your rights:** ask to see, correct or delete your data at [stenlundaron@gmail.com](mailto:stenlundaron@gmail.com). You can complain to the Swedish Authority for Privacy Protection (IMY).
- **Controller:** Rothman Solutions AB [[O: company number and address]].
