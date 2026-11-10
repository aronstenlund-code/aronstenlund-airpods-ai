# Som en ny användare: vad är självklart och vad är det inte? (Deangelo, 2026-11-10)

Underlag: A13-skärmbilderna (`reports/2026-11-09-a13-skarmbilder/`), Kellys `docs/design/enkel-start.md`, `docs/COMMANDS.md` och apptexterna. **Simulatorbilder, inget provat på telefon.** Personan: Elin, 15 år, åk 9, biologiprov på fredag, har aldrig hört talas om Lumen.

## Resan, steg för steg
| Steg | Vad Elin ser | Självklart? | Varför / förslag |
|---|---|---|---|
| 1. Intro | "Fråga högt. Få svaret i örat." + tre löften + Testa nu | **Ja** | Bra. Enda knappen är tydlig. Finstilt upprepar löftena ordagrant: korta till "Inget konto." (Kelly har samma förslag). |
| 2. Mikrofon | iOS-dialogen | Ja | – |
| 3. Första frågan | Exempelfrågor + svar | Ja | Kellys förslag: en exempelfråga, Fortsätt blå först efter svaret. |
| 4. Lägg till prov | 19 val | **Nej** | Kellys "Har du prov snart?" med rösten först löser det. |
| 5. Start | Provkort med "Få A-svar till provet", två andra prov med mikrofon, Frågor, Provläge, Fler lägen | **Nej** | Fem knappar som startar lyssning. Elin förstår inte skillnaden mellan den blå knappen, Provläge-cirkeln och mikrofonerna på raderna. Kellys "Förhör mig" + "Bara fråga" + "Fler lägen" är rätt riktning. |
| 6. Lyssnar | "Frågor – Svarar när någon frågar", "Startar …", svar, Fortsätt + röd Avsluta | **Delvis** | "Fortsätt" när den redan lyssnar läser som "nästa fråga". Rött Avsluta ser ut som ett fel. Förslag: en knapp "Pausa" som blir "Lyssna igen", och "Klar" i neutral färg. |
| 7. Inställningar | Röst "Adam", Provlyssna, Svarslängd, Röstkommandon, Minne, Prov med "Inget prov just nu" | **Nej** | "Inget prov just nu" är en dubbel negation på en brytare (på = inget prov). "Adam" säger inget om svensk röst. Prov hör hemma på Start, inte här. |

## Det som är svårast att förstå: Frågor eller Provläge?
- Nästan alla röstkommandon fungerar i **båda** lägena (`docs/COMMANDS.md`). Skillnaden är att Frågor svarar kort på **vem som helst** som frågar, och Provläge pluggar med **dig** och svarar längre.
- Elin vet inte vilket hon ska välja när hon pluggar själv och ställer en kort fråga, eller vad som händer om läraren frågar under Provläge.
- Ord som betyder nästan samma sak: Provläge, Förhör mig, Få A-svar till provet, Förberedelser, Övningsprov, Bara fråga.

**Förslag U1 (stort, ägarbeslut):** ett grundläge, "Lumen", som avgör själv om det är en kort fråga (kort svar) eller plugg (längre, förhör). Backend kan redan avgöra `fact`/`study` (D35) och `continues/new_topic` (D53). Provläge blir då en **handling**, "Förhör mig", inte ett läge. Lägena Intervju, Socialt och Rizz finns kvar under "Fler lägen", eftersom de gäller andra situationer. **Möjligt med begränsningar:** längden bestäms av gissningen; "kortare/längre" och K13:s "Mer?" täcker felgissningar. Ej verifierat.

## Ordlista att använda överallt (app, sida, röst)
Lumen · Förhör mig · Bara fråga · Fler lägen · Lägg till prov · Pausa / Lyssna igen · Klar. Använd **inte** "Få A-svar", "Förberedelser" eller "Provläge" i gränssnittet om U1 blir av.

## Regler för att varje val ska kännas självklart
1. En huvudknapp per skärm.
2. Ett val som inte behövs nu frågas när det behövs (delämne i första passet, dela historik efter första passet).
3. Samma ord på knappen som det man säger till Lumen.
4. Inga dubbla negationer, inga röda knappar utom vid fel.
5. Allt avancerat (mikrofon per läge, paus per läge, kalibrering, diagnostik) bakom en enda rad "Avancerat".
