# T6: röstkommandon i simulatorn (inte verifierat på enhet)

| Läge | Fall | Rätt | Varav bara från hörda ord | Fel åtgärd / ingen | Ej hört | Falska träffar (av vanliga meningar) | Stannade |
|---|---|---|---|---|---|---|---|
| Frågor | 102 | 91 | 3 | 9 | 1 | 1 av 10 | – |
| Provläge | 102 | 86 | 5 | 14 | 1 | 1 av 10 | – |
| Intervju | 99 | 94 | 2 | 4 | 0 | 1 av 16 | – |
| Socialt | 119 | 108 | 3 | 10 | 0 | 1 av 16 | – |
| Rizz | 119 | 106 | 2 | 12 | 0 | 1 av 16 | – |

**Totalt:** 485 av 541 rätt, 5 falska träffar av 68 vanliga meningar och universella ord utanför sina lägen.

## Per kommando (rätt / fall, alla lägen)

| Kommando | Väntat | Frågor | Provläge | Intervju | Socialt | Rizz |
|---|---|---|---|---|---|---|
| wrong | feedback | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| back | music:backToLumen | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| pmus | music:pauseMusic | 3/3 | 2/3 ⚠ | 3/3 | 3/3 | 3/3 |
| rep | cmd:repeatAnswer | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| whis | cmd:whisper | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| loud | cmd:louder | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| short | cmd:shorter | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| long | cmd:longer | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| save | cmd:saveAnswer | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| exam | cmd:nextExam | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| mem | remember | 3/3 | 1/3 ⚠ | 3/3 | 3/3 | 3/3 |
| uni-rep | cmd:repeatAnswer, none | 0/1 ⚠ | 0/1 ⚠ | 1/1 | 1/1 | 1/1 |
| uni-whis | cmd:whisper, none | 1/1 | 0/1 ⚠ | 1/1 | 1/1 | 1/1 |
| uni-loud | cmd:louder, none | 1/1 | 1/1 | 1/1 | 1/1 | 1/1 |
| uni-short | cmd:shorter, none | 0/1 ⚠ | 0/1 ⚠ | 1/1 | 1/1 | 1/1 |
| uni-fast | cmd:shorter, none | 1/1 | 1/1 | 1/1 | 1/1 | 1/1 |
| uni-more | instr:moreDetail, none | 1/1 | 1/1 | 1/1 | 1/1 | 1/1 |
| neg | none | 9/10 ⚠ | 9/10 ⚠ | 9/10 ⚠ | 9/10 ⚠ | 9/10 ⚠ |
| more | instr:moreDetail | 3/3 | 2/3 ⚠ | 3/3 | 3/3 | 3/3 |
| simp | instr:simpler | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| ex | instr:example | 1/3 ⚠ | 3/3 | 3/3 | 3/3 | 3/3 |
| sum | instr:summary | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ |
| care | instr:careful | 3/3 | 2/3 ⚠ | 3/3 | 3/3 | 3/3 |
| miss | instr:catchUp | 3/3 | 1/3 ⚠ | 3/3 | 3/3 | 3/3 |
| disc | instr:discreet | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ | 3/3 | 3/3 |
| usual | instr:asUsual | 1/2 ⚠ | 2/2 | 2/2 | 2/2 | 2/2 |
| alev | instr:aLevel | 3/3 | 3/3 | – | – | – |
| hard | instr:harderQuestion | 2/3 ⚠ | 3/3 | – | – | – |
| weak | instr:weakAreas | 3/3 | 1/3 ⚠ | – | – | – |
| quiz | instr:quizMe | 3/3 | 3/3 | – | – | – |
| qq | instr:quickQuiz | 3/3 | 3/3 | – | – | – |
| hand | pause | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| stop | stop | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
| next | music:nextTrack | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ | 2/3 ⚠ |
| prev | music:previousTrack | 3/3 | 3/3 | 2/3 ⚠ | 3/3 | 2/3 ⚠ |
| switch | flera | 2/3 ⚠ | 3/3 | 3/3 | 3/3 | 2/3 ⚠ |
| ivh | instr:interviewHelp | – | – | 3/3 | – | – |
| ivb | instr:interviewBetter | – | – | 2/2 | – | – |
| ivc | instr:interviewConfident | – | – | 2/2 | – | – |
| ivq | instr:interviewCounter | – | – | 2/2 | – | – |
| ivs | instr:interviewStuck | – | – | 3/3 | – | – |
| sr | instr:socialReply | – | – | – | 2/2 | 2/2 |
| fun | instr:funnier | – | – | – | 2/2 | 2/2 |
| nat | instr:moreNatural | – | – | – | 2/2 | 2/2 |
| top | instr:changeTopic | – | – | – | 2/2 | 2/2 |
| fol | instr:followUp | – | – | – | 3/3 | 3/3 |
| mean | instr:whatMeant | – | – | – | 2/3 ⚠ | 2/3 ⚠ |
| rz | instr:rizz | – | – | – | 0/3 ⚠ | 0/3 ⚠ |
| conf | instr:moreConfident | – | – | – | 2/2 | 2/2 |
| fl | instr:flirtier | – | – | – | 0/2 ⚠ | 0/2 ⚠ |
| sub | instr:subtler | – | – | – | 2/2 | 2/2 |
| cock | instr:cockier | – | – | – | 2/2 | 2/2 |
| resc | instr:rescue | – | – | – | 2/2 | 2/2 |
| cri | instr:lessCringe | – | – | – | 0/2 ⚠ | 0/2 ⚠ |
| three | instr:threeOptions | – | – | – | 3/3 | 3/3 |

