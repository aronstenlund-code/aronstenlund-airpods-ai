#!/usr/bin/env python3
"""K22 + K24 (Oscar O25: personal data removed in only 3/22, "jag vill hänga mig" and a surname were written to the
files): learn from real users every week WITHOUT ever writing a user's words to the public repo on its own.

1. Fetch the questions users chose to share (D57 opt-in: only users who turned on "Dela historik" upload anything to
   `shared_history`; turning it off deletes their rows). Only the question (`fragment`), the mode and the pseudonymous
   install id are read; never the answer, the summary or the user id.
2. Keep ONLY general knowledge questions. A row is dropped entirely (never "cleaned") when it has a first person, a
   person pronoun, a relation ("min kompis", "pappa", "vår lärare"), a first name, a person-like "X sa/frågade", a
   number, an address, an e-mail or link, a sensitive topic (health, sexuality, crime, drugs, violence, religion,
   politics) or any crisis sign (the same `answer/crisis.ts` as the app, through Node).
3. Group without a model (Jaccard >= 0.6 on stemmed words) and keep a group only when at least K_MIN different installs
   asked it.
4. Write the groups as CANDIDATES to the private table `real_user_candidates` (K38, Oscar O36: no longer an Actions
   artifact, which anyone signed in to GitHub can download from a public repo). A person decides per row on Aron's
   private page (backend/webtest/qa.html -> /functions/v1/real-users-admin) or Oscar through the Supabase MCP. Only the
   "approve" run of the workflow (`--approve-db`) moves approved rows to live-eval (scripts/real-user-cases.json) and
   the reality bank (scripts/real-user-bank.json), filtered once more, and then deletes them from the table. Cases
   older than 12 months are removed again.

  SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/real_users.py                       (weekly workflow -> the table)
  SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/real_users.py --approve-db ids.json (workflow "approve" run)
  python3 scripts/real_users.py --approve reviewed.json                             (a local file, after a review)
  python3 scripts/test_real_users.py   (invented data, no network, no model)"""
import argparse, datetime, json, os, pathlib, re, subprocess, sys, urllib.parse, urllib.request
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
K_MIN = 2
SIM = 0.6
RETENTION_DAYS = 365
CASES_FILE = ROOT / "scripts" / "real-user-cases.json"
BANK_FILE = ROOT / "scripts" / "real-user-bank.json"

# ---------------------------------------------------------------- personal data
FIRST_NAMES = set("""
adam albin aron alexander alice alva alma amanda anders andreas anna anton arvid astrid axel bella benjamin camilla
carl caroline casper cornelia daniel david ebba edvin elias elin ella ellen elliot elsa emil emilia emma erik
ester felicia felix filip frida gabriel hampus hanna hannes hedda hugo ida isak isabelle jakob jessica joel johan
johanna jonas jonathan josefin julia karin kevin klara lars leo liam lina linnea lisa liv loke love lovisa lucas
ludvig magnus maja malin malte maria markus martin matilda melvin meja mikael milo minna moa mohammed muhammad
nathalie nellie nicole nils noah nora olivia olle oscar otto per peter rasmus rebecka sara selma simon sofia stella
svea tilda tim tindra tove tyra valter vera viktor vilgot william wilma ylva zara saga sigge sixten theo theodor
wilhelm gustav ahmed fatima ali omar yusuf amir mohamed ibrahim hassan leila sara aisha noor maryam zainab hussein
kalle oskar gunilla eva birgitta karl lennart bengt kjell göran stefan thomas jan mats ulf håkan bo sven lars-erik
ingrid kerstin lena marie ulla monica annika helena susanne jenny linda sandra emelie therese ebbe arvid hjalmar
lukas jacob isac kim robin alex sam charlie mio idun majken juni signe stina agnes ines elvira nova lea leia
""".split())
# a first name followed by one of these is a historical or public person, not a private one ("Gustav Vasa")
PUBLIC_NEXT = re.compile(r"^(?:[IVX]+\b|den\b|vasa|adolf|af|von|de|van|II|III|eriksson\b)", re.I)

