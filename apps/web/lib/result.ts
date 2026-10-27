export type ActionResult<T = undefined> = { ok: true; data?: T; message?: string } | { ok: false; error: string };

type PgError = { code?: string; message?: string; details?: string; hint?: string } | null | undefined;

/** Turns Postgres / PostgREST errors into simple English for the admin. */
export function friendlyError(e: PgError): string {
  if (!e) return "Something went wrong.";
  const m = e.message ?? "";
  if (e.code === "42501" || /row-level security|permission denied|not_allowed/i.test(m))
    return "You are not allowed to do this, or your 2-step login has expired. Log in again and retry.";
  if (e.code === "23505") return "This already exists (duplicate).";
  if (e.code === "23514") return /answer_in_options/.test(m) ? "The answer must be one of the filled options." : "Some values are not allowed. Check the form.";
  if (e.code === "23503") return "This is still used elsewhere, so it can't be removed.";
  if (m === "unknown_exam_or_subject") return `Unknown exam or subject. ${e.details ?? ""}`.trim();
  if (m === "cannot_ban_staff") return "Remove this person's staff role before banning them.";
  if (m === "reason_required") return "Give a reason (at least 3 characters).";
  if (m === "too_many_rows") return "Too many rows: the limit is 5,000 per import.";
  return m || "Something went wrong.";
}