## Allt som inte blev rätt

Orsak: **STT** = Scribe hörde inte frasen så att den matchar, **app** = orden hördes rätt men appen gjorde något annat, **matcher** = appens matchning tog en vanlig mening som ett kommando.

| Läge | Fall | Sagt | Väntat | Appen gjorde | Scribe hörde | Utfall | Orsak |
|---|---|---|---|---|---|---|---|
| Frågor | uni-rep | Upprepa. | cmd:repeatAnswer | – | Uppe i apa. | missed | STT |
| Frågor | uni-short | Kortare. | cmd:shorter | – | Hoppa där. | missed | STT |
| Frågor | neg-10 | Jag berättade om Lumen för min kompis igår. | none | instr(19 characters) | Jag berättade om Lumen för min kompis igår. | false-hit | matcher |
| Frågor | ex-1 | Lumen, ge ett exempel. | instr:example | – | Lumen. / Ge ett exempel. | missed | app |
| Frågor | ex-2 | Lumen, ge mig ett exempel. | instr:example | – | Lumen. / Ge mig ett exempel. | missed | app |
| Frågor | sum-1 | Lumen, sammanfatta det viktigaste. | instr:summary | instr(24 characters) | Lumen, sammanfattade viktigaste. | wrong (instr(24 characters)) | STT |
| Frågor | disc-1 | Lumen, hjälp mig diskret. | instr:discreet | instr(13 characters) | Lumen, hjälp mig det. | wrong (instr(13 characters)) | STT |
| Frågor | usual-2 | Lumen, som vanligt. | instr:asUsual | – | – | not heard | STT |
| Frågor | hard-1 | Lumen, ställ en svår fråga. | instr:harderQuestion | – | Lumen. / Ellens fråga. | missed | STT |
| Frågor | next-3 | Lumen, skippa låten. | music:nextTrack | instr(13 characters) | Lumen, skippar låten. | wrong (instr(13 characters)) | STT |
| Frågor | sw-prov | Lumen, byt till provläge. | switch:prov | instr(16 characters) | Lumen, by till provläge. | wrong (instr(16 characters)) | STT |
| Provläge | pmus-1 | Lumen, pausa musiken. | music:pauseMusic | instr(21 characters), instr(14 characters) | Lumen, pausar musiken. | wrong (instr(21 characters), instr(14 characters)) | STT |
| Provläge | mem-1 | Lumen, kom ihåg att jag gillar korta svar. | remember | – | Lumen. / Kom ihåg att jag gillar korta svar. | missed | app |
| Provläge | mem-3 | Lumen, kom ihåg att jag tränar fotboll på tisdagar. | remember | – | Lumen. / Kom ihåg att jag tränar fotboll på tisdagar. | missed | app |
| Provläge | uni-rep | Upprepa. | cmd:repeatAnswer | – | Uppe i Pä. | missed | STT |
| Provläge | uni-whis | Viska. | cmd:whisper | – | – | not heard | STT |
| Provläge | uni-short | Kortare. | cmd:shorter | cmd:louder | Högre. | wrong (cmd:louder) | STT |
| Provläge | neg-10 | Jag berättade om Lumen för min kompis igår. | none | instr(19 characters) | Jag berättade om lumen för min kompis igår. | false-hit | matcher |
| Provläge | more-2 | Lumen, berätta mer. | instr:moreDetail | – | Lumen. / Berätta mer. | missed | app |
| Provläge | sum-1 | Lumen, sammanfatta det viktigaste. | instr:summary | instr(24 characters) | Lumen, sammanfattade viktigaste. | wrong (instr(24 characters)) | STT |
| Provläge | care-1 | Lumen, var säker. | instr:careful | instr(8 characters) | Lumen, varsäker. | wrong (instr(8 characters)) | STT |
| Provläge | miss-1 | Lumen, vad missade jag? | instr:catchUp | – | Lumen. / Vad missade jag? | missed | app |
| Provläge | miss-3 | Lumen, vad sa de? | instr:catchUp | – | Lumen. / Vad sa de? | missed | app |
| Provläge | disc-1 | Lumen, hjälp mig diskret. | instr:discreet | instr(21 characters) | Lumen. / Hjälp mig, det är... | wrong (instr(21 characters)) | STT |
| Provläge | weak-1 | Lumen, testa mina svagaste områden. | instr:weakAreas | instr(28 characters) | Lumen, testar mina svagaste områden. | wrong (instr(28 characters)) | STT |
| Provläge | weak-3 | Lumen, vad kan jag sämst? | instr:weakAreas | instr(15 characters) | Lumen, vad kan jag sem... | wrong (instr(15 characters)) | STT |
| Provläge | next-3 | Lumen, skippa låten. | music:nextTrack | instr(13 characters) | Lumen, skippar låten. | wrong (instr(13 characters)) | STT |
| Intervju | neg-10 | Jag berättade om Lumen för min kompis igår. | none | instr(19 characters) | Jag berättade om Lumen för min kompis igår. | false-hit | matcher |
| Intervju | sum-1 | Lumen, sammanfatta det viktigaste. | instr:summary | instr(24 characters) | Lumen, sammanfattade viktigaste. | wrong (instr(24 characters)) | STT |
| Intervju | disc-1 | Lumen, hjälp mig diskret. | instr:discreet | – | Skrevet. | missed | STT |
| Intervju | next-3 | Lumen, skippa låten. | music:nextTrack | instr(13 characters) | Lumen, skippar låten. | wrong (instr(13 characters)) | STT |
| Intervju | prev-1 | Förra låten. | music:previousTrack | – | Föra låten. | missed | STT |
| Socialt | neg-10 | Jag berättade om Lumen för min kompis igår. | none | instr(19 characters) | Jag berättade om Lumen för min kompis igår. | false-hit | matcher |
| Socialt | sum-1 | Lumen, sammanfatta det viktigaste. | instr:summary | instr(24 characters) | Lumen, sammanfattade viktigaste. | wrong (instr(24 characters)) | STT |
| Socialt | mean-3 | Lumen, vad menade de? | instr:whatMeant | instr(14 characters) | Lumen, vad menade dom? | wrong (instr(14 characters)) | STT |
| Socialt | rz-1 | Lumen, ge mig lite rizz. | instr:rizz | instr(16 characters) | Lumen, ge mig lite risk. | wrong (an instruction, but instr:other(ge mig lite risk)) | STT |
| Socialt | rz-2 | Lumen, lite rizz. | instr:rizz | instr(9 characters) | Lumen, lite risk. | wrong (instr(9 characters)) | STT |
| Socialt | rz-3 | Lumen, rizz. | instr:rizz | instr(4 characters) | Lumen, risk. | wrong (instr(4 characters)) | STT |
| Socialt | fl-1 | Lumen, flirtigare. | instr:flirtier | instr(9 characters) | Lumen, flitigare. | wrong (instr(9 characters)) | STT |
| Socialt | fl-2 | Lumen, mer flirtig. | instr:flirtier | instr(10 characters) | Lumen, mer flötig. | wrong (an instruction, but instr:other(mer flötig)) | STT |
| Socialt | cri-1 | Lumen, mindre cringe. | instr:lessCringe | instr(14 characters) | Lumen, mindre kringel. | wrong (instr(14 characters)) | STT |
| Socialt | cri-2 | Lumen, inte så cringe. | instr:lessCringe | instr(15 characters) | Lumen, inte så kringel. | wrong (instr(15 characters)) | STT |
| Socialt | next-3 | Lumen, skippa låten. | music:nextTrack | instr(13 characters) | Lumen, skippar låten. | wrong (instr(13 characters)) | STT |
| Rizz | neg-10 | Jag berättade om Lumen för min kompis igår. | none | instr(19 characters) | Jag berättade om Lumen för min kompis igår. | false-hit | matcher |
| Rizz | sum-1 | Lumen, sammanfatta det viktigaste. | instr:summary | instr(24 characters) | Lumen, sammanfattade viktigaste. | wrong (instr(24 characters)) | STT |
| Rizz | mean-3 | Lumen, vad menade de? | instr:whatMeant | instr(14 characters) | Lumen, vad menade dom? | wrong (instr(14 characters)) | STT |
| Rizz | rz-1 | Lumen, ge mig lite rizz. | instr:rizz | instr(15 characters) | Lumen, ge mig lite ris. | wrong (instr(15 characters)) | STT |
| Rizz | rz-2 | Lumen, lite rizz. | instr:rizz | instr(8 characters) | Lumen, lite ris. | wrong (instr(8 characters)) | STT |
| Rizz | rz-3 | Lumen, rizz. | instr:rizz | instr(3 characters) | Lumen, ris. | wrong (instr(3 characters)) | STT |
| Rizz | fl-1 | Lumen, flirtigare. | instr:flirtier | instr(9 characters) | Lumen, flitigare. | wrong (instr(9 characters)) | STT |
| Rizz | fl-2 | Lumen, mer flirtig. | instr:flirtier | instr(10 characters) | Lumen, mer flitig. | wrong (an instruction, but instr:other(mer flitig)) | STT |
| Rizz | cri-1 | Lumen, mindre cringe. | instr:lessCringe | instr(14 characters) | Lumen, mindre kringel. | wrong (instr(14 characters)) | STT |
| Rizz | cri-2 | Lumen, inte så cringe. | instr:lessCringe | instr(15 characters) | Lumen, inte så kringel. | wrong (instr(15 characters)) | STT |
| Rizz | next-3 | Lumen, skippa låten. | music:nextTrack | instr(13 characters) | Lumen, skippar låten. | wrong (instr(13 characters)) | STT |
| Rizz | prev-1 | Förra låten. | music:previousTrack | – | Föra låten. | missed | STT |
| Rizz | sw-prov | Lumen, byt till provläge. | switch:prov | instr(16 characters) | Lumen, by till provläge. | wrong (instr(16 characters)) | STT |

