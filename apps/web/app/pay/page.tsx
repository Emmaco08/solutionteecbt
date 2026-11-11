import { Suspense } from "react";
import type { Metadata } from "next";
import { PayFlow } from "./pay-flow";

export const metadata: Metadata = {
  title: "Get Premium",
  description: "Pay for SolutionTee Premium with card, bank transfer, USSD or OPay. Log in with the email you use in the app.",
};

/** cbt.solutiontee.com/pay (D-114). */
export default function Page() {
  return (
    <main className="grid min-h-dvh place-items-center bg-[radial-gradient(ellipse_at_top,#E8EEF8,transparent_60%)] bg-background px-4 py-6 sm:py-10 dark:bg-[radial-gradient(ellipse_at_top,#0E2348,transparent_60%)]">
      <Suspense fallback={<div className="h-96 w-full max-w-5xl animate-pulse rounded-3xl bg-card" />}>
        <PayFlow />
      </Suspense>
    </main>
  );
}
