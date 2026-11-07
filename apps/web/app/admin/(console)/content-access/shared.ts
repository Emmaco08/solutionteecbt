/** How Study content opens (D-106): per kind defaults, per exam year rules. */
export type Mode = "default" | "free" | "premium" | "ads" | "pay";
export type Rule = { mode: Mode; ads?: number; hours?: number; price_kobo?: number | null; premium_pays?: boolean };
export type Defaults = { items: Record<string, Rule>; years: Rule };
export type YearRule = { exam_id: number; exam: string; year: number; access: Mode; ad_count: number | null; ad_hours: number | null; price_kobo: number | null; pay_premium: boolean | null };
export type AccessData = {
  defaults: Defaults | null; years: YearRule[];
  exams: { id: number; code: string; years: number[] | null }[];
  sales: { kind: string; ref: string; sold: number; kobo: number }[];
};
export const KINDS: { id: string; label: string }[] = [
  { id: "video_solution", label: "Video solutions" }, { id: "lesson", label: "Video lessons" }, { id: "note", label: "Lesson notes" },
  { id: "novel", label: "Novels" }, { id: "doc", label: "Syllabus & documents" },
];
export const MODES: { id: Mode; label: string }[] = [
  { id: "default", label: "As in Free vs Premium" }, { id: "free", label: "Free for everyone" }, { id: "premium", label: "Premium only" },
  { id: "ads", label: "Free students watch videos" }, { id: "pay", label: "Pay per item" },
];
