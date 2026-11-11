#!/usr/bin/env python3
"""K22 + K24 tests with invented data only (no network, no model; Node runs answer/crisis.ts).
  python3 scripts/test_real_users.py"""
import importlib.util, json, pathlib, subprocess, sys, tempfile, unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("ru", ROOT / "scripts/real_users.py")
RU = importlib.util.module_from_spec(spec)
spec.loader.exec_module(RU)

FAKE = [  # invented shared_history rows
    {"fragment": "Lumen vad är fotosyntes", "mode": "tutor", "persona": "tutor", "install_id": "inst-a"},
    {"fragment": "vad är fotosyntes asså", "mode": "tutor", "persona": "tutor", "install_id": "inst-b"},
    {"fragment": "vad är fotosyntesen", "mode": "tutor", "persona": "tutor", "install_id": "inst-c"},
    {"fragment": "hur räknar man ut procent", "mode": "auto", "persona": "tutor", "install_id": "inst-a"},
    {"fragment": "hur räknar man procent", "mode": "push_to_talk", "persona": "tutor", "install_id": "inst-d"},
    {"fragment": "när dog Karl XII", "mode": "auto", "persona": "tutor", "install_id": "inst-k"},
    {"fragment": "när dog Karl XII", "mode": "auto", "persona": "tutor", "install_id": "inst-l"},
    # never kept, whatever the count
    {"fragment": "jag heter Elin, vad är en atom", "mode": "auto", "persona": "tutor", "install_id": "inst-e"},
    {"fragment": "jag heter Elin, vad är en atom", "mode": "auto", "persona": "tutor", "install_id": "inst-f"},
    {"fragment": "jag vill hänga mig", "mode": "auto", "persona": "tutor", "install_id": "inst-g"},
    {"fragment": "jag vill hänga mig", "mode": "auto", "persona": "tutor", "install_id": "inst-h"},
    {"fragment": "min kompis Hugo sa att jorden är platt", "mode": "auto", "persona": "tutor", "install_id": "inst-m"},
    {"fragment": "min kompis Hugo sa att jorden är platt", "mode": "auto", "persona": "tutor", "install_id": "inst-n"},
    {"fragment": "hur mycket alkohol tål man", "mode": "auto", "persona": "tutor", "install_id": "inst-o"},
    {"fragment": "hur mycket alkohol tål man", "mode": "auto", "persona": "tutor", "install_id": "inst-p"},
    {"fragment": "vad ska jag säga till henne", "mode": "tutor", "persona": "social", "install_id": "inst-j"},
    {"fragment": "", "mode": "auto", "persona": "tutor", "install_id": "inst-q"},
]