PII = [
    (re.compile(r"\S+@\S+\.\w+"), "[e-post]"),
    (re.compile(r"https?://\S+|www\.\S+"), "[länk]"),
    (re.compile(r"\b(?:19|20)?\d{6}[-+]?\d{4}\b"), "[personnummer]"),
    (re.compile(r"\+?\d[\d \-]{6,}\d"), "[nummer]"),
    (re.compile(r"\b\d{5,}\b"), "[nummer]"),
    (re.compile(r"\b[A-ZÅÄÖ][a-zåäö]+(?:gatan|vägen|gränd|torget|backen|stigen|allén) \d+\w?\b"), "[adress]"),
    (re.compile(r"\b[A-ZÅÄÖ][\wåäö-]*(?:skolan|gymnasiet)\b"), "[skola]"),
    (re.compile(r"(?i)\b(jag heter|mitt namn är|han heter|hon heter|hen heter)\s+\w+"), r"\1 [namn]"),
    (re.compile(r"(?i)\b(min|mina|mitt) (kompis|vän|bästis|mamma|pappa|syster|bror|lärare|mentor|tjej|kille|flickvän|pojkvän|granne) [A-ZÅÄÖ]\w+"), r"\1 \2 [namn]"),
]


def scrub(text: str) -> str:
    t = (text or "").strip()
    for rx, rep in PII:
        t = rx.sub(rep, t)
    words = t.split(" ")
    for i, w in enumerate(words):
        core = re.sub(r"[^\wåäöÅÄÖ]", "", w)
        if core.lower() in FIRST_NAMES and core[:1].isupper():
            nxt = words[i + 1] if i + 1 < len(words) else ""
            if not PUBLIC_NEXT.match(nxt) and not (nxt[:1].isupper() and len(nxt) > 2):
                words[i] = w.replace(core, "[namn]")
    return re.sub(r"\s+", " ", " ".join(words)).strip()


# K24: a row is kept only when it is a general knowledge question; everything else is dropped entirely
FIRST_PERSON = re.compile(r"(?<![\wåäö])(?:jag|ja|jaa|mig|mej|mitt|min|mina|vi|oss|vår|vårt|våra|själv)(?![\wåäö])", re.I)
PERSON_PRONOUN = re.compile(r"(?<![\wåäö])(?:han|hon|hen|honom|henne|hens|dom|dem|hans|hennes|deras)(?![\wåäö])", re.I)
RELATION = re.compile(
    r"(?<![\wåäö])(?:mamma|pappa|morsa|farsa|mor|far|kompis\w*|polare|vän(?:nen|ner)?|bästis|brorsa|bror|syster|syrra|"
    r"lärare(?:n)?|mentor(?:n)?|tjej(?:en)?|kille(?:n)?|flickvän\w*|pojkvän\w*|granne(?:n)?|mormor|morfar|farmor|farfar|"
    r"kusin\w*|moster|faster|morbror|farbror|chef(?:en)?|kollega\w*|klasskompis\w*|klassen|nian|åttan|sjuan|"
    r"partner|sambo|fru|man(?:nen)? min|barn(?:et|en)? mina)(?![\wåäö])", re.I)
PERSON_VERB = re.compile(r"(?<![\wåäö])[A-ZÅÄÖ][a-zåäö]+ (?:sa|sade|säger|frågade|frågar|skrev|tycker|tyckte|ska|har|är sjuk|i (?:min|vår|nian|åttan|sjuan|klassen))(?![\wåäö])")
NUMBERY = re.compile(r"\d{3,}|(?:(?:noll|ett|en|två|tre|fyra|fem|sex|sju|åtta|nio)\s+){4,}", re.I)
ADDRESS = re.compile(r"(?i)\w+(?:gatan|vägen|gränd|torget|backen|stigen|allén)\b|\S+@\S+|https?://|www\.|snabel-?a|\bat\b \w+ punkt|punkt (?:com|se|nu|org|net)\b")
# "det är Wilhelm här", "hej, Wilhelm här": a speaker who names themself
SELF_NAMED = re.compile(r"(?i)\bdet är [a-zåäö]+ (?:här|som (?:frågar|pratar))\b|^(?:hej[, ]+)?(?:lumen[, ]+)?[a-zåäö]+ här\b")
# "sex" as the number six is not the topic (Oscar O25: "vad är sex gånger åtta")
_NUM_NEXT = set("gånger plus minus delat komma år timmar minuter dagar veckor månader stycken st kronor procent av till och tusen hundra miljoner meter kilo liter sidor frågor".split())
_NUM_PREV = set("gånger plus minus med är delat och".split())


