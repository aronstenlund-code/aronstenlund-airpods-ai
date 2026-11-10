# Granskning av hela appen (Deangelo, 2026-11-10 13:00)

Underlag: källkoden (`Lumen/`, 24 000 rader Swift), `Localizable.xcstrings` (239 nycklar, alla med svenska), de senaste skärmbilderna (A18, A26/A16), `docs/RESTRIKTIONER.md` och ägarbesluten D97–D117. **Inget provat på telefon.**

## Bra
- Start ser nu ut som en riktig pluggapp: ett tydligt provkort, två knappar med en förklarande rad (D97), lugna färger och ingen handstil.
- Lyssnar: "Pausad" stämmer med knappen (R4 rättad), "Avsluta" är neutral (R6), svaren är stora och läsbara.
- Inga hemliga nycklar i repot (bara påhittade testnycklar). Inga riktiga elevers meningar i repot (bara påhittade testfall).
- Samtyckestexten berättar ärligt att ljudet går till ElevenLabs och texten till Claude via Lumens server.

## Fynd
| # | Var | Problem | Vem | Prio |
|---|---|---|---|---|
| G1 | Samtycke / Läs mer (`ConsentView.swift` + sv-texterna) | Inaktuell och delvis fel: "lyssnarkompis för **föreläsningar, möten**" (inte en pluggapp), "en **röd** indikator" (den är blå sedan R6), "att dela historik är **avstängt**" och "andra personers tal skickas **aldrig**" stämmer inte med D116 (alla frågor och svar skickas för analys) eller med Standardläge (lärarens fråga skrivs ut och skickas). Måste stämma innan någon annan än Aron använder appen. | Angela (A41), text från Kevin (K30) | **Hög** |
| G2 | Inställningar › Prov | Provdatum och årskurs finns både på Start och i Inställningar, med olika datumformat ("Sön 15 nov" / "15 nov. 2026"). Prov hör hemma på Start (A23). | Angela (A42) | Medel |
| G3 | Inställningar › Röst | "Adam" utan beskrivning och Provlyssna som egen rad (R5, väntar på K6/ElevenLabs). | Angela (A3) | Medel |
| G4 | Inställningar | "Using the iPhone's speech recognition: …" saknar svensk översättning (visas när Scribe faller tillbaka). Resten av engelskan finns bara i Diagnostik. | Angela (A42) | Låg |
| G5 | Lägesnamn | "Frågor", "Bara fråga" och "Svarar när någon frågar" ska bli Standardläge (D115). Det gamla röstkommandot "byt till frågor" måste fortsätta fungera som alias. | Angela (A37) | Medel |
| G6 | Logga | Radiovågorna finns kvar på Start och i introt. | Kelly (Ke24) när Aron valt | Medel |
| G7 | Arkitektur | `ListeningModel.swift` är 3 442 rader och styr alla lägen. Varje ny funktion ökar risken att ett läge förstör ett annat. Rekommendation: dela upp i en styrning per läge (Standard, Provläge, Intervju, Socialt/Rizz) bakom ett gemensamt protokoll, när fas 1 är klar. | Angela (backlog) | Låg nu, viktig före beta |

## Restriktioner (D114)
Koden har de åtta skydden i `docs/RESTRIKTIONER.md` del B. Det som ska bort (del A) ligger i K28 (servern) och A35 (18+-spärren i `ModeSettings.adultConfirmed` / `ModeSetupView`).

## Djupare: vad som saknas (jämfört med Quizlet, Duolingo, Speak)
| # | Saknas | Varför det behövs | Vem | Märkning |
|---|---|---|---|---|
| N1 | **Framsteg per prov:** en ring på provkortet ("68 % redo"), vad du kan och vad du ska öva på | Den vanligaste motivationen i pluggappar; datan finns redan (studiekort, förhörssvar, K17-planen) | Kevin (K33) + Angela (A43) | möjligt |
| N2 | **Widget på hemskärmen:** dagar kvar + streak + "Förhör mig" | Duolingos streak syns utan att öppna appen; i dag finns bara kontrollknappen och Live Activity | Angela (A44) | möjligt |
| N3 | **Tydligt när ElevenLabs ligger nere:** appen faller redan tillbaka till iPhonens taligenkänning och röst (i koden, ej provat på telefon), men säger inget om att kvaliteten är sämre | Hände i dag 08:10 | Angela (A45) + Toby (T10) | möjligt |
| N4 | **Betalning i appen** (StoreKit-prenumeration + gratisgräns) | Måste finnas före App Store; pris från kostnad per timme (R7) | Angela + Kevin, fas 3 | möjligt |
| N5 | **App Store-sidan:** 6 skärmbilder, text, åldersgräns, integritetsetiketter | Krävs för TestFlight extern och App Store | Kelly (Ke25), fas 3 | möjligt |
| N6 | **Kort att bläddra i tyst** (bibliotek, buss): studiekorten som vändkort med tryck | Röst fungerar inte överallt; Tyst förhör med nick finns men är svårt att upptäcka | Angela (backlog) | möjligt |

Rättelse till Aron (Deangelo): i dag sa jag att appen inte hör eller läser upp utan ElevenLabs. Koden faller tillbaka till iPhonens egen taligenkänning och röst, så den fungerar, men sämre. Ej verifierat på telefon.
