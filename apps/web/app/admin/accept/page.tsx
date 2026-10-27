import { Suspense } from "react";
import type { Metadata } from "next";
import { AuthFrame, FormSkeleton } from "@/components/admin/auth-frame";
import { AcceptForm } from "./accept-form";

export const metadata: Metadata = { title: "Set your password" };

export default function Page({ searchParams }: PageProps<"/admin/accept">) {
  return (
    <AuthFrame title="Set your password" subtitle="You were invited to the SolutionTee admin team, or asked for a reset. Choose a strong password to continue.">
      <Suspense fallback={<FormSkeleton />}>
        <Inner searchParams={searchParams} />
      </Suspense>
    </AuthFrame>
  );
}

async function Inner({ searchParams }: { searchParams: PageProps<"/admin/accept">["searchParams"] }) {
  const sp = await searchParams;
  const tokenHash = typeof sp.token_hash === "string" ? sp.token_hash : "";
  const type = sp.type === "recovery" ? "recovery" : "invite";
  return <AcceptForm tokenHash={tokenHash} type={type} />;
}
