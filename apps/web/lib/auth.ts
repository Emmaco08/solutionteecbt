import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Enums } from "@solutiontee/shared/database";

export type StaffRole = Enums<"staff_role">;
export type Staff = { id: string; email: string; name: string; role: StaffRole };

export const ROLE_LABEL: Record<StaffRole, string> = {
  super_admin: "Super admin",
  admin: "Admin",
  editor: "Editor",
  teacher: "Teacher",
};

/**
 * Data-access gate for every admin page and action: signed in, on the staff list, and 2-step verified (aal2).
 * The same rules are enforced again by RLS in Postgres, so this is for a good experience, not the only lock.
 */
export const requireStaff = cache(async (allowed?: StaffRole[]): Promise<Staff> => {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;
  if (!claims?.sub) redirect("/admin/login");

  const { data: row } = await supabase.from("staff").select("role").eq("user_id", claims.sub).maybeSingle();
  if (!row) redirect("/admin/login?e=not_staff");
  if (claims.aal !== "aal2") redirect("/admin/mfa");
  if (allowed && !allowed.includes(row.role)) redirect("/admin?e=no_access");

  const { data: profile } = await supabase.from("profiles").select("full_name").eq("id", claims.sub).maybeSingle();
  const email = String(claims.email ?? "");
  return { id: claims.sub, email, name: profile?.full_name || email.split("@")[0] || "Admin", role: row.role };
});

export const canEditContent = (r: StaffRole) => r === "super_admin" || r === "admin" || r === "editor";
export const canManage = (r: StaffRole) => r === "super_admin" || r === "admin";
/** Study content (notes, videos, novels, documents): teachers may edit too. */
export const canEditStudy = (r: StaffRole) => r === "super_admin" || r === "admin" || r === "editor" || r === "teacher";

/** True for a signed-in staff member with 2-step login (for route handlers that must not redirect). */
export async function isStaffRequest(): Promise<boolean> {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;
  if (!claims?.sub || claims.aal !== "aal2") return false;
  const { data: row } = await supabase.from("staff").select("role").eq("user_id", claims.sub).maybeSingle();
  return Boolean(row);
}
