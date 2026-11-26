// O100 S4 (Oscar): DNS rebinding – the address is checked through DNS over HTTPS, the fetch resolves again. With https
// the certificate stops it (an internal service cannot show one for the attacker's name); plain http is fetched as
// https from now on, redirects too, so a rebinding answer never gets a connection without TLS.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { checkUrl } from "./guard.ts";

Deno.test("O100 S4: an http link is fetched as https (same host, path and query)", () => {
  assertEquals(checkUrl("http://example.com/a/b?q=1#x", []).toString(), "https://example.com/a/b?q=1#x");
  assertEquals(checkUrl("https://example.com/a", []).toString(), "https://example.com/a");
  assertEquals(checkUrl("http://example.com:80/a", []).toString(), "https://example.com/a", "the default port goes with it");
});
