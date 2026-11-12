import { Suspense } from "react";
import type { Metadata } from "next";
import { TutorWeb } from "./tutor-web";

export const metadata: Metadata = { title: "Get a tutor", description: "A real teacher for JAMB, WAEC and NECO: choose a tutor plan and pay safely with Paystack." };

/** cbt.solutiontee.com/tutor (D-152, D-153 redesign): request a tutor, pick a plan or a custom price, pay with Paystack. */
export default function Page() {
  return (
    <main className="min-h-dvh bg-[#F4F6FA] dark:bg-[#060E1D]">
      <Suspense fallback={<div className="h-48 animate-pulse bg-[#0B1F44]" />}>
        <TutorWeb />
      </Suspense>
    </main>
  );
}
