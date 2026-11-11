import type { Metadata } from "next";
import { siteData, paystackFee } from "@/lib/site";
import { SiteNav } from "./_components/nav";
import { Hero } from "./_components/hero";
import { Download, ExamStrip, Faq, Features, HowItWorks, Pricing, SiteFooter, SubjectMarquee, type PricePlan } from "./_components/sections";
import { FeatureTour } from "./_components/tour";
import { Announcement, EarnSection } from "./_components/earn";
import { fill } from "@/lib/site-cms";

export const metadata: Metadata = {
  title: { absolute: "SolutionTee CBT · JAMB, WAEC and NECO CBT practice" },
  description: "Practise JAMB, WAEC and NECO past questions in a real CBT, with every answer explained, video lessons and an AI tutor. Free to start.",
  openGraph: { title: "SolutionTee CBT", description: "Practise like it’s the real exam. JAMB, WAEC and NECO CBT practice for Nigerian students.", siteName: "SolutionTee CBT" },
};

/** cbt.solutiontee.com (the proxy serves this page at "/" on that host): landing page, D-114. */
export default async function SitePage() {
  const d = await siteData();
  const plans: PricePlan[] = d.plans.map((p) => ({
    code: p.code, name: p.name, description: p.description, price: p.price, fee: paystackFee(p.price, d.fee),
    period: p.days ? `${p.days} days of Premium` : p.ends_on ? `Premium until ${new Date(p.ends_on).toLocaleDateString("en-NG", { day: "numeric", month: "long", year: "numeric" })}` : "Premium",
  }));
  const { cms, facts } = d;
  const on = cms.sections;
  const f = (t: string) => fill(t, facts);
  const links: [string, string][] = [
    ...(on.tour ? ([["#features", "Features"], ["#ai", "AI tutor"]] as [string, string][]) : []),
    ...(on.invite ? ([["#invite", "Invite & earn"]] as [string, string][]) : on.challenges ? ([["#challenges", "Challenges"]] as [string, string][]) : []),
    ...(on.pricing ? ([["#pricing", "Pricing"]] as [string, string][]) : []),
    ...(on.faq ? ([["#faq", "FAQ"]] as [string, string][]) : []),
  ];
  return (
    <div className="flex min-h-dvh flex-col overflow-x-clip bg-background">
      {cms.announcement.on && cms.announcement.text ? <Announcement text={f(cms.announcement.text)} link={cms.announcement.link} /> : null}
      <SiteNav links={links} />
      <main>
        <Hero badge={f(cms.hero.badge)} title={f(cms.hero.title)} highlight={f(cms.hero.highlight)} subtitle={f(cms.hero.subtitle)} playUrl={d.playUrl} />
        {on.exams ? <ExamStrip subjects={d.subjects} studyItems={d.studyItems} logos={d.examLogos} /> : null}
        {on.subjects ? <SubjectMarquee /> : null}
        {on.tour ? <FeatureTour /> : null}
        {on.features ? <Features /> : null}
        {on.invite ? <EarnSection kind="invite" cash={facts.cash} eyebrow={f(cms.invite.eyebrow)} title={f(cms.invite.title)} text={f(cms.invite.text)} points={cms.invite.points.map(f)} /> : null}
        {on.challenges ? <EarnSection kind="challenges" cash={facts.cash} eyebrow={f(cms.challenges.eyebrow)} title={f(cms.challenges.title)} text={f(cms.challenges.text)} points={cms.challenges.points.map(f)} /> : null}
        {on.how ? <HowItWorks title={f(cms.how.title)} steps={cms.how.steps.map((x) => ({ title: f(x.title), text: f(x.text) }))} /> : null}
        {on.pricing ? <Pricing plans={plans} /> : null}
        {on.download ? <Download playUrl={d.playUrl} title={f(cms.download.title)} text={f(cms.download.text)} /> : null}
        {on.faq ? <Faq title={f(cms.faq.title)} items={cms.faq.items.map((x) => ({ q: f(x.q), a: f(x.a) }))} /> : null}
      </main>
      <SiteFooter tagline={f(cms.footer.tagline)} />
    </div>
  );
}
