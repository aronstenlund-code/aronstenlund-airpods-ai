// POST /functions/v1/purchase - K94 (D218): StoreKit 2 purchases (verify) and App Store Server Notifications v2.
// Deployed without the gateway's JWT check: Apple's notifications carry no user; verify authenticates in code.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { useQuotaFromDb } from "../_shared/wallet_db.ts";
import { walletFields } from "../_shared/wallet.ts";
import { APPLE_ROOT_G3_SHA256 } from "./jws.ts";
import { APPLE_APP_ATTEST_ROOT_SHA256, appleAppAttestRoot } from "./attest.ts";
import { rewardStore } from "../_shared/rewards_db.ts";
import { createPurchaseHandler, type LaunchOffer, type LedgerRow, type Product, type SubRow } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const q = (s: string) => encodeURIComponent(s);
const wallet = useQuotaFromDb(db);

let launchMemo: { at: number; v: LaunchOffer | null } | null = null;
async function launchOfferFromSettings(): Promise<LaunchOffer | null> {
  if (launchMemo && Date.now() - launchMemo.at < 60_000) return launchMemo.v;
  const rows = (await db.select("drill_settings", "select=key,value&key=in.(launch_starts_at,launch_ends_at,launch_percent)")) as { key: string; value: number }[];
  const v = (k: string) => rows.find((r) => r.key === k)?.value;
  const s = v("launch_starts_at"), e = v("launch_ends_at"), pc = v("launch_percent");
  const o = s && e && e > s ? { startsAt: s * 1000, endsAt: e * 1000, percent: pc ?? 65 } : null;
  launchMemo = { at: Date.now(), v: o };
  return o;
}

Deno.serve(withCors(
  createPurchaseHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    roots: [APPLE_ROOT_G3_SHA256], // never a test root here
    bundleId: env.get("APP_BUNDLE_ID") ?? "com.rsolutions.lumen",
    // K98 (D224): welcome credits and invitations; App Attest's app id is "<TEAMID>.<bundle id>" (APPLE_TEAM_ID)
    rewards: rewardStore(db),
    attest: {
      appId: env.get("APPLE_TEAM_ID") ? `${env.get("APPLE_TEAM_ID")}.${env.get("APP_BUNDLE_ID") ?? "com.rsolutions.lumen"}` : null,
      allowDevelopment: env.get("APP_ATTEST_DEVELOPMENT") === "1",
      rootDer: appleAppAttestRoot(),
      roots: [APPLE_APP_ATTEST_ROOT_SHA256],
      newChallenge: async (u) => {
        const c = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))).replace(/[+/=]/g, "");
        await db.insert("app_attest_challenges", { challenge: c, user_id: u, expires_at: new Date(Date.now() + 5 * 60_000).toISOString() });
        return c;
      },
      useChallenge: async (u, c) =>
        (await db.updateWhere("app_attest_challenges", `challenge=eq.${q(c)}&user_id=eq.${q(u)}&used=eq.false&expires_at=gt.${q(new Date().toISOString())}`, { used: true })) > 0,
    },
    wallet: async (u) => {
      const a = await wallet(u, 0);
      return { unit: "chars", remaining: Math.max(0, a.lim - a.used), ...(a.unlimited ? { unlimited: true } : {}), ...walletFields(a) };
    },
    // K119 (D259): the launch week from drill_settings (Unix seconds; see the K119 report for the SQL that starts it)
    launchOffer: launchOfferFromSettings,
    store: {
      product: async (id) => ((await db.select("store_products", `select=*&product_id=eq.${q(id)}&limit=1`)) as Product[])[0] ?? null,
      ledger: async (tx) => ((await db.select("credit_ledger", `select=*&transaction_id=eq.${q(tx)}&limit=1`)) as LedgerRow[])[0] ?? null,
      addLedger: async (row) => {
        const had = ((await db.select("credit_ledger", `select=id&transaction_id=eq.${q(row.transaction_id)}&limit=1`)) as unknown[]).length > 0;
        if (had) return false;
        await db.insertIgnoreDuplicate("credit_ledger", row, "transaction_id");
        const mine = ((await db.select("credit_ledger", `select=user_id&transaction_id=eq.${q(row.transaction_id)}&limit=1`)) as { user_id: string }[])[0];
        return mine?.user_id === row.user_id;
      },
      subByOriginal: async (o) => ((await db.select("store_subscriptions", `select=*&original_transaction_id=eq.${q(o)}&limit=1`)) as SubRow[])[0] ?? null,
      upsertSub: async (row) => await db.upsert("store_subscriptions", { ...row, updated_at: new Date().toISOString() }, "original_transaction_id"),
    },
  }),
  extraOriginsFromEnv(),
));
