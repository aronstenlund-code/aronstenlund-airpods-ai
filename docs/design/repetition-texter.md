# Repetitionsläget: alla texter (Kelly, Ke50, D142–D147, 2026-11-13)

Till Angela (A78–A81). Kolumnen **Text** kopieras rakt in, och `{…}` är värden. Kolumnen **I koden nu** visar vad
utkastet b669d02 (Toby, D147) säger när det skiljer sig. Där den är tom stämmer koden redan. Utseendet står i
`repetition.md` och bilderna i `bilder/repetition/`.

**Ton:** du-form och korta meningar, med verbet först på knappar. Inga utropstecken och inga leverantörs- eller
modellnamn (ElevenLabs, Haiku, Sonnet). Säg inte "A+-svar" i appen, säg "Långt svar". Citat skrivs med ”…”. Tryck
skrivs alltid i samma ordning: 1 tryck = långt svar, 2 tryck = kort svar, 3 tryck = paus.

**Pluralformer:** "1 fråga" / "{n} frågor", "1 sak" / "{n} saker" och "1 fil" / "{n} filer". Använd
`String(localized:)` med `^[\(n) fråga](inflect: true)` eller två strängar. Skriv aldrig "1 frågor".

## 1. Hem
| Ställe | Text | I koden nu |
|---|---|---|
| Provkort, liten rubrik | NÄSTA PROV | |
| Provkort, bricka | {n} dagar kvar · I morgon · I dag | |
| Provkort, rad under namnet | {n} frågor · cirka {m} min per varv | |
| Huvudknapp | Starta prov | |
| Textknappar på kortet | Frågor och svar · Dela | |
| Sekundär knapp | Nytt prov | |
| Sektionsrubrik | ANDRA PROV | |
| Rad under ett annat prov | {n} frågor · ljud klart | |
| … när ljudet görs | Ljud: {klara} av {alla} klara | |
| VoiceOver på ▶ | Starta {provnamn} | |
| Rad längst ner | Fler lägen [BETA] | |
| Låst ▶ medan provet öppnas | Öppnar provet … | Öppnar provet |

**Hem utan prov**
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | Kom förberedd till provet *(Aron 22:19, A86)* | |
| Rad | Fota ditt material. Earmind gör frågor och svar och läser upp dem i örat. Du styr med tryck på AirPods, utan mikrofon. | Fota sidorna eller lägg till text. Earmind gör provfrågor med svar och läser dem i dina AirPods. Du styr med tryck, utan mikrofon. |
| Huvudknapp | Nytt prov | |

## 2. Nytt prov
| Ställe | Text | I koden nu |
|---|---|---|
| Navigationsrubrik | Nytt prov | |
| Avbryt (uppe till höger) | Avbryt | |
| Namnfält, platshållare | Provets namn, till exempel Biologiprovet | Till exempel Biologiprovet |
| Ruta 1 | Fota sidor · *Flera i följd* | Fota sidor (flera i följd) |
| Ruta 2 | Välj bilder · *Ur bildbiblioteket* | Ur bildbiblioteket |
| Ruta 3 | Skriv text · *Eller klistra in* | Eller klistra in text |
| Ruta 4 | Dokument · *PDF, Word, text* | |
| Rubrik över miniatyrerna | TILLAGT · {n} saker | Tillagt: {n} … |
| VoiceOver på × | Ta bort {sida 3 / namn.pdf} | |
| Rad | Antal frågor · {20} | Antal frågor: {20} |
| Rad | Långa svar · Kortare / Normal / Längre | |
| Fotnot | Normal är ett fullt A-svar på cirka {90} ord. Det korta svaret är första meningen. | Långa svar är ett fullständigt A-svar, omkring {90} ord. Det korta svaret är alltid den första meningen. |
| Fotnot 2 | Foton, dokument och text skickas en gång för att göra frågorna och sparas inte. | |
| Huvudknapp | Skapa frågor | |
| Huvudknapp utan material (avstängd) | Skapa frågor *(grå)* | |
| Om man trycker ändå | Lägg till material först. | |

