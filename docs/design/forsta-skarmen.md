# Första skärmen (Kelly (moln), Ke72, D215, 2026-11-17)

Ett förslag, till Angela Fable (A132). Skisser i `bilder/forsta/<id>.png` (ljust | mörkt), källa `_src/forsta.html`,
render `node docs/design/_src/forsta-render.js`. **Skisser, inget byggt, inget provat på telefon.** Utgångspunkt:
`reports/2026-11-17-a131-bilder/` och Arons skärmbild `reports/apptest/aron-2026-11-17-1348-spela-inget-hander.png`.

## Idén i en mening
Det första man ser är ett fält med markören redo och **en** knapp som säger exakt vad som händer: **"Spela i 10 min"**.
Allt annat är mindre, och det som är självklart förklaras inte.

## 1. Uppifrån och ned
| Del | Vad | Mått |
|---|---|---|
| Rad överst | Kapseln **"{1 236} krediter kvar"** till vänster, kugghjulet till höger. **Ingen rubrik "Prov"** (D215.7). | Kapsel 30 pt hög, 16 pt marginal |
| Säg-kortet | Mörkt kort (som i dag) med **bara fältet** och knappraden. Ingen rubrik "Säg i AirPods" och ingen teckenräknare: platshållaren säger vad fältet är till, och kostnaden ersätter räknaren. | 16 pt marginal, hörn 18, inre luft 14 |
| Senaste | En rad direkt under kortet, bara om det finns sparade Säg-texter (D215.3). | 10 pt över |
| Nästa prov | Som i dag, men bara riktiga prov, aldrig en Säg-text. | 18 pt över avsnittsrubriken |
| Andra prov, Prov från din skola, Fler lägen | Som i dag. | |
| Verktygsfältet | Nytt prov · Öppna länk, som i dag. | |

## 2. Säg-kortet
**Fältet:** monospace, `›` i accentfärg, platshållaren **"Skriv eller klistra in det du vill höra"**. Utan fokus visar det
3 rader och tonar ut nedåt; med fokus växer det till högst 5 rader och skrollar sedan inuti (D215.4).

**Knappraden, vänster till höger:**
| Knapp | Utseende | Gör |
|---|---|---|
| `+` | rund, tonad | Meny: Fota sidor · Välj bilder · Lägg till fil · Klistra in länk (D204) |
| ⏱ (symbolen `timer`) | rund, tonad, **utan text** | Meny med rubriken **"Spela i"**: 10 min · 15 min · 20 min · 25 min · 30 min · 35 min · 40 min · 45 min · 50 min · 55 min · 1 timme (D210). VoiceOver: "Hur länge, {10} minuter". |
| `1,0×` | kapsel, tonad | Meny: 0,5× · 0,75× · 1,0× · 1,5× |
| **Huvudknappen** längst till höger | se nedan | |

**Huvudknappen och vilken knapp som är fylld (D215.1):**
| Läge | Huvudknappen i kortet | Starta prov (Nästa prov) |
|---|---|---|
| Tomt fält, urklippet har text | **Klistra in** (tonad) | **fylld** |
| Tomt fält, tomt urklipp | **Spela i 10 min** (grå) | **fylld** |
| Text i fältet | **▶ Spela i {10} min** (**fylld**) | tonad |
| Krediterna räcker inte | **Spela i {10} min** (grå) | **fylld** |
| Spelar | (raden byts, se 5) | tonad |

**Varför "Spela i 10 min":** "⟲ 10 min" (A124) kan läsas som "om 10 minuter", alltså en fördröjd start (D210). "Spela i 10
min" kan bara betyda under tio minuter, och tiden syns där man trycker. Med "1 timme": **"Spela i 1 timme"**.

**Kostnaden (D215.2, D213):** en kort rad till höger, direkt ovanför huvudknappen, 13 pt grå: **"{120} krediter"**. Finns
ljudet redan: **"0 krediter"**. Räcker de inte: halvfet **"{120} krediter · du har {88}"** och grå Spela. Kostnaden kommer
från servern (K92); medan den räknas står ingenting där.

**Raden om låst telefon:** **"Du kan låsa telefonen. Det hörs i AirPods ändå."** (kortare än i dag), 13 pt grå, under
fältet, **bara tills man har tryckt Spela första gången**, sedan aldrig (D215.2).

## 3. Senaste (D215.3)
Rubriken **"Senaste"** (13 pt grå) och de tre senaste Säg-texterna som kapslar på en rad, med början av texten (högst cirka
24 tecken och "…"). Ett tryck lägger tillbaka texten i fältet (spelar inte). Raden går att svepa i sidled. Långtryck:
**Ta bort**. Säg-texter visas aldrig som Nästa prov eller under Andra prov.

## 4. Krediterna räcker inte
Bara raden vid knappen ändras: **"{120} krediter · du har {88}"**, halvfet, och Spela är grå. Kapseln öppnar bladet (Ke71)
där resten står. Ger servern 402 ändå, visas serverns rad på samma plats (D212).

## 5. Spelar (D215.6)
Kortet visar överst **"● Spelar i AirPods"** (accentfärg), texten (3 rader, tonad), och raden byts mot:
**⏸** (rund, fylld) · **"{7:32} kvar"** (17 pt halvfet, tabellsiffror) · **Stoppa** (textknapp till höger). Pausad: ▶ och
**"{7:32} kvar · pausad"**. Ett tryck på texten öppnar spelaren med meningarna (D185). När tiden är slut återgår kortet
till läge "Text i fältet".

## 6. Största text (iPhone SE)
Knappraden staplas: `+`, ⏱ och tempo på en rad, kostnaden under, och **Spela i 10 min** i full bredd längst ner. Inget
kapas med "…".

## 7. Texterna i en lista
| Ställe | Text |
|---|---|
| Kapseln | {1 236} krediter kvar |
| Platshållare | Skriv eller klistra in det du vill höra |
| Huvudknapp | Spela i {10} min · Spela i 1 timme |
| Huvudknapp, tomt fält med urklipp | Klistra in |
| Menyn Hur länge, rubrik | Spela i |
| Kostnad | {120} krediter · 0 krediter |
| Räcker inte | {120} krediter · du har {88} |
| Första gången | Du kan låsa telefonen. Det hörs i AirPods ändå. |
| Spelar | ● Spelar i AirPods · {7:32} kvar · Stoppa |
| Pausad | {7:32} kvar · pausad |
| Senaste | Senaste · *långtryck:* Ta bort |
| VoiceOver ⏱ | Hur länge, {10} minuter |
| VoiceOver + | Lägg till material |

Tas bort jämfört med i dag: rubriken "Prov", "Säg i AirPods" i kortet, "{120} tecken", "Räknas som … Upprepningar kostar
inget." och "Kostar … krediter. Upprepningar kostar inget." (upprepning syns i kreditbladet).
