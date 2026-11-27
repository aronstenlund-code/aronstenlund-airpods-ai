# O107: Provläge med foto-text, delade och publicerade prov, minnet, studieprofilen och studieplanen, Oscar (moln)

> Modellsvaren i del 1 och 3 är skrivna av Claude-agenter (en underagent i del 1, jag i del 3) som spelar modellen, **inte av modellen i drift**. Det som prövas är serverns kod efter modellen, alltså tolkning, kontroller, filter och talformat, och promptarnas instruktioner.
>
> Del 2 är **live** med testkonton, utan modell.
>
> 0 ElevenLabs, 0 Claude-API.

## Del 1: Provläge med foto-text (20 fall, K122, `scripts/qa/o107/`)
**Underlaget:**
- **Åtta egna bilder** (`img/`): ett rent prov, ett suddigt och brusigt, en tabell, formler, svag kontrast och sned, ett engelskt prov, anteckningar med tabell och anteckningar med formler.
- **Delarna som prövades:** `parse` (6 foto och 2 text), prov från foto (2), rättning av fritt svar (8) och ledtrådar (2).

**Inläsningen:**
- **Det som fungerade:** prov, poäng och betygsgränser lästes in; uppgifterna fick egna A-svar ("eget svar"); tabellen kom med i uppgiftstexten.
- **Begränsning:** den suddiga bilden var fortfarande läsbar, så vägen för oläsligt material prövades inte.

### Fynd
- **F1 (medel–hög): sifferkontrollen i rättningen räknar fel** (**verifierat i test** med serverns `numericCheck` och `correctPoints`).
  - "5 miljoner fler" läses som `expected: 1000000`. Ett rätt "fem miljoner" blir **0 poäng** (G4), och "5 miljoner" går igenom bara av en slump.
  - Med två rötter ("x = 2 eller x = −4") jämförs bara den sista. "x är 2" med "+E en rätt rot" blir **0 poäng**, och K1.7 skriver över återkopplingen (G3).
  - "minus 4" läses som **4**, så tecknet försvinner.
  - Prompten säger "trust it", så modellen tvingas följa kontrollen.
  - **Förslag:**
    - räkna "miljoner/miljarder/tusen" med talet före;
    - godta varje rot i ett "eller"-facit för en E-poäng som gäller "en rätt rot";
    - läs "minus" och "−" som tecken.
- **F2 (medel): engelska prov får svenska svar och en svensk talram** (P6, PT2).
  - Inläsningsprompten säger "You read a Swedish exam", och svarsskrivaren säger "in Swedish".
  - Den lästa texten blir "Fråga ett. Name the gas … Den ger en poäng." fast appen är engelsk (`x-earmind-lang: en`).
  - Samma sak som G-c i O104, men för `parse`.
- **F3 (medel): uppgiftens talade text har formler och symboler kvar** (P3, P4).
  - "Lös ekvationen **trex** + fem = tjugo", "Lös x² + **tvåx** − åtta = noll", "Förenkla **√fyrtionio** + en halv · sex", och "H₂SO₄ eller H₂SO₃" oförändrat.
  - "(milj.)" läses som det står. Tabellens rubrik blir "Bilden visar Tabell: …", och punkten före "Den ger en poäng." saknas.
  - "Den ger två poäng" tappar fördelningen E/C/A (1/1/0).
  - Förslag: talformatet för formler (x², √, ·, ½, H₂SO₄, som O105-3 för kemiska formler), "tre x", och förkortningar inom parentes.
- **F4 (låg):** inläsningsprompten saknar en väg för delvis oläsliga sidor. Där står bara "Never invent a task", medan provets prompt har "cannot be read at all".
- **F5 (låg):** provets regler om antal frågor, förståelsefrågor och påfyllning går inte att uppfylla för ren faktatabell (D1, D2), samma som P-a, P-b och E7 i O104. D2 slutade med 2 frågor och noten "Materialet räckte till 2 frågor." Det är rimligt.
- **F6 (låg):** ledtråd nivå 2 för "subtrahera två givna tal" är nästan svaret (H2).

## Del 2: delade och publicerade prov (**verifierat live**, 19/19, `scripts/qa/o107_share_live.py`, Actions 45932204592)
**Delning med länk:**
- Ett prov med färdiga frågor, alltså utan modell, delas när ljudet är klart. Innan dess svarar servern 409 "Delas när ljudet är klart (2 av 4)", och sedan ges kod och länk, samma kod varje gång.
- **Mottagaren ser:**
  - i förhandsvisningen titel, ämne, årskurs, antal frågor och `audio_ready`;
  - i kopian samma frågor och svar med eget id, och 0 krediter dras;
  - inget konto-id i förhandsvisning, kopia eller sökträffar.
- Mottagarens ändringar rör inte originalet.
- När ägaren slutar dela fungerar länken inte längre, men kopian finns kvar.
- En okänd länk ger "The link no longer works. Ask for a new one." på engelska och "Länken fungerar inte längre. Be om en ny." på svenska.

