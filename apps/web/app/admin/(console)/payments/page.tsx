import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { Receipt } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, naira } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { PaymentTable, type PaymentRow } from "./payment-table";

export const metadata: Metadata = { title: "Payments" };
const PAGE = 50;

const TABS: { key: string; label: string; status?: string; provider?: string }[] = [
  { key: "all", label: "All" },
  { key: "paystack", label: "Paystack", provider: "paystack" },
  { key: "play", label: "Google Play", provider: "play" },
  { key: "pending", label: "Pending", status: "pending" },
  { key: "review", label: "Needs review", status: "needs_review" },
  { key: "failed", label: "Failed", status: "failed" },
  { key: "refunded", label: "Refunded", status: "refunded" },
];

type Totals = { today_kobo: number; month_kobo: number; success: number; pending: number; review: number; refunded_month_kobo: number };

export default function Page({ searchParams }: PageProps<"/admin/payments">) {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Payments searchParams={searchParams} /></Suspense>;
}

async function Payments({ searchParams }: { searchParams: PageProps<"/admin/payments">["searchParams"] }) {
  await requireStaff(["super_admin", "admin"]);
  const sp = await searchParams;
  const tab = TABS.find((t) => t.key === sp.tab) ?? TABS[0];
  const q = typeof sp.q === "string" ? sp.q.trim().slice(0, 80) : "";
  const page = Math.max(1, Number(sp.page) || 1);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_payments", {
    p_status: tab.status, p_provider: tab.provider, p_q: q || undefined, p_limit: PAGE + 1, p_offset: (page - 1) * PAGE,
  });
  if (error) return <ErrorState message={error.message} />;
  const res = data as unknown as { rows: PaymentRow[]; totals: Totals };
  const rows = res.rows.slice(0, PAGE);
  const t = res.totals;
  return (
    <>
      <PageHeader title="Payments" description="Every Paystack and Google Play payment. Premium is given only after our server has checked the payment with Paystack or Google. Open a payment to see each check." />
      <div className="mb-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[["Paid today", naira(t.today_kobo)], ["Paid this month", naira(t.month_kobo)], ["Waiting (last 24 h)", String(t.pending)],
          [t.review ? "Need your review" : "Refunded this month", t.review ? String(t.review) : naira(t.refunded_month_kobo)]].map(([l, v]) => (
          <div key={l} className="rounded-2xl border bg-card p-4 shadow-[var(--shadow-1)]">
            <span className="text-sm font-bold text-muted-foreground">{l}</span>
            <b className="tnum mt-1 block text-[24px] leading-8">{v}</b>
          </div>
        ))}
      </div>
      <nav className="mb-3 flex gap-1 overflow-x-auto border-b" aria-label="Filter payments">
        {TABS.map((x) => (
          <Link key={x.key} href={`/admin/payments${x.key === "all" ? "" : `?tab=${x.key}`}`}
            className={cn("whitespace-nowrap border-b-2 px-3 py-2.5 text-sm font-bold", x.key === tab.key ? "border-primary text-foreground" : "border-transparent text-muted-foreground hover:text-foreground")}>
            {x.label}{x.key === "review" && t.review ? ` (${t.review})` : ""}
          </Link>
        ))}
      </nav>
      <PaymentTable rows={rows} q={q} page={page} hasNext={res.rows.length > PAGE} tab={tab.key} />
      {!rows.length ? (
        <div className="mt-3 rounded-2xl border bg-card">
          <EmptyState icon={<Receipt />} title={q ? "No payment matches that search" : "No payments here yet"}>
            {q ? "Search by reference (st_…) or the student's email." : "Payments appear here as soon as a student starts a checkout."}
          </EmptyState>
        </div>
      ) : null}
    </>
  );
}
