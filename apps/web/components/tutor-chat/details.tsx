"use client";
import { useEffect, useState, useTransition } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { toast } from "sonner";
import { Briefcase, Copy, EnvelopeSimple, Fire, GraduationCap, MapPin, Phone, Ranking, Target, TrendDown, TrendUp, Trophy, WhatsappLogo, X } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { initials, naira, planInfo, type Chat, type TutorOpt } from "./lib";

type Profile = {
  name: string; age: number | null; school: string | null; state: string | null; phone: string | null; email: string | null;
  exams: string[] | null; jamb_subjects: string[] | null; target_score: number | null; career: string | null; joined: string; xp: number; premium: boolean;
  streak: { current: number; longest: number; today: boolean } | null;
  topics: { topic: string; subject: string; answered: number; correct: number; pct: number }[];
  tests: { at: string; mode: string; correct: number | null; answered: number | null; questions: number | null; score: number | null; max: number | null }[];
  leaderboard: { rank: number; of: number } | null;
  request: { level: string; subject: string | null; goals: string; times: string | null; created_at: string; paid_at: string | null; custom_note: string | null };
  plan: { name: string; ends_at: string; sessions: number | null } | null;
};

const waNumber = (n: string) => { const d = n.replace(/\D/g, ""); return d.startsWith("0") ? `234${d.slice(1)}` : d; };

