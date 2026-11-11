import type { AuthedUser, Authenticator } from "./auth.ts";
import { HttpError } from "./errors.ts";

/**
 * K30/K38/K39: Aron's private pages. Only a user JWT whose email is one of OWNER_EMAIL (a secret, never in the repo)
 * AND that was signed in by email (magic link or one-time code, `amr` "otp"/"magiclink"), so a password sign-up with
 * his address cannot read anything. Throws 401/403 (or 503 when OWNER_EMAIL is unset; never told to anonymous users).
 */
export async function requireOwner(
  req: Request,
  authenticate: Authenticator,
  ownerEmails: string[],
): Promise<AuthedUser> {
  const user = await authenticate(req);
  const owners = ownerEmails.map((e) => e.trim().toLowerCase()).filter(Boolean);
  const byEmail = (user.amr ?? []).some((m) => m === "otp" || m === "magiclink");
  if (user.isAnonymous || !user.email || !byEmail) throw new HttpError(403, "forbidden", "Owner only");
  if (!owners.length) throw new HttpError(503, "unconfigured", "OWNER_EMAIL is not set");
  if (!owners.includes(user.email.toLowerCase())) throw new HttpError(403, "forbidden", "Owner only");
  return user;
}
