"use server";
import { createServiceClient } from "@/lib/supabase/server";
import { env, hasServiceKey } from "@/lib/env";

export type PayStatus = {
  status: "pending" | "success" | "failed" | "needs_review" | "refunded" | "abandoned" | "unknown";
  plan?: string; until?: string | null; amount_kobo?: number; paid_at?: string | null; kind?: "plan" | "xp" | "item" | "class";
};

const REF = /^st_[0-9a-f]{20}$/;

/** Asks the payment server to check this reference with Paystack now (D-129). Works without a login, so the result
 *  page never waits for Paystack's webhook or for the student's session. Errors are ignored: the database answer stands. */
async function confirmWithPaystack(reference: string) {
  try {
    await fetch(`${env.supabaseUrl}/functions/v1/paystack`, {
      method: "POST",
      headers: { "content-type": "application/json", apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "" },
      body: JSON.stringify({ action: "status", reference }),
      cache: "no-store",
      signal: AbortSignal.timeout(15_000),
    });
  } catch {}
}

/** A payment's status by its Paystack reference (D-114, D-129). The reference is long and random, and only the status,
 *  the plan name, the Premium end date and the amount are returned: no name or email. */
export async function payStatus(reference: string): Promise<PayStatus> {
  if (!hasServiceKey() || !REF.test(reference)) return { status: "unknown" };
  const svc = await createServiceClient();
  const read = () => svc.from("payments").select("status, provider, plan_id, entitlement_id, amount_kobo, xp_pack, item_kind, verified_at").eq("reference", reference).maybeSingle();
  let { data: p } = await read();
  if (!p) return { status: "unknown" };
  if (p.provider === "paystack" && ["pending", "abandoned", "failed"].includes(String(p.status))) {
    await confirmWithPaystack(reference);
    p = (await read()).data ?? p;
  }
  const [plan, ent] = await Promise.all([
    p.plan_id ? svc.from("plans").select("name").eq("id", p.plan_id).maybeSingle() : Promise.resolve({ data: null }),
    p.entitlement_id ? svc.from("entitlements").select("expires_at").eq("id", p.entitlement_id).maybeSingle() : Promise.resolve({ data: null }),
  ]);
  const kind = p.xp_pack ? "xp" : p.item_kind === "class" ? "class" : p.item_kind ? "item" : "plan";
  return {
    status: p.status as PayStatus["status"], plan: plan.data?.name ?? undefined, until: ent.data?.expires_at ?? null,
    amount_kobo: Number(p.amount_kobo ?? 0), paid_at: p.status === "success" ? (p.verified_at ?? null) : null, kind,
  };
}
