import "server-only";
import { cacheLife, cacheTag } from "next/cache";
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@solutiontee/shared/database";
import { env } from "@/lib/env";

export type PublicClass = { id: string; title: string; about: string | null; subject: string | null; exam: string | null; teacher: string; starts_at: string; minutes: number; access: "free" | "premium" | "paid"; price_kobo: number | null; seats_left: number | null };
export type Teacher = { name: string; subject?: string; bio?: string };
export type ClassesPage = { on: boolean; title: string; intro: string; price_note: string; teachers: Teacher[]; faq: { q: string; a: string }[] };

const DEFAULTS: ClassesPage = { on: true, title: "JAMB classes with real teachers", intro: "", price_note: "", teachers: [], faq: [] };

/** The public timetable and the page text (no login, no class links). */
export async function classesPageData(): Promise<{ page: ClassesPage; classes: PublicClass[] }> {
  "use cache";
  cacheLife("minutes");
  cacheTag("classes"); // admin → Online classes refreshes it at once
  const sb = createClient<Database>(env.supabaseUrl, env.supabasePublishableKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const [cls, cfg] = await Promise.all([sb.rpc("public_classes"), sb.from("app_settings").select("value").eq("key", "jamb_classes").maybeSingle()]);
  const v = (cfg.data?.value ?? {}) as Partial<ClassesPage>;
  return {
    page: { ...DEFAULTS, ...v, teachers: Array.isArray(v.teachers) ? v.teachers : [], faq: Array.isArray(v.faq) ? v.faq : [] },
    classes: ((cls.data ?? []) as unknown as PublicClass[]),
  };
}

export const ngn = (kobo: number) => `₦${(kobo / 100).toLocaleString("en-NG")}`;
export const lagosWhen = (iso: string) =>
  new Date(iso).toLocaleString("en-NG", { timeZone: "Africa/Lagos", weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });

// ---------------------------------------------------------------- programmes (classes v2, D-163)

export type ProgramSession = { id: string; title: string; starts_at: string; minutes: number };
export type PublicProgram = {
  id: string; slug: string; title: string; tagline: string | null; flyer_path: string | null; exam: string | null; subjects: string | null;
  teacher: string | null; teacher_photo: string | null; schedule_note: string | null; access: "free" | "premium" | "paid";
  price_kobo: number | null; compare_kobo: number | null; starts_on: string | null; ends_on: string | null; status: string;
  seats_left: number | null; buyable: boolean; sessions_left: number; sessions_done: number;
  next: { id: string; title: string; starts_at: string; minutes: number; live: boolean } | null;
};
export type ProgramPage = PublicProgram & {
  about: string | null; highlights: string[]; teacher_bio: string | null; faq: { q: string; a: string }[]; sessions: ProgramSession[];
};

const anon = () => createClient<Database>(env.supabaseUrl, env.supabasePublishableKey, { auth: { persistSession: false, autoRefreshToken: false } });

/** Paid programmes on sale, for cbt.solutiontee.com/classes (no login). */
export async function programsData(): Promise<PublicProgram[]> {
  "use cache";
  cacheLife("minutes");
  cacheTag("classes");
  const { data } = await anon().rpc("public_programs");
  return (data ?? []) as unknown as PublicProgram[];
}

/** One programme's full page by its short link. */
export async function programData(slug: string): Promise<ProgramPage | null> {
  "use cache";
  cacheLife("minutes");
  cacheTag("classes");
  const { data } = await anon().rpc("public_program", { p_slug: slug });
  return (data ?? null) as unknown as ProgramPage | null;
}

/** The website link of a class picture (signed by /classes/img; the bucket stays private). */
export const classImg = (key: string | null | undefined) => (key ? `/classes/img?k=${encodeURIComponent(key)}` : null);
export const lagosDate = (iso: string) => new Date(iso).toLocaleDateString("en-NG", { timeZone: "Africa/Lagos", day: "numeric", month: "short", year: "numeric" });
