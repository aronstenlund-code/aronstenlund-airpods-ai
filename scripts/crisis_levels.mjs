// K24: the app's crisis filter (answer/crisis.ts) for scripts/real_users.py: JSON list of texts on stdin -> levels.
import { crisisLevel } from "../backend/supabase/functions/answer/crisis.ts";
let buf = "";
process.stdin.on("data", (d) => (buf += d));
process.stdin.on("end", () => process.stdout.write(JSON.stringify(JSON.parse(buf || "[]").map((t) => crisisLevel(String(t))))));
