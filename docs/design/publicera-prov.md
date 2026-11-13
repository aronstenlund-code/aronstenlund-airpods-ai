# Publicera prov och Prov från din skola: design och texter (Kelly, Ke52, D149, D150, 2026-11-13)

Till Angela (A83). Spec: `repetitionslage.md` §11. Serverkontraktet (K49) står i `backend/README.md` under
"Publicera prov". Bilder: `bilder/repetition/pub-*.png`, ljust till vänster och mörkt till höger. Källan är
`_src/repetition.html` (Ke52-blocket), som renderas med `node docs/design/_src/repetition-render.js pub-formular`.
**Det här är skisser. Inget är byggt eller provat på telefon.** Skolorna och användarnamnet i bilderna är exempel.

**Tre regler för hela flödet**
1. **Ordet "övningsprov" används aldrig**, inte heller i VoiceOver, notiser eller felmeddelanden (D149). Det heter
   "prov", "Publicera prov" och "Prov från din skola".
2. **Inget namn utan att man väljer det** (D150). Brytaren "Visa ett användarnamn" är av från början, och fältet
   ber om ett användarnamn, inte ett namn ("Skriv inte ditt riktiga namn": många användare är minderåriga).
3. **Uppmuntra en gång och tjata aldrig.** Publicera prov nämns på provet och i det tomma läget, men inte i notiser,
   inte efter varje repetition och inte med någon räknare som "Bli först".

## 1. Skärmarna
| Skärm | Bild | Det viktigaste |
|---|---|---|
| Provet | `pub-provet.png` | **Publicera prov** är en rad i samma grupp som Dela med klassen, under Starta prov, med raden "Alla som söker på din skola kan plugga på det." Starta prov är fortfarande den enda blå knappen. |
| Publicera prov | `pub-formular.png` | Ett blad med Avbryt. Överst en ruta om vad som publiceras och vad som aldrig gör det. Därunder tre rader: **Skola** (öppnar Välj skola), **Ämne** (lista, förvalt från provets sammanfattning) och **Provdatum** (datumväljare). Sist brytaren **Visa ett användarnamn** (av). Knappen är grå, och raden ovanför den säger vad som saknas. |
| … med användarnamn | `pub-namn.png` | Brytaren på visar ett fält. Fotnot: "Syns för alla som hittar provet. Skriv inte ditt riktiga namn." Ett användarnamn som sparats används som förslag nästa gång, men brytaren är av igen. |
| Välj skola | `pub-skola.png` | Sökfält med fokus. Resultat från två bokstäver (K49 `schools`), med namn i fetstil och ort under. Ingen fritext. Den valda skolan får ✓. Fotnot: "Hittar du inte skolan? Sök på orten." |
| Publicerat | `pub-klart.png` | Ett lugnt kort på provet: ✓ Publicerat, skola · ämne · datum · utan namn (eller "som plugghajen") och "{n} har lagt till provet". Inget annat om ingen har lagt till det. Textknapparna **Ändra** och **Ta bort publiceringen**. Ingen konfetti, och inget delningsblad som öppnas av sig självt. |
| Ta bort publiceringen | `pub-tabort.png` | Ett blad som säger exakt vad som händer. Knappen har röd text (fara), enligt SYSTEM §3. |
| Prov från din skola | `pub-lista.png` | Rubrik, och skolan under med **Byt**. Ämnen som chips ("Alla" först). Två grupper: **Kommande prov** (närmaste datum först) och **Tidigare** (mer än 30 dagar bakåt sjunker, K49). Raden visar titel, ämne · datum och antal frågor, plus användarnamnet bara om personen valt det. Knappen **Lägg till** står på raden. |
| Ett publicerat prov | `pub-forhand.png` | Det man ser innan man lägger till: titel, ämne · datum · skola, antal frågor (· användarnamn), de fyra första frågorna, "och {16} frågor till" och ▶ Lyssna på första frågan. **Lägg till i mina prov** är blå. **Rapportera** står tyst längst ner, med en flagga. |
| Rapportera | `pub-rapport.png` | Ett blad med fyra skäl (en bock) och **Skicka**. Ingen fritext. Efteråt raden "Tack. Vi tittar på det." |
| Inga prov här än | `pub-tom.png` | En mening som uppmuntrar och en sekundär knapp till de egna proven. |
| Hem | `pub-hem.png` | Utan egna prov finns textlänken **Hitta prov från din skola** under Nytt prov. Att hämta är gratis (D151) och ett bra första steg. Med egna prov blir det en rad under ANDRA PROV: "Prov från din skola · 3 nya ›". "Nya" betyder publicerade sedan senast man öppnade listan. |