**Publicering på skolan:**
- Publicering utan skola och datum ger 409 "Saknas: skola, provdatum" med `missing`.
- En annan elev hittar provet på skolan och kan importera det.
- Namnet syns bara som det visningsnamn ägaren själv valt, aldrig konto eller e-post.
- Samma kontos rapport räknas en gång.
- Bara Aron kan moderera (403 "Owner only"), och ett avpublicerat prov syns inte längre.

**Inte sett:** 409-texten på engelska, eftersom ljudet blev klart innan det engelska anropet.

## Del 3: minnet, studieprofilen och studieplanen (serverns egna handlers, `scripts/qa/o107/memory_plan.ts`)
Minnena sparas på telefonen (A152) men skickas med varje fråga till servern och modellen. Därför gäller testet vad serverns **kodfilter** släpper igenom när modellen ändå skriver något den inte borde (**verifierat i harness**).

| Fall | Sagt | Modellens förslag (jag) | Det som sparas |
|---|---|---|---|
| M1 | "jag har prov i kemi på fredag" | "Har prov i kemi fredag 28 november 2026." | sparas, rätt |
| M2 | "provet i kemi är flyttat till nästa onsdag" | uppdatering | **modellen anropas inte** (`no_self_reference`), så ändringen försvinner (M-4) |
| M3 | "svara alltid kortare till mig" | "Vill ha kortare svar." | sparas |
| M4 | "jag har dyslexi så läs långsamt" | dyslexi och läs långsamt | bara "Vill att texten läses långsamt." **Bra** |
| M5 | "jag tar penicillin den här veckan" | "Tar penicillin den här veckan." | **sparas** (M-1) |
| M6 | "jag har hörselnedsättning på vänster öra" | samma | **sparas** (M-1) |
| M7 | "jag går på KBT varje tisdag" | samma | **sparas** (M-1) |
| M8 | "mitt mobilnummer är 070-123 45 67" | "Mobilnummer 070-123 45 67." | **sparas** (M-2) |
| M9 | "jag bor på Storgatan 12 i Uppsala" | samma | **sparas** (M-2) |
| M10 | "min mejl är elev.test@example.com" | samma | **sparas** (M-2) |
| M11 | "min pappa heter Johan och är arbetslös" | "Pappan heter Johan och är arbetslös." | **sparas** (M-3) |
| M12 | "jag orkar inte leva längre" | "Orkar inte leva längre." | stoppas. **Bra** |
| M13 | "I have an English test on Monday" | "Har prov i engelska måndag 30 november 2026." | sparas, på svenska. **Bra** |
| M14 | "vad är fotosyntes" | – | modellen anropas inte. **Bra** |
| M15 | "jag har glutenallergi" | samma | stoppas. **Bra** |

**Studieprofilen och studieplanen (5 fall var), allt rätt:**
- **Profilen:**
  - "jag går i nian och har prov i biologi om cellen på fredag" ger y9, Biologi, 2026-11-28, "cellen" och termer;
  - "Matematik 2c, inget prov" ger gy2 och `no_exam`;
  - ett extra fält `diagnosis: "ADHD"` från modellen **tas bort**;
  - "nästa vecka" blir måndag 30 november;
  - "fjärde klass" ger ingen årskurs (null).
- **Planen (bara kod):**
  - "I går missade du cellandning. Ska vi ta det nu?";
  - ett passerat prov ger ingen plan;
  - HTML i provnamnet tvättas och mycket lång text kortas.

### Fynd
- **M-1 (medel–hög): kodfiltret missar hälsa** (D113 B5: hälsa sparas aldrig). Det gäller läkemedelsnamn ("penicillin"), "hörselnedsättning" (bara "nedsatt hörsel" och "hörselskad" finns) och "KBT". En lista med ord blir aldrig hel. Förslag: lägg till dessa och vanliga läkemedel, och överväg att låta modellen märka varje förslag med en kategori som koden kan neka.
- **M-2 (medel): kontaktuppgifter sparas**, alltså telefonnummer, gatuadress och e-post. De finns inte i listan och skickas sedan med varje fråga. Förslag: neka mönster för telefon, e-post och adress.
- **M-3 (medel): uppgifter om andra personer sparas** ("Pappan heter Johan och är arbetslös"). Prompten förbjuder det, men koden kontrollerar inget.
- **M-4 (låg–medel): en ändring utan "jag/min/mitt" når aldrig modellen.** "provet i kemi är flyttat till nästa onsdag" lämnar det gamla datumet. Förslag: låt `SELF` också godta meningar om ett prov eller en läxa som redan finns i `memories`.

## Kvar till omtest
Facit står i `scripts/qa/OMKORNING.md`: o107 G1–G8 för F1, P1–P6 och PT1–PT2 för F2 och F3, och `memory_plan.ts` för M-1–M-4.
