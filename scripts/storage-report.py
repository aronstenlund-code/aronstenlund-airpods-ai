#!/usr/bin/env python3
"""K59: how much of Supabase Free's storage the drill audio uses. Writes reports/storage/latest.md (and one line per day
in reports/storage/history.tsv). At 70 % of 1 GB it prints WARN so the workflow can flag it for Aron.
  SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/storage-report.py"""
import datetime, json, os, pathlib, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
LIMIT = 1_000_000_000  # Free plan: 1 GB file storage
DB_LIMIT = 500_000_000  # Free plan: 500 MB database
WARN_AT = 0.70


def stats():
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    req = urllib.request.Request(URL + "/rest/v1/rpc/drill_storage_stats", data=b"{}", method="POST",
                                 headers={"apikey": key, "authorization": "Bearer " + key, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=60))


def eleven():
    """K62: the ElevenLabs credits as /drill last saw them (subscription, or the quota error's 'credits remaining')."""
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    req = urllib.request.Request(URL + "/rest/v1/provider_status?provider=eq.elevenlabs&select=*",
                                 headers={"apikey": key, "authorization": "Bearer " + key})
    rows = json.load(urllib.request.urlopen(req, timeout=30))
    if not rows:
        return None
    r = rows[0]
    lim = r.get("lim")
    left = (lim - r["used"]) if r.get("status") == 200 and r.get("used") is not None and lim else r.get("remaining_hint")
    return {"lim": lim, "left": left, "at": r.get("updated_at"), "status": r.get("status")}


def mb(b):
    return f"{b / 1e6:.1f} MB"


def main():
    s = stats()
    ev = eleven()
    ev_low = bool(ev and ev.get("lim") and ev.get("left") is not None and ev["left"] / ev["lim"] < 0.20)
    ev_line = ("okänt" if not ev or ev.get("left") is None else
               f"{ev['left']:,} av {ev['lim']:,} kvar ({ev['left'] / ev['lim']:.0%}), senast sett {str(ev['at'])[:16].replace('T', ' ')} UTC"
               + ("" if ev.get("status") == 200 else " (ur felmeddelandet: nyckeln saknar User Read)")).replace(",", " ")
    today = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=1))).date().isoformat()
    used = s["total_bytes"] / LIMIT
    days = s["per_day"][-14:]
    avg = sum(d["bytes"] for d in days) / max(1, len(days))
    left_days = (LIMIT * WARN_AT - s["total_bytes"]) / avg if avg > 0 else None
    lines = [
        f"# Lagring (K59), {today}",
        "",
        f"- **Totalt i Storage:** {mb(s['total_bytes'])} av 1 GB ({used:.1%}). Varning vid 70 %.",
        f"- **drill_audio:** {mb(s['drill_audio_bytes'])} i {s['drill_audio_files']} filer.",
        f"- **Databasen:** {mb(s['db_bytes'])} av 500 MB ({s['db_bytes'] / DB_LIMIT:.1%}).",
        f"- **ElevenLabs-krediter (K62):** {ev_line}",
        f"- **Snitt per dag (senaste {len(days)} dagarna med ljud):** {mb(avg)}"
        + (f", 70 % nås om cirka {left_days:.0f} dagar i den takten." if left_days is not None and left_days > 0 else "."),
        "",
        "| Dag | Filer | MB |",
        "|---|---|---|",
        *[f"| {d['day']} | {d['files']} | {d['bytes'] / 1e6:.1f} |" for d in s["per_day"]],
        "",
    ]
    out = ROOT / "reports/storage"
    out.mkdir(parents=True, exist_ok=True)
    (out / "latest.md").write_text("\n".join(lines), encoding="utf-8")
    hist = out / "history.tsv"
    rows = hist.read_text(encoding="utf-8").splitlines() if hist.exists() else ["day\ttotal_bytes\tdrill_audio_bytes\tfiles\tdb_bytes"]
    rows = [r for r in rows if not r.startswith(today)] + [f"{today}\t{s['total_bytes']}\t{s['drill_audio_bytes']}\t{s['drill_audio_files']}\t{s['db_bytes']}"]
    hist.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"storage {mb(s['total_bytes'])} ({used:.1%}), drill_audio {mb(s['drill_audio_bytes'])}, db {mb(s['db_bytes'])}")
    code = 0
    if used >= WARN_AT:
        print("WARN storage at", f"{used:.0%}")
        code |= 2
    if ev_low:
        print("WARN elevenlabs credits", ev_line)
        code |= 4
    return code


if __name__ == "__main__":
    sys.exit(main())
