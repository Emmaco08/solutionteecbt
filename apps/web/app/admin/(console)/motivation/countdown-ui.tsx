"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { HourglassMedium, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { inputCls } from "@/components/admin/row-form";
import { saveCountdown } from "./actions";

export type CountdownSettings = { on: boolean; daily: boolean; dates: Record<string, string> };

const SHORT: Record<string, string> = { JAMB: "UTME", WAEC: "WASSCE", NECO: "SSCE" };
const daysTo = (d: string) => Math.round((new Date(`${d}T00:00:00`).getTime() - new Date(new Date().toDateString()).getTime()) / 86_400_000);

/** Exam countdown (D-135): one date per exam; a full-screen countdown once a day and a chip on Home in the app. */
export function CountdownEditor({ initial, exams, canEdit }: { initial: CountdownSettings; exams: { code: string; name: string }[]; canEdit: boolean }) {
  const router = useRouter();
  const [s, setS] = useState(initial);
  const [pending, start] = useTransition();
  const save = () => start(async () => {
    const r = await saveCountdown(s);
    if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error);
  });
  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-3">
        {exams.map((e) => {
          const v = s.dates[e.code] ?? "";
          const d = v ? daysTo(v) : null;
          return (
            <label key={e.code} className="rounded-xl border p-3">
              <span className="block text-sm font-bold">{SHORT[e.code] ?? e.code} <span className="font-normal text-muted-foreground">· {e.name}</span></span>
              <input type="date" value={v} disabled={!canEdit} onChange={(x) => setS({ ...s, dates: { ...s.dates, [e.code]: x.target.value } })} className={`${inputCls} mt-2`} />
              <span className="mt-1.5 block text-xs text-muted-foreground">{d === null ? "No date: no countdown for this exam" : d < 0 ? "This date has passed" : d === 0 ? "Today" : `${d} days from today`}</span>
            </label>
          );
        })}
      </div>
      <div className="divide-y rounded-xl border px-4">
        <label className="flex items-center gap-4 py-3">
          <span className="grow"><b className="block text-sm">Show the countdown</b><small className="text-[13px] text-muted-foreground">The chip on Home (“143 days to your UTME”). Each student sees the next exam they chose.</small></span>
          <Switch checked={s.on} disabled={!canEdit} onCheckedChange={(on) => setS({ ...s, on })} />
        </label>
        <label className="flex items-center gap-4 py-3">
          <span className="grow"><b className="block text-sm">Full-screen countdown once a day</b><small className="text-[13px] text-muted-foreground">On the first open of each day: days left, today’s goal, streak and today’s motivation line.</small></span>
          <Switch checked={s.daily} disabled={!canEdit || !s.on} onCheckedChange={(daily) => setS({ ...s, daily })} />
        </label>
      </div>
      {canEdit ? (
        <div className="flex justify-end">
          <Button size="sm" onClick={save} disabled={pending}>{pending ? <SpinnerGap size={14} className="animate-spin" /> : <HourglassMedium size={14} weight="fill" />} Save countdown</Button>
        </div>
      ) : <p className="text-xs text-muted-foreground">Only admins can change the countdown.</p>}
    </div>
  );
}
