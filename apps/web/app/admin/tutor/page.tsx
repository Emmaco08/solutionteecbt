import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { AccountMenu } from "@/components/admin/account-menu";
import { ChatApp } from "@/components/tutor-chat/chat-app";
import type { Chat } from "@/components/tutor-chat/lib";
import { TutorProfileButton } from "./profile";

export const metadata: Metadata = { title: "My students" };

export default function Page({ searchParams }: { searchParams: Promise<{ c?: string }> }) {
  return (
    <Suspense fallback={<div className="grid h-dvh place-items-center text-sm text-muted-foreground">Loading your students…</div>}>
      <TutorHome searchParams={searchParams} />
    </Suspense>
  );
}

/** The tutor's dashboard (D-152): their students only, as a full-screen chat app. Admins may open it too. */
async function TutorHome({ searchParams }: { searchParams: Promise<{ c?: string }> }) {
  const staff = await requireStaff(["tutor", "super_admin", "admin"]);
  const { c } = await searchParams;
  const supabase = await createClient();
  const [{ data: chats }, { data: me }] = await Promise.all([
    supabase.rpc("tutor_chats", { p_scope: "mine" }),
    supabase.from("tutors").select("name, subjects, bio, years_teaching, qualification").eq("user_id", staff.id).maybeSingle(),
  ]);
  return (
    <div className="flex h-dvh flex-col bg-background">
      <header className="flex h-14 shrink-0 items-center gap-3 border-b bg-[#0B1F44] px-3 text-white dark:bg-[#060E1D] sm:px-4">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/solutiontee-mark-transparent.png" alt="SolutionTee" className="size-8 rounded-lg bg-white p-0.5" />
        <div className="min-w-0 flex-1">
          <b className="block truncate text-sm">Tutor desk</b>
          <span className="block truncate text-[11px] text-white/70">Your students, live. New messages ping and show at once.</span>
        </div>
        {staff.role === "tutor" ? <TutorProfileButton initial={{ name: me?.name ?? staff.name, subjects: me?.subjects ?? "", bio: me?.bio ?? "", years: me?.years_teaching != null ? String(me.years_teaching) : "", qualification: me?.qualification ?? "" }} /> : null}
        <div className="rounded-full bg-white text-foreground"><AccountMenu name={staff.name} email={staff.email} role={staff.role} /></div>
      </header>
      <ChatApp mode="tutor" initialChats={(chats ?? []) as unknown as Chat[]} initialOpen={c ?? null} className="min-h-0 flex-1" />
    </div>
  );
}
