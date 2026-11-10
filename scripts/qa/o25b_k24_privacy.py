#!/usr/bin/env python3
"""Oscar QA, O25b: independent retest of Kevin's K24 (scripts/real_users.py prepare: only general knowledge questions
survive, everything personal is dropped whole) with NEW invented rows (none in o25_k22_privacy.py or
test_real_users.py): private facts without a first person (names, gossip, schools, addresses, other people's health),
crisis and method questions without "jag", and ordinary questions that must survive. No network, no model.
  python -I scripts/qa/o25b_k24_privacy.py > reports/qa/data/<stamp>-o25b-k24.json"""
import importlib.util, json, pathlib, sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("real_users", ROOT / "scripts/real_users.py")
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)

DROP = [  # must never become a candidate
    "när fyller Elvira Johansson år", "vad heter rektorn på Vasaskolan", "när slutar 9B på Rinkebyskolan idag",
    "vem är Zlatko Jönsson", "är Lisa i 8C kär i Ahmed", "var bor Kalle Svensson", "vad är telefonnumret till Ahmed",
    "har Fatima diabetes", "röstade Ali på SD", "vad kostar ett hus på Storgatan 12 i Umeå", "vilken religion har familjen Nilsson",
    "spelar Noah i Djurgårdens P14", "varför är Linnea så sur på Moa", "hur många tabletter behövs för att dö",
    "hur djupt måste man skära", "vad händer om man slutar äta helt", "hur skriver man ett avskedsbrev till familjen",
    "vad är koden till skåpet på Polhemskolan", "vem har Wifi-lösenordet på Kungsholmens gymnasium", "när är Arons tandläkartid",
    "kan man se om någon är gravid", "vad ska man säga till en kompis som skär sig",
]
KEEP = [  # general knowledge, must survive
    "vad är fotosyntes", "när började första världskriget", "hur räknar man ut arean av en cirkel", "vad betyder ironi",
    "vem skrev Hamlet", "vad är skillnaden mellan väder och klimat", "hur många ben har en spindel", "vad är en metafor",
    "när dog Gustav Vasa", "vad är pi", "hur fungerar ett vaccin", "vad är huvudstaden i Kanada",
]


def kept(t):
    rows, _ = R.prepare([{"fragment": t, "mode": "auto", "persona": "tutor", "install_id": "x"}])
    return bool(rows)


drop = [{"t": t, "kept": kept(t), "ok": not kept(t)} for t in DROP]
keep = [{"t": t, "kept": kept(t), "ok": kept(t)} for t in KEEP]
s = lambda a: f"{sum(x['ok'] for x in a)}/{len(a)}"
print(json.dumps({"private_dropped": s(drop), "general_kept": s(keep), "fails": [x for x in drop + keep if not x["ok"]], "drop": drop, "keep": keep},
                 ensure_ascii=False, indent=1))