class T(unittest.TestCase):
    def test_only_general_questions_are_kept(self):
        rows, skipped = RU.prepare(FAKE)
        kept = " | ".join(r["text"] for r in rows)
        for bad in ("Elin", "hänga", "Hugo", "alkohol", "henne"):
            self.assertNotIn(bad, kept)
        self.assertGreaterEqual(skipped.get("first_person", 0) + skipped.get("crisis", 0), 4)
        self.assertEqual(skipped.get("persona"), 1)
        self.assertEqual(skipped.get("empty"), 1)
        self.assertIn("Karl XII", kept)

    def test_the_weekly_run_writes_candidates_only_never_the_repo_files(self):
        with tempfile.TemporaryDirectory() as d:
            out = pathlib.Path(d) / "candidates.json"
            before = {f: (ROOT / "scripts" / f).exists() for f in ("real-user-cases.json", "real-user-bank.json")}
            s = RU.run(FAKE, "2026-11-10", out_file=out)
            after = {f: (ROOT / "scripts" / f).exists() for f in ("real-user-cases.json", "real-user-bank.json")}
            self.assertEqual(before, after, "the repo files are untouched")
            cand = json.load(open(out, encoding="utf-8"))
            qs = [c["q"] for c in cand]
            self.assertEqual(len(cand), s["candidates"])
            self.assertTrue(any("fotosyntes" in q for q in qs))
            self.assertTrue(all(c["approved"] is False for c in cand))
            self.assertFalse(any("hänga" in q or "Elin" in q or "Hugo" in q for q in qs))

    def test_only_approved_rows_reach_the_repo_files_and_old_ones_go(self):
        with tempfile.TemporaryDirectory() as d:
            cf, bf, out = pathlib.Path(d) / "c.json", pathlib.Path(d) / "b.json", pathlib.Path(d) / "cand.json"
            RU.run(FAKE, "2026-11-10", out_file=out)
            cand = json.load(open(out, encoding="utf-8"))
            for c in cand:
                c["approved"] = "fotosyntes" in c["q"]
            cand.append({"q": "jag vill hänga mig", "mode": "fragor", "installs": 2, "approved": True})  # a reviewer's slip
            r = RU.approve(cand, "2026-11-10", cf, bf)
            cases = json.load(open(cf, encoding="utf-8"))
            self.assertEqual(r["written"], 1, "the slip is stopped by the filter again")
            self.assertEqual([c["turns"][0]["q"] for c in cases], ["vad är fotosyntes"])
            self.assertEqual(json.load(open(bf, encoding="utf-8"))[0][1], 7)
            RU.approve([], "2027-11-18", cf, bf)
            self.assertEqual(json.load(open(cf, encoding="utf-8")), [], "12-month retention")

    def test_k38_candidates_go_to_the_private_table_and_approved_rows_leave_it(self):
        calls = []

        def fake_rest(svc, method, path, body=None, prefer=None):
            calls.append((method, path, body, prefer))
            if method == "GET":
                return [{"id": "real-0123456789", "q": "vad är fotosyntes", "mode": "prov", "installs": 3, "count": 4},
                        {"id": "real-0123456780", "q": "jag vill hänga mig", "mode": "fragor", "installs": 2, "count": 2}]
            return None

        real = RU.rest
        RU.rest = fake_rest
        try:
            rows, _ = RU.prepare(FAKE)
            cand = RU.candidates(RU.group(rows), "2026-11-16")
            n = RU.store("svc", cand, "2026-11-16")
            m, path, body, prefer = calls[0]
            self.assertEqual((m, path, prefer), ("POST", "real_user_candidates?on_conflict=id", "resolution=ignore-duplicates,return=minimal"))
            self.assertEqual(n, len(body))
            self.assertEqual(set(body[0]), {"id", "week", "q", "mode", "installs", "count"}, "no install id, no user id, no decision")
            self.assertFalse(any("hänga" in b["q"] or "Elin" in b["q"] for b in body))
            with tempfile.TemporaryDirectory() as d:
                ids = pathlib.Path(d) / "ids.json"
                cf, bf = pathlib.Path(d) / "c.json", pathlib.Path(d) / "b.json"
                real_approve = RU.approve
                RU.approve = lambda rev, today: real_approve(rev, today, cf, bf)
                try:
                    s = RU.approve_db("svc", "2026-11-16", ids)
                finally:
                    RU.approve = real_approve
                self.assertEqual(calls[1][1], "real_user_candidates?select=id,q,mode,installs,count&decision=eq.approved&limit=1000")
                self.assertEqual(s["written"], 1, "a slipped crisis row is stopped by the filter again")
                self.assertEqual([c["turns"][0]["q"] for c in json.load(open(cf, encoding="utf-8"))], ["vad är fotosyntes"])
                self.assertEqual(json.load(open(ids, encoding="utf-8")), ["real-0123456789", "real-0123456780"])
            self.assertEqual(RU.delete_ids("svc", ["real-0123456789", "x),id.neq.(0"]), 1)
            self.assertEqual(calls[-1][:2], ("DELETE", "real_user_candidates?id=in.(real-0123456789)"))
        finally:
            RU.rest = real

    def test_k38_oscar_o36_private_facts_and_method_questions(self):
        drop = ["vad heter rektorn på Vasaskolan", "när slutar 9B på Rinkebyskolan idag", "vem är Zlatko Jönsson",
                "vad är koden till skåpet på Polhemskolan", "vem har Wifi-lösenordet på Kungsholmens gymnasium",
                "när är Arons tandläkartid", "hur många tabletter behövs för att dö", "hur djupt måste man skära",
                "vad händer om man slutar äta helt", "hur skriver man ett avskedsbrev till familjen"]
        keep = ["vad är skillnaden mellan grundskolan och gymnasiet", "när infördes allmän folkskola", "hur löser man 2a + 3 = 9",
                "vem var Olof Palme", "var ligger Nya Zeeland", "vem målade Mona Lisa", "vem var Martin Luther King",
                "vad gör en rektor", "varför har man läxor i skolan", "när dog Gustav Vasa"]
        lv = RU.crisis_levels(drop + keep)
        self.assertEqual([t for t, l in zip(drop, lv[:len(drop)]) if RU.why_dropped(t, l) is None], [])
        self.assertEqual([t for t, l in zip(keep, lv[len(drop):]) if RU.why_dropped(t, l) is not None], [])

    def test_k38_oscar_o38(self):
        drop = ["vad händer om man tar tio alvedon", "hur får man tag i sömntabletter utan recept", "vad är portkoden till skolan",
                "vad är lösenordet till wifi", "vad är en överdos"]
        keep = ["vem var Ingvar Kamprad", "vem var Julius Caesar", "vad är Big Bang", "vad var Atens skola", "vad är frankfurtskolan",
                "vad är den genetiska koden", "hur skapar man ett säkert lösenord"]
        lv = RU.crisis_levels(drop + keep)
        self.assertEqual([t for t, l in zip(drop, lv[:len(drop)]) if RU.why_dropped(t, l) is None], [])
        self.assertEqual([(t, RU.why_dropped(t, l)) for t, l in zip(keep, lv[len(drop):]) if RU.why_dropped(t, l) is not None], [])

    def test_k38_the_workflow_uploads_no_artifact(self):
        wf = open(ROOT / ".github/workflows/real-users.yml", encoding="utf-8").read()
        self.assertNotIn("upload-artifact", wf)

    def test_oscar_o25_cases(self):
        out = subprocess.run([sys.executable, "-I", str(ROOT / "scripts/qa/o25_k22_privacy.py")], capture_output=True, text=True, encoding="utf-8")
        d = json.loads(out.stdout)
        self.assertEqual(d["fails"], [], d["fails"])
        self.assertEqual(d["e2e_written"], [], "a private sentence from two installs is never written")

    def test_live_eval_reads_the_approved_file(self):
        self.assertIn("real-user-cases.json", open(ROOT / "scripts/live-eval.py", encoding="utf-8").read())


if __name__ == "__main__":
    unittest.main(verbosity=1)
