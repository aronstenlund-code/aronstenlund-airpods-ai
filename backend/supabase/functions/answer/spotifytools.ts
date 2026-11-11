import { SPOTIFY_API } from "../_shared/spotify.ts";

/**
 * K36 (D125): Spotify as SERVER tools in /answer. Offered only when the app says the user has connected Spotify
 * (`connections: ["spotify"]`, from GET /connect). The model picks the tool; the server runs it with the stored token
 * after the model's turn and says one sentence written in code (no second model call). Playing, pausing and skipping
 * change nothing the user cannot undo at once, so there is no confirmation step (D122 confirms writes and sends).
 */
export type SpotifyToolName = "spotify_play" | "spotify_pause" | "spotify_next" | "spotify_previous";
export const SPOTIFY_TOOLS: SpotifyToolName[] = ["spotify_play", "spotify_pause", "spotify_next", "spotify_previous"];
export const isSpotifyTool = (n: string): n is SpotifyToolName => (SPOTIFY_TOOLS as string[]).includes(n);

const empty = { type: "object", properties: {}, required: [], additionalProperties: false };
export function spotifyToolDefs(): unknown[] {
  return [
    {
      name: "spotify_play",
      description:
        "Play music in the user's Spotify. With `query`: find and play it (a song, a playlist, an album or an artist; `kind` when the user said which, e.g. 'spellistan Plugg' = playlist). Without `query`: resume what was playing.",
      input_schema: {
        type: "object",
        properties: {
          query: { type: "string", description: "What to play, as the user said it, e.g. 'Plugg', 'Blinding Lights The Weeknd'" },
          kind: { type: "string", enum: ["track", "playlist", "album", "artist"] },
        },
        required: [],
        additionalProperties: false,
      },
      strict: true,
    },
    { name: "spotify_pause", description: "Pause the user's Spotify.", input_schema: empty, strict: true },
    { name: "spotify_next", description: "Skip to the next song in the user's Spotify.", input_schema: empty, strict: true },
    { name: "spotify_previous", description: "Go back to the previous song in the user's Spotify.", input_schema: empty, strict: true },
  ];
}

export const SPOTIFY_RULE = `
Spotify tools (K36): the user has connected Spotify. When they ask to play, pause, skip or go back in their music ("spela …", "kör spellistan …", "pausa musiken", "nästa låt"), call the matching spotify tool and write NOTHING before the call. Never call a Spotify tool for a question about music.`;

export const MUSIC_REQUEST = /(?<![\p{L}])(?:spela|kör (?:spellista|låten|albumet|lite)|sätt på (?:musik|låten|spellista)|pausa (?:musiken|spotify|låten)|stoppa musiken|nästa låt|byt låt|hoppa över låten|förra låten|starta spotify|spotify)(?![\p{L}])/iu;

export function validateSpotifyInput(name: string, input: unknown): Record<string, unknown> | null {
  if (!isSpotifyTool(name) || !input || typeof input !== "object" || Array.isArray(input)) return null;
  if (name !== "spotify_play") return {};
  const i = input as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  if (i.query !== undefined) {
    if (typeof i.query !== "string" || !i.query.trim() || i.query.length > 120) return null;
    out.query = i.query.trim();
  }
  if (i.kind !== undefined) {
    if (!["track", "playlist", "album", "artist"].includes(String(i.kind))) return null;
    out.kind = i.kind;
  }
  return out;
}

export interface SpotifyResult {
  status: "ok" | "not_connected" | "premium_required" | "no_device" | "not_found" | "error";
  /** The sentence Lumen says. */
  say: string;
  /** What is now playing (title + artist or playlist name), for the app's screen. */
  playing?: string;
}

const SAY = {
  not_connected: "Spotify är inte kopplat. Du kan koppla det under Inställningar.",
  premium_required: "Spotify låter bara appar styra musiken med Premium, så det går inte med ditt konto.",
  no_device: "Jag hittar ingen Spotify som är igång. Öppna Spotify på telefonen en gång, så kan jag styra den.",
  error: "Spotify svarade inte just nu. Försök igen om en stund.",
};

