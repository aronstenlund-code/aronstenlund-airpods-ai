# D142: repetitionsläget blir standard (Deangelo)

## Beslutat
Arons produktbeslut 2026-11-13 17:05 är infört som D142. Lyssnande lägen märks BETA och utvecklas vidare. Repetitionsläget utan mikrofon blir huvudprodukten.

## Vad som finns och återanvänds (verified in code)
- Material: `/exam parse` (sidbilder), `PagePhoto` (Vision), `DocumentText` (PDF/text), `/study-profile`, `/my-answers suggest` (A-svar), `MyAnswers` (redigering).
- Knappar: `RemoteCommandHub` tar redan emot play/pause/toggle. Next/previous saknas.
- Röst: `/tts` strömmar pcm. En fil per fråga och svar saknas, och den behövs för paus från exakt samma ord.

## Teknik (detaljer och status i specen)
- 1 tryck: **möjligt**. 2 och 3 tryck: **möjligt med begränsningar** (AirPods Pro, 3 och 4; inte AirPods 2). Ej verifierat på enhet.
- Paus från samma ord: **möjligt** med filuppspelning.
- Att aldrig avsluta: **möjligt med begränsningar**. En annan app som spelar tar över knapparna (**inte möjligt** att hindra).
- .docx: läses på servern (**möjligt med begränsningar**).

## Fördelning
K45, K46 (Kevin) → A78, A79, A80 (Angela) med Ke49 (Kelly) → O55 (Oscar), T18 (Toby). BETA-punkterna (A72, A75, A76, K43, K44) fortsätter efter dessa.

## Risker
- ElevenLabs-tecken: cirka 34 000 per prov med 30 frågor (uppskattning). F5 till Aron.
- Pausad app i bakgrunden: ej verifierat hur länge iOS håller den som Now Playing (R8).
- En AirPod ur örat kan se ut som ett tryck (ej verifierat, T18).

## Nästa
Sessionerna tar punkterna från köerna. Aron svarar på F1–F5. Toby skriver en tiominuters checklista för Arons telefon.

## Tillägg 17:40 (D143)
Aron uppdaterade beslutet: ljud genereras på servern per konto direkt när provet sparas (hög kvalitet, inte Turbo), betänketid, samma ordning, alla tryck fortsätter, alla AirPods-modeller och delning till klasskamrater (bara när ljudet är klart). Specen har nu ett avsnitt om kompatibilitet (automatisk kontroll av vilka tryck som kommer fram i stället för att fråga om modell), delning och kostnad (cirka 2,6 USD ElevenLabs och 17 MB per prov med 30 frågor, ej verifierat mot Arons plan). Nya punkter: K47 och A81; K46 är ändrad.
