#!/usr/bin/env python3
"""K22 tests with invented data only (no network, no model).  python3 scripts/test_real_users.py"""
import importlib.util, json, pathlib, sys, tempfile, unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("ru", ROOT / "scripts/real_users.py")
RU = importlib.util.module_from_spec(spec)
spec.loader.exec_module(RU)

FAKE = [  # invented shared_history rows (fragment, mode, persona, install_id)
    {"fragment": "Lumen vad är fotosyntes", "mode": "tutor", "persona": "tutor", "install_id": "inst-aaaaaaaa"},
    {"fragment": "vad är fotosyntes asså", "mode": "tutor", "persona": "tutor", "install_id": "inst-bbbbbbbb"},
    {"fragment": "vad är fotosyntesen", "mode": "tutor", "persona": "tutor", "install_id": "inst-cccccccc"},
    {"fragment": "hur räknar man ut procent", "mode": "auto", "persona": "tutor", "install_id": "inst-aaaaaaaa"},
    {"fragment": "hur räknar man procent", "mode": "push_to_talk", "persona": "tutor", "install_id": "inst-dddddddd"},
    {"fragment": "jag heter Elin och går på Rinkebyskolan, vad är en atom", "mode": "auto", "persona": "tutor", "install_id": "inst-eeeeeeee"},
    {"fragment": "vad är en atom", "mode": "auto", "persona": "tutor", "install_id": "inst-ffffffff"},
    {"fragment": "ring mig på 070-123 45 67 om läxan", "mode": "auto", "persona": "tutor", "install_id": "inst-gggggggg"},
    {"fragment": "jag orkar inte leva", "mode": "auto", "persona": "tutor", "install_id": "inst-hhhhhhhh"},
    {"fragment": "jag har adhd, hur pluggar jag bäst", "mode": "tutor", "persona": "tutor", "install_id": "inst-iiiiiiii"},
    {"fragment": "vad ska jag säga till henne", "mode": "tutor", "persona": "social", "install_id": "inst-jjjjjjjj"},
    {"fragment": "när dog Gustav Vasa", "mode": "auto", "persona": "tutor", "install_id": "inst-kkkkkkkk"},
    {"fragment": "när dog Gustav Vasa", "mode": "auto", "persona": "tutor", "install_id": "inst-llllllll"},
    {"fragment": "min kompis Hugo sa att jorden är platt", "mode": "auto", "persona": "tutor", "install_id": "inst-mmmmmmmm"},
    {"fragment": "", "mode": "auto", "persona": "tutor", "install_id": "inst-nnnnnnnn"},
]


class T(unittest.TestCase):
    def test_scrub(self):
        self.assertEqual(RU.scrub("jag heter Elin och går på Rinkebyskolan, vad är en atom"), "jag heter [namn] och går på [skola], vad är en atom")
        self.assertIn("[nummer]", RU.scrub("ring mig på 070-123 45 67 om läxan"))
        self.assertEqual(RU.scrub("mejla anna.svensson@example.com"), "mejla [e-post]")
        self.assertIn("[personnummer]", RU.scrub("mitt personnummer är 070101-1234"))
        self.assertEqual(RU.scrub("min kompis Hugo sa att jorden är platt"), "min kompis [namn] sa att jorden är platt")
        self.assertEqual(RU.scrub("Elin sa att provet är svårt"), "[namn] sa att provet är svårt")
        self.assertEqual(RU.scrub("när dog Gustav Vasa"), "när dog Gustav Vasa", "a historical person stays")
        self.assertIn("[adress]", RU.scrub("jag bor på Storgatan 12"))

    def test_sensitive_and_persona_rows_are_skipped(self):
        rows, skipped = RU.prepare(FAKE)
        texts = " ".join(r["text"] for r in rows)
        self.assertNotIn("orkar inte leva", texts)
        self.assertNotIn("adhd", texts)
        self.assertNotIn("säga till henne", texts)
        self.assertEqual(skipped.get("sensitive"), 2)
        self.assertEqual(skipped.get("persona"), 1)
        self.assertEqual(skipped.get("empty"), 1)

    def test_grouping_and_k_anonymity(self):
        rows, _ = RU.prepare(FAKE)
        groups = RU.group(rows)
        foto = [g for g in groups if "fotosyntes" in g["text"]]
        self.assertEqual(len(foto), 1, groups)
        self.assertEqual(foto[0]["installs"], 3)
        with tempfile.TemporaryDirectory() as d:
            cases_f, bank_f = pathlib.Path(d) / "c.json", pathlib.Path(d) / "b.json"
            s = RU.run(FAKE, "2026-11-10", cases_f, bank_f)
            cases = json.load(open(cases_f, encoding="utf-8"))
            qs = [c["turns"][0]["q"] for c in cases]
            # asked by one install only: never in the repo
            self.assertFalse(any("jorden är platt" in q for q in qs), qs)
            self.assertFalse(any("070" in q or "Elin" in q or "Rinkeby" in q for q in qs), qs)
            self.assertTrue(any("fotosyntes" in q for q in qs))
            self.assertTrue(any("procent" in q for q in qs))
            self.assertTrue(any("Gustav Vasa" in q for q in qs))
            self.assertTrue(all(c["turns"][0]["expect"] == "either" for c in cases))
            bank = json.load(open(bank_f, encoding="utf-8"))
            self.assertEqual(len(bank), len(cases))
            self.assertEqual(bank[0][1], 7)
            self.assertEqual(s["cases"], len(cases))
            # a week later the same questions only update the counts
            RU.run(FAKE, "2026-11-17", cases_f, bank_f)
            again = json.load(open(cases_f, encoding="utf-8"))
            self.assertEqual(len(again), len(cases))
            self.assertTrue(all(c["last"] == "2026-11-17" for c in again))
            # past the 12-month retention: removed
            RU.run([], "2027-11-18", cases_f, bank_f)
            self.assertEqual(json.load(open(cases_f, encoding="utf-8")), [])

    def test_live_eval_reads_the_file(self):
        src = open(ROOT / "scripts/live-eval.py", encoding="utf-8").read()
        self.assertIn("real-user-cases.json", src)


if __name__ == "__main__":
    unittest.main(verbosity=1)
