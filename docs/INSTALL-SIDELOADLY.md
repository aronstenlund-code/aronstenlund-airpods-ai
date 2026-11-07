# Installera Lumen på iPhone utan Mac (Sideloadly, D70)

Skriven för Aron. Du behöver din Windows-dator, din iPhone (iOS 26) med kabel, ditt Apple-ID och cirka 30 minuter
första gången. Allt är gratis.

Inget här är provat på riktigt ännu. Det första installationsförsöket är testet. Gå det något fel: skriv ner exakt
vilken text som visas och vid vilket steg.

---

## 1. Hämta appfilen från GitHub (5 min)

1. Gå till https://github.com/aronstenlund-code/aronstenlund-airpods-ai och logga in.
2. Klicka på fliken **Actions** högst upp.
3. Klicka på **iOS build** i listan till vänster.
4. Klicka på den översta körningen som har en **grön bock** och där det står **main**.
5. Scrolla ner till rutan **Artifacts** längst ner på sidan och klicka på **Lumen-unsigned**. En zip-fil laddas ner.
6. Öppna mappen **Hämtade filer**, högerklicka på `Lumen-unsigned.zip` → **Extrahera alla…** → **Extrahera**. I mappen
   ligger `Lumen-unsigned.ipa`. Det är den filen du ska installera.

Filen finns kvar i 14 dagar. Hittar du ingen körning med grön bock, eller vill du ha en ny fil: **Actions** → **iOS
build** → knappen **Run workflow** till höger → låt **Branch: main** stå kvar → den gröna knappen **Run workflow**.
Efter ungefär 25 minuter finns en ny körning med filen.

## 2. Installera Sideloadly och iTunes på Windows (10 min, bara första gången)

1. **iTunes och iCloud måste vara webbversionerna från Apple, inte versionerna från Microsoft Store.** Har du någon av
   dem från Microsoft Store: **Start** → **Inställningar** → **Appar** → **Installerade appar** → klicka på **…**
   bredvid iTunes respektive iCloud → **Avinstallera**.
2. Gå till https://sideloadly.io. Ladda ner och installera **Web iTunes 64-bit** och **Web iCloud** från länkarna på
   sidan.
