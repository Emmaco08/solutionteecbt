import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { AccessBoard } from "./access-ui";
import type { AccessData } from "./shared";

export const metadata: Metadata = { title: "How content opens" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Access /></Suspense>;
}

async function Access() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [{ data, error }, { data: welcome }] = await Promise.all([supabase.rpc("admin_content_access"), supabase.rpc("admin_welcome")]);
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader
        title="How content opens"
        description="For each kind of Study content and each past-question year: as in Free vs Premium, free for everyone, Premium only, free students watch videos to open it, or pay for that one item. A single item can have its own rule (Study → edit the item). Everything is checked on the server."
      />
      <AccessBoard d={{ ...(data as unknown as AccessData), welcome: welcome as unknown as AccessData["welcome"] }} />
    </>
  );
}
