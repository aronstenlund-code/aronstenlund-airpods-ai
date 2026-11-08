import { secret } from "../../_shared/secrets.ts";
import { AnthropicProvider } from "./anthropic.ts";
import { MockProvider } from "./mock.ts";
import { type LLMProvider } from "./types.ts";

export const DEFAULT_MODEL = "claude-haiku-5-5";

/** Chooses the provider from env. Fails closed: with no ANTHROPIC_API_KEY and LLM_PROVIDER != mock,
 *  returns null and the handler answers 503 `provider_unconfigured` (app falls back on-device).
 *  The mock is only used when explicitly requested. */
export function providerFromEnv(env: { get(k: string): string | undefined }): LLMProvider | null {
  const which = (env.get("LLM_PROVIDER") ?? "anthropic").toLowerCase();
  if (which === "mock") return new MockProvider();
  if (which === "anthropic") {
    const apiKey = secret(env, "ANTHROPIC_API_KEY");
    if (!apiKey) return null;
    const effort = (env.get("LLM_EFFORT") ?? "low") as "low" | "medium" | "high";
    return new AnthropicProvider({
      apiKey,
      model: env.get("LLM_MODEL") ?? DEFAULT_MODEL,
      baseUrl: env.get("ANTHROPIC_BASE_URL") || undefined,
      effort,
      disableThinking: (env.get("LLM_DISABLE_THINKING") ?? "1") !== "0",
    });
  }
  return null;
}
