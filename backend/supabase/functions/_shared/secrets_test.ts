import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { cleanSecret, logProviderFailure, redactSecrets, secret } from "./secrets.ts";
import { classifyAnthropicError } from "../answer/llm/anthropic.ts";
import { providerFromEnv } from "../answer/llm/factory.ts";

const KEY = "sk-ant-api03-AbCdEfGh1234567890_xyz";

Deno.test("K0: a pasted key is cleaned of spaces, line breaks, invisible characters and quotes", () => {
  assertEquals(cleanSecret(` ${KEY}\n`), KEY);
  assertEquals(cleanSecret(`${KEY}\r\n`), KEY);
  assertEquals(cleanSecret(`\u200b${KEY}\u00a0`), KEY);
  assertEquals(cleanSecret(`\ufeff${KEY}`), KEY);
  assertEquals(cleanSecret(`sk-ant-api03-AbCd\nEfGh1234567890_xyz`), KEY);
  assertEquals(cleanSecret(`"${KEY}"`), KEY);
  assertEquals(cleanSecret(`“${KEY}”`), KEY);
  assertEquals(cleanSecret(KEY), KEY);
  assertEquals(cleanSecret("   \n"), null);
  assertEquals(cleanSecret(undefined), null);
  assertEquals(secret({ get: () => ` ${KEY} ` }, "ANTHROPIC_API_KEY"), KEY);
});

Deno.test("K0: the provider gets the cleaned key in its header", async () => {
  let sent = "";
  const p = providerFromEnv({
    get: (k) => (k === "ANTHROPIC_API_KEY" ? `${KEY}\n ` : undefined),
  });
  assert(p);
  // deno-lint-ignore no-explicit-any
  const cfg = (p as any).cfg as { apiKey: string };
  sent = cfg.apiKey;
  assertEquals(sent, KEY);
  assertEquals(providerFromEnv({ get: (k) => (k === "ANTHROPIC_API_KEY" ? " \n" : undefined) }), null);
});

Deno.test("K0: logs never contain the key", () => {
  assertEquals(redactSecrets(`bad header x-api-key: ${KEY}`), "bad header x-api-key: sk-ant-[redacted]");
  assertEquals(redactSecrets("token sk_abcdef0123456789abcd here", null), "token sk_[redacted] here");
  assertEquals(redactSecrets("value myverysecretvalue!", "myverysecretvalue"), "value [redacted]!");
  const lines: string[] = [];
  const e = new TypeError(`Header 'x-api-key' has invalid value: '${KEY}\n'`);
  logProviderFailure("elevenlabs", null, e, KEY, (l) => lines.push(l));
  assertEquals(lines.length, 1);
  const row = JSON.parse(lines[0]);
  assertEquals(row.event, "provider_unavailable");
  assertEquals(row.error, "TypeError");
  assert(!lines[0].includes("AbCdEfGh"));
  assert(row.message.length <= 200);
});

Deno.test("K0: 'unavailable' is logged with status, error name and message; other kinds are not", () => {
  const lines: string[] = [];
  const log = (l: string) => lines.push(l);
  const u = classifyAnthropicError(undefined, `invalid header value ${KEY}`, "TypeError", log);
  assertEquals(u.kind, "unavailable");
  assertEquals(lines.length, 1);
  const row = JSON.parse(lines[0]);
  assertEquals(row.status, null);
  assertEquals(row.error, "TypeError");
  assert(row.message.startsWith("invalid header value"));
  assert(!lines[0].includes("AbCdEfGh"));
  classifyAnthropicError(529, "Overloaded", "overloaded_error", log);
  assertEquals(JSON.parse(lines[1]).status, 529);
  classifyAnthropicError(401, "invalid x-api-key", undefined, log);
  classifyAnthropicError(429, "rate", undefined, log);
  assertEquals(lines.length, 2);
});
