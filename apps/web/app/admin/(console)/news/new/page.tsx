import { Suspense } from "react";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { requireStaff, canEditContent } from "@/lib/auth";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { NewsForm } from "../news-form";

export const metadata: Metadata = { title: "Post news" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton />}><New /></Suspense>;
}

async function New() {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) redirect("/admin/news");
  return (<><PageHeader title="Post news" /><NewsForm post={{ status: "draft" }} /></>);
}
