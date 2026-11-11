import { Suspense } from "react";
import type { Metadata } from "next";
import { TutorWeb } from "./tutor-web";

export const metadata: Metadata = { title: "Get a tutor", description: "A real teacher for JAMB, WAEC and NECO: choose a tutor plan and pay safely with Paystack." };

/** cbt.solutiontee.com/tutor (D-152): request a tutor, pick a plan or a custom price, pay with Paystack. */
export default function Page() {
  return (
    <main className="min-h-dvh bg-[radial-gradient(ellipse_at_top,#E8EEF8,transparent_60%)] bg-background px-4 py-8 sm:py-12 dark:bg-[radial-gradient(ellipse_at_top,#0E2348,transparent_60%)]">
      <div className="mx-auto w-full max-w-3xl">
        <Suspense fallback={<div className="h-64 animate-pulse rounded-3xl bg-card" />}>
          <TutorWeb />
        </Suspense>
      </div>
    </main>
  );
}
