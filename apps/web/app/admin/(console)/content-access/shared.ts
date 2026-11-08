/** How Study content opens (D-106): per kind defaults, per exam year rules. */
export type Mode = "default" | "free" | "premium" | "ads" | "pay";
export type Rule = { mode: Mode; ads?: number; hours?: number; price_kobo?: number | null; premium_pays?: boolean };
export type YearsRule = Rule & { ads_years?: Record<string, number[] | "all"> };
export type Limits = { year_per_day?: number; item_per_day?: Record<string, number> };
export type Defaults = { items: Record<string, Rule>; years: YearsRule; limits?: Limits };
export type CustomExam = { on: boolean; who: "everyone" | "premium"; max_questions: number; max_english: number; max_minutes: number };
export type Welcome = { on: boolean; hours: number; ads_level: string; extra_years: number };
export type YearRule = { exam_id: number; exam: string; year: number; access: Mode; ad_count: number | null; ad_hours: number | null; price_kobo: number | null; pay_premium: boolean | null };
export type AccessData = {
  defaults: Defaults | null; years: YearRule[];
  exams: { id: number; code: string; years: number[] | null }[];
  sales: { kind: string; ref: string; sold: number; kobo: number }[];
  welcome?: Welcome | null;
  custom?: CustomExam | null;
};
export const KINDS: { id: string; label: string }[] = [
  { id: "video_solution", label: "Video solutions" }, { id: "lesson", label: "Video lessons" }, { id: "note", label: "Lesson notes" },
  { id: "novel", label: "Novels" }, { id: "doc", label: "Syllabus & documents" },
];
export const MODES: { id: Mode; label: string }[] = [
  { id: "default", label: "As in Free vs Premium" }, { id: "free", label: "Free for everyone" }, { id: "premium", label: "Premium only" },
  { id: "ads", label: "Free students watch videos" }, { id: "pay", label: "Pay per item" },
];
