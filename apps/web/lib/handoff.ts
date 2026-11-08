import "server-only";
import { createHash, randomBytes } from "node:crypto";

/** One-time app → website sign-in codes (D-115). 256-bit random; only the sha256 is stored. */
export const newHandoffCode = () => randomBytes(32).toString("base64url");
export const hashHandoff = (c: string) => createHash("sha256").update(`handoff:${c}`).digest("hex");
export const HANDOFF_RULE = /^[A-Za-z0-9_-]{43}$/;
