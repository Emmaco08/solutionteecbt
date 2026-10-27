"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { RowForm, inputCls } from "@/components/admin/row-form";
import { deleteSlide, saveSlide } from "../app-control-actions";

type Slide = { id?: number; title?: string; body?: string; animation?: string | null; sort: number; enabled: boolean };

export function SlideForm({ slide: s }: { slide: Slide }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const k = s.id ?? "new";
  return (
    <RowForm action={saveSlide} success={s.id ? "Slide saved." : "Slide added."} submitLabel={s.id ? "Save" : "Add slide"}
      extra={s.id ? (
        <Button type="button" size="sm" variant="ghost" className="text-error" disabled={pending}
          onClick={() => confirm("Delete this slide?") && start(async () => { const r = await deleteSlide(s.id!); if (r.ok) { toast.success("Slide deleted."); router.refresh(); } else toast.error(r.error); })}>
          <Trash size={14} /> Delete
        </Button>
      ) : null}>
      {s.id ? <input type="hidden" name="id" value={s.id} /> : null}
      <div className="space-y-1.5"><Label htmlFor={`t${k}`}>Title</Label><input id={`t${k}`} name="title" defaultValue={s.title ?? ""} required className={inputCls} /></div>
      <div className="space-y-1.5"><Label htmlFor={`b${k}`}>Text</Label><textarea id={`b${k}`} name="body" defaultValue={s.body ?? ""} rows={2} required className="w-full rounded-xl border border-input bg-card px-3 py-2 text-sm" /></div>
      <div className="grid grid-cols-[1fr_80px_auto] items-end gap-3">
        <div className="space-y-1.5"><Label htmlFor={`a${k}`}>Animation</Label>
          <select id={`a${k}`} name="animation" defaultValue={s.animation ?? ""} className={inputCls}>
            {["", "cbt", "trophy", "study", "ai", "progress", "classes"].map((a) => <option key={a} value={a}>{a || "None"}</option>)}
          </select></div>
        <div className="space-y-1.5"><Label htmlFor={`o${k}`}>Order</Label><input id={`o${k}`} name="sort" type="number" min={0} max={99} defaultValue={s.sort} className={inputCls} /></div>
        <label className="flex h-10 items-center gap-2 text-sm"><Switch name="enabled" defaultChecked={s.enabled} /> Shown</label>
      </div>
    </RowForm>
  );
}
