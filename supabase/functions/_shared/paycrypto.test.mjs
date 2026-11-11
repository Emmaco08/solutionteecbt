// Unit tests for paycrypto.ts. Run: node --test supabase/functions/_shared/paycrypto.test.mjs  (Node 22.18+ strips types)
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHmac, generateKeyPairSync, createVerify } from "node:crypto";
import * as pc from "./paycrypto.ts";

const secret = "sk_test_abc123";
const body = JSON.stringify({ event: "charge.success", data: { reference: "st_0123456789abcdef0123", amount: 150000 } });
const goodSig = createHmac("sha512", secret).update(body).digest("hex");

test("Paystack signature: correct HMAC-SHA512 accepted", async () => {
  assert.equal(await pc.hmacSha512Hex(secret, body), goodSig);
  assert.equal(await pc.paystackSignatureOk(secret, body, goodSig), true);
  assert.equal(await pc.paystackSignatureOk(secret, body, goodSig.toUpperCase()), true);
});

test("Paystack signature: wrong, missing, other key or changed body refused", async () => {
  assert.equal(await pc.paystackSignatureOk(secret, body, "00" + goodSig.slice(2)), false);
  assert.equal(await pc.paystackSignatureOk(secret, body, null), false);
  assert.equal(await pc.paystackSignatureOk(secret, body, ""), false);
  assert.equal(await pc.paystackSignatureOk("sk_test_other", body, goodSig), false);
  assert.equal(await pc.paystackSignatureOk(secret, body.replace("150000", "100"), goodSig), false);
  assert.equal(await pc.paystackSignatureOk("", body, goodSig), false);
});

test("safeEqual", () => {
  assert.equal(pc.safeEqual("abc", "abc"), true);
  assert.equal(pc.safeEqual("abc", "abd"), false);
  assert.equal(pc.safeEqual("abc", "abcd"), false);
  assert.equal(pc.safeEqual("", ""), true);
});

test("sha256Hex and play account id are stable, 64 hex characters", async () => {
  assert.equal(await pc.sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  const a = await pc.playAccountId("00000000-0000-4000-8000-0000000000d1");
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.equal(a, await pc.playAccountId("00000000-0000-4000-8000-0000000000d1"));
  assert.notEqual(a, await pc.playAccountId("00000000-0000-4000-8000-0000000000d2"));
});

test("trimPaystack keeps no customer or card numbers", () => {
  const t = pc.trimPaystack({ id: 1, status: "success", amount: 150000, currency: "NGN", channel: "card",
    customer: { email: "a@b.c", phone: "080" }, authorization: { bin: "408408", last4: "4081", bank: "TEST BANK", card_type: "visa", authorization_code: "AUTH_x" } });
  const s = JSON.stringify(t);
  for (const bad of ["a@b.c", "408408", "4081", "AUTH_x", "080"]) assert.ok(!s.includes(bad), bad);
  assert.equal(t.amount, 150000);
  assert.equal(t.bank, "TEST BANK");
  assert.equal(pc.trimPaystack({ amount: 152300, requested_amount: 150000 }).requested_amount, 150000);
});

test("Google service-account JWT is RS256 and verifies with the public key", async () => {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
  const jwt = await pc.googleAssertion({ client_email: "svc@x.iam.gserviceaccount.com", private_key: pem }, "scope-x", 1_800_000_000);
  const [h, c, s] = jwt.split(".");
  const dec = (x) => JSON.parse(Buffer.from(x, "base64url").toString());
  assert.deepEqual(dec(h), { alg: "RS256", typ: "JWT" });
  assert.deepEqual(dec(c), { iss: "svc@x.iam.gserviceaccount.com", scope: "scope-x", aud: "https://oauth2.googleapis.com/token", iat: 1_800_000_000, exp: 1_800_003_600 });
  const v = createVerify("RSA-SHA256");
  v.update(`${h}.${c}`);
  assert.equal(v.verify(publicKey, Buffer.from(s, "base64url")), true);
});

test("Play purchase verdict", () => {
  const acc = "a".repeat(64);
  assert.equal(pc.playPurchaseVerdict({ purchaseState: 0, obfuscatedExternalAccountId: acc }, acc), "ok");
  assert.equal(pc.playPurchaseVerdict({ purchaseState: 2, obfuscatedExternalAccountId: acc }, acc), "pending");
  assert.equal(pc.playPurchaseVerdict({ purchaseState: 1, obfuscatedExternalAccountId: acc }, acc), "cancelled");
  assert.equal(pc.playPurchaseVerdict({ purchaseState: 0 }, acc), "wrong_account");
  assert.equal(pc.playPurchaseVerdict({ purchaseState: 0, obfuscatedExternalAccountId: "b".repeat(64) }, acc), "wrong_account");
  assert.equal(pc.playPurchaseVerdict({}, acc), "cancelled");
});
