// Checks that a request really comes from this repository's "Android app" GitHub workflow (D-065).
// GitHub gives each workflow run a short-lived signed token (OIDC). We check GitHub's signature with GitHub's
// public keys, then the claims: our repository (by id, so a renamed or copied repo does not count), our workflow
// file, a push or a manual run, and only the main or claude/* branches. No password is stored anywhere.
// Pure module (no Next imports) so `node --test lib/github-oidc.test.mjs` can run it.

export const GITHUB_ISSUER = "https://token.actions.githubusercontent.com";
export const APK_AUDIENCE = "solutiontee-apk";
export const REPO_ID = "1443641230"; // Emmaco08/solutionteecbt
export const WORKFLOW = "emmaco08/solutionteecbt/.github/workflows/android-apk.yml@";

export type GithubClaims = {
  iss: string;
  aud: string | string[];
  exp: number;
  nbf?: number;
  iat?: number;
  repository: string;
  repository_id: string;
  ref: string;
  sha: string;
  event_name: string;
  job_workflow_ref: string;
  runner_environment?: string;
  run_id?: string;
};

type Jwk = JsonWebKey & { kid?: string; kty: string; n?: string; e?: string };
let cache: { keys: Jwk[]; at: number } | null = null;

async function githubKeys(fresh = false): Promise<Jwk[]> {
  if (!fresh && cache && Date.now() - cache.at < 3600_000) return cache.keys;
  const r = await fetch(`${GITHUB_ISSUER}/.well-known/jwks`, { cache: "no-store" });
  if (!r.ok) throw new Error(`GitHub keys: HTTP ${r.status}`);
  cache = { keys: ((await r.json()) as { keys: Jwk[] }).keys, at: Date.now() };
  return cache.keys;
}

const fromB64url = (s: string) => new Uint8Array(Buffer.from(s, "base64url"));

/** The token's claims when GitHub's signature is good and it is meant for us and not expired; otherwise null. */
export async function verifyGithubToken(token: string, audience = APK_AUDIENCE, getKeys = githubKeys, now = Date.now() / 1000) {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [h, p, s] = parts;
  let header: { alg?: string; kid?: string };
  let claims: GithubClaims;
  try {
    header = JSON.parse(Buffer.from(h, "base64url").toString("utf8"));
    claims = JSON.parse(Buffer.from(p, "base64url").toString("utf8"));
  } catch {
    return null;
  }
  if (header.alg !== "RS256" || !header.kid) return null;
  let jwk = (await getKeys()).find((k) => k.kid === header.kid);
  if (!jwk) jwk = (await getKeys(true)).find((k) => k.kid === header.kid); // GitHub rotated its keys
  if (!jwk || jwk.kty !== "RSA") return null;
  const key = await crypto.subtle.importKey("jwk", { kty: "RSA", n: jwk.n, e: jwk.e }, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, fromB64url(s), new TextEncoder().encode(`${h}.${p}`));
  if (!ok) return null;
  const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (claims.iss !== GITHUB_ISSUER || !aud.includes(audience)) return null;
  if (typeof claims.exp !== "number" || claims.exp < now - 30 || (claims.nbf && claims.nbf > now + 30)) return null;
  return claims;
}

/** Only our own workflow, on a push or a manual run, from main or a claude/* branch, on GitHub's own runners. */
export function apkBuildAllowed(c: GithubClaims): boolean {
  return (
    String(c.repository_id) === REPO_ID &&
    (c.event_name === "push" || c.event_name === "workflow_dispatch") &&
    (c.ref === "refs/heads/main" || /^refs\/heads\/claude\/[A-Za-z0-9._/-]+$/.test(c.ref)) &&
    typeof c.job_workflow_ref === "string" &&
    c.job_workflow_ref.toLowerCase().startsWith(WORKFLOW) &&
    (c.runner_environment ?? "github-hosted") === "github-hosted"
  );
}

/** APK file names the workflow may upload: solutiontee-cbt-<version>.apk. */
/** App files from the workflow: the APKs (.apk) and the Google Play Console bundle (.aab, D-118). */
export const apkNameOk = (name: unknown): name is string => typeof name === "string" && /^solutiontee-cbt-[0-9][0-9A-Za-z.+-]{0,60}\.(apk|aab)$/.test(name);
