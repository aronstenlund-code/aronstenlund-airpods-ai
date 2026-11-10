# Snabbtest på telefon (20 minuter)

Bara det som **måste** testas på riktig iPhone + AirPods. Simulatorn kan inte testa något av detta.
Skrivet av Toby (apptestare), 2026-11-08. Steg 4 (röstkommandon) tillagt 2026-11-09 (T6), steg 5 (mer efter korta svar) 2026-11-10 (T7). Det långa schemat finns i `docs/DEVICE-TEST-CHECKLIST.md`.

**Du behöver:** iPhone med senaste `Lumen-unsigned.ipa`, AirPods (helst med huvudspårning: AirPods Pro eller
AirPods 3/4), internet, ett tyst rum. Ha papper och penna, eller svara direkt i chatten efter varje steg.

Svara med stegets nummer och **J** (som det ska) eller **N** + vad som hände. Exempel: `2b N – hörde inget`.

---

## 1. Eko i högtalaren (2 min)

AirPods **ur** örat och i fodralet, så att ljudet går i telefonens högtalare. Öppna Lumen, tryck **Frågor**.

| | Gör | Ska hända | Skicka |
|---|---|---|---|
| 1a | Säg högt: "Vad är huvudstaden i Norge?" | Svaret hörs i högtalaren. | J/N |
| 1b | Var tyst i 10 s efter svaret. | Lumen svarar **inte** på sitt eget svar (ingen ny fråga dyker upp). | J/N |
| 1c | Säg: "Hur många ben har en spindel?" och var tyst 10 s. | Ett svar, inget mer. | J/N |

Tryck **Avsluta**.

## 2. Byt läge med rösten (1 min)

Sätt i AirPods. Tryck **Frågor**. Lägg telefonen med skärmen nedåt.

| | Gör | Ska hända | Skicka |
|---|---|---|---|
| 2a | Säg: "Lumen, byt till provläge" | Du hör "Provläge." i AirPods inom ca 2 s. | J/N + ungefär hur många sekunder |
| 2b | Säg: "Lumen, byt till frågor" | Du hör "Frågor." | J/N |

Tryck **Avsluta**.

## 3. Provläge i 10 minuter (12 min)

Det här är huvudtestet. Nick, AirPods-knappen och låsskärmen testas medan Provläget går.

**Starta (1 min):**
1. Finns inget prov: **Lägg till prov** → NO → Biologi → ett datum nästa vecka → under "Vad kommer på provet?"
   skriv `fotosyntes, klorofyll` → **Spara prov**.
2. Tryck **Få A-svar till provet**. Kommer frågorna om dig: vid *Kontrollfrågor* välj
   **Ja–nej-frågor (svara med rösten eller nicka)**, hoppa över resten.
3. Tryck pilen **Tillbaka till start** → kugghjulet **Inställningar** → **Diagnostik** → **Diagnostik** →
   **Spela in plugg-session**. Tryck **Klar** så du kommer tillbaka. Provläget ska fortfarande lyssna
   (linjen högst upp på Start).

**Under de 10 minuterna:**

| | Gör | Ska hända | Skicka |
|---|---|---|---|
| 3a | Säg: "Vad gör klorofyll?" | Ordet blir rätt i transkriptet direkt; ett svar på 4–6 meningar. | J/N |
| 3b | Fortsätt prata tills Lumen avslutar med en ja–nej-fråga. **Nicka.** | Räknas som "Ja", Lumen går vidare. | J/N |
| 3c | Vid nästa ja–nej-fråga: **skaka på huvudet**. | Räknas som "Nej". | J/N |
| 3d | Tryck **en gång** på AirPods (klämma på skaftet). | Lumen pausar. | J/N + vad du hörde |
| 3e | Tryck en gång till. | Lumen lyssnar igen, fortfarande i **Provläge**. | J/N |
| 3f | **Lås telefonen.** Titta på låsskärmen. | Lumen-rutan visar provets namn, "Lyssnar", senaste svaret på en rad och **Pausa** och **Avsluta**. | J/N + ta en skärmbild |
| 3g | Tryck **Pausa** på låsskärmen, sedan **Fortsätt**. | Pausar och fortsätter i Provläge. | J/N |
| 3h | Låt telefonen vara låst. Ställ en fråga ungefär varannan minut tills 10 min har gått. | Varje fråga får svar. Provläget slutar **aldrig** av sig självt. | J/N + hur många frågor som fick svar av hur många |

