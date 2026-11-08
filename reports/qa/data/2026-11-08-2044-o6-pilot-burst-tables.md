# O6 tables 2026-11-08-2044 (pilot): 15 cases, voices Adam, Saga, Max, model haiku, judge sonnet

TTS 0 characters, realtime Scribe 1081.4 s, batch Scribe 0.0 s, LLM 0.4373 USD, 137 distinct answers graded, 21 Scribe sessions.

## no keyterms

| Condition | n | WER | exact | subject word | clipped | nothing | stray commit | commit lag s p50/p90 | first text s p50 | first answer enough (heard / text) |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| prat 20 dB burst | 45 | 4.13 | 2 % | 42 % | 9 % | 51 % | 18 % | 1.3 / 2.0 | 0.4 | 27 % / 100 % |
| prat 10 dB burst | 45 | 10.65 | 0 % | 22 % | 4 % | 76 % | 18 % | 0.9 / 2.0 | 0.4 | 2 % / 100 % |
| prat 5 dB burst | 45 | 8.37 | 2 % | 18 % | 2 % | 71 % | 20 % | 1.8 / 2.1 | 0.5 | 2 % / 100 % |

## right keyterms

| Condition | n | WER | exact | subject word | clipped | nothing | stray commit | commit lag s p50/p90 | first text s p50 | first answer enough (heard / text) |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| prat 20 dB burst | 45 | 3.76 | 9 % | 42 % | 13 % | 47 % | 29 % | 2.1 / 3.4 | 0.6 | 22 % / 100 % |
| prat 10 dB burst | 45 | 6.17 | 2 % | 33 % | 4 % | 58 % | 16 % | 3.2 / 3.5 | 0.4 | 9 % / 100 % |
| prat 5 dB burst | 45 | 5.69 | 2 % | 22 % | 2 % | 58 % | 20 % | 1.6 / 2.1 | 0.5 | 4 % / 100 % |

## wrong keyterms

| Condition | n | WER | exact | subject word | clipped | nothing | stray commit | commit lag s p50/p90 | first text s p50 | first answer enough (heard / text) |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|

## By kind (keyterms right, all conditions) / (quiet only)

| Kind | all: n | WER | subject word | first answer enough | quiet: WER | subject word |
|---|--:|--:|--:|--:|--:|--:|
| term | 54 | 2.86 | 15 % | 13 % (text 100 %) | nan | – |
| short | 27 | 10.19 | 26 % | 15 % (text 100 %) | nan | – |
| half | 18 | 2.08 | 39 % | 6 % (text 100 %) | nan | – |
| followup | 36 | 6.56 | 61 % | 11 % (text 100 %) | nan | – |

## By voice (no keyterms, all conditions)

| Voice | n | WER | subject word | clipped |
|---|--:|--:|--:|--:|
| Adam | 45 | 7.67 | 27 % | 4 % |
| Saga | 45 | 7.84 | 24 % | 4 % |
| Max | 45 | 7.63 | 31 % | 7 % |

## Batch vs realtime (no keyterms)

| Condition | n | batch WER | realtime WER | batch exact | realtime exact |
|---|--:|--:|--:|--:|--:|

## Chain loss

Graded rows: 270; heard-text answer worse than the plain-text answer (text ok, heard not): 240; better: 0.

Rows by cause when the heard answer failed:  Counter({'hearing': 240})

## 10 worst (hearing loss first, then WER)