**Fel när material läggs till**
| Fall | Text | I koden nu |
|---|---|---|
| Fil som inte går att öppna | {namn} gick inte att öppna. | |
| Fil utan text | {namn} har ingen text som går att läsa. Fota sidorna i stället. | {namn} gick inte att läsa. |
| Word-fil | *(ta bort felet: K45 `doc_text` läser .docx)* | {namn}: Word-filer går inte att läsa än. Spara som PDF … |
| För många bilder i en omgång | Högst {10} bilder åt gången. Lägg till resten efteråt. | |
| Kameran nekad | Earmind får inte använda kameran. Tillåt den i Inställningar, eller välj bilder ur bildbiblioteket. · knapp: Öppna Inställningar | |

## 3. Läser materialet
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | Läser ditt material | |
| Rad | {6 foton, 1 PDF och 1 text}. | Tar reda på ämne och årskurs, gör frågor och skriver svar. Det tar ungefär en minut. |
| Steg 1–4 | Läser sidorna · Tar reda på ämne och årskurs · Gör frågor · Skriver svar | *(en rad)* |
| Fotnot | Det tar ungefär en minut. Du kan lämna appen. | |
| Notis när det är klart (bara om notiser redan är tillåtna) | **{Biologiprovet} är klart.** {20} frågor med svar. Tryck för att titta på dem. | |

## 4. Stämmer det här?
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | Stämmer det här? | |
| Rader | Ämne · Årskurs · Provet handlar om | |
| Fältets rubrik | NÅGOT FEL? SKRIV DET | |
| Platshållare | Till exempel ”Det är åk 8” eller ”Ta inte med cellandning” | |
| Knapp när fältet har text | Gör om med rättelsen | |
| Rad under frågorna | {20} frågor. Du kan ändra, ta bort och lägga till efteråt. | {20} frågor / Du kan ändra … (två rader) |
| … fler än fem visas | och {15} till | |
| Huvudknapp | Ser rätt ut | |
| Testläge (mock, bara Debug) | Exempel (testläge): {ämne}. | |

## 5. Frågelistan
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | {Biologiprovet} | |
| Rad under | {20} frågor · {åk 9} · Sammanfattning | {20} frågor · {åk 9} |
| Knapp uppe till höger | Ändra · Klar | |
| Raden under i Ändra | Dra för att ändra ordning. Ordningen är den du hör. | |
| Sista raden i Ändra | Lägg till fråga | |
| Ljudets förlopp | Ljud: {klara} av {alla} klara | |
| … klart | Ljud klart | |
| … medan det görs, höger | Görs i spelordning | |
| Huvudknapp | Starta prov | |
| Rad under knappen | Spelar frågorna i dina AirPods. Earmind använder inte mikrofonen. | |
| Knappen innan första frågans ljud finns | Gör ljud … *(grå)* | Starta prov går när ljudet är klart. |
| Ta bort provet (längst ner, röd text) | Ta bort provet | |
| Bekräftelse | **Ta bort {Biologiprovet}?** Frågorna, svaren och ljudet försvinner från alla dina enheter. Kopior som du har delat finns kvar hos de andra. · Ta bort *(röd)* · Avbryt | |
| Provet finns inte | Provet finns inte längre. | |

**Ljudets förlopp:** räkna filer, inte frågor. Med iPhonens röst (D147) blir det 3 filer per fråga. Med serverns ljud
(K46, D145) blir det 2 per fråga. Texten är densamma.

## 6. Redigera en fråga
| Ställe | Text | I koden nu |
|---|---|---|
| Navigationsrubrik | Fråga {1} · Ny fråga | Ändra fråga · Ny fråga |
| Spara / Avbryt | Spara · Avbryt | |
| Fältets rubrik | FRÅGA · {4} ord | |
| … över 5 ord (grått, inte rött) | Helst högst fem ord. | |
| Fältets rubrik | SVAR · {88} ord | Långt svar (1 tryck) · {88} ord |
| Rad under svaret | Första meningen är det korta svaret (2 tryck). Hela svaret är det långa (1 tryck). | Det långa svaret börjar alltid med det korta. … |
| Om det korta och det långa svaret ligger i två fält (D147, tills K46) | KORT SVAR (2 TRYCK) / LÅNGT SVAR (1 TRYCK) · rad: Det långa svaret börjar alltid med det korta. | |
| Rutan nederst | Sparar du en ändring görs nytt ljud bara för den här frågan. | *(ihop med raden ovan)* |
| Textknappar | Lyssna · Nytt förslag | |
| Knapp på en ny fråga utan svar | Låt Earmind skriva svaret | Låt Earmind skriva svaren |
| … medan det görs | Skriver svaret … | Skriver svar … |
| Fel | Earmind kunde inte skriva svaret just nu. Skriv det själv eller försök igen. | … svaren … Skriv dem själv … |
| Lämna med osparade ändringar | **Spara ändringarna?** · Spara · Släng ändringarna *(röd)* · Avbryt | |

