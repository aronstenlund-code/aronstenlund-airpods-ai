// POST /functions/v1/purchase - K94 (D218): StoreKit 2 purchases (verify) and App Store Server Notifications v2.
// Deployed without the gateway's JWT check: Apple's notifications carry no user; verify authenticates in code.
import { extraOriginsFromEnv, withCors } from "../_shared/cors.ts";
import { createJwtAuthenticator } from "../_shared/auth.ts";
import { SupabaseRateLimiter } from "../_shared/ratelimit.ts";
import { restDbFromEnv } from "../_shared/restdb.ts";
import { useQuotaFromDb } from "../_shared/wallet_db.ts";
import { walletFields } from "../_shared/wallet.ts";
import { APPLE_ROOT_G3_SHA256 } from "./jws.ts";
import { createPurchaseHandler, type LedgerRow, type Product, type SubRow } from "./handler.ts";

const env = Deno.env;
const db = restDbFromEnv();
const q = (s: string) => encodeURIComponent(s);
const wallet = useQuotaFromDb(db);

Deno.serve(withCors(
  createPurchaseHandler({
    authenticate: createJwtAuthenticator({ supabaseUrl: env.get("SUPABASE_URL")!, hs256Secret: env.get("SUPABASE_JWT_SECRET") }),
    rateLimiter: new SupabaseRateLimiter(db),
    roots: [APPLE_ROOT_G3_SHA256], // never a test root here
    bundleId: env.get("APP_BUNDLE_ID") ?? "com.rsolutions.lumen",
    wallet: async (u) => {
      const a = await wallet(u, 0);
      return { unit: "chars", remaining: Math.max(0, a.lim - a.used), ...(a.unlimited ? { unlimited: true } : {}), ...walletFields(a) };
    },
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