def without_six(t: str) -> str:
    w = t.split()
    for i, x in enumerate(w):
        core = re.sub(r"[^\wåäö]", "", x.lower())
        if core == "sex":
            nxt = re.sub(r"[^\wåäö]", "", w[i + 1].lower()) if i + 1 < len(w) else ""
            prv = re.sub(r"[^\wåäö]", "", w[i - 1].lower()) if i else ""
            if nxt in _NUM_NEXT or prv in _NUM_PREV:
                w[i] = "6"
    return " ".join(w)
SENSITIVE = re.compile(
    r"(?i)(?<![\wåäö])(?:självmord\w*|självskad\w*|ta livet av|deprimerad|depression|ångest|ätstörning\w*|anorexi|bulimi|"
    r"adhd|autism|sjukdom(?:en)?|cancer|hiv|gravid|abort|preventiv\w*|p-piller|sex|sexuell\w*|onani|porr\w*|naken\w*|"
    r"oskuld|gay|homo\w*|bisexuell|trans(?:person)?|lesbisk|queer|kön(?:sidentitet)?|religion|muslim|kristen|jude|ateist|"
    r"röstar|parti(?:et)? jag|valet jag|knark|droger|hasch|cannabis|kokain|snus|alkohol(?:ist)?|full|berusad|stjäl|stöld|"
    r"snatta\w*|polis(?:anmäl\w*)?|misshandl\w*|slår mig|våld\w*|hot(?:ad|ar|et)|mobb\w*|skilsmässa|skild|fängelse|dömd|"
    r"vapen|kniv(?:en)?|mörda\w*|dödsstraff)(?![\wåäö])")
# a public figure or a work may keep its capital ("Röda rummet", "Ungern"); a first name never does
PUBLIC_OK_AFTER = re.compile(r"^(?:[IVX]{1,5}|den|Vasa|Adolf|Bernadotte|Lindgren|Strindberg|Lagerlöf|Linné|Nobel|Celsius|Einstein|Newton|Darwin|Curie)$")

# K38 (Oscar O36): private facts without a first person. A school, a class, a code, a password or an appointment is
# about real people in the asker's life, never a knowledge question; a "Förnamn Efternamn" pair is a private person
# unless the surname is a well-known public one. Dropping a real knowledge question here costs only one candidate.
GENERIC_SCHOOL = set("grund hög för folk folkhög real lär flick pojk privat friskola gymnasie sär yrkes sommar musik kultur dans körs trafik språk rid sjuk "
                     "simm söndags fri förskole låg mellan hög stadie lekskola".split())
SCHOOL = re.compile(r"(?i)(?<![\wåäö])([\wåäö]*?)(skolan|skola|gymnasiet|gymnasium)(?![\wåäö])")
SCHOOL_NAMED = re.compile(r"(?<![\wåäö])[A-ZÅÄÖ][\wåäö]+s (?:gymnasium|gymnasiet|skola|skolan)(?![\wåäö])")
CLASS = re.compile(r"(?<![\wåäö\d])[1-9](?:[A-Fa-f]| [A-F])(?![\wåäö])(?!\s*[-+*/=^²³])|(?<![\wåäö])[PFpf]\d{2}(?![\wåäö\d])")
PRIVATE_THING = re.compile(
    r"(?i)(?<![\wåäö])(?:rektorn|\w*koden|koder till|kod till|lösen\w*|\w*lösenord\w*|wi-?fi\w*|skåp\w*|tandläkar\w*|läkartid\w*|"
    r"\w*tid hos|telefonnummr?\w*|numret till|adressen till|personnummer\w*)(?![\wåäö])")