**Din skola:** första gången man öppnar Prov från din skola visas Välj skola med rubriken "Vilken skola går du på?"
och "Hoppa över". Valet sparas **bara på telefonen** och skickas som `my_school` i sökningen. Det sparas inte i
kontot och publiceras aldrig. Hoppar man över, visas sökfältet för skola överst i listan i stället.

## 2. Texter (kopiera rakt in)
### På provet
| Ställe | Text |
|---|---|
| Rad | Publicera prov |
| Rad under | Alla som söker på din skola kan plugga på det. |
| Rad när ljudet inte är klart (grå) | Publicera prov · *Går när ljudet är klart ({36} av {40})* |
| Kort, publicerat | ✓ Publicerat |
| … rad | {Kungsholmens gymnasium} · {Biologi} · {fre 20 nov} · utan namn |
| … med namn | {Kungsholmens gymnasium} · {Biologi} · {fre 20 nov} · som {plugghajen} |
| … antal (bara när n ≥ 1) | 1 har lagt till provet. / {n} har lagt till provet. |
| … dolt efter rapporter | Provet är dolt medan vi tittar på det. Du kan fortfarande plugga på det själv. |
| Textknappar | Ändra · Ta bort publiceringen |

### Publicera prov (bladet)
| Ställe | Text |
|---|---|
| Rubrik | Publicera prov |
| Avbryt | Avbryt |
| Ruta överst | Alla som söker på skolan kan lägga till provet och plugga på det. **Frågor, svar och ljud** publiceras. Aldrig foton, dokument eller ditt namn. |
| Rader | Skola · Ämne · Provdatum |
| Tomt värde | Välj skola · Välj ämne · Välj datum |
| Brytare | Visa ett användarnamn |
| Fotnot, av | Av: provet visas utan namn. |
| Fält, platshållare | Användarnamn |
| Fotnot, på | Syns för alla som hittar provet. Skriv inte ditt riktiga namn. |
| Saknas (ovanför knappen) | Saknas: {skola, ämne, provdatum} *(serverns `missing` i den ordningen, med små bokstäver)* |
| Ljudet inte klart | Publiceras när ljudet är klart ({36} av {40}). |
| Knapp | Publicera prov |
| Medan det skickas | Publicerar … |
| Klart (kort rad, sedan stängs bladet) | Publicerat. |
| Ändra en publicering, knapp | Spara ändringarna |

**Ämnen** (lista, i den här ordningen): Biologi, Fysik, Kemi, NO, Matematik, Svenska, Engelska, Moderna språk,
Historia, Geografi, Religion, Samhällskunskap, SO, Teknik, Annat. Förvalt är ämnet från sammanfattningen, om det
finns i listan.

**Provdatum:** datumväljaren tillåter från 30 dagar bakåt till 365 dagar framåt. Visas som "fre 20 nov", och med
år om det inte är i år.

### Välj skola
| Ställe | Text |
|---|---|
| Rubrik (från Publicera) | Välj skola |
| Rubrik (första gången i listan) | Vilken skola går du på? |
| … rad under | Då visas prov från din skola först. Det sparas bara på telefonen. |
| Sökfält | Sök skola eller ort |
| Under två bokstäver | Skriv minst två bokstäver. |
| Inga träffar | Ingen skola heter så. Sök på orten. |
| Fotnot | Hittar du inte skolan? Sök på orten. |
| Hoppa över (bara första gången) | Hoppa över |

### Prov från din skola
| Ställe | Text |
|---|---|
| Rubrik | Prov från din skola |
| Rad | {Kungsholmens gymnasium} · Byt |
| Chips | Alla · {ämnen som finns i resultatet} |
| Grupper | KOMMANDE PROV · TIDIGARE |
| Rad | {titel} / {Biologi} · {fre 20 nov} / {20} frågor · {plugghajen} |
| Knapp på raden | Lägg till |
| … efter tryck | Tillagt ✓ *(grå, och raden öppnar då ens egen kopia)* |
| Tomt | **Inga prov här än** · Publicera ditt nästa prov, så kan klasskompisarna plugga på samma frågor. · knapp: Mina prov |
| Tomt med ämnesfilter | Inga prov i {biologi} här än. · textknapp: Visa alla |
| Hem, rad | Prov från din skola · {3} nya |
| Hem utan prov, textlänk | Hitta prov från din skola |

