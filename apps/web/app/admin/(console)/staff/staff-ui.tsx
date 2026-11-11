"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Copy, PaperPlaneTilt, ShieldCheck, ShieldWarning, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Pill } from "@/components/admin/ui";
import { inputCls } from "@/components/admin/row-form";
import { changeRole, inviteStaff, removeStaff } from "./actions";

type Row = { user_id: string; email: string; full_name: string | null; role: string; created_at: string; last_sign_in_at: string | null; has_2fa: boolean };
const ROLES = [["super_admin", "Super admin"], ["admin", "Admin"], ["editor", "Editor"], ["teacher", "Teacher"], ["tutor", "Tutor (chats with their students only)"]] as const;

export function StaffList({ rows, meId, canEdit }: { rows: Row[]; meId: string; canEdit: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (p: Promise<{ ok: boolean; error?: string }>, msg: string) => start(async () => { const r = await p; if (r.ok) { toast.success(msg); router.refresh(); } else toast.error(r.error); });
  return (
    <div className="divide-y overflow-hidden rounded-2xl border bg-card">
      {rows.map((r) => (
        <div key={r.user_id} className="flex flex-wrap items-center gap-3 px-5 py-4">
          <span className="grid size-10 flex-none place-items-center rounded-full bg-gold text-xs font-bold text-navy">{(r.full_name || r.email).slice(0, 2).toUpperCase()}</span>
          <div className="min-w-0 grow">
            <b className="block truncate">{r.full_name || r.email.split("@")[0]}{r.user_id === meId ? " (you)" : ""}</b>
            <span className="block truncate text-xs text-muted-foreground">{r.email} · last login {r.last_sign_in_at ? new Date(r.last_sign_in_at).toLocaleDateString("en-GB") : "never"}</span>
          </div>
          {r.has_2fa ? <Pill tone="ok"><ShieldCheck size={12} /> 2-step on</Pill> : <Pill tone="warn"><ShieldWarning size={12} /> 2-step not set</Pill>}
          {canEdit && r.user_id !== meId ? (
            <>
              <select defaultValue={r.role} disabled={pending} aria-label={`Role for ${r.email}`} className="h-9 rounded-lg border border-input bg-card px-2 text-sm"
                onChange={(e) => run(changeRole(r.user_id, e.target.value), "Role changed.")}>
                {ROLES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
              <Button size="icon-sm" variant="ghost" className="text-error" aria-label={`Remove ${r.email}`} disabled={pending}
                onClick={() => confirm(`Remove ${r.email} from staff? They keep a normal student account.`) && run(removeStaff(r.user_id), "Removed from staff.")}><Trash size={16} /></Button>
            </>
          ) : <Pill tone="info">{ROLES.find(([v]) => v === r.role)?.[1] ?? r.role}</Pill>}
        </div>
      ))}
    </div>
  );
}

export function InviteForm() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [link, setLink] = useState("");
  return (
    <form className="space-y-3" action={(f) => start(async () => {
      const r = await inviteStaff(f);
      if (!r.ok) return void toast.error(r.error);
      toast.success(r.message ?? "Invite sent.");
      setLink(r.data?.link ?? "");
      router.refresh();
    })}>
      <div className="space-y-1.5"><Label htmlFor="inv-email">Email</Label><input id="inv-email" name="email" type="email" required className={inputCls} /></div>
      <div className="space-y-1.5"><Label htmlFor="inv-role">Role</Label>
        <select id="inv-role" name="role" defaultValue="editor" className={inputCls}>{ROLES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></div>
      <Button type="submit" disabled={pending} className="w-full"><PaperPlaneTilt size={16} /> Send invite</Button>
      {link ? (
        <div className="rounded-xl bg-warning-soft p-3 text-xs text-on-warning-soft">
          <p className="mb-2 font-bold">Send this one-time link yourself (expires in 24 hours):</p>
          <div className="flex items-center gap-2"><code className="min-w-0 grow truncate">{link}</code>
            <Button type="button" size="icon-sm" variant="ghost" aria-label="Copy link" onClick={() => navigator.clipboard.writeText(link)}><Copy size={14} /></Button></div>
        </div>
      ) : null}
    </form>
  );
}
