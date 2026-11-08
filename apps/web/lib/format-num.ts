/** Number formats for the admin dashboard (server and client). */
export type Fmt = "int" | "naira" | "pct";
export function fmt(v: number | null | undefined, f: Fmt = "int") {
  if (v === null || v === undefined || Number.isNaN(v)) return "–";
  if (f === "naira") return `₦${Math.round(v).toLocaleString("en-NG")}`;
  if (f === "pct") return `${Math.round(v)}%`;
  return Math.round(v).toLocaleString("en-NG");
}
