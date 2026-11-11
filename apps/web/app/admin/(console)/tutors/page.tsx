import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { ChatApp } from "@/components/tutor-chat/chat-app";
import type { Chat, TutorOpt } from "@/components/tutor-chat/lib";
import { TutorAdmin } from "./tutors-ui";

export const metadata: Metadata = { title: "Tutor requests" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Tutors /></Suspense>;
}

async function Tutors() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [chats, tutors, plans] = await Promise.all([
    supabase.rpc("tutor_chats", { p_scope: "all" }),
    supabase.from("tutors").select("*").order("name"),
    supabase.from("tutor_plans").select("*").order("sort").order("price_kobo"),
  ]);
  return (
    <>
      <PageHeader title="Tutor requests"
        description="Students pick a plan (or ask for a custom one) and pay; you get a push and an email. Assign a tutor within 24 hours: the tutor gets an email and chats with the student from their own dashboard. You can read and join any chat here." />
      <div className="mb-4 overflow-hidden rounded-2xl border shadow-[var(--shadow-1)]">
        <ChatApp mode="admin" initialChats={(chats.data ?? []) as unknown as Chat[]} tutors={(tutors.data ?? []) as TutorOpt[]} className="h-[calc(100dvh-12rem)] min-h-[560px]" />
      </div>
      <p className="mb-4 text-sm text-muted-foreground">Tutors sign in at <Link className="underline" href="/admin/tutor">admin.solutiontee.com/admin/tutor</Link>. Invite a tutor in <Link className="underline" href="/admin/staff">Staff</Link> with the Tutor role.</p>
      <TutorAdmin tutors={tutors.data ?? []} plans={plans.data ?? []} />
    </>
  );
}
