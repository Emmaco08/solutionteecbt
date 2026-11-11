import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { ClassesPageForm, type ClassesPageText } from "./page-text";
import { ClassList, type AdminClass } from "./classes-ui";

export const metadata: Metadata = { title: "Online classes" };

/** Classes from the last 60 days and all later ones. */
function sixtyDaysAgo() {
  return new Date(new Date().getTime() - 60 * 86400000).toISOString();
}

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Classes /></Suspense>;
}

async function Classes() {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const since = sixtyDaysAgo();
  const [list, links, regs, cat, pageText] = await Promise.all([
    supabase.from("classes").select("*").gte("starts_at", since).order("starts_at"),
    supabase.from("class_links").select("class_id, join_url, recording_url"),
    supabase.from("class_registrations").select("class_id, joined_at, payment_id"),
    getCatalogue(),
    supabase.from("app_settings").select("value").eq("key", "jamb_classes").maybeSingle(),
  ]);
  const pt = (pageText.data?.value ?? {}) as Partial<ClassesPageText>;
  if (list.error) return <ErrorState message={list.error.message} />;
  const linkMap = new Map((links.data ?? []).map((l) => [l.class_id, l]));
  const count = new Map<string, { reg: number; joined: number; paid: number }>();
  for (const r of regs.data ?? []) {
    const c = count.get(r.class_id) ?? { reg: 0, joined: 0, paid: 0 };
    c.reg++; if (r.joined_at) c.joined++; if (r.payment_id) c.paid++;
    count.set(r.class_id, c);
  }
  const rows = (list.data ?? []).map((c) => ({ ...c, join_url: linkMap.get(c.id)?.join_url ?? null, recording_url: linkMap.get(c.id)?.recording_url ?? null, counts: count.get(c.id) ?? { reg: 0, joined: 0, paid: 0 } })) as AdminClass[];
  return (
    <>
      <PageHeader title="Online classes" description="Live classes as Free, Premium or Paid. The class link is never shown in the app list: the server gives it only to students who may join, from 15 minutes before the start. Registered students get reminders 2 h, 1 h, 30, 10 and 3 minutes before, at the start, and 10 minutes in if they have not joined." />
      <ClassList classes={rows} subjects={cat.subjects} exams={cat.exams.map((e) => e.code)} />
      <Panel title="Website page: cbt.solutiontee.com/classes" className="mt-4">
        <ClassesPageForm initial={{ on: pt.on !== false, title: pt.title ?? "JAMB classes with real teachers", intro: pt.intro ?? "", price_note: pt.price_note ?? "", teachers: pt.teachers ?? [], faq: pt.faq ?? [] }} />
      </Panel>
    </>
  );
}
