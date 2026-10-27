"use server";
import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { noStaffYet } from "@/lib/setup";

export type SetupState = { error?: string; ok?: boolean };

const SetupSchema = z.object({
  name: z.string().trim().min(2, "Enter your full name").max(120),
  email: z.string().trim().toLowerCase().email("Enter a valid email address"),
  password: z
    .string()
    .min(10, "Use at least 10 characters")
    .regex(/[a-zA-Z]/, "Use letters and numbers")
    .regex(/[0-9]/, "Use letters and numbers"),
});

/** First-run only: creates the first super admin. Refuses once any staff member exists. */
export async function createFirstAdmin(_prev: SetupState, form: FormData): Promise<SetupState> {
  const parsed = SetupSchema.safeParse({ name: form.get("name"), email: form.get("email"), password: form.get("password") });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message ?? "Check the form" };
  if (!hasServiceKey()) return { error: "The server is missing SUPABASE_SECRET_KEY." };
  if (!(await noStaffYet())) return { error: "An admin account already exists. Log in instead." };

  const svc = await createServiceClient();
  const { name, email, password } = parsed.data;
  const { data, error } = await svc.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { full_name: name },
  });
  if (error || !data.user) return { error: error?.message ?? "Could not create the account" };

  await svc.from("profiles").update({ full_name: name }).eq("id", data.user.id);
  const { error: staffErr } = await svc.from("staff").insert({ user_id: data.user.id, role: "super_admin" });
  if (staffErr) return { error: "Account made, but the admin role could not be saved. Try again." };
  return { ok: true };
}