PUBLIC_SURNAMES = set("""vasa adolf bernadotte lindgren strindberg lagerlöf linné nobel celsius einstein newton darwin curie
palme hitler napoleon bonaparte luther columbus galilei shakespeare mozart beethoven bach marx lenin stalin churchill
roosevelt kennedy lincoln washington king mandela gandhi freud tesla edison obama trump biden putin zelensky jobs gates
musk swift ibrahimović zlatan bergman garbo hammarskjöld wallenberg söderberg boye fröding tegnér runeberg bellman
taube jansson rowling tolkien orwell dickens austen hemingway picasso gogh vinci michelangelo rembrandt""".split())
PUBLIC_PAIRS = ("mona lisa", "anne frank", "pippi långstrump", "emil i lönneberga", "karl xii", "gustav ii adolf")
PLACE_FIRST = set("nya förenta svarta röda döda norra södra östra västra stilla saudi sri costa puerto san sankt el la los "
                  "new great kap".split())
# K38 (O36): method questions without "jag" that answer/crisis.ts (written for spoken crisis signs) lets through
METHOD = re.compile(
    r"(?i)(?<![\wåäö])(?:tablett\w*|piller|överdos\w*|dödlig dos|för att dö|dö av|döda sig|ta sitt liv|hur djupt|skära sig|skär sig|"
    r"skära upp|avskedsbr\w*|självmordsbr\w*|slutar? äta|sluta dricka|svält\w*|hänga sig|hängning|dränka sig|hoppa från|"
    r"strypa|kväva sig)(?![\wåäö])")


def private_school(text: str) -> bool:
    if SCHOOL_NAMED.search(text):
        return True
    for m in SCHOOL.finditer(text):
        pre = m.group(1).lower().rstrip("s")
        if len(pre) >= 3 and pre not in GENERIC_SCHOOL:
            return True
    return False


def full_name(text: str) -> bool:
    """Two capitalised words in a row ("Zlatko Jönsson", "Elvira Johansson") or a capitalised genitive of a first name
    ("Arons"): a private person unless the second word is a public surname or the pair is a place ("Nya Zeeland")."""
    words = re.findall(r"[\wåäöÅÄÖéü-]+", text)
    cap = lambda w: len(w) > 1 and w[0].isupper() and w[1:].islower()
    for i, w in enumerate(words):
        if cap(w) and w.endswith("s") and w[:-1].lower() in FIRST_NAMES:
            return True
        if i + 1 < len(words) and cap(w) and cap(words[i + 1]):
            if words[i + 1].lower() in PUBLIC_SURNAMES or w.lower() in PLACE_FIRST:
                continue
            return True
    return False


def crisis_levels(texts: list[str]) -> list[str | None]:
    """The app's own crisis filter (answer/crisis.ts) through Node; any failure = every row counts as a crisis row."""
    try:
        out = subprocess.run(["node", "--experimental-transform-types", "--no-warnings", str(ROOT / "scripts" / "crisis_levels.mjs")],
                             input=json.dumps(texts), capture_output=True, text=True, encoding="utf-8", timeout=60)
        levels = json.loads(out.stdout)
        if len(levels) == len(texts):
            return levels
    except Exception:
        pass
    return ["strong"] * len(texts)  # fail closed: nothing is kept


def has_first_name(text: str) -> bool:
    words = re.findall(r"[\wåäöÅÄÖ]+", text)
    for i, w in enumerate(words):
        if w.lower() in FIRST_NAMES:
            nxt = words[i + 1] if i + 1 < len(words) else ""
            if not PUBLIC_OK_AFTER.match(nxt) and nxt.lower() not in PUBLIC_SURNAMES:
                return True
    return False


