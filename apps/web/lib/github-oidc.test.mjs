// Unit tests for github-oidc.ts. Run (from apps/web): node --test lib/github-oidc.test.mjs  (Node 22.18+ strips types)
import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, createSign } from "node:crypto";
import * as g from "./github-oidc.ts";

const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const other = generateKeyPairSync("rsa", { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: "jwk" }), kid: "k1", alg: "RS256", use: "sig" };
const keys = async () => [jwk];
const now = 1_800_000_000;

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
function token(claims, { key = privateKey, kid = "k1", alg = "RS256" } = {}) {
  const head = `${b64({ alg, kid, typ: "JWT" })}.${b64(claims)}`;
  const sig = createSign("RSA-SHA256").update(head).sign(key).toString("base64url");
  return `${head}.${sig}`;
}
const good = {
  iss: g.GITHUB_ISSUER,
  aud: g.APK_AUDIENCE,
  exp: now + 300,
  nbf: now - 10,
  iat: now - 10,
  repository: "Emmaco08/solutionteecbt",
  repository_id: g.REPO_ID,
  ref: "refs/heads/main",
  sha: "abc",
  event_name: "push",
  job_workflow_ref: "Emmaco08/solutionteecbt/.github/workflows/android-apk.yml@refs/heads/main",
  runner_environment: "github-hosted",
};

test("a real token from our workflow is accepted", async () => {
  const c = await g.verifyGithubToken(token(good), g.APK_AUDIENCE, keys, now);
  assert.equal(c?.repository_id, g.REPO_ID);
  assert.equal(g.apkBuildAllowed(c), true);
  assert.equal(g.apkBuildAllowed({ ...good, ref: "refs/heads/claude/clever-gates-rdt2wx", event_name: "workflow_dispatch" }), true);
});

test("forged, wrong-audience, expired or broken tokens are refused", async () => {
  assert.equal(await g.verifyGithubToken(token(good, { key: other.privateKey }), g.APK_AUDIENCE, keys, now), null);
  assert.equal(await g.verifyGithubToken(token({ ...good, aud: "someone-else" }), g.APK_AUDIENCE, keys, now), null);
  assert.equal(await g.verifyGithubToken(token({ ...good, iss: "https://evil.example" }), g.APK_AUDIENCE, keys, now), null);
  assert.equal(await g.verifyGithubToken(token({ ...good, exp: now - 600 }), g.APK_AUDIENCE, keys, now), null);
  assert.equal(await g.verifyGithubToken(token(good, { alg: "none" }), g.APK_AUDIENCE, keys, now), null);
  assert.equal(await g.verifyGithubToken(token(good, { kid: "unknown" }), g.APK_AUDIENCE, keys, now), null);
  assert.equal(await g.verifyGithubToken("not.a.token", g.APK_AUDIENCE, keys, now), null);
  const t = token(good);
  const tampered = t.split(".");
  tampered[1] = b64({ ...good, ref: "refs/heads/evil" });
  assert.equal(await g.verifyGithubToken(tampered.join("."), g.APK_AUDIENCE, keys, now), null);
});

test("only our repo, our workflow, pushes or manual runs, main or claude/* branches", () => {
  assert.equal(g.apkBuildAllowed({ ...good, repository_id: "999" }), false, "a copy of the repo");
  assert.equal(g.apkBuildAllowed({ ...good, event_name: "pull_request" }), false, "pull requests");
  assert.equal(g.apkBuildAllowed({ ...good, ref: "refs/heads/feature-x" }), false, "other branches");
  assert.equal(g.apkBuildAllowed({ ...good, ref: "refs/tags/v1" }), false, "tags");
  assert.equal(g.apkBuildAllowed({ ...good, job_workflow_ref: "Emmaco08/solutionteecbt/.github/workflows/other.yml@refs/heads/main" }), false, "another workflow");
  assert.equal(g.apkBuildAllowed({ ...good, runner_environment: "self-hosted" }), false, "self-hosted runners");
});

test("APK file names", () => {
  assert.equal(g.apkNameOk("solutiontee-cbt-0.3.0-202611031200.apk"), true);
  assert.equal(g.apkNameOk("../latest.json"), false);
  assert.equal(g.apkNameOk("solutiontee-cbt-0.3.0/../../x.apk"), false);
  assert.equal(g.apkNameOk("latest.json"), false);
});
