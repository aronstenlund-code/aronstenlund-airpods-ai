# A18 – Appen ska se proffsig ut (Angela, 2026-11-10)

Uppdrag: Aron 2026-11-09 ("ser lite konstigt ut och inte riktigt proffsigt som andra appar"), med tillägget om
användarvänlighet: lätt att förstå, lätt att komma igång, inte överväldigande, en tydlig väg framåt. Byggd på A13,
Kellys `docs/design/enkel-start.md` (Ke9 och Ke10) och Deangelos `docs/design/anvandarresa-deangelo.md`.
Skills: `apple-design`, `emil-design-eng`. **Simulator, inget provat på telefon.**

## Jämförelse med tre välgjorda appar
Jämförelsen bygger på hur Apple Anteckningar/Fitness, Duolingo och Speak brukar se ut (**untested assumption**:
jag har inte kunnat öppna apparna här och mätt dem; värdena är från designkunskap och Apples riktlinjer, **verified
in docs** där det står HIG).

| Område | Apple (Anteckningar, Fitness) | Duolingo | Speak | Lumen före A18 | Ändrat |
|---|---|---|---|---|---|
| Huvudhandling | En per skärm; resten i listor eller meny | En stor knapp ("Fortsätt", "Börja") längst ner | En stor mikrofon/"Start" | Start: blå knapp + 2 mikrofonrader + 2 färgade cirklar + "Fler lägen" = fem saker som startar lyssning | En blå knapp per skärm: **Förhör mig** (med prov) eller **Lägg till prov** (utan). D97:s "Få A-svar till provet" är grå. "Bara fråga" och "Fler lägen" är sekundära. |
| Ord | Verb som säger vad som händer | Korta verb | Samma ord i röst och knapp | "Få A-svar till provet", "Provläge", "Förhör mig" om samma sak | Knappen heter det man säger: "Förhör mig". |
| Färg | Färg betyder något (rött = radera) | En accentfärg, rött för fel | En accentfärg | Röd "Avsluta" var det starkaste på lyssnarskärmen | Rött bara för fel. Pausa och Avsluta är lika tysta; när Lumen är pausad är "Lyssna igen" den blå knappen. |
| Hierarki och tomma lägen | Tomt läge = en mening + en handling | Tomt läge leder vidare | Visar exempel | Lyssnar (Provläge, tomt): grå text + grå knapp | "Fråga om det du pluggar, eller bli förhörd." + ämnesord + blå "Förhör mig" + "Eller säg …". |
| Mängd text | Kort, en rad hjälptext | Kort | Kort | Tre röstkommandon i en rad längst ner | Ett kommando åt gången och ett "Kommandon"-blad med de fem viktigaste per läge. |
| Rörelse | Knappar ger efter vid tryck; ingen rörelse utan syfte | Mycket rörelse (belöning) | Diskret | Knappar blev bara genomskinligare vid tryck | Tryck: skala 0,97 + opacitet, 80 ms in, 160 ms ut (ease-out). "Fler lägen" tonar in på 0,2 s. Inga nya animationer i övrigt. |
| Ikoner | SF Symbols, sparsamt | Egna illustrationer | Få | Mikrofonikon på varje provrad | Rader har en chevron (de öppnar något); mikrofonen bara på huvudknappen. |
| Första start | Inget formulär innan värde | Värde direkt, konto senare | Prova direkt | Blå "Fortsätt" innan något svar fanns, tre exempelfrågor | En exempelfråga i kortet; "Hoppa över" tyst tills svaret kommit, sedan blå "Fortsätt". Nivåmätaren visar att den hör. |
| Fel | Hela skärmen löser problemet | – | – | Nekad mikrofon: ett rött kort och en blå Fortsätt som ledde vidare utan mikrofon | Egen skärm "Lumen hör dig inte", tre steg, "Öppna Inställningar" som enda blå knapp, "Hoppa över" tyst. |
| Typografi och marginaler | 20 pt sidmarginal, rubriker 28–34 pt | – | – | Redan 20 pt och Familjen Grotesk (D86) | Oförändrat; A13 hade redan rätt skala. |

## Designsystemet (Kellys `docs/design/SYSTEM.md`, Ke12, tillägg från Aron 2026-11-10)
- **Färger:** tokenen från SYSTEM.md (`background`, `surface`, `raised`, `ink`, `muted`, `line`, `blue`, `soft`, `red`) i
  `Shared/LumenStyle.swift`. En accent: lägesfärgerna (grafit, grön, orange, magenta) används inte längre
  (`ConversationMode.color` är blå), och lägesikonerna är blå på `soft`.
- **Inget rutpapper:** `gridPaper()` ritar nu systemets kort (`raised`, hörn 20, mjuk skugga i ljust, hårlinje i
  mörkt). Alla skärmar som använde rutpapper följer med; ett sidhuvud (hörn 0) är bara bakgrunden.
- **Ingen handstil:** frågor visas i 15 semibold grått ovanför svaret (20 regular, radavstånd). Brytaren "Frågor i
  handstil" är borta ur Inställningar (inställningen finns kvar men ändrar inget).
- **Röda pennan** är en lugn bricka ("5 dagar kvar", blå på `soft`).
- **Knappar:** hörn 14, 17 semibold; sekundär = `surface`. Listor: `insetGrouped` på `surface`.
- **Start** enligt skissen: kortet med "NÄSTA PROV", brickan, rubriken, datumet, en ruta med "Öva mer på" och D97:s
  två knappar med en förklarande rad var. Under det "ANDRA PROV" som en lista i en ram, och längst ner två
  sekundära knappar, "Bara fråga" och "Fler lägen" (ett blad).
