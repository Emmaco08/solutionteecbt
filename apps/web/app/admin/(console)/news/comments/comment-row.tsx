"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Pill, when } from "@/components/admin/ui";
import { moderateComment } from "../actions";

type C = { id: string; post_title: string; user_id: string; name: string; body: string; created_at: string; reports: number; hidden_at: string | null; hidden_reason: string | null; reviewed_at: string | null };

export function CommentRow({ c, editable }: { c: C; editable: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const act = (a: "hide" | "show" | "delete") => start(async () => {
    const r = await moderateComment(c.id, a);
    if (r.ok) { toast.success(r.message ?? "Done"); router.refresh(); } else toast.error(r.error);
  });
  return (
    <li className="flex flex-wrap items-start gap-3 p-4">
      <div className={`min-w-0 flex-1 ${c.hidden_at ? "opacity-60" : ""}`}>
        <p className="text-xs text-muted-foreground"><b className="text-foreground">{c.name}</b> on “{c.post_title}” · {when(c.created_at)}</p>
        <p className="mt-1 whitespace-pre-wrap break-words">{c.body}</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {c.reports > 0 ? <Pill tone={c.reviewed_at ? "neutral" : "warn"}>{c.reports} report{c.reports === 1 ? "" : "s"}</Pill> : null}
        {c.hidden_at ? <Pill tone="error">{c.hidden_reason === "reports" ? "Hidden by reports" : "Hidden"}</Pill> : null}
        {editable ? (
          <>
            {c.hidden_at || (c.reports > 0 && !c.reviewed_at)
              ? <Button size="sm" variant="outline" disabled={pending} onClick={() => act("show")}>Keep / show</Button> : null}
            {!c.hidden_at ? <Button size="sm" variant="outline" disabled={pending} onClick={() => act("hide")}>Hide</Button> : null}
            <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm("Delete this comment?")) act("delete"); }}>Delete</Button>
          </>
        ) : null}
      </div>
    </li>
  );
}
