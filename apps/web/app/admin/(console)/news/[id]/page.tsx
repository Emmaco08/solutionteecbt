import { Suspense } from "react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { NewsForm } from "../news-form";

export const metadata: Metadata = { title: "Edit news" };

export default function Page({ params }: PageProps<"/admin/news/[id]">) {
  return <Suspense fallback={<PageSkeleton />}><Edit params={params} /></Suspense>;
}

async function Edit({ params }: { params: PageProps<"/admin/news/[id]">["params"] }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  await requireStaff();
  const supabase = await createClient();
  const { data } = await supabase.from("news_posts").select("*").eq("id", id).maybeSingle();
  if (!data) notFound();
  return (<><PageHeader title="Edit news" /><NewsForm post={data} /></>);
}
