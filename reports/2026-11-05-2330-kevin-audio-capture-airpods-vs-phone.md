# Kevin – Ljudupptagning: AirPods eller telefon i fickan (webbsökning, ingen test på enhet)

**Kort svar: AirPods, men bara för bärarens egen röst. En avstängd telefon spelar inte in något alls.** Allt nedan är **verified in docs / forum** (se källor); inget är **verified on device**.

## Avstängd telefon
Är telefonen *avstängd* (strömmen av) körs ingen app och inget mikrofonflöde finns. Menar du *låst skärm* (telefonen på, skärmen släckt) går det att spela in i fickan om appen har bakgrundsläget `audio` och en aktiv `AVAudioSession` (playAndRecord); det är samma sak som Röstmemon och vårt flöde. Mikrofonindikatorn visas då alltid.

## AirPods eller telefon i fickan
| | AirPods | Telefon i ficka |
|---|---|---|
| Avstånd till munnen | ca 10 cm, fast placerad | 40–80 cm, tyg emellan (dämpat, brus från tygskav; ficklurv täpper till mikrofonhål) |
| Mikrofonteknik | dubbla beamforming-mikrofoner, innanför-mikrofon och (AirPods Pro 2) röstavkännande accelerometer riktade mot bärarens mun | enkel mikrofon, ingen riktning |
| Fångar | främst **bärarens** röst; andra i rummet svagare (tränad att dämpa omgivning) | rummet på avstånd, men dämpat av tyget |
| Kvalitet | via Bluetooth-samtalsläge (HFP) ofta 16 kHz, smalt (innehåll över ca 3,5 kHz svagt); nytt i iOS 26: *studio-quality recording* för AirPods 4/4 ANC/Pro 2 via `AVAudioSessionCategoryOptions.bluetoothHighQualityRecording` | full bandbredd, men dämpad |
| Bieffekt | samma AirPods spelar upp svaret → samtalsläge kan sänka uppspelningskvaliteten; test på enhet behövs | påverkar inte uppspelningen |

Forumrapporter är blandade: flera tycker att AirPods- och iPhone-mikrofonen låter lika i Röstmemon, och Apples egen community-sida säger att AirPods är det praktiska alternativet när telefonen ligger i fickan eller väskan. Det finns **inget strikt jämförande test** i det jag hittade.

## Rekommendation
1. **Standard = AirPods-mikrofonerna** för användarens egna frågor (närmare, riktad, ingen tygdämpning).
2. Aktivera `bluetoothHighQualityRecording` (kombinera med `.allowBluetoothA2DP`, standardläge, `setPrefersNoInterruptionsFromSystemAlerts`) och falla tillbaka på HFP; **mät WER** med `scripts/wer.ts` mot HFP.
3. Vill produkten höra *andra personer* i rummet (t.ex. en lärare eller ett samtal) är ingen av dem bra: AirPods dämpar dem, fickan dämpar allt. Då är telefonen på bord/skrivbord bäst; det är ett produktbeslut för Aron/Architect.
4. Test som behövs (Angela, enhet): samma fem meningar (egen röst och en annan person på 1,5 m) med (a) AirPods HFP, (b) AirPods high-quality, (c) iPhone i jeansficka, (d) iPhone på bordet; mät Scribe-ordfelsfrekvens.

## Källor
- [Apple: bluetoothHighQualityRecording](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording.md) och [WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/)
- [Engadget: iOS 26-uppdateringar för AirPods](https://www.engadget.com/audio/headphones/ios-26-updates-for-airpods-preview-enhanced-audio-recording-camera-remote-and-more-173036046.html)
- [Apple, AirPods Pro 2 tekniska data](https://www.apple.com/ie/airpods-pro/specs)
- [Apple bluetooth-dev: HFP-kodek (16 kHz)](https://lists.apple.com/archives/bluetooth-dev/2018/Nov/msg00002.html)
- [Apple Community: AirPods Pro 2 mikrofonkvalitet](https://discussions.apple.com/thread/254644963)
- [Apple Community: mikrofon dämpad](https://discussions.apple.com/thread/251665063)
- [Stack Overflow-arkiv: bakgrundsinspelning med låst skärm](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/9918761/avaudiorecorder-doesn-t-record-while-screen-is-locked)