**Avsluta (1 min):**
1. Lås upp. Står det fortfarande "Lyssnar"? (J/N)
2. **Inställningar** → **Diagnostik** → **Diagnostik** → **Exportera WAV, transkript och JSON**.
   Skicka alla tre filerna (AirDrop till datorn, eller mail till dig själv).
3. Tryck **Avsluta** på Lyssnar.

## 4. Röstkommandon (3 min)

Simulatorn har testat att orden blir rätt kommando (T6). Det här kan bara du testa: ljudet i AirPods och musiken.
Starta Spotify (eller Apple Music) och spela en låt. Öppna Lumen och tryck **Frågor** (musiken pausas).

| | Gör | Ska hända | Skicka |
|---|---|---|---|
| 4a | Fråga: "Hur långt är det till månen?" Vänta på svaret. Säg sedan: "Lumen, upprepa." | Samma svar med samma röst igen, direkt, utan paus för att hämta det. | J/N + hur många sekunder det tog |
| 4b | Säg bara: "Viska." Ställ en fråga. Säg sedan: "Lumen, högre." Ställ en fråga till. | Första svaret är tydligt tystare, det andra som vanligt. | J/N |
| 4c | Säg: "Lumen, svara kortare." Ställ en fråga. | Du hör "Kortare." och svaret är en eller två meningar. | J/N |
| 4d | Säg: "Lumen, nästa låt." | Du hör "Nästa låt.", Lumen släpper ljudet och musiken fortsätter med **nästa** låt. | J/N + vilken app |
| 4e | Starta Lumen igen (öppna appen och tryck **Frågor**). Säg bara: "Spela musik." | Lumen pausar och musiken fortsätter där den var. | J/N |

Tryck **Avsluta** om Lumen fortfarande lyssnar.

---

## 5. Mer efter korta svar (2 min)

Simulatorn har testat orden "ja", "mer" och "gärna", tiden och andra röster (T7). Det här kan bara du testa: tonen,
nicken och trycket på AirPods. Tryck **Frågor**.

| | Gör | Ska hända | Skicka |
|---|---|---|---|
| 5a | Fråga: "Vad är huvudstaden i Kanada?" Vänta tills svaret är slut. | En kort mjuk ton i AirPods, och "Säg ja för mer" i blått på skärmen i ca 5 s. | J/N |
| 5b | Fråga något kort igen. När tonen kommer: **nicka**. | Ett längre svar om samma sak. | J/N + sekunder från nick till svar |
| 5c | Fråga något kort igen. När tonen kommer: **tryck en gång** på AirPods. | Ett längre svar. Lumen pausar **inte**. | J/N |
| 5d | Fråga något kort igen. När tonen kommer: **skaka på huvudet**. | Inget mer, "Säg ja för mer" försvinner. | J/N |
| 5e | Fråga något kort igen. Låt en annan person säga "ja" när tonen kommer. | Inget längre svar (Lumen känner igen din röst om du har gjort "Lär dig min röst"). | J/N + om röstprofilen fanns |

Tryck **Avsluta**.

---

## Skicka tillbaka

1. Raderna `1a` till `5e` med J/N.
2. Skärmbilden från 3f.
3. De tre filerna från plugg-sessionen (`.wav`, `.txt`, `.json`).
4. iPhone-modell och iOS-version (Inställningar → Allmänt → Om), AirPods-modell.

Allt som blir N skrivs in i Tobys nästa rapport som fel, med ditt svar ordagrant.
