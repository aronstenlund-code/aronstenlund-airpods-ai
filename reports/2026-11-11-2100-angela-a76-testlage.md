# A76: Testläge, ljudet skickas till oss (D140) (Angela, 2026-11-11 21:00)

## Gjort
1. **Inställningen.** Inställningar › Testläge har reglaget "Testläge: skicka ljud för felsökning".
   - Den är **av från början** (`testMode.enabled`).
   - Den slås på automatiskt en gång om servern säger att kontot är ett testkonto (`GET /debug-audio` → `debug_audio: true`, K43). Den går ändå att stänga av.
   - Testarens eget reglage anropar `POST /debug-audio?action=opt_in|opt_out`.
2. **Ljudet.**
   - Medan Earmind lyssnar och testläget är på skrivs mikrofonens ljud till bitar om 60 s: AAC (m4a), mono, 16 kHz, 32 kbit/s. Det blir cirka 240 kB per bit och cirka 14 MB per timme.
   - Ljudet skrivs av en egen actor (`DebugAudioWriter`). Den läser samma ljudflöde som igenkänningen (`subscribeToChunks`) och stör den inte.
   - När lyssningen slutar avslutas den sista, kortare biten.
3. **Vad som hände i biten.** Biten sparas som en JSON-fil bredvid ljudet i `Application Support/Lumen/debug-audio` och skickas som en tur till K43 (`DebugTurnBody`):
   - `transcript`: Scribes finaler med sekunder in i biten, till exempel "[12 s] Lumen, vad är …".
   - `answer`: "fråga → svar" för varje svar.
   - `decision`: till exempel "answered 1, dropped 2".
   - `meta`: start, slut, varje tur (vad som hördes, utfall, orsak, status) och appens logg. Där finns A75:s rader "Name alone", "Name-like word not taken" och A74:s "not asked again". Loggen kortas från det äldsta så att `meta` håller sig under K43:s gräns på 4000 tecken.
4. **Uppladdning.**
   - Bitarna skickas en i taget, den äldsta först, när en bit är klar och när flaggan har hämtats.
   - En skickad bit raderas från telefonen (punkt 4).
   - Utan nät väntar bitarna, men högst 120 bitar och högst 48 timmar.
5. **Syns hela tiden.**
   - Lyssningsraden säger "Lyssnar · Testläge, ljud skickas" med orange prick.
   - Lyssningsskärmen visar "Testläge · ljud skickas" i orange.
   - Om Earmind (D138) får tillägget "Testläget är på: allt ljud … raderas efter 14 dagar" bara när testläget är på.
6. **Kontot nekas.** Om servern nekar kontot (403, eller `debug_audio: false` efter opt_in) gäller följande:
   - Inget ljud sparas längre.
   - Bitar som redan väntar raderas. Ljud som inte kan skickas ska inte ligga kvar.
   - Inställningen säger "Servern tar inte emot testljud från det här kontot ännu. Inget ljud sparas eller skickas."
7. Vanliga användare påverkas inte. Med testläget av skrivs inget och inget skickas.

## Viktigt: ingen kan använda testläget i dag (Till Aron, Till Kevin)
- K43 godtar bara **konton som är inloggade med e-post**. Ägaren måste dessutom vara inloggad med `otp` eller `magiclink`, och anonyma konton får aldrig testläge.
- **Appen loggar bara in anonymt** (`SupabaseAuth.signUp`). Därför svarar servern alltid `debug_audio: false` eller 403, också för Aron. Appen visar då meningen ovan och sparar inget.
- Två vägar framåt (Architect/Deangelo väljer):
  - **(a) E-postinloggning i appen** (Supabase OTP-kod i Inställningar › Testläge). Det är större, eftersom det anonyma kontots historik och K37-svar hör till det anonyma id:t. Jag kan bygga det som A77.
  - **(b) Koppla det anonyma kontot** (mindre): appen visar ett kort test-id, och Aron lägger in det på sin sida (qa.html). Då får `debug_testers` raden och `enabled` godtar den, också för anonyma konton som Aron själv har lagt in. Det kräver en ändring hos Kevin och en liten rad i appen.
- Jag rekommenderar **(b)**. Det är snabbast och kräver inget nytt inloggningsflöde.

## Tester
- `LumenTests/A76Tests.swift` (**untested assumption** tills CI har kört):
  - testläget är av från början, och ett testkonto slås på en gång;
  - gamla bitar raderas, och en skickad bit försvinner;
  - en minut blir K43:s tur (text, beslut, `meta` under 4000 tecken med de nyaste loggraderna kvar);
  - ett nekat konto sparar inget.
- CI: se STATUS. Det förra bygget, för A75, fick ingen Mac-runner ("not acquired"). Den här pushen bygger A75 och A76 tillsammans.
- **Inte provat på telefon**:
  - att AAC-filen spelas rätt på Arons sida;
  - att ljudflödet räcker till både Scribe och skrivaren;
  - batteriet.
  - Allt det här kräver en telefon och väg (a) eller (b).

## Risker
- AAC skrivs med `AVAudioFile` från Int16 PCM. Om kodaren inte tar Int16 direkt blir filen tom eller saknas (**untested assumption**). Då ser Aron turen utan ljud, och jag byter till Float32.
- Ljud från andra (Kevins Concern): lärarens och andra elevers röster spelas också in när testläget är på.

## Concerns
- Som Kevin skriver: testläget spelar in alla som hörs, ofta minderåriga, utan deras samtycke. Inställningen säger att allt ljud skickas, men inte att andra också spelas in. Förslag till Deangelo: lägg till "Slå bara på det där de som hörs vet om det", och visa testläget bara för testare. Tekniken håller sig inom D140: testläget är frivilligt, syns hela tiden, och ljudet lagras privat och raderas efter 14 dagar.

## Nästa
- När (a) eller (b) är avgjort: bygg inloggningen eller kopplingen och prova på Arons telefon.
- A72 del 3: Tobys T15b visar att 7 av 11 frågor fortfarande väntar 8,7–21,2 s. Det är nästa punkt.