### Ett publicerat prov
| Ställe | Text |
|---|---|
| Rad under titeln | {Biologi} · {fre 20 nov} · {Kungsholmens gymnasium} |
| Rad 2 | {20} frågor · {plugghajen} *(namnet bara om det finns)* |
| Efter de fyra första | och {16} frågor till |
| Textknapp | Lyssna på första frågan |
| Huvudknapp | Lägg till i mina prov |
| Medan det läggs till | Lägger till … |
| Klart | **{Biologiprovet} är tillagt.** Ljudet är redan klart. · knappar: Starta prov *(blå)* · Senare |
| Redan tillagt | Du har redan lagt till provet. · knapp: Öppna |
| Textknapp längst ner | Rapportera |

### Rapportera
| Ställe | Text |
|---|---|
| Rubrik | Rapportera provet |
| Rad | Vad är fel? |
| Skäl (`reason`) | Fel i frågor eller svar (`fel`) · Kränkande innehåll (`krankande`) · Någon annans material (`upphovsratt`) · Något annat (`annat`) |
| Knapp | Skicka |
| Efteråt | Tack. Vi tittar på det. |
| Redan rapporterat | Du har redan rapporterat provet. Tack. |

### Ta bort publiceringen
| Ställe | Text |
|---|---|
| Rubrik | Ta bort publiceringen? |
| Rad | Provet försvinner från listan för {Kungsholmens gymnasium}. {De 12 som redan lagt till det} behåller sin kopia. Ditt eget prov finns kvar. *(Utan tillägg: "Ditt eget prov finns kvar." direkt efter första meningen.)* |
| Knapp (röd text) | Ta bort publiceringen |
| Avbryt | Avbryt |
| Efteråt | Publiceringen är borttagen. |

### Fel
| Fall | Text |
|---|---|
| Ingen internetanslutning | Ingen internetanslutning. Försök igen när du är uppkopplad. |
| Skolorna går inte att hämta | Skolorna går inte att hämta just nu. Försök igen om en stund. |
| Publiceringen misslyckades | Det gick inte att publicera just nu. Försök igen om en stund. |
| Det publicerade provet är borttaget eller dolt (404) | Provet finns inte längre. |
| Okänt | Något gick fel. Försök igen. |

### VoiceOver
| Element | Etikett |
|---|---|
| Lägg till på en rad | Lägg till {Biologiprovet} |
| Flaggan | Rapportera provet |
| Brytaren | Visa ett användarnamn, av / på |
| Skolraden | {Kungsholmens gymnasium}, {Stockholm} |

## 3. Till Angela och Kevin
- **Ordet "övningsprov" finns kvar i appen i dag** (grep 2026-11-13 21:17), i det gamla röstförhöret A16 (BETA). Det
  syns eller hörs på tre ställen:
  `ListeningScreen.swift:101` (knappen "Kör övningsprovet"), `ListeningScreen.swift:153` ("Övningsprov, …") och
  `ListeningModel.swift:2875` (sägs: "Övningsprov, {n} frågor …"). Förslag: knappen heter **"Förhör mig på provet"**,
  raden och det som sägs blir **"Provfrågor, {n} frågor …"**. Röstkommandona i `PracticeRun.swift` får fortsätta
  känna igen "övningsprovet" när användaren själv säger det, eftersom det inte visas. Efter rättningen ska
  `grep -rn '"[^"]*vningsprov' Lumen --include=*.swift` bara ge träffar i reguljära uttryck och kommentarer.
- "3 nya" på Hem kräver att appen minns när listan öppnades senast (på telefonen). Det behövs inget i K49.
- **Till Kevin (K49):** `report` en andra gång från samma konto bör ge ett tydligt svar (409 `already_reported`), så att
  appen kan visa "Du har redan rapporterat provet". Kontraktet säger inte vad som händer i dag.
- **Ej verifierat:** att Skolverkets register ger ort (`locality`) för alla skolor. Saknas den, visas bara namnet.
