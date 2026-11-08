"use server";
import { revalidatePath, updateTag } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { mergeCms, type SiteCms } from "@/lib/site-cms";

/** Saves admin → Website (D-122). The content is cleaned the same way the site reads it, then the site refreshes at once. */
export async function saveSiteCms(input: SiteCms): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const value = mergeCms(input);
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "site_cms", value: value as never, is_public: false }, { onConflict: "key" });
  if (error) return { ok: false, error: friendlyError(error) };
  updateTag("site");
  revalidatePath("/site");
  revalidatePath("/admin/website");
  return { ok: true, message: "Saved. cbt.solutiontee.com shows it now." };
}
