import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { PaymentSettingsForm, type FeeCheck, type PaySettings } from "./form";
import { PaystackKeys, type KeysState, type ServerState } from "./keys";
import { env } from "@/lib/env";

export const metadata: Metadata = { title: "Payment settings" };

const DEFAULTS: PaySettings = {
  play: { google: true, website: false },
  website_url: "https://cbt.solutiontee.com/pay",
  fees: { paystack: { on: false, mode: "none", pct: 1.5, flat: 100, flat_from: 2500, cap: 2000 }, google: { on: false, pct: 15 } },
};

/** Settings saved before D-132 have only "on". */
function withMode(p: PaySettings["fees"]["paystack"]): PaySettings["fees"]["paystack"] {
  return { ...p, mode: p.mode ?? (p.on ? "ours" : "none") };
}

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Settings /></Suspense>;
}

async function Settings() {
  const me = await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [s, plans, flag, checks, keys, server] = await Promise.all([
    supabase.from("app_settings").select("key, value").in("key", ["payments", "site"]),
    supabase.from("plans").select("name, price_kobo, play_product_id_fee, is_active").order("sort"),
    supabase.from("feature_flags").select("enabled").eq("key", "codes_in_play_build").maybeSingle(),
    supabase.rpc("admin_paystack_fee_check"),
    supabase.rpc("admin_paystack_keys"),
    // What the payment server uses right now (mode and key kinds only, never a key).
    fetch(`${env.supabaseUrl}/functions/v1/paystack?health=1`, { cache: "no-store", signal: AbortSignal.timeout(8000) })
      .then((r) => (r.ok ? (r.json() as Promise<ServerState>) : null)).catch(() => null),
  ]);
  if (s.error || plans.error) return <ErrorState message={(s.error ?? plans.error)!.message} />;
  const byKey = Object.fromEntries((s.data ?? []).map((r) => [r.key, r.value]));
  const v = (byKey.payments ?? {}) as Partial<PaySettings>;
  const playUrl = String((byKey.site as { play_url?: string } | undefined)?.play_url ?? "");
  const initial: PaySettings = {
    play: { ...DEFAULTS.play, ...(v.play ?? {}) },
    website_url: v.website_url ?? DEFAULTS.website_url,
    fees: { paystack: withMode({ ...DEFAULTS.fees.paystack, ...(v.fees?.paystack ?? {}) }), google: { ...DEFAULTS.fees.google, ...(v.fees?.google ?? {}) } },
  };
  return (
    <>
      <PageHeader title="Payment settings" description="How students pay in the Google Play app, and whether processing fees are added. Changes reach phones the next time the app opens; no app update needed." />
      {keys.data ? (
        <div className="mb-6"><PaystackKeys initial={keys.data as KeysState} server={server} canEdit={me.role === "super_admin"} /></div>
      ) : null}
      <PaymentSettingsForm initial={initial} checks={(checks.data as FeeCheck[] | null) ?? []} playUrl={playUrl} playCodes={flag.data?.enabled === true} plans={(plans.data ?? []).filter((p) => p.is_active).map((p) => ({ name: p.name, price: p.price_kobo / 100, fee_id: p.play_product_id_fee }))} />
    </>
  );
}
