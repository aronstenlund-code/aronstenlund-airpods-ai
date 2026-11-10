#!/usr/bin/env python3
"""K22 (backlog "Lär av riktiga användare", Aron 2026-11-10): learn from real users, every week, without a model call.

1. Fetch the questions users chose to share (D57 opt-in: only users who turned on "Dela historik" upload anything
   to `shared_history`; turning it off deletes their rows). Only the question (`fragment`), the mode and the
   pseudonymous install id are read; never the answer, the summary or the user id.
2. Remove personal data: e-mail, phone and personal numbers, addresses, links, long digit strings, first names in
   personal contexts and common Swedish first names, school names. Rows about sensitive things (crisis, health,
   own religion, politics or sexuality, other people's private lives) are skipped entirely.
3. Group them without a model: normalise (wake word, filler words, digits), then greedy grouping on word overlap
   (Jaccard >= 0.6). A group is kept only when at least K_MIN different installs asked it (k-anonymity: a question
   only one person asked never enters the repo).
4. Add the groups to live-eval (scripts/real-user-cases.json, read by scripts/live-eval.py) and to the reality bank
   (scripts/real-user-bank.json, Oscar's O15 format: id, group 7, mode, profile, text, expect, kw), with the date.
   Cases older than 12 months are removed again (the same retention as D57's table).

  SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/real_users.py [--days 7] [--dry-run]
  python3 scripts/test_real_users.py   (fake data, no network, no model)"""
import argparse, datetime, json, os, pathlib, re, sys, urllib.parse, urllib.request
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
adam albin alexander alice alva alma amanda anders andreas anna anton arvid astrid axel bella benjamin camilla
carl caroline casper cornelia daniel david ebba edvin elias elin ella ellen elliot elsa emil emilia emma erik
ester felicia felix filip frida gabriel hampus hanna hannes hedda hugo ida isak isabelle jakob jessica joel johan
johanna jonas jonathan josefin julia karin kevin klara lars leo liam lina linnea lisa liv loke love lovisa lucas
ludvig magnus maja malin malte maria markus martin matilda melvin meja mikael milo minna moa mohammed muhammad
nathalie nellie nicole nils noah nora olivia olle oscar otto per peter rasmus rebecka sara selma simon sofia stella
svea tilda tim tindra tove tyra valter vera viktor vilgot william wilma ylva zara saga sigge sixten theo theodor
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


# rows that are never kept (even scrubbed): crisis, health, own beliefs and private life (GDPR special categories)
SENSITIVE = re.compile(
    r"(?i)\b(?:orkar inte leva|vill (?:inte leva|dö)|ta livet av|självmord\w*|självskad\w*|skär mig|skada mig själv|"
    r"deprimerad|depression|ångest|ätstörning|anorexi|adhd|autism|diagnos|medicin(?:er)?|psykolog|kurator|"
    r"gravid|abort|sex|naken|nakenbild|jag är (?:gay|homo|bi|trans|lesbisk|muslim|kristen|jude|ateist)|"
    r"min (?:religion|tro)|jag röstar|partiet jag|misshandl\w*|polisanmäl\w*|skild|skilsmässa|mobbad|mobbar)\b"
)


def sensitive(text: str) -> bool:
    return bool(SENSITIVE.search(text or ""))


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
    """raw shared_history rows -> scrubbed rows for grouping, plus counts (nothing else is kept)."""
    rows, skipped = [], Counter()
    for r in raw:
        frag = (r.get("fragment") or "").strip()
        if not frag:
            skipped["empty"] += 1
            continue
        if (r.get("persona") or "tutor") != "tutor":
            skipped["persona"] += 1  # Socialt/Rizz/Intervju: other people's words may be in it
            continue
        if sensitive(frag):
            skipped["sensitive"] += 1
            continue
        t = scrub(frag)[:300]
        mode = "prov" if r.get("mode") == "tutor" else "fragor"
        rows.append({"text": t, "mode": mode, "install": r.get("install_id") or "?"})
    return rows, dict(skipped)


def run(raw: list[dict], today: str, cases_file=CASES_FILE, bank_file=BANK_FILE, dry=False) -> dict:
    rows, skipped = prepare(raw)
    groups = group(rows)
    existing = json.load(open(cases_file, encoding="utf-8")) if pathlib.Path(cases_file).exists() else []
    cases = merge(existing, groups, today)
    if not dry:
        json.dump(cases, open(cases_file, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        json.dump(bank_of(cases), open(bank_file, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return {"rows": len(raw), "kept": len(rows), "skipped": skipped, "groups": len(groups),
            "groups_k": sum(g["installs"] >= K_MIN for g in groups), "cases": len(cases)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    svc = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not svc:
        print("::warning::no SUPABASE_SERVICE_ROLE_KEY secret: skipped (owner: GitHub > Settings > Secrets > Actions)")
        return 0
    print("::add-mask::" + svc)
    s = run(fetch(svc, a.days), datetime.date.today().isoformat(), dry=a.dry_run)
    print(json.dumps(s))  # numbers only: no user text in the log
    return 0


if __name__ == "__main__":
    sys.exit(main())
