# Webbetan på earmind.vercel.app/beta (Kelly (moln), Ke86, D249–D251, 2026-11-21)

Design för Angela Schrutes A156. **Samma utseende som iOS-appens första skärm**, mobil först (393 pt bred, fungerar ner
till 320), engelska som standard och svenska om `navigator.language` börjar med `sv` (D251). Texter: `engelska.md`.
Skiss: `bilder/webbeta/` (källa `_src/webbeta.html`, render `node docs/design/_src/webbeta-render.js`).

## 1. Tokens (ur appens skärmbilder, Ke80)
| Token | Ljust | Mörkt | Används till |
|---|---|---|---|
| `--bg` | `#f2f2f7` | `#000000` | sidan |
| `--surface` | `#ffffff` | `#1c1c1e` | kort, listor |
| `--card` | `#101319` | `#101319` | Säg-kortet (mörkt i båda lägena, som i appen) |
| `--card-text` | `#ffffff` | `#ffffff` | text i Säg-kortet |
| `--accent` | `#2346c8` | `#7f9bff` | fyllda knappar, länkar |
| `--accent-on-card` | `#7f9bff` | `#7f9bff` | Spela i det mörka kortet (text `#101319`) |
| `--tint` | `#d7def5` | `#2a3350` | tonade knappar (Starta prov när Spela är fylld) |
| `--secondary` | `#6b6b70` | `#a1a1a6` | hjälptext (minst 4,5:1) |
| `--warn` | `#fff4d6` | `#3a3120` | skärmraden (se 3) |

Typsnitt: `-apple-system, system-ui, sans-serif`; fältet i Säg-kortet `ui-monospace, "SF Mono", Menlo, monospace`.
Hörn: kort 20 px, kapslar helt runda, knappar 999 px. Avstånd: 16 px sidmarginal, 12 px mellan kort.
`prefers-color-scheme` styr ljust och mörkt; `prefers-reduced-motion`: bara toning (A150).

## 2. Första skärmen (uppifrån)
1. **Rad överst:** kapseln "{1.2k} credits left" (öppnar Krediter) · kugghjul (Inställningar). Liten etikett **Beta**
   bredvid kapseln.
2. **Skärmraden** (avsnitt 3), bara när något spelar eller lyssnar, eller första gången.
3. **Säg-kortet:** samma som appen (forsta-skarmen.md, stil-och-roster.md): fältet, röstkapseln + "How should it sound?"
   när det finns text, kostnaden, knappraden `+` · ⏱ · tempo · **Play for 10 min**. `+` på webben: Choose photos ·
   Add file · Paste link (ingen kamera-knapp; filväljaren erbjuder kameran själv på mobilen).
4. **Recent** (kapslar), **Next quiz**, **Other quizzes**, **More modes (beta)**.
5. **Verktygsrad längst ner:** New quiz · Open link.
6. Spelar: kortet blir spelkortet ("● Playing in AirPods · {voice} · {7:32} left · Stop"), som appen.

## 3. Skärmen måste vara på i betan (D250)
Webbläsaren pausar ljudet och stänger mikrofonen när skärmen släcks eller sidan lämnas. Betan håller skärmen vaken med
**Screen Wake Lock** (`navigator.wakeLock.request('screen')`) när något spelar eller lyssnar, och släpper den när det
slutar.

**Raden** (gul ton `--warn`, ovanför Säg-kortet, med en länk till guiden):
| | English | Svenska |
|---|---|---|
| Rubrik | Keep the screen on | Ha skärmen på |
| Text | In the beta, the screen has to stay on while it plays or listens. Your phone can be up to about 10 m (33 ft) from your AirPods, so you can put it down. | I betan måste skärmen vara på medan det spelar eller lyssnar. Telefonen kan ligga upp till cirka 10 meter från dina AirPods, så du kan lägga ifrån dig den. |
| Länk | How to keep it on | Så håller du den på |
| När Wake Lock är på | The screen stays on while it plays. | Skärmen hålls på medan det spelar. |
| Om sidan lämnas och ljudet stannar (vid återkomst) | It stopped because the screen turned off. Play again? · Play | Det stannade för att skärmen släcktes. Spela igen? · Spela |

Skriv **"10 m"/"10 meter" med hårt mellanslag** så att talet inte bryts från enheten. "Cirka 10 meter" är Apples egen siffra för Bluetooth-räckvidd (support.apple.com: "within about 33 feet (10 meters)";
**verifierat i dokumentation**, D250). Väggar och fickor kan korta den.

**Om iOS-appen** (en rad längre ner i guiden): "In the iOS app it keeps playing with the screen off." / "I iOS-appen
spelar det vidare med skärmen av." **Otestat (D209, TILL-ARON #29): visas inte förrän Aron har provat på telefon.**

## 4. Guiden: håll skärmen på (blad)
**English**
> **Keep the screen on**
> The beta keeps the screen awake while it plays. If your screen still turns off:
> **iPhone:** Settings › Display & Brightness › Auto-Lock › Never.
> Low Power Mode locks the screen after 30 seconds anyway, so turn it off while you listen.
> **Android:** Settings › Display › Screen timeout.
> Change it back when you're done.

**Svenska**
> **Håll skärmen på**
> Betan håller skärmen vaken medan det spelar. Släcks den ändå:
> **iPhone:** Inställningar › Skärm och ljusstyrka › Automatisk låsning › Aldrig.
> Strömsparläget låser skärmen efter 30 sekunder ändå, så stäng av det medan du lyssnar.
> **Android:** Inställningar › Skärm › Tidsgräns för skärm.
> Ändra tillbaka när du är klar.

Strömsparläget sätter Automatisk låsning till 30 sekunder (Apples dokumentation om Strömsparläge, **verifierat i
dokumentation**). Menynamnen på Android varierar mellan tillverkare (**untested assumption** för alla modeller).

## 5. Krediter på webben (D249)
Bladet Krediter som i appen, men utan köp: under siffran "1,500 credits every month." och i stället för Fyll på-delen
raden **"Purchases come with the iOS app."** / "Köp kommer i iOS-appen." Ingen välkomst (App Attest finns inte på
webben). Räcker krediterna inte: "{120} credits · you have {88}" utan Top up-länk.

## 6. Lyssnarlägen (More modes, beta)
Samma samtyckesskärm som appen (D21) före första start; först därefter frågar webbläsaren om mikrofonen. Medan den lyssnar:
**en rad överst på varje skärm** "● Listening · Stop" (som appen). Skärmraden (3) visas också.

## 7. Media Session och AirPods
`navigator.mediaSession.metadata`: title = textens första rad, artist = "EarMind", album = "Say in AirPods". Hantera
`play`, `pause`, `stop` (AirPods-tryck pausar och spelar). Ingen dold uppspelning: kortet visar alltid att det spelar.

## 8. TikTok-svar (Ke86, för Aron när betan är uppe)
**Svenska**
> Nu kan du testa EarMind i webbläsaren: earmind.vercel.app/beta 🎧 Skriv det du vill kunna, tryck Spela och lyssna i
> AirPods. Ha skärmen på i betan – telefonen kan ligga en bit bort. Appen kommer till iPhone snart.

**English**
> You can try EarMind in your browser now: earmind.vercel.app/beta 🎧 Type what you want to learn, tap Play and listen
> in your AirPods. Keep the screen on in the beta – your phone can sit a few steps away. The iPhone app is coming soon.

Kort (TikTok-svar räcker gott under 150 tecken per språk), inget om låst skärm, inget om dold användning, inga löften om
pris eller välkomstkrediter. Länken fungerar först när /beta är publicerad.
