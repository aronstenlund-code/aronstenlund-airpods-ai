// K98 (D224): App Attest with a fake chain made at test time; nothing leaves the test.
import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { InvalidAttestation, verifyAttestation } from "./attest.ts";
import { testAttest } from "./testpki.ts";

const APP = "ABCDE12345.com.rsolutions.lumen";
const ch = () => crypto.getRandomValues(new Uint8Array(32));

Deno.test("K98 App Attest: a genuine attestation for our challenge and app is accepted; the key id is the key's hash", async () => {
  const a = await testAttest();
  const c = ch();
  const { keyId, attestation } = await a.attest(c, APP);
  const r = await verifyAttestation(keyId, attestation, c, { roots: [a.rootSha], rootDer: a.rootDer, appId: APP });
  assertEquals(r.keyId, keyId);
});

Deno.test("K98 App Attest refuses: another challenge, another app, a development key in production, a counter, another root, a wrong key id", async () => {
  const a = await testAttest();
  const c = ch();
  const reason = async (f: () => Promise<unknown>) => {
    try {
      await f();
      return "accepted";
    } catch (e) {
      return e instanceof InvalidAttestation ? e.reason : String(e);
    }
  };
  const ok = await a.attest(c, APP);
  const opts = { roots: [a.rootSha], rootDer: a.rootDer, appId: APP };
  assertEquals(await reason(() => verifyAttestation(ok.keyId, ok.attestation, ch(), opts)), "nonce");
  assertEquals(await reason(() => verifyAttestation(ok.keyId, ok.attestation, c, { ...opts, appId: "OTHER.com.x" })), "app");
  const dev = await a.attest(c, APP, { aaguid: "appattestdevelop" });
  assertEquals(await reason(() => verifyAttestation(dev.keyId, dev.attestation, c, opts)), "environment");
  assertEquals(await reason(() => verifyAttestation(dev.keyId, dev.attestation, c, { ...opts, allowDevelopment: true })), "accepted");
  const used = await a.attest(c, APP, { counter: 3 });
  assertEquals(await reason(() => verifyAttestation(used.keyId, used.attestation, c, opts)), "counter");
  const other = await testAttest();
  assertEquals(await reason(() => verifyAttestation(ok.keyId, ok.attestation, c, { ...opts, rootDer: other.rootDer })), "root");
  assertEquals(await reason(() => verifyAttestation(ok.keyId, ok.attestation, c, { ...opts, roots: [other.rootSha], rootDer: other.rootDer })), "chain");
  const two = await a.attest(c, APP);
  assertEquals(await reason(() => verifyAttestation(two.keyId, ok.attestation, c, opts)), "key");
  const bad = await a.attest(c, APP, { wrongNonce: true });
  assertEquals(await reason(() => verifyAttestation(bad.keyId, bad.attestation, c, opts)), "nonce");
  await assertRejects(() => verifyAttestation(ok.keyId, Uint8Array.of(1, 2, 3), c, opts), InvalidAttestation);
});
