import "server-only";
import { createHash, randomBytes } from "node:crypto";

/** One-time link token for the parent/guardian "turn off" page (D-109). Only its sha256 is stored. */
export const newGuardianToken = () => randomBytes(32).toString("base64url");
export const hashGuardianToken = (t: string) => createHash("sha256").update(t).digest("hex");

/** Age from the year of birth only (what the app asks). */
export const ageFromYear = (year: number) => new Date().getFullYear() - year;

/** "t•••@gmail.com" */
export const maskEmail = (e: string) => e.replace(/^(.).*(@.*)$/, "$1•••$2");