def why_dropped(text: str, crisis: str | None = None) -> str | None:
    """None when the row is a general knowledge question that may be kept; else the reason (for the counts only)."""
    t = text or ""
    if crisis:
        return "crisis"
    for pair in PUBLIC_PAIRS:  # a famous work or person named like a private one ("Mona Lisa")
        t = re.sub(rf"(?i)\b{pair}\b", "verket", t)
    t_six = without_six(t)  # the number six is not the topic sex
    for name, rx, txt in (("first_person", FIRST_PERSON, t), ("person", PERSON_PRONOUN, t), ("relation", RELATION, t),
                          ("sensitive", SENSITIVE, t_six), ("number", NUMBERY, t), ("address", ADDRESS, t),
                          ("person_verb", PERSON_VERB, t), ("self_named", SELF_NAMED, t), ("method", METHOD, t),
                          ("private_thing", PRIVATE_THING, t), ("class", CLASS, t)):
        if rx.search(txt):
            return name
    if private_school(t):
        return "school"
    if has_first_name(t) or full_name(t):
        return "name"
    return None


def sensitive(text: str) -> bool:
    """K24: True = never kept (not a general knowledge question). Kept for Oscar's O25 test."""
    return why_dropped(text, crisis_levels([text])[0]) is not None


# ---------------------------------------------------------------- grouping
FILLER = set("lumen hej asså alltså typ liksom ba bara eh öh äh okej ok men nu då snälla tack kan du".split())


def stem(w: str) -> str:
    """A light Swedish stem: definite and plural endings off long words ("fotosyntesen" = "fotosyntes")."""
    for suf in ("arna", "erna", "orna", "en", "et", "na", "n"):
        if len(w) > 6 and w.endswith(suf):
            return w[: -len(suf)]
    return w


def norm(text: str) -> str:
    t = text.lower()
    t = re.sub(r"\[[^\]]+\]", " ", t)
    t = re.sub(r"\d+", "#", t)
    t = re.sub(r"[^\wåäö# ]", " ", t)
    return " ".join(stem(w) for w in t.split() if w not in FILLER)


WAKE = re.compile(r"^(?:(?:hej|okej|ok)\s+)?lumen[,!.]?\s+", re.I)


def clean_text(text: str) -> str:
    """The text that is stored: no wake word, no trailing fillers."""
    t = WAKE.sub("", text.strip())
    t = re.sub(r"(?i)\s+(?:asså|alltså|typ|liksom|tack|då)$", "", t)
    return t[:1].lower() + t[1:] if t[:2].istitle() and not t[:2].isupper() and t.split(" ")[0].lower() not in FIRST_NAMES else t


def jaccard(a: set, b: set) -> float:
    return len(a & b) / max(1, len(a | b))


def group(rows: list[dict]) -> list[dict]:
    """rows: {text, mode, install}. Greedy grouping on word overlap; most frequent groups first."""
    groups: list[dict] = []
    for r in rows:
        n = norm(r["text"])
        if len(n.split()) < 1:
            continue
        ws = set(n.split())
        best = None
        for g in groups:
            if g["mode"] == r["mode"] and jaccard(ws, g["words"]) >= SIM:
                best = g
                break
        if best is None:
            best = {"mode": r["mode"], "words": ws, "texts": Counter(), "installs": set()}
            groups.append(best)
        best["texts"][clean_text(r["text"])] += 1
        best["installs"].add(r["install"])
    out = []
    for g in groups:
        rep = g["texts"].most_common(1)[0][0]
        out.append({"text": rep, "mode": g["mode"], "count": sum(g["texts"].values()), "installs": len(g["installs"]),
                    "variants": len(g["texts"])})
    return sorted(out, key=lambda x: (-x["installs"], -x["count"], x["text"]))


# ---------------------------------------------------------------- outputs
def case_id(text: str, mode: str) -> str:
    import hashlib
    return "real-" + hashlib.sha256(f"{mode}|{norm(text)}".encode()).hexdigest()[:10]


