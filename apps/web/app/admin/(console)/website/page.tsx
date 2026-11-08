import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { mergeCms } from "@/lib/site-cms";
import { WebsiteEditor } from "./editor";

export const metadata: Metadata = { title: "Website" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Website /></Suspense>;
}

async function Website() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data } = await supabase.from("app_settings").select("key, value").in("key", ["site_cms", "cash_prizes"]);
  const s = Object.fromEntries((data ?? []).map((r) => [r.key, r.value as Record<string, unknown>]));
  const cash = s.cash_prizes?.on === true, teens = cash && s.cash_prizes?.teens === true;
  return (
    <>
      <PageHeader title="Website" description="Everything on cbt.solutiontee.com: turn sections on or off and change their words. Saving updates the site at once." />
      <WebsiteEditor initial={mergeCms(s.site_cms)} cash={cash} teens={teens} />
    </>
  );
}
