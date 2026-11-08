/**
 * Website content managed from admin → Website (D-122). Stored in app_settings.site_cms; anything missing or invalid
 * falls back to these defaults, so the site never breaks. Texts may use {rewards}, which becomes what students can win
 * right now (it follows the cash prize switches), so a text never promises cash while cash is off.
 */
export const SECTION_KEYS = ["exams", "subjects", "tour", "features", "invite", "challenges", "how", "pricing", "download", "faq"] as const;
export type SectionKey = (typeof SECTION_KEYS)[number];

export const SECTION_LABELS: Record<SectionKey, string> = {
  exams: "Exams and numbers strip",
  subjects: "Moving subjects ribbon",
  tour: "Feature tour (phone with real app screens)",
  features: "“And there’s more” cards",
  invite: "Invite friends and earn",
  challenges: "Practise in challenges and win",
  how: "Start in three steps",
  pricing: "Premium prices",
  download: "Download the app",
  faq: "Questions students ask",
};

export type Faq = { q: string; a: string };
export type SiteCms = {
  announcement: { on: boolean; text: string; link: string };
  hero: { badge: string; title: string; highlight: string; subtitle: string };
  sections: Record<SectionKey, boolean>;
  invite: { eyebrow: string; title: string; text: string; points: string[] };
  challenges: { eyebrow: string; title: string; text: string; points: string[] };
  how: { title: string; steps: { title: string; text: string }[] };
  download: { title: string; text: string };
  faq: { title: string; items: Faq[] };
  footer: { tagline: string };
};

export const CMS_DEFAULTS: SiteCms = {
  announcement: { on: false, text: "", link: "" },
  hero: {
    badge: "JAMB · WAEC · NECO CBT practice",
    title: "Practise like it’s the",
    highlight: "real exam.",
    subtitle: "{questions}+ past questions from {firstYear} to {lastYear}, a timed CBT that feels like exam day, every answer explained, and an AI tutor that helps you understand. Learn. Think. Solve.",
  },
  sections: { exams: true, subjects: true, tour: true, features: true, invite: true, challenges: true, how: true, pricing: true, download: true, faq: true },
  invite: {
    eyebrow: "Invite friends",
    title: "Share your code. Earn {rewards}.",
    text: "Every friend who joins with your code and finishes a practice test counts. The more friends, the cheaper your Premium.",
    points: ["{pct}% off Premium for every friend, up to {maxPct}%", "+{xp} XP for every friend who joins", "Share on WhatsApp in one tap"],
  },
  challenges: {
    eyebrow: "Challenges",
    title: "Practise in challenges. Win {rewards}.",
    text: "Timed challenges with students across Nigeria every week. Free to join, fair-play rules, winners shown on the Winners wall.",
    points: ["Free to join, no XP fee", "Top 3 win {rewards}", "Every finisher gets +{finishXp} XP"],
  },
  how: {
    title: "Start in three steps",
    steps: [
      { title: "Get the app", text: "Download it free and create your account with your email." },
      { title: "Pick your exam", text: "Choose JAMB, WAEC or NECO, your subjects and your target score." },
      { title: "Practise and improve", text: "Take timed tests, read the explanations and fix your weak topics." },
    ],
  },
  download: { title: "Your exam is coming. Start today.", text: "Free to download. Works on Android phones with 3 GB of memory or more." },
  faq: {
    title: "Questions students ask",
    items: [
      { q: "Is SolutionTee CBT free?", a: "Yes. You can practise free every day. Premium opens every past-question year, video solutions, lessons and more AI tutor help." },
      { q: "How do I pay without a card?", a: "On this website you can pay with bank transfer, USSD, OPay and other bank apps through Paystack. Log in with the same email you use in the app, and Premium shows in the app at once." },
      { q: "Does Premium renew by itself?", a: "No. You pay once for the period you choose. Nothing is taken from your account later." },
      { q: "Can I use it without data?", a: "Yes. Download questions while you have data, then practise offline. Your results sync later." },
      { q: "Is the AI tutor safe for students?", a: "It only helps with schoolwork and exam topics, and it refuses anything else. Students under 18 never see personalised ads." },
      { q: "Who can use SolutionTee CBT?", a: "Students aged 13 and older. If you are 13 to 17, we let a parent or guardian know you joined." },
      { q: "Is this the official JAMB, WAEC or NECO app?", a: "No. SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO." },
    ],
  },
  footer: { tagline: "Learn. Think. Solve." },
};

