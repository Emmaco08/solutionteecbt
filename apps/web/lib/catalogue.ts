import "server-only";
import { createClient } from "@/lib/supabase/server";

export type Exam = { id: number; code: string; name: string; logo_path: string | null };
export type Subject = { id: number; code: string; name: string };

/** Exams and subjects (small, read on most content pages). */
export async function getCatalogue() {
  const supabase = await createClient();
  const [exams, subjects] = await Promise.all([
    supabase.from("exam_bodies").select("id, code, name, logo_path").order("sort"),
    supabase.from("subjects").select("id, code, name").order("sort"),
  ]);
  return { exams: (exams.data ?? []) as Exam[], subjects: (subjects.data ?? []) as Subject[] };
}

export const STATUS_TONE = { draft: "neutral", review: "warn", published: "ok" } as const;
export const STATUS_LABEL = { draft: "Draft", review: "Needs review", published: "Published" } as const;
