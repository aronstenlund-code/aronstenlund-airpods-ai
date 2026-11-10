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

    def test_oscar_o25_cases(self):
        out = subprocess.run([sys.executable, "-I", str(ROOT / "scripts/qa/o25_k22_privacy.py")], capture_output=True, text=True, encoding="utf-8")
        d = json.loads(out.stdout)
        self.assertEqual(d["fails"], [], d["fails"])
        self.assertEqual(d["e2e_written"], [], "a private sentence from two installs is never written")

    def test_live_eval_reads_the_approved_file(self):
        self.assertIn("real-user-cases.json", open(ROOT / "scripts/live-eval.py", encoding="utf-8").read())


if __name__ == "__main__":
    unittest.main(verbosity=1)