async function api(token: string, method: string, path: string, body: unknown, fetchImpl: typeof fetch) {
  const r = await fetchImpl(`${SPOTIFY_API}${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, ...(body ? { "content-type": "application/json" } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(6000),
  });
  const text = await r.text().catch(() => "");
  let j: Record<string, unknown> = {};
  try {
    j = text ? JSON.parse(text) : {};
  } catch { /* empty body */ }
  return { status: r.status, j };
}

const norm = (s: string) => s.toLowerCase().normalize("NFC").replace(/[^\p{L}\p{N} ]/gu, " ").replace(/\s+/g, " ").trim();

interface Target {
  context_uri?: string;
  uris?: string[];
  label: string;
}

/** Finds what to play: the user's own playlists first (by name), then a Spotify search (limit 5, max 10 since 2026). */
async function findTarget(token: string, query: string, kind: string | undefined, fetchImpl: typeof fetch): Promise<Target | null> {
  if (!kind || kind === "playlist") {
    const mine = await api(token, "GET", "/me/playlists?limit=50", null, fetchImpl);
    const items = Array.isArray(mine.j.items) ? mine.j.items as { name?: string; uri?: string }[] : [];
    const q = norm(query);
    const own = items.find((p) => p?.name && norm(p.name) === q) ??
      items.find((p) => p?.name && (norm(p.name).includes(q) || q.includes(norm(p.name))) && norm(p.name).length >= 3);
    if (own?.uri) return { context_uri: own.uri, label: `spellistan ${own.name}` };
  }
  const types = kind ?? "track,playlist,album,artist";
  const s = await api(token, "GET", `/search?${new URLSearchParams({ q: query, type: types, limit: "5" })}`, null, fetchImpl);
  if (s.status !== 200) return null;
  const pick = <T>(k: string) => ((s.j[k] as { items?: T[] } | undefined)?.items ?? []).filter(Boolean);
  type Item = { name?: string; uri?: string; artists?: { name?: string }[]; owner?: { display_name?: string } };
  const order = kind ? [kind] : ["track", "playlist", "album", "artist"];
  for (const k of order) {
    const it = pick<Item>(`${k}s`)[0];
    if (!it?.uri) continue;
    const by = it.artists?.[0]?.name;
    if (k === "track") return { uris: [it.uri], label: by ? `${it.name} med ${by}` : String(it.name) };
    if (k === "playlist") return { context_uri: it.uri, label: `spellistan ${it.name}` };
    if (k === "album") return { context_uri: it.uri, label: by ? `albumet ${it.name} med ${by}` : `albumet ${it.name}` };
    return { context_uri: it.uri, label: String(it.name) };
  }
  return null;
}

function failure(status: number, j: Record<string, unknown>): SpotifyResult {
  const reason = String((j.error as { reason?: string } | undefined)?.reason ?? "");
  if (status === 403 && /PREMIUM/i.test(reason)) return { status: "premium_required", say: SAY.premium_required };
  if (status === 404 || /NO_ACTIVE_DEVICE/i.test(reason)) return { status: "no_device", say: SAY.no_device };
  if (status === 401) return { status: "not_connected", say: SAY.not_connected };
  return { status: "error", say: SAY.error };
}

/** Runs one Spotify tool for the user. `token` null = not connected (or the refresh failed). */
export async function runSpotify(
  name: SpotifyToolName,
  input: Record<string, unknown>,
  conn: { token: string; premium: boolean | null } | null,
  fetchImpl: typeof fetch = fetch,
): Promise<SpotifyResult> {
  if (!conn) return { status: "not_connected", say: SAY.not_connected };
  if (conn.premium === false) return { status: "premium_required", say: SAY.premium_required };
  const t = conn.token;
  try {
    if (name === "spotify_pause") {
      const r = await api(t, "PUT", "/me/player/pause", null, fetchImpl);
      return r.status < 300 ? { status: "ok", say: "Jag pausade musiken." } : failure(r.status, r.j);
    }
    if (name === "spotify_next" || name === "spotify_previous") {
      const r = await api(t, "POST", name === "spotify_next" ? "/me/player/next" : "/me/player/previous", null, fetchImpl);
      return r.status < 300 ? { status: "ok", say: name === "spotify_next" ? "Nästa låt." : "Förra låten." } : failure(r.status, r.j);
    }
    const query = typeof input.query === "string" ? input.query : "";
    const target = query ? await findTarget(t, query, input.kind as string | undefined, fetchImpl) : null;
    if (query && !target) return { status: "not_found", say: `Jag hittade inte ${query} på Spotify.` };
    const body = target ? (target.uris ? { uris: target.uris } : { context_uri: target.context_uri }) : null;
    let r = await api(t, "PUT", "/me/player/play", body, fetchImpl);
    if (r.status === 404) {
      // no active device: start on the phone (or whatever Spotify device is there) when there is one
      const d = await api(t, "GET", "/me/player/devices", null, fetchImpl);
      const devs = Array.isArray(d.j.devices) ? d.j.devices as { id?: string; type?: string; is_restricted?: boolean }[] : [];
      const dev = devs.find((x) => x.type === "Smartphone" && !x.is_restricted && x.id) ?? devs.find((x) => !x.is_restricted && x.id);
      if (!dev?.id) return { status: "no_device", say: SAY.no_device };
      r = await api(t, "PUT", `/me/player/play?device_id=${encodeURIComponent(dev.id)}`, body, fetchImpl);
    }
    if (r.status >= 300) return failure(r.status, r.j);
    return target
      ? { status: "ok", say: `Nu spelas ${target.label}.`, playing: target.label }
      : { status: "ok", say: "Musiken är igång igen." };
  } catch (e) {
    console.warn("spotify_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
    return { status: "error", say: SAY.error };
  }
}
