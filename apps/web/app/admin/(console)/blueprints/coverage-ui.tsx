"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Sparkle, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type Sec = { key: string; label: string; count: number };

/** Sorts unsorted English questions with the AI, 300 at a time. Press it again until nothing is left. */
export function SortButton() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  async function run() {
    setBusy(true);
    try {
      const { data } = await createClient().auth.getSession();
      const token = data.session?.access_token;
      if (!token) throw new Error("Log in again.");
      const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/sort-sections`, {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify({ limit: 300 }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? `HTTP ${r.status}`);
      setMsg(`Sorted ${j.sorted ?? 0} · ${j.left ?? 0} left`);
      toast.success(`Sorted ${j.sorted ?? 0}. ${j.left ?? 0} left.`);
      router.refresh();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not sort the questions.");
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="flex items-center gap-3">
      {msg ? <span className="text-sm text-muted-foreground" aria-live="polite">{msg}</span> : null}
      <Button type="button" size="sm" disabled={busy} onClick={run}>
        {busy ? <SpinnerGap size={14} className="animate-spin" /> : <Sparkle size={14} />} Sort English sections with AI
      </Button>
    </div>
  );
}

/** Years down the side, sections across. A red cell has fewer questions than the blueprint asks for. */
export function Coverage({ rows, sections }: { rows: { year: number; section: string | null }[]; sections: Sec[] }) {
  if (!rows.length) return <p className="text-sm text-muted-foreground">No published JAMB English questions yet.</p>;
  const years = [...new Set(rows.map((r) => r.year))].sort((a, b) => b - a);
  const known = new Set(sections.map((s) => s.key));
  const cnt = new Map<string, number>();
  for (const r of rows) {
    const k = `${r.year}|${r.section && known.has(r.section) ? r.section : "_none"}`;
    cnt.set(k, (cnt.get(k) ?? 0) + 1);
  }
  const get = (y: number, k: string) => cnt.get(`${y}|${k}`) ?? 0;
  const unsortedAll = years.reduce((t, y) => t + get(y, "_none"), 0);
  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        Published questions per year and section. <b className="text-error">Red</b> means the year has fewer than the blueprint asks for, so the paper fills the rest from other years.
        {unsortedAll ? ` ${unsortedAll.toLocaleString()} question(s) are not sorted into a section yet.` : ""}
      </p>
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-sm">
          <thead className="bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
            <tr>
              <th className="px-3 py-2.5">Year</th>
              {sections.map((s) => <th key={s.key} className="px-3 py-2.5 text-right">{s.label}<div className="font-normal normal-case">needs {s.count}</div></th>)}
              <th className="px-3 py-2.5 text-right">Not sorted</th><th className="px-3 py-2.5 text-right">Total</th><th className="px-3 py-2.5">Paper</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {years.map((y) => {
              const short = sections.filter((s) => get(y, s.key) < s.count);
              const total = years.length ? sections.reduce((t, s) => t + get(y, s.key), 0) + get(y, "_none") : 0;
              return (
                <tr key={y}>
                  <td className="px-3 py-2.5 font-bold">{y}</td>
                  {sections.map((s) => {
                    const n = get(y, s.key);
                    return <td key={s.key} className={cn("tnum px-3 py-2.5 text-right", n < s.count && "bg-error-soft font-bold text-on-error-soft")}>{n}</td>;
                  })}
                  <td className="tnum px-3 py-2.5 text-right text-muted-foreground">{get(y, "_none")}</td>
                  <td className="tnum px-3 py-2.5 text-right">{total}</td>
                  <td className="px-3 py-2.5 text-xs">{short.length ? <span className="font-bold text-on-warning-soft">Filled from other years: {short.map((s) => s.label.toLowerCase()).join(", ")}</span> : <span className="text-success">Complete</span>}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
