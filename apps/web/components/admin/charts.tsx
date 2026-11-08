"use client";
import { useId, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { fmt, type Fmt } from "@/lib/format-num";

/*
 * Admin charts (D-124). Plain SVG/HTML, no chart library. Rules (dataviz skill): one series per trend chart in the
 * brand blue (light #2563B3, dark #5B8DEF), thin marks, 2px lines, bars at most 24px with 4px rounded data ends,
 * recessive grid, values in text colours, a hover tooltip on every mark, identity never by colour alone.
 * Categorical slots (validated light and dark): blue, orange, aqua; more than three fold into "Other".
 */
export const SERIES = ["text-[#2563B3] dark:text-[#5B8DEF]", "text-[#eb6834] dark:text-[#d95926]", "text-[#1baf7a] dark:text-[#199e70]"] as const;
const BLUE = SERIES[0];


const short = (iso: string) => new Date(`${iso}T12:00:00`).toLocaleDateString("en-GB", { day: "numeric", month: "short" });

/* ------------------------------------------------------------------ stat tile */
export function Stat({ label, value, f = "int", prev, sub, help }: { label: string; value: number; f?: Fmt; prev?: number; sub?: string; help?: string }) {
  const delta = prev === undefined ? null : prev === 0 ? (value > 0 ? null : 0) : Math.round(((value - prev) / prev) * 100);
  return (
    <div className="rounded-2xl border bg-card p-4 shadow-[var(--shadow-1)] sm:p-5" title={help}>
      <span className="text-[13px] font-bold text-muted-foreground sm:text-sm">{label}</span>
      <b className="tnum mt-1.5 block truncate text-[21px] leading-[28px] tracking-[-0.4px] sm:text-[28px] sm:leading-[34px]">{fmt(value, f)}</b>
      <span className="text-xs text-muted-foreground">
        {delta !== null ? (
          <span className={cn("font-bold", delta > 0 ? "text-success" : delta < 0 ? "text-error" : "")}>{delta > 0 ? "▲" : delta < 0 ? "▼" : ""} {Math.abs(delta)}%</span>
        ) : prev !== undefined ? <span className="font-bold">New</span> : null}
        {delta !== null || prev !== undefined ? " vs previous period" : ""}{sub ? (delta !== null || prev !== undefined ? " · " : "") + sub : ""}
      </span>
    </div>
  );
}

/* ------------------------------------------------------------------ tooltip */
function Tip({ x, y, children, show }: { x: number | string; y: number; children: React.ReactNode; show: boolean }) {
  if (!show) return null;
  return (
    <div className="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-full whitespace-nowrap rounded-lg border bg-popover px-2.5 py-1.5 text-xs shadow-[var(--shadow-2)]"
      style={{ left: x, top: y - 8 }}>{children}</div>
  );
}

/* ------------------------------------------------------------------ trend (line + soft area, crosshair) */
export function Trend({ data, f = "int", label, height = 190 }: { data: { day: string; v: number }[]; f?: Fmt; label: string; height?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  const [hover, setHover] = useState<{ i: number; w: number; h: number } | null>(null);
  const i = hover?.i ?? null;
  const id = useId().replace(/:/g, "");
  const W = 640, H = height, L = 8, R = 64, T = 12, B = 24; // R: gutter for the axis numbers
  const max = Math.max(1, ...data.map((d) => d.v));
  const nice = (() => { const p = 10 ** Math.floor(Math.log10(max)); const m = max / p; return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10) * p; })();
  const x = (k: number) => L + (data.length <= 1 ? (W - L - R) / 2 : (k * (W - L - R)) / (data.length - 1));
  const y = (v: number) => T + (H - T - B) * (1 - v / nice);
  const line = data.map((d, k) => `${k ? "L" : "M"}${x(k).toFixed(1)},${y(d.v).toFixed(1)}`).join("");
  const area = data.length ? `${line}L${x(data.length - 1)},${H - B}L${x(0)},${H - B}Z` : "";
  const ticks = [0, nice / 2, nice];
  const every = Math.max(1, Math.ceil(data.length / 6));
  function move(e: React.PointerEvent) {
    const r = ref.current?.getBoundingClientRect(); if (!r || !data.length) return;
    const rel = ((e.clientX - r.left) / r.width) * W;
    setHover({ i: Math.max(0, Math.min(data.length - 1, Math.round(((rel - L) / (W - L - R)) * (data.length - 1)))), w: r.width, h: r.height });
  }
  const total = data.reduce((s, d) => s + d.v, 0);
  return (
    <figure className="m-0">
      <figcaption className="sr-only">{label}: {fmt(total, f)} in total</figcaption>
      <div ref={ref} className={cn("relative touch-none select-none", BLUE)} onPointerMove={move} onPointerLeave={() => setHover(null)}>
        <svg viewBox={`0 0 ${W} ${H}`} className="block h-auto w-full" role="img" aria-label={label}>
          <defs><linearGradient id={`g${id}`} x1="0" x2="0" y1="0" y2="1"><stop offset="0" stopColor="currentColor" stopOpacity=".18" /><stop offset="1" stopColor="currentColor" stopOpacity="0" /></linearGradient></defs>
          {ticks.map((t) => <line key={t} x1={L} x2={W - R} y1={y(t)} y2={y(t)} className="stroke-border" strokeWidth="1" strokeDasharray={t ? "3 4" : undefined} />)}
          {area ? <path d={area} fill={`url(#g${id})`} /> : null}
          <path d={line} fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
          {i !== null ? <>
            <line x1={x(i)} x2={x(i)} y1={T} y2={H - B} className="stroke-muted-foreground" strokeWidth="1" strokeDasharray="2 3" />
            <circle cx={x(i)} cy={y(data[i]!.v)} r="4.5" fill="currentColor" className="stroke-card" strokeWidth="2" />
          </> : null}
        </svg>
        {/* dates as HTML so they stay readable on phones (SVG text would shrink with the chart) */}
        {data.map((d, k) => ((k % every === 0 && k < data.length - Math.ceil(every / 2)) || k === data.length - 1 ? (
          <span key={d.day} className={cn("pointer-events-none absolute whitespace-nowrap text-[10px] leading-none text-muted-foreground sm:inline sm:text-[11px]",
            k === 0 || k === data.length - 1 || k === Math.floor((data.length - 1) / 2 / every) * every ? "inline" : "hidden")}
            style={{ left: `${(x(k) / W) * 100}%`, top: `${((H - B + 8) / H) * 100}%`, transform: k === 0 ? "none" : k === data.length - 1 ? "translateX(-100%)" : "translateX(-50%)" }}>{short(d.day)}</span>
        ) : null))}
        {ticks.map((t) => <span key={t} className="tnum pointer-events-none absolute right-0 text-[10px] leading-none text-muted-foreground" style={{ top: `${(y(t) / H) * 100}%`, transform: "translateY(-50%)" }}>{fmt(t, f)}</span>)}
        {hover && i !== null ? (
          <Tip show x={(x(i) / W) * hover.w} y={(y(data[i]!.v) / H) * hover.h}>
            <b className="text-foreground">{fmt(data[i]!.v, f)}</b> <span className="text-muted-foreground">{label.toLowerCase()} · {short(data[i]!.day)}</span>
          </Tip>
        ) : null}
      </div>
    </figure>
  );
}

/* ------------------------------------------------------------------ columns (hours, weekdays) */
export function Columns({ data, label, f = "int", height = 150 }: { data: { label: string; v: number; tip?: string }[]; label: string; f?: Fmt; height?: number }) {
  const [i, setI] = useState<number | null>(null);
  const max = Math.max(1, ...data.map((d) => d.v));
  const every = data.length > 12 ? 3 : 1;
  return (
    <div className="relative" role="img" aria-label={label}>
      <div className="flex items-end gap-[2px]" style={{ height }}>
        {data.map((d, k) => (
          <div key={d.label} className="relative flex h-full flex-1 cursor-default items-end justify-center" onPointerEnter={() => setI(k)} onPointerLeave={() => setI(null)}>
            <div className={cn("w-full max-w-6 rounded-t-[4px] bg-current transition-opacity", BLUE, i !== null && i !== k && "opacity-50")}
              style={{ height: `${Math.max(d.v ? 3 : 1, (d.v / max) * 100)}%`, opacity: d.v ? undefined : 0.25 }} />
            {i === k ? <Tip show x="50%" y={0}><b>{fmt(d.v, f)}</b> <span className="text-muted-foreground">{d.tip ?? d.label}</span></Tip> : null}
          </div>
        ))}
      </div>
      <div className="mt-1.5 flex gap-[2px]">
        {data.map((d, k) => <span key={d.label} className="flex-1 text-center text-[10px] text-muted-foreground">{k % every === 0 ? d.label : ""}</span>)}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ horizontal bar list (distributions) */
export function BarList({ items, f = "int", total, empty = "No data yet.", extra }: {
  items: { label: string; n: number; note?: string }[]; f?: Fmt; total?: number; empty?: string; extra?: (it: { label: string; n: number; note?: string }) => React.ReactNode;
}) {
  if (!items.length || items.every((x) => !x.n)) return <p className="py-6 text-center text-sm text-muted-foreground">{empty}</p>;
  const max = Math.max(1, ...items.map((x) => x.n));
  const sum = total ?? items.reduce((s, x) => s + x.n, 0);
  return (
    <ul className="space-y-3">
      {items.map((it) => (
        <li key={it.label} title={`${it.label}: ${fmt(it.n, f)}${sum && f !== "pct" ? ` (${Math.round((it.n / sum) * 100)}%)` : ""}`}>
          <div className="flex items-baseline justify-between gap-3 text-sm">
            <span className="min-w-0 truncate font-bold">{it.label}</span>
            <span className="tnum shrink-0 text-muted-foreground">{fmt(it.n, f)}{sum && f !== "pct" ? <span className="ml-1.5 text-xs">{Math.round((it.n / sum) * 100)}%</span> : null}{extra ? extra(it) : null}</span>
          </div>
          <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-muted">
            <div className={cn("h-full rounded-full bg-current", BLUE)} style={{ width: `${Math.max(2, (it.n / max) * 100)}%` }} />
          </div>
          {it.note ? <p className="mt-1 text-xs text-muted-foreground">{it.note}</p> : null}
        </li>
      ))}
    </ul>
  );
}

/* ------------------------------------------------------------------ split bar (up to 3 parts + Other) */
export function Split({ items, f = "int" }: { items: { label: string; n: number }[]; f?: Fmt }) {
  const sorted = [...items].sort((a, b) => b.n - a.n);
  const parts = sorted.length > 3 ? [...sorted.slice(0, 2), { label: "Other", n: sorted.slice(2).reduce((s, x) => s + x.n, 0) }] : sorted;
  const sum = parts.reduce((s, x) => s + x.n, 0);
  if (!sum) return <p className="py-4 text-sm text-muted-foreground">No data yet.</p>;
  return (
    <div>
      <div className="flex h-3 gap-[2px] overflow-hidden rounded-full">
        {parts.map((p, k) => p.n ? <div key={p.label} title={`${p.label}: ${fmt(p.n, f)}`} className={cn("h-full bg-current first:rounded-l-full last:rounded-r-full", SERIES[k % 3])} style={{ width: `${(p.n / sum) * 100}%` }} /> : null)}
      </div>
      <ul className="mt-3 flex flex-wrap gap-x-5 gap-y-1.5 text-sm">
        {parts.map((p, k) => (
          <li key={p.label} className="flex items-center gap-2">
            <span className={cn("size-2.5 rounded-sm bg-current", SERIES[k % 3])} aria-hidden />
            <b>{p.label}</b><span className="tnum text-muted-foreground">{fmt(p.n, f)} · {Math.round((p.n / sum) * 100)}%</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
