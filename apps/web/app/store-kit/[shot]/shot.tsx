"use client";
import { Phone3D } from "@/app/site/_components/phone";
import { AiScreen, CbtScreen, LeaderScreen, ResultScreen, StudyScreen } from "@/app/site/_components/screens";

/** Google Play store images (D-118), drawn at their real pixel size and captured with a headless browser. */
const SHOTS: Record<string, { title: string; text: string; screen: React.ReactNode; accent?: string }> = {
  "1": { title: "A real JAMB, WAEC & NECO CBT", text: "Timed tests that feel like exam day", screen: <CbtScreen play={false} /> },
  "2": { title: "Your score the moment you finish", text: "JAMB score out of 400, by subject", screen: <ResultScreen play={false} /> },
  "3": { title: "Stuck? Ask your AI tutor", text: "Snap a question and get the steps", screen: <AiScreen play={false} /> },
  "4": { title: "Video solutions & lessons", text: "Learn it properly, then practise", screen: <StudyScreen play={false} /> },
  "5": { title: "Challenges & leaderboards", text: "Practise with students across Nigeria", screen: <LeaderScreen play={false} /> },
};

export function Shot({ id }: { id: string }) {
  if (id === "feature") return <Feature />;
  if (id === "icon") return <Icon />;
  const s = SHOTS[id] ?? SHOTS["1"];
  return (
    <div className="relative overflow-hidden" style={{ width: 1080, height: 1920, background: "linear-gradient(160deg,#0B1F44 0%,#06132B 55%,#0E2A5C 100%)" }}>
      <div className="absolute -left-40 top-40 size-[700px] rounded-full bg-[#2563B3]/35 blur-[140px]" />
      <div className="absolute -right-40 bottom-0 size-[600px] rounded-full bg-[#F2B233]/25 blur-[140px]" />
      <div className="relative px-20 pt-28 text-center text-white">
        <h1 className="text-[78px] font-bold leading-[1.05] tracking-tight">{s.title}</h1>
        <p className="mt-6 text-[40px] text-[#C9D5EA]">{s.text}</p>
      </div>
      <div className="absolute left-1/2 top-[520px] -translate-x-1/2">
        <Phone3D width={700} tilt={false} float={false}>{s.screen}</Phone3D>
      </div>
    </div>
  );
}

function Feature() {
  return (
    <div className="relative overflow-hidden text-white" style={{ width: 1024, height: 500, background: "linear-gradient(120deg,#0B1F44 0%,#06132B 60%,#0E2A5C 100%)" }}>
      <div className="absolute -left-24 -top-24 size-[420px] rounded-full bg-[#2563B3]/40 blur-[110px]" />
      <div className="absolute -right-10 bottom-[-120px] size-[380px] rounded-full bg-[#F2B233]/30 blur-[110px]" />
      <div className="relative flex h-full items-center pl-16">
        <div className="w-[520px]">
          <div className="flex items-center gap-4">
            {/* Real brand mark from /brand (never redrawn) */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/favicon.svg" alt="" className="size-[84px] rounded-[20px]" />
            <span className="text-[44px] font-bold tracking-tight">SolutionTee <span className="text-[#F2B233]">CBT</span></span>
          </div>
          <p className="mt-6 text-[40px] font-bold leading-[1.1]">Practise like it’s the real exam.</p>
          <p className="mt-4 text-[22px] text-[#C9D5EA]">JAMB · WAEC · NECO CBT practice with every answer explained and an AI tutor.</p>
        </div>
      </div>
      <div className="absolute right-[150px] top-[40px] rotate-[6deg]"><Phone3D width={250} tilt={false} float={false}><ResultScreen play={false} /></Phone3D></div>
      <div className="absolute right-[-20px] top-[70px] rotate-[-4deg]"><Phone3D width={250} tilt={false} float={false}><CbtScreen play={false} /></Phone3D></div>
    </div>
  );
}

function Icon() {
  return (
    // The brand's own app icon file, unchanged (/brand/favicon.svg), drawn at 512 × 512.
    // eslint-disable-next-line @next/next/no-img-element
    <img src="/brand/favicon.svg" alt="SolutionTee CBT" width={512} height={512} style={{ display: "block", width: 512, height: 512 }} />
  );
}
