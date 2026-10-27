"use server";
import { revalidatePath } from "next/cache";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { getCatalogue } from "@/lib/catalogue";
import { MAX_ROWS, validateRows, type ImportRow } from "@solutiontee/shared/csv";

export type ImportSummary = { batch_id: string; total: number; inserted: number; possible_duplicates: number; new_topics: number; new_years: number; dry_run: boolean };

/** Validates again on the server (never trust the browser), then calls import_questions (one transaction). */
export async function runImport(fileName: string, rows: ImportRow[], dryRun: boolean): Promise<ActionResult<ImportSummary>> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Only editors and admins can import." };
  if (!Array.isArray(rows) || rows.length === 0) return { ok: false, error: "The file has no rows." };
  if (rows.length > MAX_ROWS) return { ok: false, error: `The limit is ${MAX_ROWS} rows per import.` };

  const { exams, subjects } = await getCatalogue();
  const check = validateRows(rows, { exams: exams.map((e) => e.code), subjects: subjects.flatMap((s) => [s.code, s.name]) });
  if (check.errors.length) return { ok: false, error: `${check.badRows.size} row(s) still have problems. Fix them and try again.` };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("import_questions", {
    p_file_name: fileName.slice(0, 200), p_rows: rows as unknown as never, p_dry_run: dryRun,
  });
  if (error) return { ok: false, error: friendlyError(error) };
  if (!dryRun) revalidatePath("/admin", "layout");
  return { ok: true, data: data as unknown as ImportSummary };
}

export async function undoImport(batchId: string): Promise<ActionResult<number>> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Only editors and admins can undo imports." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("undo_import", { p_batch: batchId });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, data: data ?? 0 };
}
