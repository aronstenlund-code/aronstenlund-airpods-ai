# Läsläget: design och texter (Kelly (moln), Ke63, D185, 2026-11-15)

Underlag till Angela Fable (A106, vyerna), Angela Schrute (A105, logiken och låsskärmen) och Kevin (HJALP.md, K70).
Skisserna ligger i `bilder/lasa/<id>.png`, ljust till vänster och mörkt till höger. Källan är `_src/lasa.html` (samma
iOS-stil som Ke53, `apple.html`), och den renderas med `node docs/design/_src/lasa-render.js`. **Det här är skisser.
Inget är byggt och inget är provat på telefon.** Exempeltexten (biologi åk 9) är påhittad.

## 1. Förebilden
**Texten i Musik som följer låten** (synkade låttexter): raden som sjungs är fullfärgad och halvfet, resten är grå,
texten skrollar av sig själv och ett tryck på en rad hoppar dit. Det är exakt vad D185 beskriver, och iPhone-användare
känner redan igen det. Knapparna är systemets spelarknappar (Musik och Podcaster): bakåt, paus/spela och framåt.

## 2. Skärmarna
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Nytt prov: Frågor | `nytt-fragor.png` | **Svar till A106: segmenterad kontroll**, inte två rader. Valet har två korta ord och byter vad resten av avsnittet visar, och det är just det segmenterade kontroller är till för i iOS. Den står i ett eget avsnitt **Gör**, direkt under materialet, med **Frågor** förvalt. Under kontrollen bara det som gäller valet: Antal frågor och Vilken årskurs?. |
| Nytt prov: Läs upp texten | `nytt-las.png` | Antal frågor och årskurs försvinner. Två fotnoter: vad det blir och vad det kostar. Huvudknappen heter **Skapa uppläsning**. Raden under knappen är densamma som för frågor (kvoten). |
| Stämmer det här? (text) | `las-stammer.png` | Ämne och årskurs som i dag. I stället för frågorna: **Rubriker** med antal meningar per rubrik, och en rad med längden. Kostnaden i siffror under knappen innan ljudet görs. Rättelsefältet som i dag. |
| Provets skärm: en text | `text.png` | I stället för frågelistan visas hela texten i ett kort, rubrikerna fetstilta. Tryck på en mening startar spelaren där. Starta prov ligger fast nederst, precis som för frågor. ⋯-menyn och Dela som för frågor (Ändra ordning finns inte för en text). |
| Spelaren: läser | `spelare.png` | Överst: Avsluta (textknapp), provets namn, "Mening 5 av 9" och rubriken man är under, och en tunn förloppslinje. Texten: lästa meningar halvt fullfärgade, **meningen som läses fullfärgad, halvfet och med `tintsoft` bakom**, kommande grå. Texten skrollar så att meningen som läses står i övre tredjedelen. Nederst ⏮ ⏸ ⏭ och raden med trycken. |
| Spelaren: pausad | `spelare-paus.png` | Markeringen blir grå (`fill`), ⏸ blir ▶ och raden "Pausad. Fortsätter från början av meningen." visas (D164). Första tryckgruppen heter nu Fortsätt. |
| Spelaren: slut | `spelare-slut.png` | **Förslag:** texten börjar inte om av sig själv (D185 säger inget). Skärmen säger "Slut på texten" och har Börja om. 1 tryck på AirPods = Börja om, 3 tryck = förra meningen. Ändra det om Deangelo vill att texten går runt som frågelistan. |
| Hem: en text | `hem-text.png` | Raden under namnet säger **Text · cirka {m} min** i stället för antal frågor. Ingen egen färg och ingen egen ikon: ordet räcker, och kortet och knappen är desamma. |
| Styr med dina AirPods: en text | `kontroller-text.png` | Samma skärm och test som för frågor, men med textens tre tryck. Visas första gången man startar en text (se 4.1). |

## 3. Regler
1. **Bara en sak lyser:** meningen som läses. Ingen ordmarkering inuti meningen (för plottrigt i löpande text).
2. **Skrollning:** meningen som läses hålls i övre tredjedelen. Skrollar användaren själv slutar texten följa med, och
   en liten knapp "Till meningen" visas nere till höger tills man trycker på den eller nästa rubrik börjar (som Musik).
