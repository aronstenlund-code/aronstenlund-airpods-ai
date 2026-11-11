# T15 – Den väntande frågan, med A70-loggen (Toby, 2026-11-11 19:30)

**Simulatorn räknas aldrig som verifiering på enhet.** GitHub `macos-26`, iOS 26-simulatorn (iPhone 17), `say`-tal via
WAV-kroken, live Scribe och `/answer`, Apples röst (0 ElevenLabs-tecken). Bygget är main efter A70 (d5121e3) och A71
steg 1, på grenen af2fe8a.

- **Körning:** [43072123518](https://github.com/aronstenlund-code/aronstenlund-airpods-ai/actions/runs/43072123518).
- **Ny uppsättning i retest, `vantan`:**
  - T14:s fall q4, c1 och c3, fyra gånger var (12 frågor), i Frågor;
  - 22 s mellan filerna, så att tvåmeningssvar hinner läsas upp;
  - testet loggar när `speaker.isSpeaking` går till och från (`speech-start`/`speech-end`), eftersom appen inte loggar när talet slutar;
  - sammanfattningen görs av `scripts/apptest/vantan_summary.py`.
- **Rådata:** `reports/apptest/2026-11-11-t15/` (`retest-vantan.json` har hela loggen, `summary.md` har tabellerna).

## Kort
| Mått | Resultat |
|---|---|
| A70-raden "A question waits 3 s: …" | **Kom aldrig**, inte en gång på 12 frågor. Väntan sker inte i frågetimern. |
| Turer som väntade över 4 s från hörd fråga till anrop | **5 av 8** (14,7–26,3 s). Alla fem är halva frågor (c1 och c3). |
| Hela frågor (q4) | 0 s väntan (svar i förväg), 2 av 2 som hördes |
| Mikrofonen öppen efter att rösten tystnat | **0,6–0,8 s, 9 av 9.** Kravet "högst 1 s" klaras i simulatorn. |
| Hörda | 8 av 12. De fyra första föll på ett TLS-fel i Scribe (se nedan). |

## Orsaken, ordagrant ur loggen (till Angela, A72)
**Väntan sitter efter A63:s rad "Half a question: Scribe asked for the rest now".** Turen släpps först när Scribe stänger
sin session, eller 13–15 s senare, även när fortsättningen redan har kommit som final:

| Halv fråga | "Half a question: Scribe asked for the rest now, words waiting: …" | Fortsättningen hörd | `Activation` | Scribe-sessionen stängde | Lokal VAD |
|---|---|---|---|---|---|
| c1 | 143,63 s, `true` | 144,29 s "Barien i världen." | **145,33 s (1,0 s)** | 190,32 s | **"Local VAD not ready: all audio goes to Scribe"** |
| c3 | 172,58 s, `false` | – | 190,28 s (17,7 s) | 190,32 s | inte redo |
| c1 | 244,95 s, `true` | 245,44 s "Barierna i världen." | **271,31 s (25,9 s)** | 271,32 s | "Local VAD in front of Scribe" + "Wearer focus in front of Scribe (A10)" |
| c3 | 298,35 s, `false` | – | 311,45 s (13,1 s) | – | i fronten |
| c1 | 365,11 s, `true` | 365,63 s "Bärjen i världen." | 379,91 s (14,3 s) | – | i fronten |
| c3 | 407,30 s, `false` | – | 424,31 s (17,0 s) | 424,31 s | i fronten |

Vad raderna visar:
1. **När fortsättningen kommer som final (c1), går turen vidare på 1,0 s utan VAD, men tar 14–26 s med VAD och
   bärarfokus i fronten.** Mellan finalen och anropet finns bara en rad: `Answer ahead discarded (a different turn)`,
   1 s efter finalen.
   - När Scribe stänger vid 271,32 s loggas `Wearer focus: 0 s of others muted, 0 own ends of turn`. Bärarfokus
     (A10) hittade alltså inget slut på turen. Nästa session slutade med `2 s of others muted, 0 own ends of turn`.
     Där räknades 2 s av testets tal som "andra", trots att ingen röst var inlärd.
   - **Untested assumption:** när VAD och bärarfokus står framför Scribe, väntar den hopslagna turen på ett "eget slut
     på turen" från bärarfokus. Det kommer aldrig, eftersom ingen röstprofil är inlärd i testet. Då släpps turen
     först av Scribes stängning, eller av någon annan timer efter cirka 13–15 s.
2. **När fortsättningen inte hörs som en egen final (c3, `words waiting: false`)** begär A63 resten innan
   fortsättningen har sagts. Pausen är 3,5 s, och begäran går 1,8 s efter första halvan. När orden sedan kommer,
   begärs ingen final igen. Turen släpps först 13–18 s senare.
3. Mätningen visar också att T14:s "mikrofonen stängd 12–15 s" var rösten som fortfarande talade (`speaker.isSpeaking`
   sann). När rösten tystnat öppnas igenkänningen efter 0,6–0,8 s, alltså ekosvansen på 0,7 s. **Mikrofonen är inte
   felet.** Långa röster i simulatorn är det.

**Förslag till A72:**
- Låt en hållen halv fråga gå vidare **senast 1,5 s efter sista finalen**, oavsett VAD och bärarfokus. När
  fortsättningen finns behövs ingen mer väntan.
- Be om final igen (`commit()`) när nya ord kommer efter "Scribe asked for the rest now".
- Logga vad turen väntar på medan den hålls, på samma sätt som A70 gör för frågetimern. Då syns det nästa gång.

## Övrigt
- **TLS-fel vid start:** Scribe gav `Ett TLS-fel ledde till att den säkra anslutningen misslyckades` vid 28 s. Appen
  föll till iPhonens igenkänning, som inte startar i simulatorn, och försökte Scribe igen först efter 102 s
  (`STT start failed: … DictationTranscriber` vid 130,24 s). Det var nätet i CI.
  - På en telefon startar iPhonens igenkänning, så det märks troligen inte. **Untested assumption.**
  - Men 100 s utan nytt försök på Scribe är långt.
- **Scribe hör "bergen" fel** i 3 av 3 fall ("Barien", "Barierna", "Bärjen"). Svaret blev då om barriärer. Det är
  Scribe och `say`-rösten, inte appen.
- **Kostnad:** cirka 7,5 min Scribe och 8 `/answer`, 0 ElevenLabs-tecken.

## Kvar
- T15b när Angelas A72 är pushad. Krav: 0 av 10 väntar över 4 s, mikrofonen öppen högst 1 s efter talet, inga ekon
  som blir frågor. Testet är klart (`vantan`), och samma push startar det.