- **Lyssnar** enligt skissen:
  - titeln i mitten; "Byt läge" och "Kommandon" under ⋯;
  - statusen som en rund bricka i mitten (punkt, ord, nivåmätare);
  - inget rutpappershuvud;
  - tummen ned utan ram.
- **Elias** står i ett vitt kort (hörn 24, skugga), också i mörkt läge.
- **Kellys granskning del 1** (`reports/2026-11-10-0805-kelly-granskning-a18.md`): punkterna 1–4 och 6 var redan
  rättade i `c36830b`, som kom efter versionen hon granskade. Punkt 5 är rättad efter granskningen: lyssnarraden
  (`ListeningIndicatorBar`) har en blå punkt i stället för röd. Hastighetens första ord är "Lugn", som i hennes skiss.
- **Loggan** är oförändrad. Kellys tre förslag (U5) väntar på Arons val.

## Vad som ändrades (skärm för skärm)
- **Intro:** Elias-bilden (godkänd) ligger nu i appen (`Lumen/Resources/Images/IntroElias@2x/@3x.png`, @3x
  kvantiserad från 317 till 191 kB så att den håller gränsen 300 kB). Ringarna utgår från hörluren i bilden
  (`IntroHeroView.ringOrigin = (0,32; 0,37)` i bildens egna koordinater). I mörkt läge ligger ett mjukt ljust sken
  bakom honom, så att den marinblå tröjan inte försvinner. Inget asset catalog skapades (det hade krävt en AppIcon-
  inställning); bilden laddas med `UIImage(named:)`.
- **Fråga vad som helst:** en exempelfråga (i kortet), nivåmätaren i kortet, "Hoppa över" tills första svaret, sedan
  blå "Fortsätt". Med nekad mikrofon: `MicrophoneDeniedView`.
- **Start:** "Förhör mig" startar Provläge för provet och ber direkt om första förhörsfrågan
  (`ListeningModel.startQuiz(for:)`). "Få A-svar till provet" (D97) finns kvar som andra knapp, se A23. Andra prov är rader med chevron. Under: "Bara fråga" (Frågor) och "Fler lägen"
  (Provläge utan förhör, Intervju, Socialt, Rizz 18+ som rader). Utan prov: "Har du prov snart?" på samma kort.
  Raden om att byta läge med rösten är borta (den står i Byt läge-bladet).
- **Lyssnar:** ett kommando i raden + knappen "Kommandon" (blad med fem). Pausa / Avsluta lika tysta, "Lyssna igen"
  blå när pausad. Tomt Provläge: blå "Förhör mig".
- **Inställningar › Röstkommandon:** "De viktigaste" (förhör mig, utveckla, igen, pausa, avsluta, kortare) först,
  allt annat och alla brytare under "Alla kommandon". Sökning hittar fortfarande alla.
- **Inställningar › Prov:** brytaren "Inget prov just nu" (på = inget prov) heter nu "Jag har ett prov".
- **Egna kommandon:** skärmen var på engelska; nu svenska.

## De fem kommandona per läge (`CommandTips.essentials`)
| Läge | Kommandon |
|---|---|
| Provläge | förhör mig, utveckla, igen, pausa, avsluta |
| Frågor | igen, utveckla, kortare, pausa, avsluta |
| Intervju | hjälp mig svara, jag fastnar, igen, pausa, avsluta |
| Socialt | vad ska jag svara, tre alternativ, byt ämne, pausa, avsluta |
| Rizz | ge mig rizz, rädda mig, tre alternativ, pausa, avsluta |

## Testresultat
- **CI:** se "CI" nedan.
- **Skärmbilder:** `reports/2026-11-10-a18-skarmbilder/` (efter), före = `reports/2026-11-09-a13-skarmbilder/`.
  Simulator, `screenshots.yml` körning 42775680102 (iPhone 17 Pro) och 42775684726 (iPhone SE), commit `6133e6c`.
  - Intro, första frågan, Start, Lyssnar och Inställningar, ljust och mörkt.
  - På introbilderna sticker Elias-bilden ut under kortets nederkant. Det är rättat i `ddec2ad`: bilden ligger inne i
    kortet och klipps av det. Den rättade versionen är inte fotad än, så ta med den i T3.
- **Enhet:** inget.

## Kända begränsningar
- "Avsluta" heter fortfarande Avsluta (Kelly föreslog "Klar"). Röstkommandot är "avsluta", och "klar" betyder
  redan något i Intervjuläge (D72), så knappen följer rösten (Deangelos regel 3, och A23.4 säger "Avsluta").
- Kellys förslag "Har du prov snart?" i första starten byggdes som A22 (stående uppgift).
- Dela historik i första starten (D57) är kvar. Att flytta den kräver Arons ja (Till Aron).

## Till Aron
- **Dela historik i första starten:** Kelly och Deangelo vill fråga det efter första passet i stället. D57 säger
  "i onboarding". Ja eller nej?
- **U1, ett grundläge** (Deangelos förslag): inte byggt. Det är ett ägarbeslut.

## Till Toby
- Kör om T3. `ScreenTourTests` letar efter "Få A-svar till provet" (nu "Förhör mig"), trycker "Fortsätt" på
  första frågan (före svaret heter den "Hoppa över") och "Avsluta" (finns kvar). Nya saker att fota:
  "Kommandon"-bladet, "Fler lägen" utfällt, "Lumen hör dig inte".

## CI
Grönt i CI: iOS build 42773767993 (`bda589a`, designsystemet), 42775666996 (`6133e6c`, Kellys punkt 5 och T7). Bygget
för enhet räknar varningar som fel, och alla LumenTests är gröna. Två körningar föll på vägen, båda på kompileringsfel
som rättades: `switch` utan `return` efter en `if`, och en muterande metod i `#expect`.
