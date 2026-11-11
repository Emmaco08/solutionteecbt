"use server";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" }); // this browser only, never the app (D-129)
  redirect("/admin/login?e=signed_out");
}
