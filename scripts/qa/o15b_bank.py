"""Oscar QA, O15b (PLAN 2b, the standing task): the reality bank grows. Same format as o15_bank.py; run with
  python -I scripts/qa/o15.py --bank scripts/qa/o15b_bank.py
Groups 7-12 (new 2026-11-10, none in Kevin's banks):
  7  spoken maths, units, numbers Scribe writes as digits or symbols
  8  questions Lumen cannot know or should not guess (own grade, the teacher's plans) and trick questions
  9  other voices: reported speech, a book or a podcast read aloud, song lyrics, Siri, a question answered by the speaker
  10 code-switching: Arabic/English/Swedish mixes, full English, Lumen's name misheard
  11 feelings and health from a teenager (must not be silent or cold), and app requests in passing
  12 Provläge follow-ups without context, and long rambles with the question in the middle"""
import importlib.util, pathlib

_s = importlib.util.spec_from_file_location("o15_bank", pathlib.Path(__file__).with_name("o15_bank.py"))
_b = importlib.util.module_from_spec(_s)
_s.loader.exec_module(_b)
PROFILES = _b.PROFILES
F, P = "fragor", "prov"
A, S, E = "answer", "silent", "either"

CASES = [
    # ------------------------------------------------------------------ 7 spoken maths and units, digits and symbols
    ("g7-01", 7, F, None, "vad är 7 x 8", A, "56|femtiosex"),
    ("g7-02", 7, F, None, "vad är 3/4 av 20", A, "15|femton"),
    ("g7-03", 7, F, None, "vad är 2^10", A, "1024|tusen tjugofyra|ettusen tjugofyra"),
    ("g7-04", 7, F, None, "vad blir sju komma fem gånger fyra", A, "trettio|30"),
    ("g7-05", 7, F, None, "hur mycket är en tredjedel plus en fjärdedel", A, "sju tolftedelar|7/12|sju genom tolv"),
    ("g7-06", 7, F, None, "vad är tio upphöjt till noll", A, "ett|1"),
    ("g7-07", 7, F, None, "hur många deciliter är en liter", A, "tio|10"),
    ("g7-08", 7, F, None, "hur många sekunder är det på ett dygn", A, "86 400|86400|åttiosextusen fyrahundra"),
    ("g7-09", 7, F, None, "vad är 15 % av 80", A, "12|tolv"),
    ("g7-10", 7, F, None, "minus tre gånger minus fyra", A, "12|tolv"),
    ("g7-11", 7, F, None, "vad är roten ur 2 ungefär", A, "1,41|ett komma fyra"),
    ("g7-12", 7, F, None, "hur många nollor har en miljard", A, "nio|9"),
    ("g7-13", 7, P, "ma8", "x plus 5 är lika med 12, vad är x", A, "sju|7"),
    ("g7-14", 7, P, "ma8", "vad är vinkelsumman i en fyrhörning", A, "360|trehundrasextio"),
    ("g7-15", 7, P, "fy1", "hur många meter per sekund är 90 km/h", A, "25|tjugofem"),
    ("g7-16", 7, P, "kemi1", "vad är H2O2", A, "väteperoxid"),
    ("g7-17", 7, P, "kemi1", "vad betyder NaCl", A, "natriumklorid|koksalt"),
    ("g7-18", 7, P, "ma3", "vad är f prim av x om f av x är x^3", A, "tre x i kvadrat|3x"),
    # ------------------------------------------------------------------ 8 cannot know / should not guess / trick
    ("g8-01", 8, F, None, "vad fick jag på provet", A, "vet inte|kan inte|inte veta|ingen tillgång|frågar|läraren"),
    ("g8-02", 8, F, None, "vad har vi för läxa till imorgon", A, "vet inte|kan inte|inte veta|schema|läraren"),
    ("g8-03", 8, F, None, "får man ha miniräknare på provet", E, ""),
    ("g8-04", 8, F, None, "vilket väger mest, ett kilo fjädrar eller ett kilo järn", A, "lika|samma"),
    ("g8-05", 8, F, None, "hur många r finns det i jordgubbe", A, "ett|1|ett r"),
    ("g8-06", 8, F, None, "om ett plan störtar precis på gränsen mellan Sverige och Norge, var begraver man de överlevande", A, "överlevande|inte begrav"),
    ("g8-07", 8, F, None, "vad är inte ett däggdjur, val eller haj", A, "haj"),
    ("g8-08", 8, F, None, "hur många djur av varje sort tog Moses med på arken", A, "noa|noah"),
    ("g8-09", 8, F, None, "vad heter min mamma", A, "vet inte|kan inte|inte veta"),
    ("g8-10", 8, F, None, "vem vinner melodifestivalen nästa år", A, "vet inte|kan inte|går inte|omöjligt|ingen vet|förutsäga"),
    ("g8-11", 8, F, None, "kommer det komma på provet", A, "vet inte|kan inte|läraren|troligt|kan komma"),
    ("g8-12", 8, F, None, "vilken är världens högsta byggnad", A, "burj khalifa"),
    # ------------------------------------------------------------------ 9 other voices around the student
    ("g9-01", 9, F, None, "han frågade mig vad fotosyntes är och jag visste inte", E, "ljus|koldioxid"),
    ("g9-02", 9, F, None, "kapitel tre: vad är en cell? En cell är den minsta byggstenen i allt levande", S, ""),
    ("g9-03", 9, F, None, "och nu blir det väder: vad blir det för väder i helgen? Jo, det blir regn i hela landet", S, ""),
    ("g9-04", 9, F, None, "is this the real life, is this just fantasy", S, ""),
    ("g9-05", 9, F, None, "vad är huvudstaden i Frankrike, Paris ju", S, ""),
    ("g9-06", 9, F, None, "hej Siri, vad är klockan", E, ""),
    ("g9-07", 9, F, None, "mamma sa: har du städat ditt rum", S, ""),
    ("g9-08", 9, F, None, "i podden frågade de vem som uppfann internet, och de sa att det var flera personer", S, ""),
    ("g9-09", 9, F, None, "vem är det som ringer", S, ""),
    ("g9-10", 9, F, None, "fråga en: vad är en art? fråga två: vad är ett ekosystem? ni har tjugo minuter", E, "art|ekosystem"),
    ("g9-11", 9, P, "bio9", "läraren säger: vad händer i mitokondrien? skriv ner ert svar", A, "energi|cellandning|atp"),
    ("g9-12", 9, P, "hist9", "som min farfar brukade säga, vad var det för tider", S, ""),
    # ------------------------------------------------------------------ 10 code-switching, English, misheard name
    ("g10-01", 10, F, None, "yani vad är fotosyntes", A, "ljus|koldioxid|klorofyll"),
    ("g10-02", 10, F, None, "shuno vad betyder demokrati", A, "folk|val|styr"),
    ("g10-03", 10, F, None, "what is the capital of Norway", A, "oslo"),
    ("g10-04", 10, F, None, "how do you say hej då in English", A, "goodbye|bye"),
    ("g10-05", 10, F, None, "Lumin, vad är en atom", A, "kärna|elektron|proton"),
    ("g10-06", 10, F, None, "lymen vem skrev Hamlet", A, "shakespeare"),
    ("g10-07", 10, F, None, "vad betyder habibi", A, "älskling|kära|min kära|arabiska"),
    ("g10-08", 10, F, None, "vad är skillnaden på affect och effect", A, "verb|substantiv|påverka"),
    ("g10-09", 10, F, None, "khalas vad är klockan i Tokyo nu", E, "tokyo"),
    ("g10-10", 10, F, None, "hur säger man jag älskar dig på arabiska", A, "uhibbuk|ana"),
    ("g10-11", 10, P, "en9", "what's the past tense of bring", A, "brought"),
    ("g10-12", 10, P, "en9", "hur böjer man swim, swam, swum eller", A, "swam|swum"),
    # ------------------------------------------------------------------ 11 feelings, health, app requests in passing
    ("g11-01", 11, F, None, "jag har ont i magen vad ska jag göra", A, "vila|vatten|läkare|1177|vård"),
    ("g11-02", 11, F, None, "jag orkar inte mer med skolan", E, ""),
    ("g11-03", 11, F, None, "jag är så nervös inför provet imorgon", E, ""),
    ("g11-04", 11, F, None, "hur många timmar ska man sova i min ålder", A, "åtta|nio|8|9|tio"),
    ("g11-05", 11, F, None, "är det farligt att dricka energidryck varje dag", A, "koffein|socker|hjärta|sömn"),
    ("g11-06", 11, F, None, "påminn mig om provet imorgon", E, ""),
    ("g11-07", 11, F, None, "sätt en timer på tio minuter", E, ""),
    ("g11-08", 11, F, None, "prata lite långsammare", E, ""),
    ("g11-09", 11, F, None, "kan du säga det kortare", E, ""),
    ("g11-10", 11, F, None, "ingen gillar mig", E, ""),
    # ------------------------------------------------------------------ 12 Provläge follow-ups without context, rambles
    ("g12-01", 12, P, "bio9", "förklara det igen fast enklare", E, ""),
    ("g12-02", 12, P, "bio9", "och den andra då", E, ""),
    ("g12-03", 12, P, "kemi1", "varför då", E, ""),
    ("g12-04", 12, P, "ma8", "jag fattar fortfarande inte", E, ""),
    ("g12-05", 12, P, "hist9", "okej så om jag har förstått rätt så var det typ att Tyskland var argt efter första världskriget, och sen kom Hitler, men vad hade Versaillesfreden med det att göra egentligen, för det fattade jag inte riktigt på lektionen", A, "skadestånd|skuld|förödmjuk|krigsskuld"),
    ("g12-06", 12, P, "bio9", "alltså vi hade om det här idag och läraren pratade jättemycket om celler och sånt och jag skrev typ ingenting men det var något om att växtceller har en grej som djurceller inte har, vad var det", A, "cellvägg|kloroplast|vakuol"),
    ("g12-07", 12, P, "fy1", "jag håller på med en uppgift där en boll släpps från tio meters höjd och jag ska räkna ut hur fort den åker när den slår i marken men jag vet inte vilken formel jag ska använda", A, "mgh|lägesenergi|rörelseenergi|fjorton|14"),
    ("g12-08", 12, P, "sv1", "vi ska skriva en novell och jag undrar hur lång en novell brukar vara och om den måste ha ett lyckligt slut eller om det får vara öppet", A, "kort|öppet|slut"),
]