def merge(existing: list[dict], groups: list[dict], today: str) -> list[dict]:
    """live-eval cases: new groups added (by id), counts updated, cases past the retention removed."""
    by_id = {c["id"]: c for c in existing}
    for g in groups:
        if g["installs"] < K_MIN:
            continue
        cid = case_id(g["text"], g["mode"])
        mode = {"fragor": "auto", "prov": "tutor"}.get(g["mode"], g["mode"])
        if cid in by_id:
            by_id[cid]["seen"] = by_id[cid].get("seen", 0) + g["count"]
            by_id[cid]["last"] = today
        else:
            by_id[cid] = {"id": cid, "cat": "verklighet", "source": "shared_history (D57 opt-in)", "added": today, "last": today,
                          "seen": g["count"], "installs": g["installs"],
                          "turns": [{"q": g["text"], "mode": mode, "expect": "either"}]}
    cutoff = (datetime.date.fromisoformat(today) - datetime.timedelta(days=RETENTION_DAYS)).isoformat()
    return sorted((c for c in by_id.values() if c.get("last", c.get("added", today)) >= cutoff), key=lambda c: c["id"])


def bank_of(cases: list[dict]) -> list[list]:
    """Oscar's O15 tuple: (id, group, mode, profile, text, expect, kw); group 7 = real users, mode fragor/prov."""
    out = []
    for c in cases:
        t = c["turns"][0]
        out.append([c["id"], 7, "prov" if t["mode"] == "tutor" else "fragor", None, t["q"], "either", ""])
    return out


# ---------------------------------------------------------------- fetching
def fetch(svc: str, days: int) -> list[dict]:
    since = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%SZ")
    q = urllib.parse.urlencode({"select": "fragment,mode,persona,install_id", "created_at": f"gte.{since}", "order": "created_at.asc", "limit": "5000"})
    req = urllib.request.Request(f"{URL}/rest/v1/shared_history?{q}", headers={"apikey": svc, "authorization": "Bearer " + svc})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())


def prepare(raw: list[dict]) -> tuple[list[dict], dict]:
    """raw shared_history rows -> general questions for grouping, plus counts per reason (nothing else is kept)."""
    rows, skipped = [], Counter()
    cand = []
    for r in raw:
        frag = (r.get("fragment") or "").strip()
        if not frag:
            skipped["empty"] += 1
        elif (r.get("persona") or "tutor") != "tutor":
            skipped["persona"] += 1  # Socialt/Rizz/Intervju: other people's words may be in it
        else:
            cand.append(r)
    levels = crisis_levels([(r.get("fragment") or "").strip() for r in cand])
    for r, lv in zip(cand, levels):
        frag = r["fragment"].strip()
        why = why_dropped(frag, lv)
        if why:
            skipped[why] += 1
            continue
        mode = "prov" if r.get("mode") == "tutor" else "fragor"
        rows.append({"text": scrub(frag)[:300], "mode": mode, "install": r.get("install_id") or "?"})
    return rows, dict(skipped)


def candidates(groups: list[dict], today: str) -> list[dict]:
    return [{"id": case_id(g["text"], g["mode"]), "q": g["text"], "mode": g["mode"], "installs": g["installs"], "count": g["count"],
             "date": today, "approved": False} for g in groups if g["installs"] >= K_MIN]