- au-57 nokt · prat 10 dB burst · Saga: said "kvadratrot" → heard "Trött. Läraren glömde sin kaffekopp i klassrummet och händerna fulla med böcker. Vi ses vid entrén klockan halv tre. Vi borde fråga om vi får ha fotbollen i ladan imorgon. Vad hände efter att Napoleon? Vi skulle kunna ha hört att det kommer ett nytt spel. Industriella revolutionen. Pratar om det. Jag tror att bussen är sen igen. Jag tog fel buss i morse. Pythagoras. Hur fick jag laddaren när du ändå står där? Och hur räknar man ut den andra sidan? Mamma sa att jag får sova över hos dig om jag är trött. Kvadratroten. Min lillebror fyller år på lördag." (WER 102.0, commits 1, answer enough 0, plain text 1); answer: 'Pythagoras sats säger att i en rätvinklig triangel är kvadraten på hypotenusan lika med summan av kvadraterna på de två kateterna. Med kateterna a och b och hyp'
- au-57 nokt · prat 5 dB burst · Max: said "kvadratrot" → heard "Nej, men verkligen. Hon sa precis samma sak förra veckan också. Visst vi kunde åka till stan efter skolan istället? Räkna ut det. Jag tror att bussen är sen igen. Franska revolutionen. Vi borde fråga om vi får ha fotboll i lärarlovet. Vad hände efter att Napoleon... Det var den bästa matchen jag har sett. Har du hört att... Industriella revolutionen. Min lillebror fyller år på lördag och... Varför då? Jag tog fel buss i morse och kom tjugo... Träningen är inställd på grund av regnet. Och hur räknar man ut den andra sidan? Läraren glömde sin... Kvadratroten." (WER 98.0, commits 1, answer enough 0, plain text 1); answer: 'Kvadratroten av ett tal är det tal som, multiplicerat med sig självt, ger talet. Till exempel är kvadratroten ur fyrtionio lika med sju, eftersom sju gånger sju'
- au-17 nokt · prat 5 dB burst · Adam: said "pythagoras" → heard "Nej, trycklömdes en katt på köksbänken igen. Räkna ut det. Jag tog felsats i morse. Vi ses vid entrén klockan halv fem. Franska revolutionen. Har du sett vad jag la i min jacka i morse? Mamma sa att jag... Vad hände efter att Napoleon... Vi ska tillbaka till stan efter skolan istället. Industriella revolutionen. Det börjar regna precis när rasten är slut. Jag tror att bussen är... Varför då? Jag glömde skicka in uppgiften... Skit tagor asså." (WER 77.0, commits 1, answer enough 0, plain text 1); answer: ''
- au-57 nokt · prat 10 dB burst · Adam: said "kvadratrot" → heard "Franska revolutionen. Spel på fredag. Alla pratar om det. Vad hände efter att Napoleon... Vi har entré klockan halv fyra. Industriella revolutionen. Jag har en ny jacka i morse. Mamma sa att jag får sova... Varför då? Efter skolan istället. Pythagoras. Det börjar regna precis när... Jag tror att bussen... Och hur räknar man ut den andra sidan? Jag glömde skicka in... Kan du skicka laddaren... Kvadratroter. Det var..." (WER 69.0, commits 2, answer enough 0, plain text 1); answer: 'Pythagoras sats gäller i en rätvinklig triangel: kvadraten på hypotenusan är lika med summan av kvadraterna på de två kateterna, alltså c i kvadrat är lika med '
- au-33 nokt · prat 10 dB burst · Max: said "tryck" → heard "Min lillebror fyller år på några dagar. Sällan ing- Hon sa att träningen är inställd på grund av regn. Eh, skillnaden mellan mitos och... Jag har inte hunnit äta lunch än. Har du hunnit äta? Effekt. Läraren glömde sin kaffekopp i klassrummet igen. Det luktar som att någon har bränt vid entrén klockan halv åtta." (WER 55.0, commits 1, answer enough 0, plain text 1); answer: 'Effekt är hur snabbt energi omvandlas eller hur mycket arbete som görs per sekund. Enheten är watt, och ett watt motsvarar en joule per sekund. Om en lampa har '
- au-57 nokt · prat 10 dB burst · Max: said "kvadratrot" → heard "Varför då? Det var den bästa matchen jag har sett. Har du hört att det kommer ett nytt- Pythagoras. Min lillebror fyller år på lördag och vi- Och hur räknar man ut den andra sidan? Och kom tjugo minuter- Hon sa att träningen är inställd- Kvadratroten. Mamma sa att jag får..." (WER 51.0, commits 2, answer enough 0, plain text 1); answer: 'Pythagoras sats gäller rätvinkliga trianglar: kvadraten på hypotenusan är lika med summan av kvadraterna på de två kateterna, alltså c i kvadrat är lika med a i'
- au-33 nokt · prat 10 dB burst · Saga: said "tryck" → heard "Ska vi sitta tillsammans vid lunchen eller är du uppe i borgen? Lillebror fyller år på lördag. Det luktar som att någon har bränt popcorn i hela korridoren. Hon sa att träningen är inställd på grund av regnet. Nej, men verkligen. Hon sa på så- Omslaget till lunchen. Är du hungrig?" (WER 51.0, commits 1, answer enough 0, plain text 1); answer: ''
- au-57 kt · prat 10 dB burst · Saga: said "kvadratrot" → heard "Kommer ett nytt svar. Pythagoras. Alla pratar om det. Jag tror att- Och hur räknar man ut den andra sidan? Jag tog fel buss i morse och kom- Skicka laddaren när du ändå står där." (WER 35.0, commits 1, answer enough 0, plain text 1); answer: 'Pythagoras sats säger att i en rätvinklig triangel är kvadraten på hypotenusan lika med summan av kvadraterna på de två kateterna. Med kateterna a och b och hyp'
- au-57 kt · prat 5 dB burst · Adam: said "kvadratrot" → heard "Pythagoras. Var jag lade min jacka i morse. Mamma sa att jag- Och hur räknar man ut den andra sidan? ...efter skolan istället. Titta, det var- Kvadratrot. Jag tror att bussen är sen..." (WER 32.0, commits 1, answer enough 0, plain text 1); answer: 'Pythagoras sats säger att i en rätvinklig triangel är kvadraten på hypotenusan lika med summan av kvadraterna på de två kateterna, alltså a i kvadrat plus b i k'
- au-57 kt · prat 5 dB burst · Saga: said "kvadratrot" → heard "Spel på fyrtiotal, alla pratar om det. Jag tror att bussen är sen igen. Jag tog fel buss i morse och kom- Kan du skicka laddaren när du ändå står där?" (WER 31.0, commits 1, answer enough 0, plain text 1); answer: ''

## Window and segment view

'In window' = commits that arrive from the start of the question until the next question starts. 'Anywhere' = the subject word is somewhere in that condition's transcript (heard, but maybe late or merged).

| Mode | Condition | n | words of the question in window | subject word in window | subject word anywhere | nothing in window | > 3 extra words in window |
|---|---|--:|--:|--:|--:|--:|--:|
| no keyterms | prat 20 dB burst | 45 | 0.34 | 42 % | 69 % | 49 % | 44 % |
| no keyterms | prat 10 dB burst | 45 | 0.10 | 22 % | 64 % | 69 % | 31 % |
| no keyterms | prat 5 dB burst | 45 | 0.08 | 18 % | 47 % | 69 % | 29 % |
| right keyterms | prat 20 dB burst | 45 | 0.38 | 42 % | 78 % | 44 % | 44 % |
| right keyterms | prat 10 dB burst | 45 | 0.32 | 33 % | 78 % | 51 % | 47 % |
| right keyterms | prat 5 dB burst | 45 | 0.19 | 22 % | 53 % | 60 % | 38 % |