3. **Tryck på en mening** = börja läsa där, även när det är pausat. Långtryck gör ingenting.
4. **Knapparna:** SF Symbols `backward.fill`, `pause.fill`/`play.fill` och `forward.fill` (som Musik), stora träffytor
   (minst 44 pt, paus 64 pt). VoiceOver: "Förra meningen", "Pausa"/"Fortsätt", "Nästa mening".
5. **Avsluta** är en textknapp uppe till vänster, aldrig röd. Platsen sparas (A105), och nästa start fortsätter från
   den meningen, som "Fortsätt" för frågor.
6. **Största text:** texten följer Dynamic Type helt. Raden med trycken staplas lodrätt vid `.accessibility1` och uppåt,
   och knapparna ligger kvar på en rad.
7. **Mörkt läge:** svart bakgrund som i skissen. Markeringen är `tintsoft` på svart.
8. **Ingen mikrofon** i läsläget, precis som Starta prov.

## 4. Till Deangelo och Angela
1. **Trycken betyder olika saker i de två lägena.** I frågor är 1 = långt svar, 2 = kort svar, 3 = paus. I en text är
   1 = paus, 2 = nästa mening, 3 = förra meningen (D185). Det bryter mot regeln "ett tryck betyder alltid samma sak"
   (repetition.md §4.1). Textens tryck följer systemet (Spela/pausa, Nästa spår, Förra spåret), så de är lätta att lära,
   men användaren måste se dem. Därför: **kontrollskärmen visas första gången man startar en text**, och raden med
   trycken står alltid under spelarknapparna. **Ej verifierat på telefon.**
2. **Knappen heter Starta prov** även för en text (Arons namn, D142). Det håller Hem och provets skärm likadana.
3. **Låsskärmen (A105):** titel = rubriken man är under (eller provets namn om texten saknar rubriker), artist =
   "EarMind · {Biologiprovet} · mening {5} av {9}". Byt inte titel för varje mening: det blinkar på låsskärmen.
   Med `previousTrack`/`nextTrack` på syns ⏮ ⏸ ⏭ (**ej verifierat**, samma som för frågor).
4. **Första starten** (D160) visar inte valet. En ny användare gör frågor. Valet syns från andra provet.
5. **Kostnaden** visas före och efter: fotnoten i Nytt prov förklarar regeln, och Stämmer det här? säger exakt
   ("Texten räknas som {k} frågor"). Räcker kvoten inte, säger samma rad det innan ljudet görs (se texterna).

## 5. Texter
Kolumnen **Text** kopieras rakt in, och `{…}` är värden. Pluralformer som i `repetition-texter.md`.

**Nytt prov**
| Ställe | Text |
|---|---|
| Avsnittets rubrik | GÖR |
| Segmenterad kontroll | Frågor · Läs upp texten |
| Fotnot vid Frågor | Varje fråga får ett kort och ett långt svar. *(som i dag)* |
| Fotnot 1 vid Läs upp texten | EarMind läser upp materialet som en löpande text, utan frågor. Du pausar och hoppar mellan meningar med AirPods. |
| Fotnot 2 vid Läs upp texten | Texten räknas som en fråga per påbörjade 800 tecken, ungefär en tredjedel av en boksida. |
| Huvudknapp | Skapa frågor · Skapa uppläsning |
| VoiceOver på kontrollen | Gör, Frågor / Gör, Läs upp texten |

**Läser materialet** (steg)
| Ställe | Text |
|---|---|
| Steg vid text | Läser sidorna · Tar reda på ämne och årskurs · Gör texten klar för uppläsning |
| Fotnot | Det tar ungefär en minut. Du kan lämna appen. *(som i dag)* |

**Stämmer det här? (text)**
| Ställe | Text |
|---|---|
| Avsnitt | RUBRIKER · rad: {Fotosyntesen} · {6} meningar |
| Utan rubriker i materialet | *(avsnittet visas inte)* |
| Rad under | {9} meningar · cirka {1} min. Sidnummer och sidhuvuden är borttagna. |
| Platshållare i rättelsen | Till exempel ”Ta inte med sista sidan” |
| Under knappen (K70 `counts_as`) | Texten räknas som {1} fråga. {11} kvar sedan. |
| … kvoten räcker inte | Texten räknas som {9} frågor, och du har {6} kvar den här månaden. Ta bort några sidor, eller vänta till den 1 {december}. *(Ser rätt ut grå)* |
| … `truncated` (K70: högst 40 000 tecken) | Materialet var för långt. EarMind läser upp de första cirka {16} sidorna. Gör ett prov till av resten. |
| Materialet hade ingen text (422 `drill_unreadable`) | EarMind hittade ingen text att läsa upp. Fota sidorna igen eller klistra in texten. · knapp: Lägg till material |

