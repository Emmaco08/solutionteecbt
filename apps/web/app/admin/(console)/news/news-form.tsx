"use client";
import { useActionState, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { SpinnerGap, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button, buttonVariants } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { ImageUpload } from "@/components/admin/image-upload";
import { inputCls } from "@/components/admin/row-form";
import { deleteNews, saveNews, type NewsState } from "./actions";

export type NewsPost = { id?: string; title?: string; summary?: string | null; body?: string | null; category?: string; link_type?: string | null; link_target?: string | null; image_path?: string | null; is_pinned?: boolean; notify?: boolean; comments_on?: boolean; status?: string; publish_at?: string };
const local = (iso?: string) => { const d = iso ? new Date(iso) : new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().slice(0, 16); };

export function NewsForm({ post: n }: { post: NewsPost }) {
  const router = useRouter();
  const [state, action, saving] = useActionState<NewsState, FormData>(saveNews, {});
  const [linkType, setLinkType] = useState(n.link_type ?? "none");
  const [pending, start] = useTransition();
  return (
    <form action={action} className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
      {n.id ? <input type="hidden" name="id" value={n.id} /> : null}
      <section className="space-y-4 rounded-2xl border bg-card p-5">
        <div className="space-y-1.5"><Label htmlFor="title">Title</Label><input id="title" name="title" defaultValue={n.title ?? ""} required className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="summary">Summary (shown on the card)</Label><input id="summary" name="summary" defaultValue={n.summary ?? ""} maxLength={400} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="body">Full story</Label><textarea id="body" name="body" defaultValue={n.body ?? ""} rows={10} className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm" /></div>
        <div className="space-y-1.5"><Label>Picture</Label><ImageUpload name="image_path" kind="news" defaultKey={n.image_path} /></div>
      </section>
      <aside className="space-y-4 rounded-2xl border bg-card p-5">
        <div className="space-y-1.5"><Label htmlFor="category">Category</Label>
          <select id="category" name="category" defaultValue={n.category ?? "update"} className={inputCls}>
            <option value="update">Update</option><option value="exam">Exam news</option><option value="app">App news</option><option value="tips">Study tips</option>
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="link_type">Button on the post</Label>
          <select id="link_type" name="link_type" value={linkType} onChange={(e) => setLinkType(e.target.value)} className={inputCls}>
            <option value="none">No button</option><option value="screen">Open an app screen</option><option value="url">Open a website</option><option value="doc">Open a document</option>
          </select></div>
        {linkType !== "none" ? <div className="space-y-1.5"><Label htmlFor="link_target">{linkType === "url" ? "Link (https://…)" : "Target"}</Label><input id="link_target" name="link_target" defaultValue={n.link_target ?? ""} className={inputCls} /></div> : <input type="hidden" name="link_target" value="" />}
        <div className="space-y-1.5"><Label htmlFor="publish_at">Publish at</Label><input id="publish_at" name="publish_at" type="datetime-local" defaultValue={local(n.publish_at)} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="status">Status</Label>
          <select id="status" name="status" defaultValue={n.status === "published" ? "published" : "draft"} className={inputCls}>
            <option value="draft">Draft</option><option value="published">Published</option>
          </select></div>
        <label className="flex items-center justify-between text-sm"><span>Pin to the top</span><Switch name="is_pinned" defaultChecked={n.is_pinned} /></label>
        <label className="flex items-center justify-between gap-3 text-sm"><span>Send as a notification when it is published<span className="block text-xs text-muted-foreground">Goes to students who keep Announcements on. Sent once.</span></span><Switch name="notify" defaultChecked={n.notify} /></label>
        <label className="flex items-center justify-between gap-3 text-sm"><span>Allow comments<span className="block text-xs text-muted-foreground">Students can comment and like. Reported comments go to News → Comments.</span></span><Switch name="comments_on" defaultChecked={n.comments_on !== false} /></label>
        {state.error ? <p role="alert" className="rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{state.error}</p> : null}
        <div className="flex gap-2">
          <Button type="submit" disabled={saving} className="grow">{saving ? <SpinnerGap size={16} className="animate-spin" /> : null} Save</Button>
          <Link href="/admin/news" className={buttonVariants({ variant: "outline" })}>Cancel</Link>
        </div>
        {n.id ? (
          <Button type="button" variant="ghost" className="w-full text-error" disabled={pending}
            onClick={() => confirm("Delete this post?") && start(async () => { const r = await deleteNews(n.id!); if (r.ok) { toast.success("Post deleted."); router.push("/admin/news"); } else toast.error(r.error); })}>
            <Trash size={16} /> Delete post
          </Button>
        ) : null}
      </aside>
    </form>
  );
}
