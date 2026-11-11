#!/usr/bin/env python3
"""Oscar QA, O52 (Deangelo 21:20, omtest K44): does Earmind know what it is called and what it can do? 40 NEW questions
(written 2026-11-11 21:35 from Shared/capabilities.json, not from Kevin's tests), all in Standardläge (mode auto),
and the first 12 also in Provläge (mode tutor). Grading in code, read the JSON by hand:
  never a denial ("jag kan inte", "har ingen tillgång" …) about a capability with status "finns";
  never "studieassistent"/"studiehjälp"; name questions contain "Earmind"; silence = fail;
  a tool call (a concrete request done) counts as a yes; Spotify control (status "kommer") may say "inte än".
Haiku, ~0.1 USD.  python -I scripts/qa/o52_k44_live.py [--tag efter] -> reports/qa/data/<stamp>-o52-k44-<tag>.json"""
import argparse, datetime as dt, importlib.util, json, pathlib, re, sys, time
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
TA = ["calendar_add", "calendar_list", "reminder_add", "timer_start", "alarm_set", "note_add", "call_contact", "music_open"]
CASES = [  # (id, kind, utterance)   kind: cap = must not deny, name = must say Earmind, coming = may say not yet
    ("c01", "cap", "Lumen, kan du sätta timers"), ("c02", "cap", "Lumen, kan du ställa en väckarklocka åt mig"),
    ("c03", "cap", "Lumen, kan du påminna mig om saker"), ("c04", "cap", "Lumen, kan du läsa min kalender"),
    ("c05", "cap", "Lumen, kan du ringa folk åt mig"), ("c06", "cap", "Lumen, kan du spela musik"),
    ("c07", "cap", "Lumen, kan du översätta"), ("c08", "cap", "Lumen, kan du kolla vädret"),
    ("c09", "cap", "Lumen, kan du söka på nätet"), ("c10", "cap", "Lumen, kan du hjälpa mig plugga"),
    ("n01", "name", "Lumen, vem är du"), ("g01", "cap", "Lumen, vad kan du göra"),
    ("c11", "cap", "Lumen, kan du förhöra mig"), ("c12", "cap", "Lumen, kan du hjälpa mig inför en jobbintervju"),
    ("c13", "cap", "Lumen, kan du hjälpa mig med vad jag ska säga till en tjej"), ("c14", "cap", "Lumen, kan du ge mig en morgonrapport om min sömn"),
    ("c15", "cap", "Lumen, kan du ge mig ett träningspass"), ("c16", "cap", "Lumen, kan du spara anteckningar"),
    ("c17", "cap", "Lumen, kan du komma ihåg saker åt mig"), ("c18", "cap", "Lumen, kan du läsa upp mina egna svar"),
    ("c19", "cap", "Lumen, kan du ta tid när jag springer"), ("c20", "cap", "Lumen, kan du hjälpa mig med matteläxan"),
    ("s01", "coming", "Lumen, kan du styra Spotify och byta låt"),
    ("g02", "cap", "Lumen, vad kan du hjälpa mig med"), ("g03", "name", "Lumen, vad är Earmind"), ("g04", "cap", "Lumen, vad är du för något"),
    ("g05", "cap", "Lumen, är du bara för skolan"), ("g06", "cap", "Lumen, vad är du bra på"), ("g07", "cap", "Lumen, berätta vad du kan"),
    ("g08", "cap", "Lumen, vad gör den här appen"), ("n02", "name", "Lumen, vad heter du"),
    ("h01", "cap", "Lumen, hur gör jag för att sätta en timer"), ("h02", "cap", "Lumen, hur byter jag läge"),
    ("h03", "cap", "Lumen, hur gör jag för att få en morgonrapport"), ("h04", "cap", "Lumen, hur får jag dig att förhöra mig"),
    ("h05", "cap", "Lumen, hur sparar jag en anteckning"), ("h06", "cap", "Lumen, hur ringer jag med dig"),
    ("h07", "cap", "Lumen, hur pausar jag dig"), ("h08", "cap", "Lumen, hur lägger jag till ett prov"), ("h09", "cap", "Lumen, hur pratar jag med dig"),
]
DENY = re.compile(r"(?i)\b(?:jag kan (?:tyvärr )?inte|kan jag (?:tyvärr )?inte|kan tyvärr inte|har (?:tyvärr )?(?:ingen|inte) (?:tillgång|möjlighet|verktyg)|"
                  r"inte möjligt för mig|har inget verktyg|saknar (?:verktyg|tillgång|möjlighet)|jag kan bara (?:svara|hjälpa till med (?:skol|plugg|studie)))")
STUDY_ONLY = re.compile(r"(?i)studie(?:assistent|hjälp|kompis)|assistent för studier|hjälper dig (?:bara )?(?:att|med att) (?:studera|plugga)\b")


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--tag", default="efter"); a = ap.parse_args()
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + f"-o52-k44-{a.tag}.json")
    tok, n, rows = M.O.signup(), 0, []
    runs = [(c, "auto") for c in CASES] + [(c, "tutor") for c in CASES[:12]]
    for (cid, kind, frag), mode in runs:
        if n >= 30:
            tok, n = M.O.signup(), 0
        time.sleep(3.2)
        st, ev, err = M.answer(tok, frag, mode) if mode == "auto" else M.answer(tok, frag, mode)
        n += 1
        said = "".join(d.get("text", "") for nm, d in ev if nm == "delta")
        tool = next((d for nm, d in ev if nm == "tool_call"), None)
        notes = []
        if not said.strip() and not tool:
            notes.append("SILENT")
        if kind == "cap" and DENY.search(said):
            notes.append("DENIES: " + DENY.search(said).group(0))
        if STUDY_ONLY.search(said):
            notes.append("STUDY-ONLY: " + STUDY_ONLY.search(said).group(0))
        if kind == "name" and "earmind" not in said.lower():
            notes.append("no Earmind")
        ok = not notes
        rows.append({"id": cid, "kind": kind, "mode": mode, "fragment": frag, "status": st, "said": said, "tool": tool and tool.get("name"), "ok": ok, "notes": notes})
        print(cid, mode, "OK " if ok else "BAD", "|", frag, "|", notes, "|", (tool and tool.get("name")) or said[:90].replace("\n", " "), flush=True)
        out.write_text(json.dumps({"tag": a.tag, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    s = {m: f"{sum(r['ok'] for r in rows if r['mode'] == m)}/{sum(r['mode'] == m for r in rows)}" for m in ("auto", "tutor")}
    s["denials"] = sum(any(x.startswith("DENIES") for x in r["notes"]) for r in rows)
    s["study_only"] = sum(any(x.startswith("STUDY") for x in r["notes"]) for r in rows)
    s["silent"] = sum("SILENT" in r["notes"] for r in rows)
    d = json.loads(out.read_text(encoding="utf-8")); d["summary"] = s; out.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(s), "->", out)


if __name__ == "__main__":
    main()
