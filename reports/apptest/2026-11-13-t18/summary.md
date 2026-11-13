# T18: repetitionsläget i simulatorn (mockljud, inte enhet)

- R5d ordning i 3 varv: 1 2 3 4 1 2 3 4 1 2 3 4 1 (rätt)
- Betänketid: 12 gånger, medel 6.03 s, 6.02–6.05 s (krav 6 s ± 0,8)
- Ljudsessionen: AVAudioSessionCategoryPlayback; mikrofonbehörighet: aldrig frågad
- Avslutades aldrig av sig själv under 13 frågor: ja
- 1 tryck (play) → långt svar: ja, 6.05 s (fil 6,0 s), sedan nästa fråga utan betänketid
- 2 tryck (nästa spår) → kort svar ur den långa filen: ja, stannade efter 2.62 s (slut 2,5 s)
- 2 tryck med egen kortsvarsfil: ja, 2.56 s (fil 2,5 s)
- toggle och pause från iOS räknas som 1 tryck: ja
- R7 (proxy) paus → fortsätt med alla fyra kommandon, största hopp 0.000 s: play: pausad vid 2.00 s, fortsatte från 2.00 s, resten 4.02 s (väntat 4.00); next: pausad vid 2.29 s, fortsatte från 2.29 s, resten 3.76 s (väntat 3.71); previous: pausad vid 2.60 s, fortsatte från 2.60 s, resten 3.45 s (väntat 3.40); toggle: pausad vid 2.91 s, fortsatte från 2.91 s, resten 3.12 s (väntat 3.09)
- R8 (proxy): samtal pausar ja, fortsätter av sig själv med shouldResume ja; utan shouldResume väntar den på tryck ja och trycket fortsätter ja; ljudvägen borta pausar ja, aktiv efter 5 s ja, tryck fortsätter ja
- Fråga utan ljud: väntar (waitingForAudio) ja, fortfarande aktiv efter 2 s ja, spelas 0.06 s efter att ljudet finns (försök var 1 s), ljudsessionen AVAudioSessionCategoryPlayback