const str = (v: unknown, max: number, d: string) => (typeof v === "string" ? v.slice(0, max) : d);
const list = (v: unknown, max: number, len: number, d: string[]) =>
  Array.isArray(v) ? v.filter((x): x is string => typeof x === "string" && x.trim() !== "").slice(0, max).map((x) => x.slice(0, len)) : d;
const obj = (v: unknown) => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {});

/** Safe merge of whatever is stored with the defaults (never trusts the stored shape). */
export function mergeCms(raw: unknown): SiteCms {
  const r = obj(raw), D = CMS_DEFAULTS;
  const a = obj(r.announcement), h = obj(r.hero), s = obj(r.sections), inv = obj(r.invite), ch = obj(r.challenges);
  const how = obj(r.how), dl = obj(r.download), fq = obj(r.faq), ft = obj(r.footer);
  const link = str(a.link, 300, "");
  const steps = Array.isArray(how.steps) ? how.steps.map(obj) : [];
  const items = Array.isArray(fq.items) ? fq.items.map(obj).filter((x) => typeof x.q === "string" && x.q.trim() && typeof x.a === "string") : null;
  return {
    announcement: { on: a.on === true, text: str(a.text, 200, ""), link: /^(https:\/\/|\/)/.test(link) ? link : "" },
    hero: { badge: str(h.badge, 80, D.hero.badge), title: str(h.title, 80, D.hero.title), highlight: str(h.highlight, 60, D.hero.highlight), subtitle: str(h.subtitle, 400, D.hero.subtitle) },
    sections: Object.fromEntries(SECTION_KEYS.map((k) => [k, typeof s[k] === "boolean" ? (s[k] as boolean) : D.sections[k]])) as SiteCms["sections"],
    invite: { eyebrow: str(inv.eyebrow, 40, D.invite.eyebrow), title: str(inv.title, 120, D.invite.title), text: str(inv.text, 400, D.invite.text), points: list(inv.points, 5, 120, D.invite.points) },
    challenges: { eyebrow: str(ch.eyebrow, 40, D.challenges.eyebrow), title: str(ch.title, 120, D.challenges.title), text: str(ch.text, 400, D.challenges.text), points: list(ch.points, 5, 120, D.challenges.points) },
    how: {
      title: str(how.title, 80, D.how.title),
      steps: D.how.steps.map((d, i) => ({ title: str(steps[i]?.title, 60, d.title), text: str(steps[i]?.text, 200, d.text) })),
    },
    download: { title: str(dl.title, 80, D.download.title), text: str(dl.text, 300, D.download.text) },
    faq: { title: str(fq.title, 80, D.faq.title), items: items ? items.slice(0, 15).map((x) => ({ q: String(x.q).slice(0, 160), a: String(x.a).slice(0, 800) })) : D.faq.items },
    footer: { tagline: str(ft.tagline, 80, D.footer.tagline) },
  };
}

export type RewardFacts = {
  cash: boolean; teens: boolean; pct: number; maxPct: number; xp: number; finishXp: number; cashEvery: number; cashNaira: number;
  questions: number; firstYear: number; lastYear: number;
};

/** What students can win right now, in words. */
export function rewardsWords(f: Pick<RewardFacts, "cash">) {
  return f.cash ? "cash prizes, Premium days and XP" : "Premium days and XP";
}

/** Fills {rewards}, {pct}, {xp} … in a CMS text. Unknown placeholders are left out. */
export function fill(text: string, f: RewardFacts) {
  const v: Record<string, string> = {
    rewards: rewardsWords(f), pct: String(f.pct), maxPct: String(f.maxPct), xp: String(f.xp), finishXp: String(f.finishXp),
    cashEvery: String(f.cashEvery), cashNaira: `₦${f.cashNaira.toLocaleString("en-NG")}`,
    questions: f.questions.toLocaleString("en-NG"), firstYear: String(f.firstYear), lastYear: String(f.lastYear),
  };
  return text.replace(/\{(\w+)\}/g, (_, k: string) => v[k] ?? "");
}
