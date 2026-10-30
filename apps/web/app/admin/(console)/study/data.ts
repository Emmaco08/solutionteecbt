import "server-only";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";

/** Lists the study form needs: exams, subjects and topics (with their subject). */
export async function studyLists() {
  const supabase = await createClient();
  const [{ exams, subjects }, topics] = await Promise.all([
    getCatalogue(),
    supabase.from("topics").select("id, name, subject_id").order("name").limit(3000),
  ]);
  return {
    exams: exams.map((e) => ({ id: e.id, code: e.code, name: e.name })),
    subjects: subjects.map((s) => ({ id: s.id, name: s.name })),
    topics: topics.data ?? [],
  };
}
