import type { Metadata } from "next";
import { siteData, paystackFee } from "@/lib/site";
import { SiteNav } from "./_components/nav";
import { Hero } from "./_components/hero";
import { AiShowcase, Download, ExamStrip, Faq, Features, HowItWorks, Pricing, SiteFooter, type PricePlan } from "./_components/sections";

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
  return (
    <div className="flex min-h-dvh flex-col overflow-x-clip bg-background">
      <SiteNav />
      <main>
        <Hero questions={d.questions} firstYear={d.firstYear} lastYear={d.lastYear} playUrl={d.playUrl} />
        <ExamStrip subjects={d.subjects} studyItems={d.studyItems} />
        <Features />
        <AiShowcase />
        <HowItWorks />
        <Pricing plans={plans} />
        <Download playUrl={d.playUrl} />
        <Faq />
      </main>
      <SiteFooter />
    </div>
  );
}
