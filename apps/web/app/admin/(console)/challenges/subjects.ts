import type { createClient } from "@/lib/supabase/server";

/** JAMB subjects in their usual order (for challenge forms, pools and CSV checks). */
export async function jambSubjects(supabase: Awaited<ReturnType<typeof createClient>>) {
  const { data } = await supabase.from("exam_subjects").select("subjects(id, name, sort), exam_bodies!inner(code)").eq("exam_bodies.code", "JAMB");
  return ((data ?? []) as unknown as { subjects: { id: number; name: string; sort: number } | null }[])
    .map((x) => x.subjects).filter((x): x is { id: number; name: string; sort: number } => !!x)
    .sort((a, b) => a.sort - b.sort || a.name.localeCompare(b.name)).map(({ id, name }) => ({ id, name }));
}
