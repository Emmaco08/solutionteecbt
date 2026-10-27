"use client";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { RowForm, inputCls } from "@/components/admin/row-form";
import { savePlan } from "../app-control-actions";

type Plan = { id: number; code: string; name: string; description: string | null; price_naira: number; duration_days: number | null; ends_on: string | null; play_product_id: string | null; is_active: boolean };

export function PlanCard({ plan: p, badge, priceLabel }: { plan: Plan; badge: React.ReactNode; priceLabel: string }) {
  return (
    <section className="rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
      <div className="mb-4 flex items-start justify-between">
        <div><b className="text-[17px]">{p.name}</b><p className="tnum text-[28px] font-bold leading-9">{priceLabel}</p></div>
        {badge}
      </div>
      <RowForm action={savePlan} success={`${p.name} saved.`}>
        <input type="hidden" name="id" value={p.id} />
        <div className="space-y-1.5"><Label htmlFor={`n${p.id}`}>Name</Label><input id={`n${p.id}`} name="name" defaultValue={p.name} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor={`d${p.id}`}>Short description</Label><input id={`d${p.id}`} name="description" defaultValue={p.description ?? ""} className={inputCls} /></div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5"><Label htmlFor={`p${p.id}`}>Price (₦)</Label><input id={`p${p.id}`} name="price_naira" type="number" min={0} step={50} defaultValue={p.price_naira} className={inputCls} /></div>
          <div className="space-y-1.5"><Label htmlFor={`days${p.id}`}>Days</Label><input id={`days${p.id}`} name="duration_days" type="number" min={1} defaultValue={p.duration_days ?? ""} placeholder="or end date" className={inputCls} /></div>
        </div>
        <div className="space-y-1.5"><Label htmlFor={`e${p.id}`}>Ends on (instead of days)</Label><input id={`e${p.id}`} name="ends_on" type="date" defaultValue={p.ends_on ?? ""} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor={`g${p.id}`}>Google Play product ID</Label><input id={`g${p.id}`} name="play_product_id" defaultValue={p.play_product_id ?? ""} placeholder={`premium_${p.code}`} className={`${inputCls} font-mono`} /></div>
        <label className="flex items-center justify-between text-sm"><span>On sale</span><Switch name="is_active" defaultChecked={p.is_active} /></label>
      </RowForm>
    </section>
  );
}
