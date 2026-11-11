import "server-only";
import { cacheLife, cacheTag } from "next/cache";
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@solutiontee/shared/database";
import { env } from "@/lib/env";
import { mergeCms, type RewardFacts, type SiteCms } from "@/lib/site-cms";

export type SitePlan = { code: string; name: string; description: string | null; price: number; days: number | null; ends_on: string | null };
export type SiteData = {
  plans: SitePlan[];
  questions: number;
  subjects: number;
  firstYear: number;
  lastYear: number;
  studyItems: number;
  fee: { on: boolean; pct: number; flat: number; flat_from: number; cap: number };
  playUrl: string;
  cms: SiteCms;
  facts: RewardFacts;
  /** Admin → Settings → "Show the JAMB, WAEC and NECO logos" (D-111): the website follows the app (D-131). */
  examLogos: boolean;
};

/** Live numbers and prices for the public website (cbt.solutiontee.com), cached for an hour. Never personal data. */
export async function siteData(): Promise<SiteData> {
  "use cache";
  cacheLife("hours");
  cacheTag("site"); // admin → Website and the cash switches refresh it at once (updateTag)
  const facts: RewardFacts = { cash: false, teens: false, pct: 5, maxPct: 100, xp: 50, finishXp: 20, cashEvery: 20, cashNaira: 5000, questions: 30000, firstYear: 1978, lastYear: 2025 };
  const fallback: SiteData = {
    plans: [], questions: 30000, subjects: 15, firstYear: 1978, lastYear: 2025, studyItems: 300,
    fee: { on: false, pct: 1.5, flat: 100, flat_from: 2500, cap: 2000 }, playUrl: "", cms: mergeCms(null), facts, examLogos: false,
  };
  if (!env.supabaseSecretKey) return fallback;
  const sb = createClient<Database>(env.supabaseUrl, env.supabaseSecretKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const [plans, q, first, last, study, settings] = await Promise.all([
    sb.from("plans").select("code, name, description, price_kobo, duration_days, ends_on").eq("is_active", true).order("sort"),
    sb.from("questions").select("id", { count: "exact", head: true }).eq("status", "published"),
    sb.from("questions").select("year").eq("status", "published").not("year", "is", null).order("year").limit(1).maybeSingle(),
    sb.from("questions").select("year").eq("status", "published").not("year", "is", null).order("year", { ascending: false }).limit(1).maybeSingle(),
    sb.from("study_items").select("id", { count: "exact", head: true }),
    sb.from("app_settings").select("key, value").in("key", ["payments", "site", "site_cms", "cash_prizes", "referrals", "xp", "exam_logos"]),
  ]);
  const s = Object.fromEntries((settings.data ?? []).map((r) => [r.key, r.value as Record<string, unknown>]));
  const fees = (s.payments?.fees ?? {}) as { paystack?: Partial<SiteData["fee"]> };
  const num = (v: unknown, d: number) => (typeof v === "number" && Number.isFinite(v) ? v : d);
  const cp = s.cash_prizes ?? {}, rf = s.referrals ?? {}, xp = s.xp ?? {};
  const questions = q.count ?? fallback.questions;
  const firstYear = Number(first.data?.year ?? fallback.firstYear), lastYear = Number(last.data?.year ?? fallback.lastYear);
  return {
    cms: mergeCms(s.site_cms),
    examLogos: s.exam_logos?.on === true,
    facts: {
      cash: cp.on === true, teens: cp.on === true && cp.teens === true,
      pct: num(rf.pct_per_friend, facts.pct), maxPct: num(rf.max_pct, facts.maxPct), xp: num(xp.referral, facts.xp),
      finishXp: num(xp.challenge_finish, facts.finishXp), cashEvery: num(rf.cash_every, facts.cashEvery), cashNaira: num(rf.cash_naira, facts.cashNaira),
      questions, firstYear, lastYear,
    },
    plans: (plans.data ?? []).map((p) => ({ code: p.code, name: p.name, description: p.description, price: p.price_kobo / 100, days: p.duration_days, ends_on: p.ends_on })),
    questions,
    subjects: fallback.subjects,
    firstYear,
    lastYear,
    studyItems: study.count ?? fallback.studyItems,
    fee: { ...fallback.fee, ...(fees.paystack ?? {}) },
    playUrl: typeof s.site?.play_url === "string" && String(s.site.play_url).startsWith("https://play.google.com/") ? String(s.site.play_url) : "",
  };
}

/** Same sum as the server's private.paystack_fee, in naira (display only; the server decides what is charged). */
export function paystackFee(price: number, f: SiteData["fee"]) {
  if (!f.on || price <= 0) return 0;
  const pct = Math.min(Math.max(f.pct, 0), 20) / 100;
  let total = price / (1 - pct);
  if (f.flat > 0 && total >= f.flat_from) total = (price + f.flat) / (1 - pct);
  let fee = Math.ceil(total - price);
  if (f.cap > 0) fee = Math.min(fee, f.cap);
  return Math.max(fee, 0);
}

export type CashState = "off" | "adults" | "teens";

/** Cash prize switches for the Privacy Policy and Terms (D-122). Refreshed at once when an admin flips them. */
export async function cashState(): Promise<CashState> {
  "use cache";
  cacheLife("hours");
  cacheTag("site");
  if (!env.supabaseSecretKey) return "off";
  const sb = createClient<Database>(env.supabaseUrl, env.supabaseSecretKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data } = await sb.from("app_settings").select("value").eq("key", "cash_prizes").maybeSingle();
  const v = (data?.value ?? {}) as { on?: boolean; teens?: boolean };
  return v.on !== true ? "off" : v.teens === true ? "teens" : "adults";
}

/** Keeps only the `<!-- if cash=… -->` blocks that match [state] ("on" matches adults and teens). */
export function applyCashBlocks(md: string, state: CashState) {
  return md.replace(/<!-- if cash=(\w+) -->\n?([\s\S]*?)<!-- end -->\n?/g, (_, want: string, body: string) =>
    want === state || (want === "on" && state !== "off") ? body : "");
}
