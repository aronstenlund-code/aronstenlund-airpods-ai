# O106: lyssnarläget i vardagen, spelat genom K122, Oscar (moln)

> Modellsvaren är skrivna av en Claude-agent som spelar modellen utan att känna till bedömningen, **inte av modellen i drift**. Det som går att lita på är serverns vägval (frågegrinden, direktvägen, avklippta frågor), promptarnas innehåll och talformatet.

**Omfattning:**
- **28 fall** i `scripts/qa/o106/cases.json`, alla `mode: auto` (lyssnarläget, Standard).
- Situationer:
  - en lärare som frågar klassen;
  - en kompis som frågar något;
  - korta och halva frågor;
  - följdfrågor och ämnesbyte med `recent_qa`;
  - flera frågor i en mening;
  - bakgrundsprat utan fråga och frågor till någon annan;
  - engelska och svenska blandat.
- Alla gick till `done`, utan nätanrop. 0 ElevenLabs, 0 Claude.
- **O105-omtestet** väntar på Kevins rad. Han rättar O105-1–4 nu.

## Utfall mot kriterierna
| Kriterium | Utfall |
|---|---|
| **Svarar bara på frågor** | **Frågegrinden (auto-prompten) fungerar.** Tyst för "jag ska handla efter skolan sen", "haha nej men han är så rolig asså", "varför händer alltid sånt här mig", "Elin, har du tagit med dig boken?", "äh jag vet inte, vad tror du" och den halva "och vad hette hennes". "vad sa du?" stoppades av serverns ekoregel.<br>**Men direktvägen (K68) svarar på allt som börjar med ett frågeord och slutar med "?"**, också frågor mellan människor, se L1 |
| **Kort A-svar** | 1–2 meningar för fakta (A01, A03, A13, A18, A20, A21, A24, A25). Studiefrågan A15 (väder och klimat) fick 5 meningar, eftersom servern gav ledtråden "study". A19 (klockan och flygtid) fick ledtråden "study" fast det är två fakta (L4) |
| **Rätt språk** | En engelsk fråga med `language: en` gav ett engelskt svar (A13). En engelsk fråga i en svensk app (A16) gav ett svenskt svar. Blandat ("vad är skillnaden mellan weather och climate") gav ett svenskt svar |
| **Inget påhittat** | "vem vann melodifestivalen 2031" gav "har inte hållits än". "Ottawa?" (A06) gav en bekräftelse, vilket är rimligt men en tolkningsfråga |
| **Följdfrågor** | "och cellandning då" (refines), "men hur högt är det i fot då" (continues) och "vilken är världens längsta flod" (new_topic) fick alla rätt koppling |

## Fynd till Kevin
- **L1 (medel–hög): i lyssnarläget svarar appen högt på vardagsfrågor mellan människor.**
  - K68 (`answer/handler.ts` cirka rad 1244, `isClearQuestion`) skickar varje mening med minst tre ord, som börjar med ett frågeord och slutar med "?", till **direktvägen**. Den hoppar över frågegrinden ("is never 'not a question' in Standardläge").
  - Direktprompten kan inte vara tyst ("When you must decline, one short sentence and a useful alternative, never silence") och har ingen SILENCE-del, fast den hänvisar till en.
  - **Verifierat i återspelning:**
    - "Vad ska vi äta ikväll?" gav "Det kan jag inte veta, men något snabbt är pasta med pesto eller en omelett.";
    - "Hur mår din mamma nu?" gav "Det vet jag inte, men du kan fråga hur hon mår …";
    - "Var lade du mina nycklar?" gav "Det vet jag inte, men titta i jackfickorna …".
    - Alla tre `answered: true`, upplästa.
  - "Elin, har du tagit med dig boken?" klarade sig bara för att det inte börjar med ett frågeord.
  - I ett klassrum eller i ett samtal blir det ett svar i örat på frågor till kompisen. Det strider mot "someone else talking = shorter and discreet" och är störande.
  - **Förslag:**
    - (a) direktvägen bara för frågor som går att svara på med kunskap: inte "du/din/vi/mina" riktade till en annan person, och inte frågor om personliga förhållanden;
    - (b) eller en tyst väg i direktprompten, till exempel "[[TYST]]" när frågan uppenbart är riktad till någon annan och inte går att svara på.
  - K68 löste att samma kunskapsfråga ibland tystades, så en regel för "du"/"vi"-frågor bör inte röra kunskapsfrågor ("Vad heter Kanadas huvudstad?").
- **L2 (låg): avklippta frågor med ett ägande ord på slutet** ("och vad hette hennes", "hans", "deras", "sin") fångas inte av `isCutOff` (`DANGLING_WORD`). De går till modellen, som här var tyst. Lägg till ägande pronomen, så att appen väntar på resten.
- **L3 (låg): talformat.** "2031" lästes "tvåtusen **trettioen**" och "tvåtusen **trettioett**" i samma svar (A17). "20:59" blev "tjugo och femtio nio" (A19). Delningen av -nio är K115 med avsikt, men "en/ett" bör vara samma för ett årtal.
- **L4 (låg): ledtråden `answer_type_hint` "study"** gavs för en retorisk fras (A10) och för klockan och flygtid (A19). `done.breakdown.answer_type` säger "study" också när modellens meta säger "fact".
- **L5 (låg, prompten):**
  - RELATION har "och …?" som exempel på continues, men ett nytt begrepp är refines enligt definitionen. Syskonfrågor kan bli refines i stället för new_topic.
  - Översättningsregeln "ONLY the translation" krockar med "vad betyder X" (förklaring).
  - "Ottawa?" ensamt (eko eller gissning) står inte i reglerna.
  - Direktvägens `reply_hint` nämner REL, VET och SÖK, som direktprompten inte definierar. Det gäller bara verktyget.

## Inte prövat
- Riktigt tal: brus, flera talare och Scribes felhörningar. Fallen är rena textfragment.
- Aktiveringsordet i ett fullt samtal. Det provades i O103 K1–K3.
- Rizz och Socialt i lyssnarläget. De har egna promptar (O102).
