"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const money = () => requireStaff(["super_admin", "admin"]);

const Paid = z.object({
  claim_id: z.string().regex(/^[0-9a-f-]{36}$/),
  receipt: z.string().regex(/^public\/winners\/[A-Za-z0-9/_.-]+$/, "Upload the transfer receipt first").or(z.literal("")),
  publish: z.boolean(),
  hidden_ok: z.boolean(),
  note: z.string().trim().max(300),
});

/** After paying by bank transfer: mark the claim paid and (optionally) post the receipt on the Winners wall. */
export async function markPaid(form: FormData): Promise<ActionResult> {
  const staff = await money();
  const p = Paid.safeParse({ ...Object.fromEntries(form), publish: form.get("publish") === "on", hidden_ok: form.get("hidden_ok") === "on" });
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const v = p.data;
  if (v.publish && !v.receipt) return { ok: false, error: "Upload the receipt to post it on the Winners wall" };
  if (v.publish && !v.hidden_ok) return { ok: false, error: "Confirm that the account number and balance are hidden on the receipt" };
  const supabase = await createClient();
  const { data: claim, error } = await supabase.from("prize_claims")
    .update({ status: "paid", paid_at: new Date().toISOString(), paid_by: staff.id }).eq("id", v.claim_id).neq("status", "paid")
    .select("id, amount, adult, entry_id").maybeSingle();
  if (error) return { ok: false, error: friendlyError(error) };
  if (!claim) return { ok: false, error: "It is already marked as paid." };
  if (v.publish) {
    const { data: e } = await supabase.from("challenge_entries").select("rank, user_id, challenges(title)").eq("id", claim.entry_id).single();
    const { data: prof } = await supabase.from("profiles").select("full_name, state").eq("id", e?.user_id ?? "").maybeSingle();
    const parts = (prof?.full_name ?? "Winner").trim().split(/\s+/);
    // Minors are shown by first name only (D-033).
    const name = claim.adult && parts.length > 1 ? `${parts[0]} ${parts[parts.length - 1][0].toUpperCase()}.` : parts[0];
    const place = e?.rank === 1 ? "1st place" : e?.rank === 2 ? "2nd place" : e?.rank === 3 ? "3rd place" : `#${e?.rank} place`;
    const title = (e?.challenges as unknown as { title: string } | null)?.title ?? "Challenge";
    const { error: e2 } = await supabase.from("winners_wall").insert({
      claim_id: claim.id, challenge_title: title, name, state: prof?.state ?? null, place, amount: claim.amount, receipt_path: v.receipt, note: v.note || null,
    });
    if (e2) return { ok: false, error: `Marked paid, but the Winners wall post failed: ${friendlyError(e2)}` };
  }
  revalidatePath("/admin/winners");
  return { ok: true, message: v.publish ? "Marked paid and posted on the Winners wall." : "Marked paid." };
}

export async function rejectClaim(claimId: string, note: string): Promise<ActionResult> {
  await money();
  const supabase = await createClient();
  const { error } = await supabase.from("prize_claims").update({ status: "rejected", admin_note: note.slice(0, 500) || null }).eq("id", claimId).neq("status", "paid");
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/winners");
  return { ok: true, message: "Claim rejected." };
}

export async function setWallPost(id: string, published: boolean): Promise<ActionResult> {
  await money();
  const supabase = await createClient();
  const { error } = await supabase.from("winners_wall").update({ published }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/winners");
  return { ok: true, message: published ? "Shown on the Winners wall." : "Hidden from the Winners wall." };
}

/** Prize payout by Paystack Transfer (D-090): "check" asks Paystack whose account it is, "send" sends the money,
 *  "verify" asks how it went. The paystack Edge Function checks that this admin has 2-step login. */
export async function payout(claimId: string, step: "check" | "send" | "verify"): Promise<ActionResult<{ verified_name?: string; status?: string }>> {
  await money();
  if (!/^[0-9a-f-]{36}$/.test(claimId)) return { ok: false, error: "Bad claim" };
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("paystack", { body: { action: `payout_${step}`, claim_id: claimId } });
  if (error) {
    let msg = "Paystack did not answer. Try again.";
    try { msg = (await (error as { context?: Response }).context?.json())?.error ?? msg; } catch { /* keep the default */ }
    return { ok: false, error: msg };
  }
  revalidatePath("/admin/winners");
  const d = (data ?? {}) as { verified_name?: string; status?: string };
  return {
    ok: true, data: d,
    message: step === "check" ? `Paystack says the account belongs to ${d.verified_name}.`
      : d.status === "sent" ? "Sent. The winner has been told." : d.status === "failed" ? "Paystack could not send it. See the reason below."
      : "Sent to Paystack. It usually arrives within minutes; this page updates when Paystack confirms.",
  };
}
