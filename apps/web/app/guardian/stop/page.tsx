import { Suspense } from "react";
import type { Metadata } from "next";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { hashGuardianToken, maskEmail } from "@/lib/guardian";
import { StopButton } from "./stop-button";

export const metadata: Metadata = {
  title: "Turn off your child's account",
  robots: { index: false, follow: false },
};

/** Opened from the parent/guardian notice email (D-109). Shows whose account it is, then one button. */
export default function Page({
  searchParams,
}: {
  searchParams: Promise<{ t?: string }>;
}) {
  return (
    <main className="grid min-h-dvh place-items-center bg-[var(--c-bg)] px-4 py-10">
      <Suspense
        fallback={
          <div className="h-80 w-full max-w-md animate-pulse rounded-3xl bg-card" />
        }
      >
        <Body searchParams={searchParams} />
      </Suspense>
    </main>
  );
}

async function Body({
  searchParams,
}: {
  searchParams: Promise<{ t?: string }>;
}) {
  const { t = "" } = await searchParams;
  let child: { name: string; email: string; off: boolean } | null = null;
  if (hasServiceKey() && /^[A-Za-z0-9_-]{30,80}$/.test(t)) {
    const svc = await createServiceClient();
    const { data: row } = await svc
      .from("guardian_consents")
      .select("user_id, withdrawn_at")
      .eq("token_hash", hashGuardianToken(t))
      .maybeSingle();
    if (row) {
      const [{ data: p }, { data: u }] = await Promise.all([
        svc
          .from("profiles")
          .select("full_name")
          .eq("id", row.user_id)
          .maybeSingle(),
        svc.auth.admin.getUserById(row.user_id),
      ]);
      child = {
        name: String(p?.full_name ?? "").split(" ")[0] || "your child",
        email: maskEmail(u.user?.email ?? ""),
        off: !!row.withdrawn_at,
      };
    }
  }
  return (
    <section className="w-full max-w-md rounded-3xl border bg-card p-6 text-center shadow-sm">
      {/* Real brand mark from /brand (never redrawn) */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/favicon.svg"
        alt=""
        className="mx-auto mb-4 size-16 rounded-2xl"
      />
      {!child ? (
        <>
          <h1 className="text-2xl font-bold">Link not valid</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            This link is not valid or the account no longer exists. Reply to our
            email if you need help.
          </p>
        </>
      ) : child.off ? (
        <>
          <h1 className="text-2xl font-bold">Account turned off</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            {child.name}&apos;s account ({child.email}) is turned off and will
            be deleted 30 days after you turned it off.
          </p>
        </>
      ) : (
        <>
          <h1 className="text-2xl font-bold">
            Turn off {child.name}&apos;s account?
          </h1>
          <p className="mt-2 text-sm text-muted-foreground">
            Account: <b>{child.email}</b>. {child.name} will not be able to log
            in any more, and the account and its data will be deleted after 30
            days.
          </p>
          <p className="mt-3 text-sm text-muted-foreground">
            If you are happy for {child.name} to keep practising, you can simply
            close this page. You do not need to do anything.
          </p>
          <StopButton token={t} name={child.name} />
        </>
      )}
      <p className="mt-6 text-xs leading-5 text-muted-foreground">
        SolutionTee CBT is an independent exam-practice platform and is not
        affiliated with or endorsed by JAMB, WAEC or NECO.
      </p>
    </section>
  );
}