def run(raw: list[dict], today: str, cases_file=None, bank_file=None, dry=False, out_file=None) -> dict:
    """Tests only (invented data): the candidates go to out_file (a temporary file). The weekly run puts them in the
    private table instead (K38, main -> store); the repo files are written only by approve()."""
    rows, skipped = prepare(raw)
    groups = group(rows)
    cand = candidates(groups, today)
    target = out_file or cases_file
    if target and not dry:
        json.dump([{"id": c["id"], "turns": [{"q": c["q"], "mode": c["mode"]}], **c} for c in cand],
                  open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    if bank_file and not dry:
        json.dump([], open(bank_file, "w", encoding="utf-8"))
    return {"rows": len(raw), "kept": len(rows), "skipped": skipped, "groups": len(groups), "candidates": len(cand)}


def approve(reviewed: list[dict], today: str, cases_file=CASES_FILE, bank_file=BANK_FILE) -> dict:
    """After a person's review: only rows with "approved": true, checked again by the filter, go to the repo files."""
    ok = [c for c in reviewed if c.get("approved") is True]
    levels = crisis_levels([c.get("q") or c["turns"][0]["q"] for c in ok])
    groups = []
    for c, lv in zip(ok, levels):
        q = c.get("q") or c["turns"][0]["q"]
        if why_dropped(q, lv) is None:
            groups.append({"text": q, "mode": c.get("mode", "fragor"), "count": c.get("count", K_MIN), "installs": max(K_MIN, c.get("installs", K_MIN))})
    existing = json.load(open(cases_file, encoding="utf-8")) if pathlib.Path(cases_file).exists() else []
    cases = merge(existing, groups, today)
    json.dump(cases, open(cases_file, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(bank_of(cases), open(bank_file, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return {"approved": len(ok), "written": len(groups), "cases": len(cases)}


TABLE = "real_user_candidates"  # K38: service role only (RLS on, no client grants); never an artifact, never git


def rest(svc: str, method: str, path: str, body=None, prefer: str | None = None):
    h = {"apikey": svc, "authorization": "Bearer " + svc, "content-type": "application/json"}
    if prefer:
        h["prefer"] = prefer
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    with urllib.request.urlopen(urllib.request.Request(f"{URL}/rest/v1/{path}", data=data, method=method, headers=h), timeout=60) as r:
        raw = r.read()
    return json.loads(raw) if raw else None


def store(svc: str, cand: list[dict], today: str) -> int:
    """K38: the week's candidates go to the private table. A row that is already there (waiting, approved or rejected)
    is left as it is, so a rejected question is not offered again."""
    rows = [{"id": c["id"], "week": today, "q": c["q"][:300], "mode": c["mode"], "installs": c["installs"], "count": c["count"]} for c in cand]
    if rows:
        rest(svc, "POST", f"{TABLE}?on_conflict=id", rows, "resolution=ignore-duplicates,return=minimal")
    return len(rows)


def approve_db(svc: str, today: str, ids_file: pathlib.Path) -> dict:
    """K38: rows a person marked approved (Aron's page or Oscar via MCP) -> the repo files, filtered once more. The ids
    are written to ids_file so the workflow deletes them from the table only after the commit is pushed."""
    rows = rest(svc, "GET", f"{TABLE}?select=id,q,mode,installs,count&decision=eq.approved&limit=1000") or []
    s = approve([{**r, "approved": True} for r in rows], today)
    ids_file.write_text(json.dumps([r["id"] for r in rows]), encoding="utf-8")
    return s


def delete_ids(svc: str, ids: list[str]) -> int:
    ids = [i for i in ids if re.fullmatch(r"real-[0-9a-f]{10}", i)]
    if ids:
        rest(svc, "DELETE", f"{TABLE}?id=in.({','.join(ids)})", prefer="return=minimal")
    return len(ids)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--approve", help="a reviewed candidates file (local): rows with approved=true go to the repo files")
    ap.add_argument("--approve-db", metavar="IDS_FILE", help="K38: approved rows in the private table -> the repo files")
    ap.add_argument("--delete-ids", metavar="IDS_FILE", help="K38: delete these rows from the table (after the push)")
    a = ap.parse_args()
    today = datetime.date.today().isoformat()
    if a.approve:
        print(json.dumps(approve(json.load(open(a.approve, encoding="utf-8")), today)))
        return 0
    svc = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not svc:
        print("::warning::no SUPABASE_SERVICE_ROLE_KEY secret: skipped (owner: only after Oscar's approval of K38)")
        return 0
    print("::add-mask::" + svc)
    if a.approve_db:
        print(json.dumps(approve_db(svc, today, pathlib.Path(a.approve_db))))
        return 0
    if a.delete_ids:
        print(json.dumps({"deleted": delete_ids(svc, json.load(open(a.delete_ids, encoding="utf-8")))}))
        return 0
    rows, skipped = prepare(fetch(svc, a.days))
    groups = group(rows)
    cand = candidates(groups, today)
    stored = store(svc, cand, today)
    # numbers only: no user text in the log
    print(json.dumps({"kept": len(rows), "skipped": skipped, "groups": len(groups), "candidates": stored}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
