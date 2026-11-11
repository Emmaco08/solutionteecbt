import { Suspense } from "react";
import type { Metadata } from "next";
import { ClassDashboard } from "./dashboard";

export const metadata: Metadata = { title: "My classes", description: "Your SolutionTee live classes: join, recordings, materials and assignments." };

/** cbt.solutiontee.com/classes/me (D-148). */
export default function Page() {
  return (
    <main className="min-h-dvh bg-[radial-gradient(ellipse_at_top,#E8EEF8,transparent_60%)] bg-background px-4 py-8 sm:py-12 dark:bg-[radial-gradient(ellipse_at_top,#0E2348,transparent_60%)]">
      <div className="mx-auto w-full max-w-3xl">
        <Suspense fallback={<div className="h-64 animate-pulse rounded-3xl bg-card" />}>
          <ClassDashboard />
        </Suspense>
      </div>
    </main>
  );
}
