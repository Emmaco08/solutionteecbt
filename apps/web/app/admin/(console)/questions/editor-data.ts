import "server-only";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";

/** Lists the editor needs: exams, subjects, passages and known topics. */
export async function editorLists() {
  const supabase = await createClient();
  const [{ exams, subjects }, passages, topics] = await Promise.all([
    getCatalogue(),
    supabase.from("passages").select("id, title, year, exam_bodies(code), subjects(name)").order("created_at", { ascending: false }).limit(300),
    supabase.from("topics").select("name").order("name").limit(2000),
  ]);
  return {
    exams: exams.map((e) => ({ id: e.id, code: e.code, name: e.name })),
    subjects: subjects.map((s) => ({ id: s.id, code: s.code, name: s.name })),
    passages: (passages.data ?? []).map((p) => ({
      id: p.id,
      label: `${(p.exam_bodies as unknown as { code: string } | null)?.code ?? ""} ${p.year ?? ""} ${(p.subjects as unknown as { name: string } | null)?.name ?? ""}: ${p.title || "Untitled passage"}`.trim(),
    })),
    topics: [...new Set((topics.data ?? []).map((t) => t.name))],
  };
}
