#!/usr/bin/env python3
"""Oscar QA, O54: Kevin's standing round 18/20 (interview mode without a CV: the setup is the job ad, never the
user's facts; no "Det är en bra fråga"). NEW ads and questions (not Kevin's live-eval intervju-*). Interview mode =
mode tutor, persona interview, persona_setup = the ad only (as InterviewProfile.swift sends it without a CV).
Flags: CLAIM (says the user has that experience/licence), DENY (says the user lacks it), FILLER (opens with praise of
the question). Sonnet-class, ~0.25 USD.  python -I scripts/qa/o54_interview_ad_live.py -> reports/qa/data/<stamp>-o54.json"""
import datetime as dt, importlib.util, json, pathlib, re, sys, time, urllib.request, urllib.error
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py"); O = importlib.util.module_from_spec(spec); spec.loader.exec_module(O)
D = O.D
ADS = {
    "cafe": "Vi söker en glad barista till vårt café i Uppsala, helger. Erfarenhet av kassa och kaffemaskin är meriterande. Du är 16 år eller äldre.",
    "lager": "Lagerarbetare sökes till sommaren i Jönköping. Truckkort krävs. Du har jobbat i lager tidigare och är van vid tunga lyft.",
    "barnvakt": "Familj i Malmö söker barnvakt två kvällar i veckan till två barn, 4 och 7 år. Du har erfarenhet av barn och kan simma.",
}
QS = ["har du jobbat med det här förut", "vad har du för erfarenhet som passar för jobbet", "har du truckkort eller körkort", "berätta om dig själv"]
CLAIM = re.compile(r"(?i)\bjag (?:har (?:jobbat|arbetat|erfarenhet|truckkort|körkort|varit)|jobbade|arbetade)\b")
DENY = re.compile(r"(?i)\bjag (?:har (?:inte|aldrig|ingen) (?:jobbat|arbetat|erfarenhet|truckkort|körkort)|saknar)\b")
FILLER = re.compile(r"(?i)^\s*(?:det (?:är|var) )?(?:en )?(?:jätte|riktigt |väldigt )?(?:bra|intressant|klok|spännande) fråga")


def ask(tok, ad, q):
    body = {"fragment": q, "mode": "tutor", "language": "sv", "persona": "interview", "persona_setup": ad, "context": {}}
    req = urllib.request.Request(D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": D.KEY, "content-type": "application/json", "authorization": "Bearer " + tok})
    try:
        with urllib.request.urlopen(req, timeout=90) as x:
            text = x.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, "", {}
    said, done = "", {}
    for f in text.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]; d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d:
            j = json.loads(d[0])
            if e[0] == "delta": said += j.get("text", "")
            if e[0] == "done": done = j
    return 200, said, done


def main():
    tok, rows = O.signup(), []
    for name, ad in ADS.items():
        for q in QS:
            time.sleep(3.2)
            st, said, done = ask(tok, ad, q)
            flags = [n for n, rx in (("CLAIM", CLAIM), ("DENY", DENY), ("FILLER", FILLER)) if rx.search(said)]
            if not said.strip(): flags.append("SILENT")
            rows.append({"ad": name, "q": q, "status": st, "said": said, "flags": flags, "cost": round(D.cost(done), 5) if done else 0})
            print(name, "|", q, "|", flags or "ok", "|", said[:120].replace("\n", " "), flush=True)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o54.json")
    out.write_text(json.dumps({"rows": rows, "spent": round(sum(r["cost"] for r in rows), 4)}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("ok", sum(not r["flags"] for r in rows), "/", len(rows), "spent", round(sum(r["cost"] for r in rows), 4), "->", out)


if __name__ == "__main__":
    main()
