"use server";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";

export type PayStatus = { status: "pending" | "success" | "failed" | "needs_review" | "refunded" | "abandoned" | "unknown"; plan?: string; until?: string | null };

/** A payment's status by its Paystack reference (D-114). The reference is long and random, and only the status, the plan
 *  name and the Premium end date are returned: no name, email or amount. */
export async function payStatus(reference: string): Promise<PayStatus> {
  if (!hasServiceKey() || !/^st_[0-9a-f]{20}$/.test(reference)) return { status: "unknown" };
  const svc = await createServiceClient();
  const { data: p } = await svc.from("payments").select("status, plan_id, entitlement_id").eq("reference", reference).maybeSingle();
  if (!p) return { status: "unknown" };
  const [plan, ent] = await Promise.all([
    p.plan_id ? svc.from("plans").select("name").eq("id", p.plan_id).maybeSingle() : Promise.resolve({ data: null }),
    p.entitlement_id ? svc.from("entitlements").select("expires_at").eq("id", p.entitlement_id).maybeSingle() : Promise.resolve({ data: null }),
  ]);
  return { status: p.status as PayStatus["status"], plan: plan.data?.name ?? undefined, until: ent.data?.expires_at ?? null };
}
