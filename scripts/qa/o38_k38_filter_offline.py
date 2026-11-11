#!/usr/bin/env python3
"""Oscar QA, O38: NEW independent rows for K38's extra K22 filters (scripts/real_users.py prepare), none in
o25_k22_privacy.py, o25b_k24_privacy.py or test_real_users.py. DROP = private or crisis rows that must never become
a candidate (class/school/person written differently, method questions with brand names or compounds); KEEP = general
knowledge questions that should survive (a false drop only costs one candidate, a leak puts a row in front of a human
reviewer and, if missed, in the public repo). No network, no model.
  python -I scripts/qa/o38_k38_filter_offline.py > reports/qa/data/<stamp>-o38-filter.json"""
import importlib.util, json, pathlib, sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("real_users", ROOT / "scripts/real_users.py")
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)

DROP = [
    # classes and schools written another way
    "vad heter mattläraren i sjuan", "när har nian idrott på fredag", "vem är mentor för åtta b", "när är föräldramötet för 7B",
    "vad heter killen som går på Ekbackens skola", "när går bussen från Hagaskolan", "hur mycket väger Mohammed i 9c",
    # private things and people
    "vad är pinkoden till mammas kort", "vad är portkoden på Storgatan 5", "vad är adressen till Lucas",
    "vem gjorde slut med Ebba igår", "vad gav läraren för betyg till Hugo", "vad är Ahmeds snapchat",
    "är Bergströms i 9C skilda", "vem i klassen är gay", "var bor läraren som heter Sara", "vad har Wilma för nummer",
    "vilken vikarie har vi i svenska imorgon",
    # crisis and method questions without "jag", with brand names and compounds
    "vad händer om man tar tio alvedon", "hur mycket paracetamol är farligt", "hur får man tag i sömntabletter utan recept",
    "vilken höjd måste man hoppa från för att dö", "vad är det snabbaste sättet att försvinna för alltid",
    "hur länge tar det att svälta ihjäl", "vilka mediciner är dödliga ihop", "hur gör man en snara",
]
KEEP = [
    "vad är skolplikt", "vad betyder folkhögskola", "vad är skillnaden mellan friskola och kommunal skola",
    "vem var Ingvar Kamprad", "vem var Greta Garbo", "vad är Röda korset", "vem var Karl den store", "vad är Atens skola",
    "vad är frankfurtskolan", "vad är den genetiska koden", "hur skapar man ett säkert lösenord", "vad är en överdos",
    "vad är Pythagoras sats", "vad hände i Sankt Petersburg 1917", "vem var Julius Caesar", "vad är Svarta döden",
    "hur många tabletter finns i en Alvedon-förpackning", "vad är en metafor i en dikt", "vad är Big Bang",
    "vem skrev Röda rummet",
]


def why(t):
    rows, _ = R.prepare([{"fragment": t, "mode": "auto", "persona": "tutor", "install_id": "x"}])
    if rows:
        return None
    r = getattr(R, "why_dropped", None)
    return (r(t) if r else "dropped") or "dropped"


drop = [{"t": t, "why": why(t)} for t in DROP]
keep = [{"t": t, "why": why(t)} for t in KEEP]
for x in drop:
    x["ok"] = x["why"] is not None
for x in keep:
    x["ok"] = x["why"] is None
s = lambda a: f"{sum(x['ok'] for x in a)}/{len(a)}"
print(json.dumps({"private_dropped": s(drop), "general_kept": s(keep), "leaks": [x["t"] for x in drop if not x["ok"]],
                  "false_drops": [[x["t"], x["why"]] for x in keep if not x["ok"]], "drop": drop, "keep": keep}, ensure_ascii=False, indent=1))
