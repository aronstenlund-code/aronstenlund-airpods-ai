# Exakt ChatGPT-ikonerna (Kelly, Ke40, D139)

Aron 18:51: "Dessa ikoner ska vara exakt som de som ChatGPT gjorde." **Inget är omritat.** Varje originalfil i
`../` (A–F) är bara beskuren och uppskalad med `../../_src/exakt.py`:
1. Den rundade rutan hittas i bilden och beskärs till en kvadrat.
2. Hörnen utanför originalets rundade ruta (vitt för A–C, svart för D–F) fylls med närmaste färg inifrån.
3. Kvadraten beskärs 2,6–3,1 % inåt per sida, precis så mycket att iOS-maskens hörn (22,4 %) hamnar innanför
   originalets hörn (26–29 %). Annars hade en vit eller svart flik och originalets kantlinje synts i hörnen.
4. Uppskalning till 1024 × 1024 med Lanczos. Ingen färg, form, stapel eller glöd ändras.
Mått per ikon: `_mått.txt`. Kontroll: `kontroll.png` (förlaga, 1024 utan mask, med iOS-mask, 60 och 29 pt på mörkt
och ljust).

## Filer
| Fil | Till |
|---|---|
| `A.png` … `F.png` | Röstningen (A71: rutnät 2 × 3), samma storlek, iOS-maskens hörn `0.2237 × storlek`, `.continuous` |
| `AppIcon-1024.png` | **AppIcon (Any)** = D glasklotet, fyrkantig, utan genomskinlighet (iOS rundar själv) |

Mörk och tonad AppIcon-variant är inte gjorda: de vore ändringar av bilden. Utan dem tar iOS 18 fram egna.

## Begränsningar
- **Upplösning:** originalen är små (A–C cirka 260 px, D–F cirka 380 px), så 1024-filerna är uppskalade ×2,7 (D–F)
  och ×4 (A–C) och är något mjuka i 1024. I 60 och 29 pt syns det inte. Skarpare kräver att ChatGPT gör om bilden i
  högre upplösning, eller en AI-uppskalare (Real-ESRGAN finns inte i molnmiljön).
- **Glaskanten** på D–F ligger nära originalets ytterkant och blir delvis beskuren av steg 3; iOS-masken hade skurit
  bort samma del ändå.

## Symbolen i rubriken
En enfärgad symbol kan inte vara exakt bilden. Förslag till Angela: visa `AppIcon-1024.png` i liten storlek med
iOS-maskens hörn (28 pt, följer textstorleken) i rubriken och introt. En förenklad enfärgad symbol finns i
`../vektor/D-glasklotet-symbol.svg` om Aron hellre vill ha det; den är inte exakt och används inte utan hans ja.
