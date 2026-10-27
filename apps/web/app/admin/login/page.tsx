import { Suspense } from "react";
import type { Metadata } from "next";
import { AuthFrame, FormSkeleton } from "@/components/admin/auth-frame";
import { noStaffYet } from "@/lib/setup";
import { LoginForm, SetupForm } from "./forms";

export const metadata: Metadata = { title: "Admin login" };

const ERRORS: Record<string, string> = {
  not_staff: "This account is not on the admin team. Ask a super admin to invite you.",
  signed_out: "You have been signed out.",
};

export default function Page({ searchParams }: PageProps<"/admin/login">) {
  return (
    <Suspense fallback={<AuthFrame title="Welcome back"><FormSkeleton /></AuthFrame>}>
      <Gate searchParams={searchParams} />
    </Suspense>
  );
}

async function Gate({ searchParams }: { searchParams: PageProps<"/admin/login">["searchParams"] }) {
  const sp = await searchParams;
  const e = typeof sp.e === "string" ? sp.e : "";
  const next = typeof sp.next === "string" && sp.next.startsWith("/admin") ? sp.next : "/admin";
  if (await noStaffYet()) {
    return (
      <AuthFrame title="Set up your admin account" subtitle="No admin exists yet. Create the first super admin. This form disappears once it is done.">
        <SetupForm />
      </AuthFrame>
    );
  }
  return (
    <AuthFrame title="Welcome back" subtitle="Log in to the SolutionTee admin. You will confirm with your authenticator app next.">
      <LoginForm notice={ERRORS[e]} next={next} />
    </AuthFrame>
  );
}
