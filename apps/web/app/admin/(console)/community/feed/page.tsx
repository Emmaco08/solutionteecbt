import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { PageHeader } from "@/components/admin/ui";
import { StaffCommunity } from "./feed-ui";

export const metadata: Metadata = { title: "Community feed" };

/**
 * The Community as staff see it (D-156): the same feed students see, with posting as yourself or as a SolutionTee page,
 * likes, replies and reposts, and taking any post or reply down. Everyone on the team can post; super admins post as
 * the official @solutiontee page; super admins, admins and moderators can take things down.
 */
export default async function Page() {
  const me = await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  return (
    <>
      <PageHeader
        title="Community feed"
        description="Join the conversation with students. Your posts carry the SolutionTee mark so students know you work for SolutionTee. Post as yourself or as a SolutionTee page."
      />
      <StaffCommunity role={me.role} />
    </>
  );
}
