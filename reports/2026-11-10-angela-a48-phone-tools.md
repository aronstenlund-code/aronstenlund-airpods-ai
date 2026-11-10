# A48 – Telefonverktyg för agenten (D122) (Angela, 2026-11-10)

Underlag: D122, Kevins K35 (`reports/2026-11-10-2056-kevin-k35-agent-tools.md`) och protokollet i `docs/AGENT.md`.
Numret A48 användes redan i dag för `qa_log`. Den här punkten kallas **"A48 telefonverktyg"**.

**Det här är kod och enhetstester. Kalendern, påminnelserna, larmen och timern är inte provade på telefon**, och inte
heller hela vägen mot servern från appen (untested assumption).

## Vad som gjordes
1. **Appen anmäler verktygen.** Varje `/answer` i Standardläge och Provläge skickar `tools_available` med alla sex
   verktygen:
   - `calendar_add`, `calendar_list`, `reminder_add`, `timer_start`, `alarm_set` och `note_add`.
   - **Inte** för svar som hämtas i förväg (D80). Ett sådant svar kanske aldrig efterfrågas, och ett verktyg får
     aldrig köras på något användaren inte sa klart.
   - Servern ger inga verktyg i Auto och inte i de sociala lägena (K35).
2. **`tool_call`** är en ny SSE-händelse. Verktygets indata sparas exakt som den kom, så den kan skickas tillbaka
   oförändrad (`JSONValue`).
3. **Lumen frågar innan något ändras.** När `confirm` finns säger Lumen frågan, till exempel "Ska jag lägga in
   Tandläkaren torsdag den 12 november klockan 15:00 i kalendern?". Lyssnar visar samma fråga med "Nej" och "Ja".
   - Ett "ja", "gör det" eller "okej" kör verktyget.
   - Ett "nej" eller "avbryt" skickar `declined`.
   - Säger användaren något annat släpps verktyget, och det sagda blir en vanlig fråga.
   - Utan `confirm` körs verktyget direkt. Det gäller `calendar_list`, `timer_start` och `note_add`.
4. **Verktygen på telefonen** (`LivePhoneTools`):
   - **Kalender och påminnelser** använder EventKit. Kalendern läser högst 20 händelser.
   - **Timer och larm** använder AlarmKit (iOS 26). Larmet ringer nästa gång klockan blir den tiden, i dag eller i
     morgon.
   - **Anteckningar** sparas i appens Anteckningar med rubriken "Anteckning".
   - Behörigheten frågas första gången ett verktyg används, aldrig när appen startar. Texterna finns på svenska och
     engelska.
5. **`tool_round`:** sedan skickas samma fråga en gång till, med anropet och resultatet (`ok`, `declined` eller
   `error`). Modellen säger då en kort mening om resultatet.

**Kod:**
- `Lumen/Core/Agent/PhoneTools.swift` är ny: `JSONValue`, `PhoneToolCall`, `ToolRound`, `ToolConfirmReply`,
  `PhoneToolTime` och protokollet `PhoneToolRunning`.
- `Lumen/Core/Agent/LivePhoneTools.swift` är ny. Varje verktyg körs i en egen funktion utanför aktören, med en egen
  `EKEventStore`. Därför går inget som inte är `Sendable` mellan aktörer (Swift 6).
- Ändrade filer:
  - `AnswerEvent.toolCall`;
  - `AnswerSink.answerToolCall`;
  - `AnswerContext.toolsAvailable` och `toolRound`, som följer med genom `clamped`;
  - `NotesStore.add(text:)`;
  - kortet med "Ja" och "Nej" på Lyssnar;
  - `NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription` och
    `NSAlarmKitUsageDescription`.

## Tester
`LumenTests/PhoneToolsTests.swift`:
- `tool_call` går att läsa, med indata, `confirm` och `null`;
- `tools_available` och `tool_round` skickas och tappas inte i `clamped`, och de saknas när inga verktyg finns;
- "ja", "nej" och "något annat" tolkas rätt;
- serverns tider tolkas rätt: ISO utan zon, bara datum, och nästa 06:30;
- en anteckning hamnar i Anteckningar.

## CI
Grönt i CI: iOS build 42913492996 (`0a58586`). Bygget för enhet räknar varningar som fel, och alla LumenTests är
gröna, PhoneToolsTests inräknade. AlarmKit kompilerar alltså mot iOS 26-SDK:n.

## Kända begränsningar
- **Sideloadly (untested assumption):** det osignerade bygget har inga särskilda rättigheter. EventKit och AlarmKit
  behöver inga, så de bör fungera, men det är inte provat.
- Ett verktyg per tur, som K35 säger.
- Det finns ingen lista i appen över larm som Lumen har ställt. De syns i Klockan/AlarmKit-vyn i iOS.

## Till Aron
Prova på telefonen, i Standardläge:
1. Säg "Lumen, lägg in tandläkaren på torsdag klockan tre". Svara ja, och titta i Kalender.
2. Säg "sätt en timer på fem minuter". Den ska starta utan fråga.
3. Säg "väck mig halv sju i morgon". Svara ja, och titta i Klockan.
4. Säg "vad har jag i morgon".

## Till Toby
`ListeningModel.phoneTools` kan bytas mot en falsk `PhoneToolRunning` i E2E-tester.
