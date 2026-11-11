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
