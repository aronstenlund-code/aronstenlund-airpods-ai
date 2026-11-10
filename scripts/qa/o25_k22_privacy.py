#!/usr/bin/env python3
"""Oscar QA, O25: independent offline test of Kevin's K22 privacy layer (scripts/real_users.py: scrub, sensitive,
prepare). The repo is public, so every shared question that survives scrub + k-anonymity ends up readable by anyone.
No network, no model, invented data only.
  python -I scripts/qa/o25_k22_privacy.py > reports/qa/data/<stamp>-o25-k22-privacy.json
pii:   [utterance, the private part that must NOT survive scrub()]
sens:  utterances that must be skipped entirely (crisis, health, sex life, religion, politics, crime, others' private life)
keep:  ordinary questions that must survive (no over-blocking), with a word that must still be there."""
import importlib.util, json, pathlib, sys, tempfile

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("real_users", ROOT / "scripts/real_users.py")
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)

PII = [
    ["min kompis Lisa Andersson sa att provet var svårt", "Andersson"],
    ["Lisa Andersson i nian sa att provet flyttas", "Lisa"],
    ["jag och elin ska plugga ikväll, vad är fotosyntes", "elin"],
    ["Ahmed och jag gör grupparbetet, hur skriver man en källhänvisning", "Ahmed"],
    ["Fatima frågade om läxan, vad betyder empati", "Fatima"],
    ["vår lärare Kalle sa att vi har prov på fredag", "Kalle"],
    ["min mamma heter Gunilla, hur stavar man det på engelska", "Gunilla"],
    ["Oskar i min klass sa att jorden är platt", "Oskar"],
    ["kan du ringa 070-123 45 67", "45 67"],
    ["mitt nummer är noll sju noll ett två tre fyra fem sex sju", "noll sju noll ett två tre fyra"],
    ["mitt personnummer är 090314-1234 behöver skolan det", "1234"],
    ["jag bor på storgatan 12 i Umeå, hur långt är det till skolan", "storgatan 12"],
    ["jag bor på Ringvägen i Hässleholm", "Ringvägen"],
    ["jag går på Kungsholmens gymnasium", "Kungsholmens"],
    ["jag går i 9B på vasaskolan", "vasaskolan"],
    ["följ mig på insta lisa_2009", "lisa_2009"],
    ["min snap är @elin.k09", "@elin.k09"],
    ["mejla aron punkt stenlund snabel-a icloud punkt com", "stenlund"],
    ["vår bil har registreringsnumret ABC 123", "ABC 123"],
    ["min bror Noel har feber", "Noel"],
    ["hej Lumen, det är Wilhelm här, vad är klockan", "Wilhelm"],
    ["Elvira Johansson har födelsedag idag, vad ska jag köpa", "Johansson"],
]
SENS = [
    "jag vill hänga mig", "jag rispar mig på armarna", "jag har skurit mig igen", "jag har sparat tabletter ifall jag inte orkar",
    "ingen skulle sakna mig om jag försvann", "jag har diabetes, får jag äta godis", "jag har epilepsi, får jag spela tv-spel",
    "är jag gay om jag gillar killar", "jag tror att jag är bi", "jag har klamydia, vad gör jag", "jag har fått mens för första gången",
    "pappa slår mig när han är full", "mina föräldrar ska skiljas", "jag har rökt hasch, märks det i blodet", "jag snattade på ICA igår",
    "min kompis tar kokain", "jag fastar under ramadan, hur orkar jag träningen", "jag är kär i min lärare", "min syster är gravid och sexton",
    "jag har ätit nästan ingenting på en vecka för att gå ner i vikt",
]
KEEP = [
    ["vad är sex gånger åtta", "sex"], ["vad betyder medicinsk", "medicinsk"], ["vem var Gustav Vasa", "Gustav"],
    ["när dog Karl XII", "Karl"], ["vad hände i andra världskriget", "världskriget"], ["vad är fotosyntes", "fotosyntes"],
    ["hur stavar man rytm", "rytm"], ["vad är huvudstaden i Ungern", "Ungern"], ["vem skrev Röda rummet", "Röda"],
    ["vad är skillnaden mellan diagnos och prognos i biologi", "prognos"],
]

pii = []
for t, secret in PII:
    s = R.scrub(t)
    leaked = secret.lower() in s.lower() and not R.sensitive(t)
    pii.append({"t": t, "scrubbed": s, "secret": secret, "skipped_as_sensitive": R.sensitive(t), "ok": not leaked})
sens = [{"t": t, "skipped": R.sensitive(t), "scrubbed_if_kept": None if R.sensitive(t) else R.scrub(t), "ok": R.sensitive(t)} for t in SENS]
keep = [{"t": t, "skipped": R.sensitive(t), "scrubbed": R.scrub(t), "ok": not R.sensitive(t) and w.lower() in R.scrub(t).lower()} for t, w in KEEP]

# end to end: the same private sentence from two installs passes k-anonymity, so it would be written to the public repo
raw = [{"fragment": PII[0][0], "mode": "auto", "persona": "tutor", "install_id": "a"},
       {"fragment": PII[0][0], "mode": "auto", "persona": "tutor", "install_id": "b"},
       {"fragment": SENS[0], "mode": "auto", "persona": "tutor", "install_id": "a"},
       {"fragment": SENS[0], "mode": "auto", "persona": "tutor", "install_id": "b"}]
with tempfile.TemporaryDirectory() as d:
    cf, bf = pathlib.Path(d) / "c.json", pathlib.Path(d) / "b.json"
    summ = R.run(raw, "2026-11-10", cases_file=cf, bank_file=bf)
    written = [c["turns"][0]["q"] for c in json.loads(cf.read_text(encoding="utf-8"))]

s = lambda a: f"{sum(x['ok'] for x in a)}/{len(a)}"
print(json.dumps({"pii_removed": s(pii), "sensitive_skipped": s(sens), "ordinary_kept": s(keep), "e2e_summary": summ, "e2e_written": written,
                  "fails": [x for x in pii + sens + keep if not x["ok"]], "pii": pii, "sens": sens, "keep": keep}, ensure_ascii=False, indent=1))
