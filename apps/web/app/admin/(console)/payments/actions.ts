"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

export type PaymentDetail = {
  payment: {
    id: string; reference: string; provider: string; status: string; amount_kobo: number; list_kobo: number; discount_kobo: number;
    channel: string | null; source: string; created_at: string; verified_at: string | null; refunded_at: string | null;
    plan: string; email: string | null; promo: string | null; premium_until: string | null; premium_revoked: string | null;
  };
  events: { at: string; provider: string; kind: string; ok: boolean; note: string | null }[];
};

const REF = /^st_[0-9a-f]{20}$/;

export async function getPayment(id: string): Promise<ActionResult<PaymentDetail>> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_payment", { p_id: id });
  if (error || !data) return { ok: false, error: error ? friendlyError(error) : "Payment not found" };
  return { ok: true, data: data as unknown as PaymentDetail };
}

/** Calls the paystack Edge Function as the signed-in admin (it checks 2-step login itself). */
async function paystackFn(body: Record<string, unknown>): Promise<ActionResult<Record<string, unknown>>> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("paystack", { body });
  if (error) {
    let msg = error.message;
    try { msg = ((await (error as { context?: Response }).context?.json()) as { error?: string })?.error ?? msg; } catch { /* keep message */ }
    return { ok: false, error: msg };
  }
  return { ok: true, data: data as Record<string, unknown> };
}

export async function checkPayment(reference: string): Promise<ActionResult> {
  if (!REF.test(reference)) return { ok: false, error: "Bad reference" };
  const r = await paystackFn({ action: "check", reference });
  if (!r.ok) return r;
  revalidatePath("/admin/payments");
  return { ok: true, message: `Paystack says: ${String(r.data?.status ?? "unknown")}` };
}

export async function refundPayment(reference: string): Promise<ActionResult> {
  if (!REF.test(reference)) return { ok: false, error: "Bad reference" };
  const r = await paystackFn({ action: "refund", reference });
  if (!r.ok) return r;
  revalidatePath("/admin/payments");
  return { ok: true, message: "Refund asked for. Premium is removed when Paystack finishes it (usually a few days)." };
}
