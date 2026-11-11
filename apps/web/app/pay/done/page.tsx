import { Suspense } from "react";
import type { Metadata } from "next";
import { payStatus } from "./status";
import { PayResult } from "./result";

export const metadata: Metadata = {
  title: "Payment",
  robots: { index: false, follow: false },
};

/**
 * Where Paystack sends the student after paying (Edge Function secret PAYSTACK_CALLBACK_URL, D-061; website D-114).
 * Nothing is decided here: Premium is given by the server after it checks the payment with Paystack. This page shows
 * the result (by the payment reference) or tells an app user to go back to the app.
 */
export default function Page({ searchParams }: { searchParams: Promise<{ reference?: string; trxref?: string }> }) {
  return (
    <main className="grid min-h-dvh place-items-center bg-[radial-gradient(ellipse_at_top,#E8EEF8,transparent_60%)] bg-background px-4 py-10 dark:bg-[radial-gradient(ellipse_at_top,#0E2348,transparent_60%)]">
      <div className="w-full max-w-md">
        <div className="mb-5 flex items-center justify-center gap-2.5">
          {/* Real brand mark from /brand (never redrawn) */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/favicon.svg" alt="" className="size-8 rounded-xl" />
          <span className="text-[16px] font-bold">SolutionTee <span className="text-[#C88A12] dark:text-[#F2B233]">CBT</span></span>
        </div>
        <section className="rounded-3xl border bg-card p-6 shadow-[var(--shadow-2,0_10px_30px_rgba(6,19,43,.08))] sm:p-8">
          <Suspense fallback={<div className="h-72 animate-pulse rounded-2xl bg-muted" />}>
            <Body searchParams={searchParams} />
          </Suspense>
        </section>
        <p className="mt-5 text-center text-xs text-muted-foreground">Payments are processed securely by Paystack.</p>
      </div>
    </main>
  );
}

async function Body({ searchParams }: { searchParams: Promise<{ reference?: string; trxref?: string }> }) {
  const sp = await searchParams;
  const reference = String(sp.reference ?? sp.trxref ?? "");
  if (!/^st_[0-9a-f]{20}$/.test(reference)) {
    return (
      <div className="text-center">
        <h1 className="text-2xl font-bold">Thank you</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          We are checking your payment with Paystack. Close this page to go back to the SolutionTee app. Premium turns on as soon as the payment is confirmed, usually within a minute.
        </p>
        <p className="mt-4 rounded-xl bg-info-soft px-3 py-2 text-sm text-on-info-soft">Paid by bank transfer? It can take a few minutes. You do not need to pay again.</p>
      </div>
    );
  }
  return <PayResult reference={reference} initial={await payStatus(reference)} />;
}
