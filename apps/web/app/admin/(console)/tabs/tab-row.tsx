"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { inputCls } from "@/components/admin/row-form";
import { saveTab } from "../app-control-actions";

type Tab = { key: string; title: string; icon: string; type: string; sort: number; enabled: boolean; premium_only: boolean; min_app_version: string | null };

export function TabRow({ tab: t }: { tab: Tab }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <form action={(f) => start(async () => { const r = await saveTab(f); if (r.ok) { toast.success(`${t.title} tab saved.`); router.refresh(); } else toast.error(r.error); })}
      className="grid grid-cols-2 items-center gap-3 px-4 py-3 text-sm lg:grid-cols-[56px_minmax(0,1fr)_160px_72px_96px_110px_120px_90px]">
      <input type="hidden" name="key" value={t.key} />
      <input name="sort" type="number" min={0} max={99} defaultValue={t.sort} aria-label="Order" className={inputCls} />
      <input name="title" defaultValue={t.title} aria-label="Title" className={inputCls} />
      <input name="icon" defaultValue={t.icon} aria-label="Icon" className={`${inputCls} font-mono text-xs`} />
      <span className="text-xs text-muted-foreground">{t.type.replace("_", " ")}</span>
      <Switch name="premium_only" defaultChecked={t.premium_only} aria-label="Premium only" />
      <input name="min_app_version" defaultValue={t.min_app_version ?? ""} placeholder="any" aria-label="Minimum app version" className={`${inputCls} font-mono`} />
      <label className="flex items-center gap-2"><Switch name="enabled" defaultChecked={t.enabled} aria-label="Shown" /><span className="text-xs">Shown</span></label>
      <Button type="submit" size="sm" variant="outline" disabled={pending}>Save</Button>
    </form>
  );
}
