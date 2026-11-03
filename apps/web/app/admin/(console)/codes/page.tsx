import { Suspense } from "react";
import type { Metadata } from "next";
import { GooglePlayLogo, Ticket } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel, naira } from "@/components/admin/ui";
import { CodeForm, CodeRows, type CodeRow } from "./code-ui";

export const metadata: Metadata = { title: "Redeem codes" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Codes /></Suspense>;
}

async function Codes() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [{ data, error }, plans] = await Promise.all([
    supabase.rpc("admin_codes"),
    supabase.from("plans").select("id, name").order("sort"),
  ]);
  if (error || plans.error) return <ErrorState message={(error ?? plans.error)!.message} />;
  const res = data as unknown as { rows: CodeRow[]; totals: { active: number; used_month: number; discount_month_kobo: number } };
  return (
    <>
      <PageHeader title="Redeem codes" description="Give students a discount or free Premium days. The server checks every code when it is used: dates, uses left, one use per student and which plans it works on." />
      <div className="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
        {[["Active codes", String(res.totals.active)], ["Used this month", String(res.totals.used_month)], ["Discount given this month", naira(res.totals.discount_month_kobo)]].map(([l, v]) => (
          <div key={l} className="rounded-2xl border bg-card p-4 shadow-[var(--shadow-1)]"><span className="text-sm font-bold text-muted-foreground">{l}</span><b className="tnum mt-1 block text-[24px] leading-8">{v}</b></div>
        ))}
      </div>
      <p className="mb-4 flex gap-3 rounded-2xl bg-info-soft px-4 py-3 text-sm text-on-info-soft">
        <GooglePlayLogo size={20} weight="fill" className="mt-0.5 flex-none" />
        <span><b>Where codes work:</b> discount codes work for Paystack payments (website and the APK from the website). In the Play Store app, Google allows only Google Play promo codes for discounts; create those in Play Console. Free-day codes are typed in the app under Me, then Redeem a code.</span>
      </p>
      <div className="grid gap-4 xl:grid-cols-[1.1fr_1fr]">
        <Panel title="Create codes"><CodeForm plans={plans.data ?? []} /></Panel>
        <Panel title="Codes" bodyClassName="p-0">
          {res.rows.length ? <CodeRows rows={res.rows} plans={plans.data ?? []} /> : (
            <EmptyState icon={<Ticket />} title="No codes yet">Create a shared code for a school or a WhatsApp group, or a batch of one-use codes for class reps.</EmptyState>
          )}
        </Panel>
      </div>
    </>
  );
}
