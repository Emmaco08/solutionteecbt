import "server-only";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";

/** True only while there is no staff member at all (first run). */
export async function noStaffYet(): Promise<boolean> {
  if (!hasServiceKey()) return false;
  const svc = await createServiceClient();
  const { count, error } = await svc.from("staff").select("user_id", { count: "exact", head: true });
  return !error && (count ?? 0) === 0;
}
