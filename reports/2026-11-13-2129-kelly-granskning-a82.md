# Kelly: granskning av A82 (repetitionsläget) på bild

Datum: 2026-11-13 21:29. Roll: Kelly Kapoor (design). Underlag: `docs/design/repetition.md` (Ke49),
`repetition-texter.md` (Ke50) och min kodgranskning `reports/2026-11-13-2025-kelly-granskning-a78-a81-kod.md` (R1–R12).
Bilder: CI "Simulator screenshots" **43497812619** (b32e0da, grön), 13 scener i ljust och mörkt. Kontaktblad:
`reports/2026-11-13-a82-granskning/` (`light0/1.jpg`, `dark0/1.jpg`).

## Bedömning
**Godkänd med två medelfynd.** Uppspelningen, kontrollskärmen, materialet, redigeringen och Fler lägen följer
designen. Fynden från kodgranskningen är stängda utom R10, som delvis är kvar (låg).

| Fynd (kod) | Status på bild |
|---|---|
| R1 röd Avsluta | **Stängd:** neutral sekundär knapp |
| R2 handstil | **Stängd:** frågan i Familjen Grotesk bold |
| R3 rött vid paus | **Stängd:** grå bricka "Pausad" och paussymbol |
| R4 svarsknappar | **Stängd:** tyst rad ● Långt svar ●● Kort svar ●●● Paus/Fortsätt |
| R5 ring och stapel | **Stängd** |
| R6 vänta på allt ljud | **Stängd:** "Gör ljud …" (`repWaiting`) |
| R7 två tryck från Hem | **Stängd:** NÄSTA PROV-kort med Starta prov, ▶ på andra prov |
| R8 blått BETA | **Stängd:** grå kontur |
| R9 pausraden | **Stängd:** "Vilket tryck som helst fortsätter" |
| R10 en sak i taget | Delvis: rutan "Tryck två gånger nu" med prickarna finns, men ingen stor puls (låg, kan vänta) |
| R11 alert för Fortsätt | **Stängd:** eget blad |
| R12 Word-felet | Syns inte på bild. Rad i Material: "PDF, Word, text" |

## Nya fynd
| # | Scen | Fynd | Ska vara | Nivå |
|---|---|---|---|---|
| B1 | `repResume` | "Biologiprovet, fråga **7 av 5**." | Index inom provet. Är det demodata, rätta demodatan. Kan det hända på riktigt (provet kortades efter att platsen sparades), börja från fråga 1 eller kläm till sista. | Medel |
| B2 | `repHome`, `repHomeEmpty` | Under Fler lägen (BETA) står kvar rutan **"Här startar du Earmind"** och en stor ramad knapp **"Starta Earmind"**, och på `repHomeEmpty` dessutom "Earmind kan allt". Det lyssnande läget tar lika stor plats som Starta prov, och rutan pekar nya användare dit (Ke35 gällde före D142). | Under Fler lägen: en rad "Fler lägen [BETA] ›" (`repetition.md`, `hem.png`). Rutan "Här startar du Earmind" visas inte längre för nya användare. "Starta Earmind" och "Earmind kan allt" flyttas in bakom Fler lägen. | Medel |
| B3 | `repPlayThink` | Ringen visar **0** under "Tänk". | Räkna ner till 1 och gå sedan vidare, och visa aldrig 0. Kan också vara en frusen scen: kontrollera i koden. | Låg |
| B4 | `repControls` | "Långt svar · Kom inte fram" visas medan steg 2 testas. | "Kom inte fram" först när testet är slut, eller "Hoppades över" om man tryckt Hoppa över. Under testet: Väntar/Sen. | Låg |
| B5 | `repShare` | Scenen ser ut som frågelistan, och Dela syns inte i bild. | Scrolla till Dela, eller visa Dela-raden avstängd ("Delas när ljudet är klart") och klar i två scener, så att den går att granska. | Låg |
| B6 | `repPlayAnswer` | Svaret står i grått utan läsa-med (det upplästa i full färg) och utan halvfet första mening. | Som `spelar-svar.png`, när ordtidsstämplarna från K46 finns. Kan vänta. | Låg |

Allt annat stämmer med designen och texterna: Material (fyra rutor, Antal frågor, Kortare/Normal/Längre, grå Skapa
frågor), frågelistan (Ljud klart, Starta prov, raden om mikrofonen), redigeringen (kort svar som första meningen,
"Sparar du en ändring …") och Fler lägen (BETA på alla, fotnoten). Mörkt läge har inga fel på någon bild.

## Till Angela
B1 och B2 först. B2 är ett produktbeslut som redan är fattat (D142: första vägen är Nytt prov → Starta prov), inte
smak. B3–B6 kan tas när det passar.

## Test
Granskat på simulatorbilder (iPhone, iOS 26 enligt CI), inte på telefon. Ljud, tryck och låsskärm går inte att
granska på bild (Toby T18).
