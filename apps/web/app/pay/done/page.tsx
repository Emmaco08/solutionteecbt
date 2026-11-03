import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Payment received",
  robots: { index: false, follow: false },
};

/**
 * Where Paystack sends the student after paying (Edge Function secret PAYSTACK_CALLBACK_URL, D-061).
 * Nothing is decided here: Premium is given by the server after it checks the payment with Paystack.
 * The page only tells the student to go back to the app, which checks the payment when it reopens.
 */
export default function Page() {
  return (
    <main className="grid min-h-dvh place-items-center bg-[var(--c-bg)] px-4 py-10">
      <section className="w-full max-w-md rounded-3xl border bg-card p-6 text-center shadow-sm">
        {/* Real brand mark from /brand (never redrawn) */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/favicon.svg" alt="" className="mx-auto mb-4 size-16 rounded-2xl" />
        <h1 className="text-2xl font-bold">Thank you</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          We are checking your payment with Paystack. Close this page to go back to the SolutionTee app. Premium turns on as soon as the payment is confirmed, usually within a minute.
        </p>
        <p className="mt-4 rounded-xl bg-info-soft px-3 py-2 text-sm text-on-info-soft">
          Paid by bank transfer? It can take a few minutes. You do not need to pay again.
        </p>
      </section>
    </main>
  );
}