## 7. Styr med dina AirPods (kontrollskärmen)
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | Styr med dina AirPods | |
| Rad under rubriken (bara innan första trycket) | Frågan spelas en gång så att trycken kommer fram. | *(saknas, D147 punkt 5)* |
| Stor instruktion | Tryck en gång nu · Tryck två gånger nu · Tryck tre gånger nu | |
| Rad under | på skaftet, som när du pausar musik · … byter låt · … går tillbaka en låt | |
| Rad 1 | Långt svar · *Hela svaret* | 1 tryck · Långt svar |
| Rad 2 | Kort svar · *Bara första meningen* | 2 tryck · Kort svar |
| Rad 3 | Paus · *Vilket tryck som helst fortsätter* | Paus, och 3 igen för att fortsätta |
| Status | Väntar … · Sen · ✓ | |
| Status när inget kom inom 8 s | Kom inte fram | |
| Uppe till höger | Hoppa över | |
| Allt klart, rubrik | Allt fungerar | |
| … rad | Under paus fortsätter vilket tryck som helst. | Under paus fortsätter … Avsluta på telefonen. Annars börjar listan om. |
| … rad med låsikon | Knapparna på låsskärmen gör samma sak. | |
| Huvudknapp | Starta prov | |
| Rad under knappen | Avsluta på telefonen. Annars börjar listan om. | |

**Ett tryck kom inte fram**
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik i rutan, när 1 tryck fungerar men inte 2 eller 3 | Dina AirPods har dubbeltryck per lur | |
| Rad | Ställ in dem så här, så fungerar alla tre: | |
| Rader | **Vänster:** Nästa spår → kort svar · **Höger:** Spela/pausa → långt svar och paus | |
| Väg (ej verifierad i iOS 26, kontrollera på telefon) | Inställningar › Bluetooth › ⓘ vid dina AirPods › Dubbeltryck | |
| Knapp | Öppna Inställningar | |
| Rubrik när inget tryck alls kommer fram | Trycken kom inte fram | Trycket kom inte fram |
| … rad | Kolla att båda AirPods sitter i öronen och är anslutna. Knapparna på låsskärmen fungerar alltid. | Kolla att AirPods sitter i öronen … Spelarknapparna på låsskärmen fungerar alltid. |
| Textknapp | Prova igen | |
| Huvudknapp | Starta ändå | |

**Inga AirPods anslutna**
| Ställe | Text |
|---|---|
| Rubrik | Anslut dina AirPods |
| Rad | Ta ut dem ur fodralet och sätt dem i öronen. Det går också att lyssna i telefonens högtalare. |
| Huvudknapp | Starta ändå |

## 8. Uppspelningen
| Ställe | Text | I koden nu |
|---|---|---|
| Överst | Fråga {7} av {20} · Varv {2} | |
| Bricka | {Biologiprovet} · Frågan · Tänk · Långt svar · Kort svar · Pausad | |
| Under ringen | Tänk | |
| Väntar på ljud | Gör ljud … | |
| Pausad, stort | Tryck på AirPods för att fortsätta | Pausad. Tryck på AirPods för att fortsätta. Fortsätter från samma ord. |
| Pausad, litet | Fortsätter från samma ord | |
| Tryckraden | ● Långt svar · ●● Kort svar · ●●● Paus *(Fortsätt när pausat)* | Långt / 1 tryck … |
| VoiceOver på tryckraden | {Långt svar}, {1 tryck} på AirPods | |
| Knapp | Avsluta | |
| VoiceOver-tips på Avsluta | Avslutar provet. Du kan fortsätta där du var nästa gång. | Det enda som avslutar. Annars börjar listan om. |
| Efter Avsluta (kort rad) | Sparat på fråga {7}. | Provet är avslutat. |
| Avbrutet av en annan app | Pausat. {Spotify} spelar nu. Tryck på ▶ här eller på låsskärmen för att fortsätta. *(Använd "En annan app" om namnet saknas.)* | |
| AirPods bortkopplade | Pausat. AirPods kopplades bort. | |

