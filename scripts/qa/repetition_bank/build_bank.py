"""Oscar: testbank för repetitionsläget. 10 påhittade prov med facit.

Allt innehåll är skrivet av Oscar (QA). Ingen elevtext, inga riktiga prov, inga namn på riktiga skolor/elever.
Formatet följer /exam (D84/K15): varje uppgift har no, text, points {E,C,A}, answer, assessment, topic.
`exam_text` är provet som text (som eleven klistrar in eller som en PDF:s textlager), med facit och
bedömningsanvisning sist, så att samma bank kan skickas till `/exam {"action":"parse","text":...}` och
jämföras mot `key` här.

Kör:  python -I scripts/qa/repetition_bank/build_bank.py
Skriver: scripts/qa/repetition_bank/exams.json  (och kontrollerar strukturen; 0 nätverksanrop, 0 USD)

`accept` = andra formuleringar som ska räknas som rätt vid rättning av ett talat svar (hörfel/synonymer).
`wrong`  = typiska felsvar som INTE får godkännas (för att testa falskt Rätt, jfr O43d).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from materials import M  # noqa: E402  O55: materialet, formaten och lärandemålen


def t(no, text, E, C, A, answer, topic, accept=(), wrong=(), assessment=""):
    return {
        "no": str(no), "text": text, "points": {"E": E, "C": C, "A": A}, "answer": answer,
        "assessment": assessment or "Full poäng för svar som stämmer med facit.",
        "topic": topic, "accept": list(accept), "wrong": list(wrong),
    }


EXAMS = [
    {
        "id": "bio-ak8-fotosyntes", "subject": "Biologi", "grade": "åk 8", "title": "Prov: Ekologi och fotosyntes",
        "tasks": [
            t(1, "Vad behöver en växt för att kunna göra fotosyntes? Nämn tre saker.", 2, 0, 0,
              "Ljus (solljus), koldioxid och vatten.", "fotosyntes",
              accept=["solljus, koldioxid och vatten", "ljusenergi, CO2 och vatten"], wrong=["syre, vatten och jord"]),
            t(2, "Vilka två ämnen bildas vid fotosyntesen?", 2, 0, 0,
              "Glukos (socker) och syre.", "fotosyntes", accept=["socker och syre", "druvsocker och syre"],
              wrong=["koldioxid och vatten"]),
            t(3, "Vad kallas de organismer som tillverkar sin egen näring?", 1, 0, 0,
              "Producenter.", "näringskedja", accept=["autotrofa organismer"], wrong=["konsumenter", "nedbrytare"]),
            t(4, "Förklara varför det finns färre rovdjur än växtätare i ett ekosystem.", 0, 2, 0,
              "Vid varje steg i näringskedjan går det mesta av energin förlorad (ungefär 90 %) som värme och rörelse, "
              "så det finns mindre energi kvar till nästa led.", "energiflöde",
              accept=["bara cirka 10 procent av energin går vidare till nästa nivå"], wrong=["rovdjuren äter upp varandra"]),
            t(5, "Vad gör nedbrytarna i ett ekosystem? Ge ett exempel på en nedbrytare.", 1, 1, 0,
              "De bryter ner döda växter och djur till näringsämnen som växterna kan ta upp igen. Exempel: svampar, "
              "bakterier eller daggmaskar.", "nedbrytare", accept=["maskar", "mögelsvampar"], wrong=["rävar"]),
            t(6, "Resonera om vad som kan hända i en sjö om för mycket gödsel rinner ut i den.", 0, 1, 2,
              "Övergödning: alger växer kraftigt, dör och bryts ner av bakterier som förbrukar syret. Syrebrist gör att "
              "fiskar och bottendjur dör. Det kan motverkas med mindre gödsel och skyddszoner vid vatten.", "övergödning",
              wrong=["sjön blir renare"]),
        ],
        "boundaries": [{"grade": "E", "total": 5}, {"grade": "C", "total": 9, "min_ca": 3}, {"grade": "A", "total": 12, "min_a": 2}],
    },
    {
        "id": "hist-ak9-forsta-varldskriget", "subject": "Historia", "grade": "åk 9", "title": "Prov: Första världskriget",
        "tasks": [
            t(1, "Vilka år pågick första världskriget?", 1, 0, 0, "1914–1918.", "årtal",
              accept=["från 1914 till 1918", "nittonhundrafjorton till nittonhundraarton"], wrong=["1939–1945"]),
            t(2, "Vilken händelse i Sarajevo brukar räknas som den utlösande orsaken?", 1, 0, 0,
              "Mordet på den österrikiske tronföljaren Franz Ferdinand 1914.", "orsaker",
              accept=["skottet mot Franz Ferdinand", "att ärkehertigen sköts"], wrong=["Hitler invaderade Polen"]),
            t(3, "Nämn de två stora allianserna i kriget.", 2, 0, 0,
              "Ententen (Storbritannien, Frankrike, Ryssland) och Centralmakterna (Tyskland, Österrike-Ungern).",
              "allianser", accept=["trippelententen och centralmakterna"], wrong=["axelmakterna och de allierade"]),
            t(4, "Beskriv hur skyttegravskriget fungerade på västfronten.", 1, 1, 0,
              "Arméerna grävde ner sig i långa skyttegravar från Nordsjön till Schweiz. Fronten rörde sig nästan inte, "
              "anfall över ingenmansland med kulsprutor och taggtråd gav enorma förluster.", "skyttegravskriget"),
            t(5, "Varför gick USA med i kriget 1917? Ge två skäl.", 0, 2, 0,
              "Tysklands oinskränkta ubåtskrig sänkte amerikanska fartyg, och Zimmermann-telegrammet där Tyskland "
              "försökte få Mexiko att anfalla USA.", "USA", accept=["ubåtskriget", "telegrammet till Mexiko"],
              wrong=["Pearl Harbor"]),
            t(6, "Resonera om hur Versaillesfreden kan ha bidragit till ett nytt krig.", 0, 1, 2,
              "Tyskland fick ta på sig skulden, betala stora skadestånd, förlora land och rusta ner. Det skapade "
              "förödmjukelse och ekonomiska problem som nazisterna utnyttjade; samtidigt var det inte freden ensam "
              "utan också depressionen på 1930-talet.", "Versaillesfreden"),
        ],
        "boundaries": [{"grade": "E", "total": 5}, {"grade": "C", "total": 9, "min_ca": 3}, {"grade": "A", "total": 11, "min_a": 2}],
    },
    {
        "id": "ma1b-ekvationer", "subject": "Matematik", "grade": "Matematik 1b", "title": "Prov: Ekvationer och funktioner",
        "tasks": [
            t(1, "Lös ekvationen 3x + 5 = 20.", 1, 0, 0, "x = 5", "ekvationer", accept=["fem"], wrong=["x = 25/3", "x = 15"]),
            t(2, "Lös ekvationen 2(x − 4) = x + 3.", 2, 0, 0, "x = 11", "ekvationer", accept=["elva"], wrong=["x = 7", "x = 1"]),
            t(3, "Vilken lutning har linjen y = −2x + 7?", 1, 0, 0, "k = −2", "räta linjen",
              accept=["minus två", "-2"], wrong=["7", "2"]),
            t(4, "En linje går genom punkterna (1, 3) och (3, 11). Bestäm linjens ekvation.", 0, 2, 0,
              "k = (11 − 3)/(3 − 1) = 4, m = 3 − 4 = −1, alltså y = 4x − 1.", "räta linjen",
              accept=["y = 4x - 1", "y är fyra x minus ett"], wrong=["y = 4x + 3", "y = 8x - 5"]),
            t(5, "Ett gym kostar 300 kr i startavgift och 150 kr per månad. Efter hur många månader har man betalat 1 950 kr?",
              1, 1, 0, "300 + 150x = 1 950 ger x = 11 månader.", "problemlösning", accept=["elva månader"],
              wrong=["13 månader", "10 månader"]),
            t(6, "Två mobilabonnemang: A kostar 99 kr/mån + 2 kr per GB, B kostar 149 kr/mån fritt surf. Vid hur många GB "
                 "per månad blir B billigast? Motivera.", 0, 1, 2,
              "99 + 2x = 149 ger x = 25. Över 25 GB per månad är B billigast (vid exakt 25 GB kostar de lika).",
              "problemlösning", accept=["mer än 25 GB", "fler än tjugofem gigabyte"], wrong=["50 GB", "25 GB eller mindre"]),
        ],
        "boundaries": [{"grade": "E", "total": 4}, {"grade": "C", "total": 8, "min_ca": 3}, {"grade": "A", "total": 11, "min_a": 2}],
    },
    {
        "id": "ke1-mol", "subject": "Kemi", "grade": "Kemi 1", "title": "Prov: Stökiometri och mol",
        "tasks": [
            t(1, "Vad är molmassan för vatten, H2O? (H = 1,0 g/mol, O = 16,0 g/mol)", 1, 0, 0, "18,0 g/mol", "molmassa",
              accept=["18 gram per mol"], wrong=["17 g/mol", "34 g/mol"]),
            t(2, "Hur många mol är 88 g koldioxid, CO2? (C = 12,0, O = 16,0)", 1, 1, 0,
              "M = 44,0 g/mol, n = 88/44 = 2,0 mol.", "substansmängd", accept=["två mol"], wrong=["0,5 mol", "4 mol"]),
            t(3, "Balansera reaktionsformeln: H2 + O2 → H2O", 1, 0, 0, "2 H2 + O2 → 2 H2O", "reaktionsformler",
              accept=["två H2 plus O2 ger två H2O"], wrong=["H2 + O2 → H2O2"]),
            t(4, "Vad är koncentrationen om 0,50 mol NaCl löses i 250 ml vatten?", 0, 2, 0,
              "c = n/V = 0,50/0,250 = 2,0 mol/dm³", "koncentration", accept=["2 molar", "två mol per liter"],
              wrong=["0,125 mol/dm³", "125 mol/dm³"]),
            t(5, "Hur många gram syrgas behövs för att förbränna 16 g metan? CH4 + 2 O2 → CO2 + 2 H2O", 0, 1, 2,
              "n(CH4) = 16/16 = 1,0 mol, n(O2) = 2,0 mol, m = 2,0 · 32 = 64 g.", "stökiometri",
              accept=["sextiofyra gram"], wrong=["32 g", "16 g"]),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 6, "min_ca": 2}, {"grade": "A", "total": 8, "min_a": 1}],
    },
    {
        "id": "fy-ak9-ellara", "subject": "Fysik", "grade": "åk 9", "title": "Prov: Ellära",
        "tasks": [
            t(1, "Vilken enhet mäts elektrisk ström i?", 1, 0, 0, "Ampere (A).", "ström", accept=["ampär"], wrong=["volt", "watt"]),
            t(2, "Skriv Ohms lag.", 1, 0, 0, "U = R · I (spänning = resistans gånger ström).", "Ohms lag",
              accept=["U är lika med R gånger I", "R = U/I"], wrong=["P = U · I"]),
            t(3, "En lampa har resistansen 6 Ω och spänningen 12 V. Hur stor är strömmen?", 1, 1, 0, "I = 12/6 = 2 A",
              "Ohms lag", accept=["två ampere"], wrong=["72 A", "0,5 A"]),
            t(4, "Vad är skillnaden mellan serie- och parallellkoppling när en lampa går sönder?", 0, 2, 0,
              "I seriekoppling bryts hela kretsen och alla lampor slocknar; i parallellkoppling lyser de andra lamporna "
              "eftersom strömmen har andra vägar.", "kopplingar"),
            t(5, "En vattenkokare på 2 000 W används 3 minuter varje dag i 30 dagar. Hur mycket energi går åt i kWh, och vad "
                 "kostar det om 1 kWh kostar 2 kr?", 0, 1, 2,
              "Tid: 3 · 30 = 90 min = 1,5 h. Energi: 2 kW · 1,5 h = 3 kWh. Kostnad: 6 kr.", "energi",
              accept=["tre kilowattimmar och sex kronor"], wrong=["180 kWh", "6 000 kWh"]),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 6, "min_ca": 2}, {"grade": "A", "total": 8, "min_a": 1}],
    },
    {
        "id": "eng6-grammar", "subject": "Engelska", "grade": "Engelska 6", "title": "Test: Grammar and vocabulary",
        "tasks": [
            t(1, "Translate to English: 'Jag har bott här i tre år.'", 1, 0, 0, "I have lived here for three years.",
              "present perfect", accept=["I've been living here for three years"], wrong=["I live here since three years"]),
            t(2, "What is the past tense of 'to seek'?", 1, 0, 0, "Sought.", "irregular verbs", wrong=["seeked"]),
            t(3, "Choose the correct word: 'If I ___ rich, I would travel the world.' (was/were)", 1, 0, 0, "were",
              "conditionals", wrong=["will be"]),
            t(4, "Explain the difference between 'affect' and 'effect'.", 0, 2, 0,
              "'Affect' is usually a verb (to influence); 'effect' is usually a noun (the result).", "vocabulary",
              wrong=["they mean exactly the same"]),
            t(5, "Give a synonym for 'ubiquitous' and use it in a sentence.", 0, 1, 1,
              "Omnipresent / everywhere / widespread, e.g. 'Smartphones are ubiquitous today.'", "vocabulary",
              accept=["omnipresent", "everywhere", "widespread"], wrong=["rare", "unique"]),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 5, "min_ca": 2}, {"grade": "A", "total": 7, "min_a": 1}],
    },
    {
        "id": "sv1-sprakhistoria", "subject": "Svenska", "grade": "Svenska 1", "title": "Prov: Svensk språkhistoria",
        "tasks": [
            t(1, "Vad kallas skriftsystemet som användes i Norden på vikingatiden?", 1, 0, 0, "Runor (futharken).",
              "runsvenska", accept=["runalfabetet", "futhark"], wrong=["latin", "kilskrift"]),
            t(2, "Vilket språk lånade svenskan många ord från under Hansans tid?", 1, 0, 0, "Lågtyska.", "lånord",
              accept=["tyska", "medellågtyska"], wrong=["franska", "engelska"]),
            t(3, "Ge två exempel på franska lånord i svenskan.", 1, 0, 0, "T.ex. trottoar, paraply, fåtölj, byrå.",
              "lånord", accept=["paraply", "trottoar", "fåtölj", "byrå", "nivå", "ateljé"], wrong=["skräp", "dator"]),
            t(4, "Varför är Gustav Vasas bibel från 1541 viktig för svenskan?", 0, 2, 0,
              "Den blev en förebild för stavning och skriftspråk och spreds till kyrkor över hela landet, vilket gjorde "
              "skriftspråket mer enhetligt.", "nysvenska", accept=["den gjorde stavningen enhetlig"]),
            t(5, "Resonera om hur engelskan påverkar svenskan i dag. Ge för- och nackdelar.", 0, 1, 2,
              "Många lånord (t.ex. inom teknik och ungdomsspråk) gör språket rikare och underlättar internationell "
              "kontakt, men kan leda till domänförlust när svenska inte längre används inom vissa områden.",
              "engelska lånord", accept=["domänförlust"]),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 5, "min_ca": 2}, {"grade": "A", "total": 7, "min_a": 1}],
    },
    {
        "id": "ge-ak7-klimat", "subject": "Geografi", "grade": "åk 7", "title": "Prov: Klimat och vegetationszoner",
        "tasks": [
            t(1, "Vad är skillnaden mellan väder och klimat?", 1, 0, 0,
              "Väder är hur det är just nu eller några dagar; klimat är genomsnittet under lång tid (ungefär 30 år).",
              "väder och klimat"),
            t(2, "Vilken vegetationszon täcker större delen av Norrland?", 1, 0, 0, "Barrskogszonen (tajgan).",
              "vegetationszoner", accept=["tajga", "barrskog"], wrong=["tundra", "stäpp"]),
            t(3, "Varför är det varmare vid ekvatorn än vid polerna?", 1, 1, 0,
              "Solstrålarna träffar jorden mer rakt vid ekvatorn och värmer en mindre yta; vid polerna kommer de snett "
              "och sprids över en större yta.", "solinstrålning", wrong=["ekvatorn ligger närmare solen"]),
            t(4, "Vad kallas den varma havsström som gör Skandinaviens klimat mildare?", 1, 0, 0, "Golfströmmen.",
              "havsströmmar", accept=["Nordatlantiska driften"], wrong=["El Niño", "Humboldtströmmen"]),
            t(5, "Förklara varför det regnar mycket på västsidan av den skandinaviska fjällkedjan.", 0, 1, 2,
              "Fuktiga västvindar från Atlanten tvingas upp över fjällen, luften kyls, vattenångan kondenserar och det "
              "regnar på lovartsidan (orografisk nederbörd); på östsidan blir det regnskugga.", "nederbörd",
              accept=["orografisk nederbörd", "regnskugga"]),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 6, "min_ca": 2}, {"grade": "A", "total": 8, "min_a": 1}],
    },
    {
        "id": "sh1b-demokrati", "subject": "Samhällskunskap", "grade": "Samhällskunskap 1b", "title": "Prov: Demokrati och statsskick",
        "tasks": [
            t(1, "Hur många ledamöter har Sveriges riksdag?", 1, 0, 0, "349.", "riksdagen",
              accept=["trehundrafyrtionio"], wrong=["350", "349 plus talmannen"]),
            t(2, "Hur ofta är det ordinarie riksdagsval i Sverige?", 1, 0, 0, "Vart fjärde år.", "val",
              accept=["var fjärde år", "fjärde året"], wrong=["vart tredje år", "vart femte år"]),
            t(3, "Vilken spärr måste ett parti klara för att komma in i riksdagen?", 1, 0, 0,
              "4 procent av rösterna i hela landet (eller 12 procent i en valkrets).", "val",
              accept=["fyra procent", "fyraprocentsspärren"], wrong=["5 procent", "10 procent"]),
            t(4, "Förklara maktdelningen mellan riksdag, regering och domstolar.", 0, 2, 0,
              "Riksdagen stiftar lagar och kontrollerar regeringen, regeringen styr landet och verkställer besluten, "
              "domstolarna dömer enligt lagarna och är självständiga.", "maktdelning"),
            t(5, "Resonera om för- och nackdelar med direktdemokrati jämfört med representativ demokrati.", 0, 1, 2,
              "Direktdemokrati ger medborgarna direkt inflytande och legitimitet men är långsam, kräver mycket "
              "kunskap av alla och kan ge kortsiktiga beslut; representativ demokrati är effektivare men avståndet till "
              "väljarna blir större.", "demokratimodeller"),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 5, "min_ca": 2}, {"grade": "A", "total": 7, "min_a": 1}],
    },
    {
        "id": "re-ak8-varldsreligioner", "subject": "Religionskunskap", "grade": "åk 8", "title": "Prov: Världsreligionerna",
        "tasks": [
            t(1, "Vad heter islams heliga skrift?", 1, 0, 0, "Koranen.", "islam", accept=["Qur'an"], wrong=["Toran", "Vedaskrifterna"]),
            t(2, "Vad kallas judendomens vilodag och vilken dag börjar den?", 1, 0, 0,
              "Sabbaten (shabbat), som börjar vid solnedgången på fredagen.", "judendom",
              accept=["shabbat", "fredag kväll"], wrong=["söndag", "ramadan"]),
            t(3, "Vad betyder karma inom hinduism och buddhism?", 1, 1, 0,
              "Att handlingar får följder: goda handlingar ger goda följder och dåliga ger dåliga, även i kommande liv.",
              "karma", wrong=["ödet är bestämt av gudarna från början"]),
            t(4, "Nämn de fyra ädla sanningarna i buddhismen i korthet.", 0, 2, 0,
              "Livet innebär lidande; lidandet orsakas av begär; lidandet kan upphöra (nirvana); vägen dit är den "
              "åttafaldiga vägen.", "buddhism", accept=["den åttafaldiga vägen"]),
            t(5, "Jämför synen på livet efter döden i kristendomen och hinduismen.", 0, 1, 2,
              "Kristendomen: ett liv, sedan uppståndelse och dom (himmel/helvete). Hinduismen: återfödelse (samsara) "
              "styrd av karma tills själen (atman) befrias (moksha).", "liv efter döden",
              accept=["samsara", "moksha", "återfödelse"]),
        ],
        "boundaries": [{"grade": "E", "total": 3}, {"grade": "C", "total": 5, "min_ca": 2}, {"grade": "A", "total": 7, "min_a": 1}],
    },
]


def exam_text(e):
    lines = [f"{e['title']} – {e['subject']} {e['grade']}", ""]
    for task in e["tasks"]:
        p = task["points"]
        lines.append(f"{task['no']}. {task['text']} ({p['E']}/{p['C']}/{p['A']})")
    lines += ["", "FACIT OCH BEDÖMNINGSANVISNING"]
    for task in e["tasks"]:
        lines.append(f"{task['no']}. {task['answer']} {task['assessment']}")
    lines += ["", "Betygsgränser:"]
    for b in e["boundaries"]:
        extra = "".join(f", varav minst {b[k]} {'C/A' if k == 'min_ca' else 'A'}-poäng" for k in ("min_ca", "min_a") if k in b)
        lines.append(f"{b['grade']}: minst {b['total']} poäng{extra}")
    return "\n".join(lines)


def check(exams):
    errs = []
    if len(exams) != 10:
        errs.append(f"{len(exams)} prov, ska vara 10")
    ids = [e["id"] for e in exams]
    if len(set(ids)) != len(ids):
        errs.append("dubbla id")
    for e in exams:
        total = sum(sum(t["points"].values()) for t in e["tasks"])
        a_pts = sum(t["points"]["A"] for t in e["tasks"])
        for b in e["boundaries"]:
            if b["total"] > total:
                errs.append(f"{e['id']}: gräns {b['grade']} {b['total']} > maxpoäng {total}")
            if b.get("min_a", 0) > a_pts:
                errs.append(f"{e['id']}: min_a {b['min_a']} > A-poäng {a_pts}")
        for task in e["tasks"]:
            if not task["answer"] or not task["topic"]:
                errs.append(f"{e['id']} {task['no']}: facit eller topic saknas")
            if sum(task["points"].values()) == 0:
                errs.append(f"{e['id']} {task['no']}: 0 poäng")
            if len(task["text"]) > 3000 or len(task["answer"]) > 3000:
                errs.append(f"{e['id']} {task['no']}: över /exam-gränsen 3000")
        if len(exam_text(e)) > 40_000:
            errs.append(f"{e['id']}: exam_text över 40 000")
    return errs


def main():
    out = []
    for e in EXAMS:
        out.append({
            "id": e["id"], "subject": e["subject"], "grade": e["grade"], "title": e["title"],
            "source": "påhittat av Oscar (QA), ingen elevtext",
            "topic": M[e["id"]]["topic"],
            "material": {"pages": M[e["id"]]["pages"],
                         "formats": [{"format": f, "pages": i} for f, i in M[e["id"]]["formats"]],
                         "files": f"scripts/qa/repetition_bank/files/{e['id']}/ (make_files.py)"},
            "goals": [{"id": g, "goal": t, "keywords": k} for g, t, k in M[e["id"]]["goals"]],
            "outside": M[e["id"]]["outside"],
            "exam_text": exam_text(e),
            "key": {"tasks": e["tasks"], "boundaries": e["boundaries"],
                    "max": {k: sum(t["points"][k] for t in e["tasks"]) for k in "ECA"}},
        })
    errs = check(EXAMS)
    for e in EXAMS:
        m = M.get(e["id"])
        if not m:
            errs.append(f"{e['id']}: material saknas")
            continue
        text = " ".join(m["pages"]).lower()
        for g, _, kws in m["goals"]:
            for kw in kws:
                if kw.lower() not in text:
                    errs.append(f"{e['id']} {g}: nyckelordet '{kw}' står inte i materialet")
        used = sorted(i for _, idx in m["formats"] for i in idx)
        if used != list(range(len(m["pages"]))):
            errs.append(f"{e['id']}: formaten täcker inte varje sida exakt en gång")
        for o in m["outside"]:
            if o.lower() in text:
                errs.append(f"{e['id']}: 'utanför' {o} står i materialet")
    if errs:
        print("FEL:\n  " + "\n  ".join(errs))
        sys.exit(1)
    with open(os.path.join(HERE, "exams.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    n = sum(len(e["tasks"]) for e in EXAMS)
    print(f"OK: {len(out)} prov, {n} uppgifter, "
          f"{sum(len(t['wrong']) for e in EXAMS for t in e['tasks'])} felsvar, "
          f"{sum(len(t['accept']) for e in EXAMS for t in e['tasks'])} godtagbara varianter")


if __name__ == "__main__":
    main()