function Stat({ icon: Icon, label, value, tone }: { icon: typeof Fire; label: string; value: string; tone: string }) {
  return (
    <div className="rounded-2xl border bg-background p-3">
      <span className={cn("mb-1 inline-grid size-8 place-items-center rounded-lg", tone)}><Icon size={18} weight="fill" /></span>
      <p className="text-lg font-bold tabular-nums leading-tight">{value}</p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}

function Row({ icon: Icon, children, copy }: { icon: typeof Fire; children: React.ReactNode; copy?: string }) {
  return (
    <div className="flex items-center gap-3 py-1.5 text-sm">
      <Icon size={18} className="shrink-0 text-muted-foreground" />
      <span className="min-w-0 flex-1 break-words">{children}</span>
      {copy ? <button type="button" onClick={() => { void navigator.clipboard.writeText(copy); toast.success("Copied"); }} className="rounded-md p-1 text-muted-foreground hover:bg-muted" aria-label="Copy"><Copy size={16} /></button> : null}
    </div>
  );
}

export function Details({ sb, chat, mode, tutors, onClose, onChanged }: {
  sb: SupabaseClient; chat: Chat; mode: "tutor" | "admin"; tutors?: TutorOpt[]; onClose: () => void; onChanged: () => void;
}) {
  const [p, setP] = useState<Profile | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [tutor, setTutor] = useState(chat.tutor_id ?? "");
  const [price, setPrice] = useState(chat.custom_price_kobo ? String(chat.custom_price_kobo / 100) : "");
  const [days, setDays] = useState(String(chat.custom_days ?? 30));

  useEffect(() => {
    let live = true;
    sb.rpc("tutor_student_profile", { p_request: chat.id }).then(({ data, error }) => {
      if (!live) return;
      if (error) setErr("Could not load the student's details.");
      else setP(data as unknown as Profile);
    });
    return () => { live = false; };
  }, [sb, chat.id]);

  const act = (fn: () => PromiseLike<{ data: unknown; error: unknown }>, ok: string) => start(async () => {
    const { data, error } = await fn();
    const d = (data ?? {}) as { ok?: boolean; error?: string };
    if (error || d.ok === false) return void toast.error(({ not_paid: "The student has not paid yet.", no_login: "This tutor has no login yet. Invite them in Staff with the Tutor role.", price: "Check the price and days." } as Record<string, string>)[d.error ?? ""] ?? "That did not work. Try again.");
    toast.success(ok);
    onChanged();
  });

  const strong = p ? [...p.topics].sort((a, b) => b.pct - a.pct).slice(0, 5) : [];
  const weak = p ? p.topics.filter((t) => t.pct < 60).slice(0, 5) : [];
  const plan = planInfo(chat.plan);

  return (
    <aside className="flex h-full flex-col bg-card">
      <div className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
        <b className="flex-1">Student details</b>
        <button type="button" onClick={onClose} className="rounded-full p-2 hover:bg-muted" aria-label="Close details"><X size={20} /></button>
      </div>
      <div className="flex-1 space-y-5 overflow-y-auto p-4">
        <div className="text-center">
          <div className="mx-auto grid size-20 place-items-center rounded-full bg-gradient-to-br from-[#2563B3] to-[#0B1F44] text-2xl font-bold text-white shadow">{initials(chat.name)}</div>
          <h3 className="mt-2 text-lg font-bold">{chat.name}</h3>
          <p className="text-sm text-muted-foreground">{[p?.age ? `${p.age} years` : null, p?.state, p?.premium ? "Premium" : null].filter(Boolean).join(" · ")}</p>
        </div>
        {err ? <p className="text-sm text-red-600">{err}</p> : !p ? <div className="space-y-2">{[0, 1, 2, 3].map((i) => <div key={i} className="h-14 animate-pulse rounded-xl bg-muted" />)}</div> : (
          <>
            <div className="grid grid-cols-2 gap-2">
              <Stat icon={Fire} label="Day streak" value={String(p.streak?.current ?? 0)} tone="bg-orange-100 text-orange-600 dark:bg-orange-950" />
              <Stat icon={Ranking} label={p.leaderboard ? `of ${p.leaderboard.of} on the board` : "Leaderboard"} value={p.leaderboard ? `#${p.leaderboard.rank}` : "-"} tone="bg-sky-100 text-sky-700 dark:bg-sky-950" />
              <Stat icon={Trophy} label="XP" value={p.xp.toLocaleString("en-NG")} tone="bg-amber-100 text-amber-700 dark:bg-amber-950" />
              <Stat icon={Target} label="Target score" value={p.target_score ? String(p.target_score) : "-"} tone="bg-emerald-100 text-emerald-700 dark:bg-emerald-950" />
            </div>
            <section>
              <h4 className="mb-1 text-xs font-bold uppercase tracking-wide text-muted-foreground">Contact</h4>
              {p.email ? <Row icon={EnvelopeSimple} copy={p.email}><a className="hover:underline" href={`mailto:${p.email}`}>{p.email}</a></Row> : null}
              {p.phone ? <Row icon={Phone} copy={p.phone}><a className="hover:underline" href={`tel:${p.phone}`}>{p.phone}</a> · <a className="font-bold text-[#128C7E] hover:underline" href={`https://wa.me/${waNumber(p.phone)}`} target="_blank" rel="noopener noreferrer"><WhatsappLogo size={14} className="inline" /> WhatsApp</a></Row> : null}
              {p.school ? <Row icon={GraduationCap}>{p.school}</Row> : null}
              {p.state ? <Row icon={MapPin}>{p.state}</Row> : null}
              {p.career ? <Row icon={Briefcase}>Dream career: <b>{p.career}</b></Row> : null}
            </section>
            <section>
              <h4 className="mb-2 text-xs font-bold uppercase tracking-wide text-muted-foreground">Exams and subjects</h4>
              <div className="flex flex-wrap gap-1.5">
                {(p.exams ?? []).map((e) => <span key={e} className="rounded-full bg-primary px-2.5 py-0.5 text-xs font-bold text-primary-foreground">{e}</span>)}
                {(p.jamb_subjects ?? []).map((s) => <span key={s} className="rounded-full border px-2.5 py-0.5 text-xs">{s}</span>)}
              </div>
            </section>
            <section className="rounded-2xl bg-muted/60 p-3">
              <h4 className="mb-1 text-xs font-bold uppercase tracking-wide text-muted-foreground">What they asked for</h4>
              <p className="text-sm">{p.request.goals}</p>
              <p className="mt-1 text-xs text-muted-foreground">{[p.request.level?.toUpperCase(), p.request.subject, p.request.times ? `Free: ${p.request.times}` : null].filter(Boolean).join(" · ")}</p>
              {p.request.custom_note ? <p className="mt-2 text-xs"><b>Custom plan:</b> {p.request.custom_note}</p> : null}
              {plan ? <p className="mt-2 text-xs"><b>{plan.name}</b> plan · {plan.left} day{plan.left === 1 ? "" : "s"} left{p.plan?.sessions ? ` · ${p.plan.sessions} lessons` : ""}</p> : null}
            </section>
            {strong.length ? (
              <section>
                <h4 className="mb-2 flex items-center gap-1 text-xs font-bold uppercase tracking-wide text-emerald-700"><TrendUp size={16} /> Strong topics</h4>
                <ul className="space-y-1.5">{strong.map((t) => <TopicBar key={t.topic} t={t} good />)}</ul>
              </section>
            ) : null}
            {weak.length ? (
              <section>
                <h4 className="mb-2 flex items-center gap-1 text-xs font-bold uppercase tracking-wide text-red-700"><TrendDown size={16} /> Needs work</h4>
                <ul className="space-y-1.5">{weak.map((t) => <TopicBar key={t.topic} t={t} />)}</ul>
              </section>
            ) : null}
            {!p.topics.length ? <p className="text-sm text-muted-foreground">No topic results yet: they need to practise a little more.</p> : null}
            {p.tests.length ? (
              <section>
                <h4 className="mb-2 text-xs font-bold uppercase tracking-wide text-muted-foreground">Recent tests</h4>
                <ul className="divide-y rounded-xl border text-sm">
                  {p.tests.map((t, i) => (
                    <li key={i} className="flex items-center gap-2 px-3 py-2">
                      <span className="flex-1 capitalize">{t.mode.replace(/_/g, " ")}</span>
                      <span className="text-xs text-muted-foreground">{new Date(t.at).toLocaleDateString("en-NG", { day: "numeric", month: "short" })}</span>
                      <b className="tabular-nums">{t.score != null && t.max ? `${t.score}/${t.max}` : t.correct != null ? `${t.correct}/${t.questions ?? t.answered}` : "-"}</b>
                    </li>
                  ))}
                </ul>
              </section>
            ) : null}
          </>
        )}
        {mode === "admin" ? (
          <section className="space-y-3 rounded-2xl border p-3">
            <h4 className="text-xs font-bold uppercase tracking-wide text-muted-foreground">Admin</h4>
            <div className="grid gap-1 text-sm">
              <label htmlFor="assign" className="font-medium">Tutor</label>
              <div className="flex gap-2">
                <select id="assign" className="h-10 flex-1 rounded-xl border bg-background px-2" value={tutor} onChange={(e) => setTutor(e.target.value)}>
                  <option value="">Choose a tutor</option>
                  {(tutors ?? []).filter((t) => t.active || t.id === chat.tutor_id).map((t) => <option key={t.id} value={t.id} disabled={!t.user_id}>{t.name}{t.subjects ? ` · ${t.subjects}` : ""}{t.user_id ? "" : " (no login)"}</option>)}
                </select>
                <Button disabled={pending || !tutor || tutor === chat.tutor_id} onClick={() => act(() => sb.rpc("admin_tutor_assign", { p_request: chat.id, p_tutor: tutor }), "Tutor assigned. They got an email.")}>Assign</Button>
              </div>
              {!["paid", "matched"].includes(chat.status) ? <p className="text-xs text-muted-foreground">You can assign a tutor after the student pays.</p> : null}
            </div>
            <div className="grid gap-1 text-sm">
              <span className="font-medium">Custom price {chat.custom_note ? "" : "(only if they asked)"}</span>
              <div className="flex gap-2">
                <input aria-label="Price in naira" type="number" min={50} placeholder="₦" className="h-10 w-28 rounded-xl border bg-background px-2" value={price} onChange={(e) => setPrice(e.target.value)} />
                <input aria-label="Days" type="number" min={1} max={366} className="h-10 w-20 rounded-xl border bg-background px-2" value={days} onChange={(e) => setDays(e.target.value)} />
                <span className="self-center text-xs text-muted-foreground">days</span>
                <Button variant="outline" disabled={pending || !price} onClick={() => act(() => sb.rpc("admin_tutor_quote", { p_request: chat.id, p_price_kobo: Math.round(Number(price) * 100), p_days: Number(days) }), "Price sent to the student.")}>Send</Button>
              </div>
              {chat.custom_price_kobo ? <p className="text-xs text-muted-foreground">Current: {naira(chat.custom_price_kobo)} for {chat.custom_days} days</p> : null}
            </div>
            <Button variant="ghost" className="text-red-600" disabled={pending} onClick={() => { if (confirm("Close this request? The student can start a new one.")) act(() => sb.rpc("admin_tutor_close", { p_request: chat.id }), "Request closed."); }}>Close request</Button>
          </section>
        ) : null}
      </div>
    </aside>
  );
}

function TopicBar({ t, good }: { t: { topic: string; subject: string; pct: number; answered: number }; good?: boolean }) {
  return (
    <li className="text-sm">
      <div className="flex justify-between gap-2"><span className="truncate">{t.topic} <span className="text-xs text-muted-foreground">· {t.subject}</span></span><b className="tabular-nums">{t.pct}%</b></div>
      <div className="mt-1 h-1.5 rounded-full bg-muted"><div className={cn("h-full rounded-full", good ? "bg-emerald-500" : "bg-red-500")} style={{ width: `${Math.max(4, t.pct)}%` }} /></div>
    </li>
  );
}