## 9. Låsskärmen (Now Playing)
| Fält | Text |
|---|---|
| Titel | {frågan}, till exempel ”Varför behövs klorofyll?” |
| Artist | Earmind · {Biologiprovet} · {7} av {20} |
| Album | {Biologiprovet} |
| Bild | appikonen (exakt D, D139) |

## 10. Fortsätt där du var?
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | Fortsätt där du var? | |
| Rad | {Biologiprovet}, fråga {7} av {20}. | |
| Huvudknapp | Fortsätt | Fortsätt / Fortsätt från fråga {7} *(två ställen)* |
| Sekundär | Börja från fråga 1 | |
| Textknapp | Inte nu | |

## 11. Dela
| Ställe | Text | I koden nu |
|---|---|---|
| Rubrik | Dela med klassen | |
| Rad | Kompisarna får samma frågor, svar och ljud. De behöver ett gratis Earmind-konto. | Frågor, svar och ljud delas. Foton och dokument delas inte. … |
| Lista | Frågor och svar · {20} / Ljud · {36} av {40} / Foton och dokument · delas inte | |
| Fotnot | Ändrar någon en fråga i sin kopia ändras inte ditt prov. | |
| Knapp, avstängd | Delas när ljudet är klart ({36} av {40}) | |
| Knapp, klar | Dela | Skicka länken |
| Medan länken görs | Gör en länk … | |
| Text i delningsbladet | Plugga {Biologiprovet} med mig i Earmind: {länk} | Plugga {titel} med Earmind |
| Utan K47 | Delning kommer snart. | |
| Fel | Det gick inte att dela just nu. Försök igen om en stund. | Det gick inte att dela just nu. |
| Mottagaren, klart | {Biologiprovet} är tillagt. | |
| Mottagaren, utan konto | Logga in för att lägga till {Biologiprovet}. Det är gratis. | |
| Mottagaren, delningen avstängd | Det här provet delas inte längre. | Provet gick inte att öppna. |
| Mottagaren, tills K47 | Delade prov går inte att öppna än. | |
| Den som delat: stäng delningen | Sluta dela · bekräftelse: **Sluta dela {Biologiprovet}?** Nya kan inte öppna länken. De som redan har provet behåller sin kopia. | |

## 12. BETA och Fler lägen
| Ställe | Text |
|---|---|
| Märket | BETA *(versaler, grå kontur, ingen färg)* |
| Rubrik | Fler lägen |
| Ingress | De här lägena lyssnar på vad du säger. De är i BETA och blir bättre hela tiden. |
| Rader | Standardläge · Förhör med rösten · Intervju · Socialt · Rizz · Sömn *(alla med BETA)* |
| Fotnot | Lyssnande lägen använder mikrofonen. Starta prov gör det aldrig. |
| VoiceOver på märket | Beta, under utveckling |

## 13. Fel och gränser
| Fall | Text | Knapp |
|---|---|---|
| Inget nät när frågorna ska göras | Ingen internetanslutning. Frågorna görs när du är uppkopplad igen. | Försök igen |
| Inget nät under uppspelning | *(ingen text: ljud som redan är nedladdat spelas som vanligt)* | |
| Inget nät, nästa ljud saknas | Ingen internetanslutning. Ljudet för fråga {8} kommer när du är uppkopplad. Frågorna med ljud spelas under tiden. | |
| Frågorna kunde inte göras (nätet finns, anslutningen bröts eller servern svarade fel) | Det gick inte att skapa frågorna. Försök igen. *(A85)* | Försök igen |
| Materialet räckte inte | Earmind hittade för lite att göra frågor av. Lägg till fler sidor eller mer text. | Lägg till material |
| Ljud kunde inte göras (rösttjänsten svarar fel) | Ljudet för {3} frågor kunde inte göras. Earmind försöker igen av sig själv. | Försök nu |
| Dagens gräns för nytt ljud (K46) | Dagens gräns för nytt ljud är nådd. Resten görs i morgon. Frågorna som har ljud kan du plugga på redan nu. | |
| Inloggningen gick ut | Logga in igen för att spara provet. Ingenting har försvunnit. | Logga in |
| Okänt fel | Något gick fel. Försök igen. | Försök igen |