## Terminala kommandon: läget efteråt

| Läge | Fall | Sagt | Väntat | Utfall | Efteråt |
|---|---|---|---|---|---|
| Frågor | hand-1 | Pausa. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | hand-2 | Spela musik. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | hand-3 | Lumen, pausa dig. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | stop-1 | Lumen, sluta lyssna. | stop | ok | mode=standard listening=false active=false state=idle |
| Frågor | stop-2 | Lumen, avsluta. | stop | ok | mode=standard listening=false active=false state=idle |
| Frågor | stop-3 | Lumen, stäng av. | stop | ok | mode=standard listening=false active=false state=idle |
| Frågor | next-1 | Nästa låt. | music:nextTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | next-2 | Lumen, hoppa över låten. | music:nextTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | next-3 | Lumen, skippa låten. | music:nextTrack | wrong (instr(13 characters)) | mode=standard listening=true active=true state=listening |
| Frågor | prev-1 | Förra låten. | music:previousTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | prev-2 | Lumen, föregående låt. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | prev-3 | Lumen, spela förra låten. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Frågor | sw-prov | Lumen, byt till provläge. | switch:prov | wrong (instr(16 characters)) | mode=standard listening=true active=true state=listening |
| Frågor | sw-interview | Lumen, gå till intervjuläge. | switch:interview | ok | mode=interview listening=true active=true state=listening |
| Frågor | sw-social | Lumen, starta socialt läge. | switch:social | ok | mode=social listening=true active=true state=listening |
| Provläge | hand-1 | Pausa. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | hand-2 | Spela musik. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | hand-3 | Lumen, pausa dig. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | stop-1 | Lumen, sluta lyssna. | stop | ok | mode=standard listening=false active=false state=idle |
| Provläge | stop-2 | Lumen, avsluta. | stop | ok | mode=standard listening=false active=false state=idle |
| Provläge | stop-3 | Lumen, stäng av. | stop | ok | mode=standard listening=false active=false state=idle |
| Provläge | next-1 | Nästa låt. | music:nextTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | next-2 | Lumen, hoppa över låten. | music:nextTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | next-3 | Lumen, skippa låten. | music:nextTrack | wrong (instr(13 characters)) | mode=prov listening=true active=true state=listening |
| Provläge | prev-1 | Förra låten. | music:previousTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | prev-2 | Lumen, föregående låt. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | prev-3 | Lumen, spela förra låten. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Provläge | sw-social | Lumen, starta socialt läge. | switch:social | ok | mode=social listening=true active=true state=listening |
| Provläge | sw-rizz | Lumen, byta till rizzläge. | switch:rizz | ok | mode=rizz listening=true active=true state=listening |
| Provläge | sw-standard2 | Lumen, lyssna efter frågor. | switch:standard | ok | mode=standard listening=true active=true state=listening |
| Intervju | hand-1 | Pausa. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | hand-2 | Spela musik. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | hand-3 | Lumen, pausa dig. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | stop-1 | Lumen, sluta lyssna. | stop | ok | mode=standard listening=false active=false state=idle |
| Intervju | stop-2 | Lumen, avsluta. | stop | ok | mode=standard listening=false active=false state=idle |
| Intervju | stop-3 | Lumen, stäng av. | stop | ok | mode=standard listening=false active=false state=idle |
| Intervju | next-1 | Nästa låt. | music:nextTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | next-2 | Lumen, hoppa över låten. | music:nextTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | next-3 | Lumen, skippa låten. | music:nextTrack | wrong (instr(13 characters)) | mode=interview listening=true active=true state=listening |
| Intervju | prev-1 | Förra låten. | music:previousTrack | missed | mode=interview listening=true active=true state=listening |
| Intervju | prev-2 | Lumen, föregående låt. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | prev-3 | Lumen, spela förra låten. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Intervju | sw-prov2 | Lumen, provläge. | switch:prov | ok | mode=prov listening=true active=true state=listening |
| Intervju | sw-standard2 | Lumen, lyssna efter frågor. | switch:standard | ok | mode=standard listening=true active=true state=listening |
| Intervju | sw-social2 | Lumen, socialt. | switch:social | ok | mode=social listening=true active=true state=listening |
| Socialt | hand-1 | Pausa. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | hand-2 | Spela musik. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | hand-3 | Lumen, pausa dig. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | stop-1 | Lumen, sluta lyssna. | stop | ok | mode=standard listening=false active=false state=idle |
| Socialt | stop-2 | Lumen, avsluta. | stop | ok | mode=standard listening=false active=false state=idle |
| Socialt | stop-3 | Lumen, stäng av. | stop | ok | mode=standard listening=false active=false state=idle |
| Socialt | next-1 | Nästa låt. | music:nextTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | next-2 | Lumen, hoppa över låten. | music:nextTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | next-3 | Lumen, skippa låten. | music:nextTrack | wrong (instr(13 characters)) | mode=social listening=true active=true state=listening |
| Socialt | prev-1 | Förra låten. | music:previousTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | prev-2 | Lumen, föregående låt. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | prev-3 | Lumen, spela förra låten. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Socialt | sw-interview | Lumen, gå till intervjuläge. | switch:interview | ok | mode=interview listening=true active=true state=listening |
| Socialt | sw-rizz | Lumen, byta till rizzläge. | switch:rizz | ok | mode=rizz listening=true active=true state=listening |
| Socialt | sw-prov2 | Lumen, provläge. | switch:prov | ok | mode=prov listening=true active=true state=listening |
| Rizz | hand-1 | Pausa. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | hand-2 | Spela musik. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | hand-3 | Lumen, pausa dig. | pause | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | stop-1 | Lumen, sluta lyssna. | stop | ok | mode=standard listening=false active=false state=idle |
| Rizz | stop-2 | Lumen, avsluta. | stop | ok | mode=standard listening=false active=false state=idle |
| Rizz | stop-3 | Lumen, stäng av. | stop | ok | mode=standard listening=false active=false state=idle |
| Rizz | next-1 | Nästa låt. | music:nextTrack | ok (from the heard words: unnamed music commands have no log line) | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | next-2 | Lumen, hoppa över låten. | music:nextTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | next-3 | Lumen, skippa låten. | music:nextTrack | wrong (instr(13 characters)) | mode=rizz listening=true active=true state=listening |
| Rizz | prev-1 | Förra låten. | music:previousTrack | missed | mode=rizz listening=true active=true state=listening |
| Rizz | prev-2 | Lumen, föregående låt. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | prev-3 | Lumen, spela förra låten. | music:previousTrack | ok | mode=standard listening=false active=true state=paused(Lumen.PauseReason.user) |
| Rizz | sw-social2 | Lumen, socialt. | switch:social | ok | mode=social listening=true active=true state=listening |
| Rizz | sw-prov | Lumen, byt till provläge. | switch:prov | wrong (instr(16 characters)) | mode=rizz listening=true active=true state=listening |
| Rizz | sw-standard | Lumen, växla till frågor. | switch:standard | ok | mode=standard listening=true active=true state=listening |
