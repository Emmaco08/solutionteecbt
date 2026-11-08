import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { DeleteFlow } from "./delete-flow";

export const metadata: Metadata = {
  title: "Delete your account",
  description: "Delete your SolutionTee CBT account and data, with or without the app.",
};

/** cbt.solutiontee.com/delete-account (Google Play account deletion requirement, D-118). */
export default function Page() {
  return (
    <main className="min-h-dvh bg-background px-4 py-10">
      <div className="mx-auto max-w-xl">
        <Link href="/" className="mb-6 flex items-center gap-2.5" aria-label="SolutionTee CBT home">
          {/* Real brand mark from /brand (never redrawn) */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
          <span className="text-[17px] font-bold">SolutionTee CBT</span>
        </Link>
        <h1 className="text-[30px] font-bold leading-tight tracking-tight">Delete your SolutionTee CBT account</h1>
        <div className="mt-4 space-y-3 text-[15px] leading-7 text-muted-foreground">
          <p><b className="text-foreground">In the app:</b> Me → Settings → Delete account.</p>
          <p><b className="text-foreground">Without the app:</b> use the form below. We email a code to the address on your account to make sure it is you.</p>
          <p><b className="text-foreground">What is deleted:</b> your account, profile, practice history, results, XP, streaks, bookmarks, AI tutor chats and photos, and notifications, within 30 days (most of it at once).</p>
          <p><b className="text-foreground">What we keep:</b> payment and tax records for at least 6 years, as the law requires, separated from your details; and one-way coded phone identifiers of banned accounts for up to 2 years, so banned accounts cannot come back. Unused Premium time, XP and items are lost.</p>
          <p>Questions? Email <a className="underline" href="mailto:privacy@solutiontee.com">privacy@solutiontee.com</a>. See also our <Link className="underline" href="/privacy">Privacy Policy</Link>.</p>
        </div>
        <Suspense fallback={<div className="mt-8 h-64 animate-pulse rounded-3xl bg-card" />}>
          <DeleteFlow />
        </Suspense>
      </div>
    </main>
  );
}
