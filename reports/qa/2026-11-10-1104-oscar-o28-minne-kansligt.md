# Oscar O28: Kodens skyddsnät för känsliga minnen (/memory och appen), offline

Datum: 2026-11-10, 11:02–11:04
Uppgift: stående uppgift (PLAN 2b).

**Regeln (D80, ändrad 2026-11-08):** Lumens minne sparar aldrig följande, även om modellen föreslår det:
- hemadress, skulder, pengar;
- känsliga kategorier enligt GDPR art. 9: hälsa, religion, politik, sexualitet, etnicitet, brott;
- fakta om andra personer.

Modellen är första lagret. Här testas kodlagret: servern (`memory/handler.ts`, `SENSITIVE_RAW` efter `STUDY_WORDS`) och appen (`Lumen/Core/History/MemoryExtraction.swift`, `SensitiveFilter.stems`).

**Skript:** `scripts/qa/o28_memory_sensitive_offline.mjs`. Kostnad: 0 USD.
- `handler.ts` importerar `npm:`-paket som Node inte kan läsa in. Därför läser skriptet de två driftsatta reguljära uttrycken direkt ur filen och använder dem som `parseMemoryReply` gör.
- Appens lista testade jag med samma fall (delsträngar som i `isSensitive`).

**Rådata:** `reports/qa/data/2026-11-10-1103-o28-memory.json`

**Verified in code.** Appens filter är bara läst och tillämpat i Python, inte kört på telefonen.

## Varför det är viktigt
Ett sparat minne skickas med i varje fråga, alltså till servern och till AI-modellen. Ett minne som "Har haft självmordstankar" eller "Har epilepsi" följer därmed med i varje anrop tills eleven tar bort det.

## Resultat
| Del | Servern | Appen | Båda tillsammans |
|---|---|---|---|
| Känsliga minnen som stoppas | **2/27** | 5/27 | **5/27** |
| Vanliga studieminnen som sparas | 15/20 | 14/20 | – |

**Känsliga minnen som går igenom båda filtren (22 av 27):**
| Kategori | Minne |
|---|---|
| hälsa | "Har epilepsi", "Har celiaki och äter glutenfritt", "Tar Concerta varje morgon", "Har dyslexi", "Väger 45 kilo och vill gå ner", "Har mens och ont i magen" |
| kris | "Skär sig ibland när det är jobbigt", "Har haft självmordstankar" |
| sexualitet | "Är bi", "Har en pojkvän som heter Ali" |
| religion | "Fastar under ramadan", "Går i kyrkan varje söndag" |
| politik | "Är med i Ungsocialisterna" |
| ursprung | "Kommer från Syrien", "Är romsk" |
| brott | "Har snattat" |
| andra personer | "Mamma heter Karin och jobbar på ICA" |
| kontakt | "Telefonnummer 070 123 45 67", "Mejl elin.k@gmail.com", "Instagram lisa_2009" |
| pengar och plats | "Har 2000 kr på kortet", "Bor i Rinkeby" |

Stoppas av något av filtren:
- "Röstade på Vänsterpartiet" och "Bästa kompisen Elin har ADHD" (av båda);
- "Är gay", "Har en ätstörning" och "Pappa sitter i fängelse" (bara av appen).

**Studieminnen som felaktigt stoppas** (ordbitar inuti vanliga ord):
| Minne | Stoppas av | Ord |
|---|---|---|
| "Har lånat en bok om rymden" | båda | "lån" |
| "Gillar sjukt mycket fotboll" | båda | "sjuk" |
| "Skriver en uppsats om brottslighet i Sverige" | båda | "brott" |
| "Läser om kristendomen i religion" | båda | "kristen" |
| "Har prov i historia om judeförföljelsen" | båda | "jude" |
| "Läser religionskunskap" | **bara appen** | K8 rättade det på servern, men inte i appens lista |

## Till Kevin (server) och Angela (app)
- **Kevin:** utvidga `SENSITIVE_RAW` med följande:
  - hälsa: epilepsi, celiaki, gluten/laktos, intolerans, dyslexi, mens, väger/kilo, ätstörning, medicinnamn som Concerta, Elvanse och Ritalin;
  - kris (samma ord som `crisis.ts`);
  - gay, bi, lesbisk och relationer med namn;
  - religion: ramadan, fasta, kyrka, moské, synagoga, bön;
  - politik: "är med i", ungdomsförbund, parti;
  - ursprung: "kommer från" + land, romsk, same;
  - brott: snatta, fängelse, gripen;
  - kontaktuppgifter: e-post, telefonnummer, @-namn och "insta/snap";
  - pengar och plats: "kr", "bor i".
- **Kevin:** använd ordgränser (`\b`) för korta stammar ("lån", "sjuk", "brott", "kristen", "jude"), så att "lånat", "sjukt", "brottslighet", "kristendomen" och "judeförföljelsen" blir kvar. Undanta också ordet när det står efter "om", "i" eller "uppsats om".
- **Angela:** låt appens `SensitiveFilter` följa serverns lista, inklusive K8:s studieord. I dag stoppar appen "Läser religionskunskap", som servern släpper igenom.
- **Båda:** en enda lista på ett ställe, eller ett gemensamt test med de 47 fallen: `node scripts/qa/o28_memory_sensitive_offline.mjs`.

## Kostnad
0 USD.