**Provets skärm (text)**
| Ställe | Text |
|---|---|
| Rad under rubriken | Text · {9} meningar · cirka {1} min · ljud klart |
| … medan ljudet görs | Text · {9} meningar · Ljud: {2} av {3} klara |
| Fotnot under texten | Tryck på en mening för att börja där. |
| Huvudknapp | Starta prov · *(efter avbrott)* Fortsätt |
| Rad under knappen | Spelas i dina AirPods. Mikrofonen används inte. |
| VoiceOver på en mening | {meningen}. Knapp. Tips: Börjar läsa här. |

**Spelaren**
| Ställe | Text |
|---|---|
| Uppe till vänster | Avsluta |
| Överst | Mening {5} av {9} · {Fotosyntesen} |
| Pausad | Pausad. Fortsätter från början av meningen. |
| Tryckraden | ● Paus · ●● Nästa mening · ●●● Förra meningen *(pausad: ● Fortsätt)* |
| Knapp när man skrollat bort | Till meningen |
| Slut, rubrik | Slut på texten |
| Slut, rad | Du har lyssnat igenom hela {Biologiprovet}. |
| Slut, knapp | Börja om |
| Slut, tryckraden | ● Börja om · ●●● Förra meningen |
| Väntar på ljud | Gör ljud … |
| Inget nät och ljudet saknas | Ingen internetanslutning. Resten av texten kommer när du är uppkopplad. |
| VoiceOver på knapparna | Förra meningen · Pausa / Fortsätt · Nästa mening |

**Hem**
| Ställe | Text |
|---|---|
| Provkort, rad under namnet | Text · cirka {6} min |
| Rad under ett annat prov | Text · cirka {11} min · ljud klart |

**Styr med dina AirPods (text)**
| Rad | Text |
|---|---|
| Rubrik över raderna | Medan texten läses: |
| 1 (●) | Tryck 1 gång för att pausa eller fortsätta. |
| 2 (●●) | Tryck 2 gånger för nästa mening. |
| 3 (●●●) | Tryck 3 gånger för förra meningen. |
| Testets rader | Paus · *Tryck en gång* / Nästa mening · *Tryck två gånger* / Förra meningen · *Tryck tre gånger* |

**Låsskärmen**
| Fält | Text |
|---|---|
| Titel | {rubriken}, annars {Biologiprovet} |
| Artist | EarMind · {Biologiprovet} · mening {5} av {9} |

## 6. Till Kevin: avsnitt till docs/HJALP.md
Läggs in efter "Starta prov och styr med AirPods" och i `_shared/hjalp.ts` samtidigt (testet kräver att de är lika).
Raden "att hoppa över en fråga eller gå tillbaka till förra frågan" under "Det här finns inte" gäller fortfarande frågor
och står kvar.

> ## Läs upp texten
> - I **Nytt prov** väljer du **Frågor** eller **Läs upp texten**. Med Läs upp texten gör EarMind inga frågor, utan
>   läser upp ditt material som en löpande text med samma röst.
> - EarMind gör texten klar för uppläsning: rubriker läses som rubriker, sidnummer och sidhuvuden tas bort, och fel
>   från fotot rättas. Innehållet ändras inte och kortas inte.
> - **Trycken** i en text: 1 tryck = pausa eller fortsätt. 2 tryck = nästa mening. 3 tryck = förra meningen. När du
>   fortsätter börjar EarMind från början av meningen.
> - På skärmen ser du texten, och meningen som läses är markerad. Tryck på en mening för att börja där. Knapparna
>   under texten gör samma sak som trycken.
> - När texten är slut börjar den inte om av sig själv. Tryck **Börja om** för att lyssna igen.
> - **Kostnad:** texten räknas som en fråga per påbörjade 800 tecken, ungefär en tredjedel av en boksida. Under
>   **Stämmer det här?** ser du hur många frågor texten räknas som, innan ljudet görs.
> - Du kan dela och publicera en text precis som ett prov med frågor.

Punkten om att texten inte börjar om gäller bara om Deangelo håller med om förslaget i 2 (Spelaren: slut).
