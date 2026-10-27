import { Suspense } from "react";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AuthFrame, FormSkeleton } from "@/components/admin/auth-frame";
import { createClient } from "@/lib/supabase/server";
import { MfaForm } from "./mfa-form";

export const metadata: Metadata = { title: "2-step login" };

export default function Page({ searchParams }: PageProps<"/admin/mfa">) {
  return (
    <Suspense fallback={<AuthFrame title="2-step login"><FormSkeleton /></AuthFrame>}>
      <Gate searchParams={searchParams} />
    </Suspense>
  );
}

async function Gate({ searchParams }: { searchParams: PageProps<"/admin/mfa">["searchParams"] }) {
  const sp = await searchParams;
  const next = typeof sp.next === "string" && sp.next.startsWith("/admin") ? sp.next : "/admin";
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const uid = data?.claims?.sub;
  if (!uid) redirect("/admin/login");

  // Only staff may continue (students who find this page are signed out).
  const { data: staff } = await supabase.from("staff").select("role").eq("user_id", uid).maybeSingle();
  if (!staff) {
    await supabase.auth.signOut();
    redirect("/admin/login?e=not_staff");
  }
  if (data?.claims?.aal === "aal2") redirect(next);

  return (
    <AuthFrame title="2-step login" subtitle="Every admin uses an authenticator app (Google Authenticator or Microsoft Authenticator). It protects students' data even if a password leaks.">
      <MfaForm next={next} />
    </AuthFrame>
  );
}
