import "server-only";
import { createServerClient } from "@supabase/ssr";
import { createClient as createPlainClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";
import { connection } from "next/server";
import type { Database } from "@solutiontee/shared/database";
import { env } from "@/lib/env";

/** Supabase client acting as the signed-in user (RLS applies). Use in Server Components and Server Actions. */
export async function createClient() {
  // Supabase reads the clock and cookies: always request-time, never prerendered.
  await connection();
  const cookieStore = await cookies();
  return createServerClient<Database>(env.supabaseUrl, env.supabasePublishableKey, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (list) => {
        try {
          list.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Called from a Server Component: the proxy refreshes the session instead.
        }
      },
    },
  });
}

/** Service-role client: bypasses RLS. Only for the few trusted server tasks (first admin, staff invites). */
export async function createServiceClient() {
  await connection();
  if (!env.supabaseSecretKey) throw new Error("SUPABASE_SECRET_KEY is not set");
  return createPlainClient<Database>(env.supabaseUrl, env.supabaseSecretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
