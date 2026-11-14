"""A96/K60: the shared fixture for the ChatGPT import (Kevin's `drill/import_text.ts` and the app's `ChatGPTImport`).
Builds `o58-cases.json` from Oscar's 20 variants (`scripts/qa/o58_import.py`, O58) with the expected result per item:
question (with "?"), short = the first sentence, long = the whole answer word for word (line breaks and blank lines
inside the answer become single spaces). Both sides' tests read this file, so they give the same result.
  python -I -X utf8 testdata/import/make_cases.py"""
import importlib.util, json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o58", ROOT / "scripts/qa/o58_import.py")
o58 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(o58)


def one_line(text):
    return " ".join(text.split())


cases = []
for v in o58.variants():
    items = []
    for q, a in v["pairs"]:
        q = one_line(q)
        a = one_line(a)
        items.append({"question": q if q[-1] in "?.!" else q + "?", "short": o58.first_sentence(a), "long": a})
    cases.append({"name": v["name"], "note": v["note"], "text": v["text"], "status": v["status"], "items": items})

out = pathlib.Path(__file__).with_name("o58-cases.json")
out.write_text(json.dumps(cases, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(len(cases), "cases ->", out)