3. Ladda ner Sideloadly för Windows 64-bit (https://sideloadly.io/SideloadlySetup64.exe) och installera den.
   Starta om datorn.

## 3. Koppla in iPhonen (2 min)

1. Anslut iPhonen till datorn med kabel och lås upp den.
2. På iPhonen visas **Lita på den här datorn?** Tryck **Lita på** och ange din lösenkod.
3. Starta Sideloadly. Kontrollera att din iPhone syns i rutan **iDevice**.

## 4. Installera appen (5 min)

1. Dra `Lumen-unsigned.ipa` till ikonen **IPA** i Sideloadly.
2. Skriv ditt Apple-ID (e-postadressen) i rutan **Apple account**.
3. Klicka på **Start**. Ange lösenordet till ditt Apple-ID när Sideloadly frågar. Har du tvåstegsverifiering kommer
   en sexsiffrig kod till dina andra Apple-enheter, och den skriver du in i Sideloadly. Lösenord och kod skriver du
   själv, ingen agent gör det åt dig. Vill du hålla ditt vanliga Apple-ID utanför går ett extra gratis Apple-ID lika
   bra.
4. Vänta tills det står **Done** längst ner i Sideloadly.

**Om installationen stoppas:**
- Felet nämner bundle ID eller App ID: klicka på **Advanced options**, kryssa i **Change Bundle ID** och klicka på
  **Start** igen.
- Felet nämner extensions, widget eller plugin: klicka på **Advanced options**, kryssa i **Remove Extensions** och
  klicka på **Start** igen. Då försvinner knappen i Kontrollcenter och visningen på låsskärmen, men resten av appen
  fungerar. Skriv ner att du gjorde så.

## 5. Slå på Utvecklarläge och lita på ditt Apple-ID (3 min, bara första gången)

1. På iPhonen: **Inställningar** → **Integritet och säkerhet** → scrolla längst ner → **Utvecklarläge** → slå på.
   iPhonen startar om. Efter omstarten frågar den om Utvecklarläge ska slås på: tryck **Slå på** och ange
   lösenkoden. Syns inte **Utvecklarläge**: gör först steg 4 klart och titta sedan igen.
2. **Inställningar** → **Allmänt** → **VPN och enhetshantering** → under **Utvecklarapp** trycker du på din
   e-postadress → **Lita på "…"** → **Lita på**.
3. Öppna Lumen från hemskärmen.

## 6. Var sjunde dag

Med ett gratis Apple-ID slutar appen fungera efter 7 dagar. Den går då inte att öppna, men inget försvinner.

- **Enklast:** anslut iPhonen, öppna Sideloadly och gör steg 4 igen med samma fil eller en nyare. Historik, minne och
  inställningar ligger kvar.
- **Automatiskt:** Sideloadly har **Automatic App Refreshing**, som förnyar appen i bakgrunden när datorn är på och
  iPhonen finns på samma wifi. Slå på det i Sideloadlys inställningar om du vill. Det är inte provat än.

Apple tillåter bara ett fåtal appar åt gången per gratis Apple-ID, och Lumen räknas som två (appen och tillägget för
Kontrollcenter). Om Sideloadly säger att gränsen är nådd: ta bort andra appar som du har installerat på samma sätt.
Den uppgiften har jag inte kunnat kontrollera i dokumentationen.

## 7. Vad du testar först

Följ `docs/DEVICE-TEST-CHECKLIST.md`. **Hoppa över Del 1 och Del 2**, de gäller Mac och Xcode. Gör i den här
ordningen:

1. **3i** Samtycke och lyssnarskärmen (5 min).
2. **3t** Kärnflödet från början till slut: håll knappen, ställ en fråga, hör svaret i AirPods (10 min). Det här är
   det viktigaste. Fungerar inget annat, skicka bara resultatet från 3t.
3. **3q** Växla till musik (10 min).
4. **3v**, **3w**, **3x** och **3x2**: Provläge, Intervjuläge, Rizzläge och Socialt läge, med en kompis som vet att
   appen lyssnar.
5. **3y** Historik och minne.
6. **3z** Siri, Kontrollcenter och låsskärmen. **Det här kan fungera sämre med ett gratis Apple-ID**, och inte alls
   om du fick välja **Remove Extensions**. Skriv ner vad som händer, det är ett resultat i sig.

**WAV-filer från Diagnostik (om du gör mikrofontesterna):** anslut iPhonen, öppna iTunes → klicka på
iPhone-ikonen uppe till vänster → **Fildelning** → **Lumen** → markera filerna `lumen-*.wav` → **Spara till…**. Lägg
dem inte i git.

Skicka sedan resultaten enligt Del 4 i checklistan.

---

## Teknik (för agenterna)

- CI (`.github/workflows/ios-build.yml`) arkiverar appen osignerad (`CODE_SIGNING_ALLOWED=NO`,
  `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGN_IDENTITY=""`) när build och alla tester är gröna, på `main` och vid manuell
  körning. `Payload/Lumen.app` packas till `Lumen-unsigned.ipa` och laddas upp som artefakten `Lumen-unsigned` (14
  dagar). Debug-konfiguration, så Diagnostik och WAV-delningen finns med. `ENABLE_DEBUG_DYLIB=NO` gör att hela
  programkoden ligger i appens egen binär och Sideloadly signerar den som vanligt.
- **Entitlements:** repot har inga `.entitlements`-filer och appen använder inga App Groups, push, iCloud,
  HealthKit eller andra funktioner som kräver betalt konto. Därför tas inget bort. Bakgrundsljud
  (`UIBackgroundModes: audio`), Live Activities (`NSSupportsLiveActivities`), kontroller (WidgetKit-tillägget
  `LumenControls`) och App Shortcuts är Info.plist-nycklar eller vanliga tillägg och kräver ingen entitlement.
  Sideloadly lägger själv till de entitlements som en gratis provisioneringsprofil ger. **Ej provat på enhet.**
- Att App Intents, kontroller och Live Activities fungerar med ett gratis Apple-ID är ett **ej provat antagande**.
