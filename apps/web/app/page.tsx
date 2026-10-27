import Link from "next/link";

// Placeholder until the marketing site and student web app are built (Phase 5).
export default function Home() {
  return (
    <main className="grid min-h-dvh place-items-center bg-navy-deep px-4 text-center text-white">
      <div className="max-w-md">
        <img src="/brand/favicon.svg" alt="" className="mx-auto size-16 rounded-2xl" />
        <h1 className="mt-6 text-[32px] font-bold leading-[38px] tracking-tight">SolutionTee CBT</h1>
        <p className="mt-2 text-[17px] text-gold">Learn. Think. Solve.</p>
        <p className="mt-4 text-sm leading-6 text-[#BCC9DF]">JAMB, WAEC and NECO practice for Nigerian students. The app and website are on the way.</p>
        <Link href="/admin" className="mt-8 inline-flex h-12 items-center rounded-xl bg-gold px-6 font-bold text-navy">Admin login</Link>
        <p className="mt-10 text-xs leading-5 text-[#8FA2C4]">SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.</p>
      </div>
    </main>
  );
}
