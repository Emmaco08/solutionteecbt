import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { PaymentSettingsForm, type PaySettings } from "./form";

export const metadata: Metadata = { title: "Payment settings" };

const DEFAULTS: PaySettings = {
  play: { google: true, website: false },
  website_url: "https://cbt.solutiontee.com/pay",
  fees: { paystack: { on: false, pct: 1.5, flat: 100, flat_from: 2500, cap: 2000 }, google: { on: false, pct: 15 } },
};

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Settings /></Suspense>;
}

async function Settings() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [s, plans] = await Promise.all([
    supabase.from("app_settings").select("value").eq("key", "payments").maybeSingle(),
    supabase.from("plans").select("name, price_kobo, play_product_id_fee, is_active").order("sort"),
  ]);
  if (s.error || plans.error) return <ErrorState message={(s.error ?? plans.error)!.message} />;
  const v = (s.data?.value ?? {}) as Partial<PaySettings>;
  const initial: PaySettings = {
    play: { ...DEFAULTS.play, ...(v.play ?? {}) },
    website_url: v.website_url ?? DEFAULTS.website_url,
    fees: { paystack: { ...DEFAULTS.fees.paystack, ...(v.fees?.paystack ?? {}) }, google: { ...DEFAULTS.fees.google, ...(v.fees?.google ?? {}) } },
  };
  return (
    <>
      <PageHeader title="Payment settings" description="How students pay in the Google Play app, and whether processing fees are added. Changes reach phones the next time the app opens; no app update needed." />
      <PaymentSettingsForm initial={initial} plans={(plans.data ?? []).filter((p) => p.is_active).map((p) => ({ name: p.name, price: p.price_kobo / 100, fee_id: p.play_product_id_fee }))} />
    </>
  );
}
