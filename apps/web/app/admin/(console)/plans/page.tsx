import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Pill, naira } from "@/components/admin/ui";
import { PlanCard } from "./plan-card";

export const metadata: Metadata = { title: "Plans & prices" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Plans /></Suspense>;
}

async function Plans() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.from("plans").select("*").order("sort");
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader title="Plans & prices" description="Premium plans students can buy. Paystack charges the price set here. For the Play Store app, also set the same price on the product in Google Play Console (the product ID links them)." />
      {data.some((p) => p.description?.startsWith("SAMPLE")) ? (
        <p className="mb-4 rounded-2xl bg-warning-soft px-4 py-3 text-sm text-on-warning-soft"><b>These are still the SAMPLE prices from the design.</b> Confirm or change them before launch, then remove the word SAMPLE from the description.</p>
      ) : null}
      <div className="grid gap-4 lg:grid-cols-3">
        {data.map((p) => (
          <PlanCard key={p.id} plan={{ ...p, price_naira: p.price_kobo / 100 }} badge={<Pill tone={p.is_active ? "ok" : "neutral"}>{p.is_active ? "On sale" : "Hidden"}</Pill>} priceLabel={naira(p.price_kobo)} />
        ))}
      </div>
    </>
  );
}
