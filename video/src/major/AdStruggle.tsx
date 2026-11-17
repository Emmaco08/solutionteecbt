import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Burst, Cursor, EndCard, ExamLogos, Flash, KText, LogoReveal } from "../pack/kit";
import { BounceText, C, Cutout, EmojiPill, FONT, Footage, Hill, LifeCard, LightStage, PhoneIn, PulseDot, Shot, Slam, Tag, easeInOut, hillY, lerp, p, spr, useF, useS } from "./kit2";
import { CLIPS } from "./clips";

// Ad 1, "Shouldn't be a struggle" (D-183, plan docs/plans/advert-major.md): 33 s, Bolt + Chowdeck + Uber Eats style.
// A student's problem (real-looking footage and 3D students from Google Flow), then the app's real screens solve it.
export const STRUGGLE_SECONDS = 33;

// ------------------------------------------------------------------ 0–2.3 s: the light goes off
const Hook: React.FC = () => {
  const F = useF();
  return (
    <Shot a={0} b={2.35} first>
      <LightStage gold={0.25} blue={0.25} />
      <BounceText text="Reading for UTME…" at={0.05} y={F.H * 0.1} size={92} stagger={0.03} />
      <Footage src={CLIPS.lamp.src} from={CLIPS.lamp.from} at={0} out={2.05} x={F.cx} y={F.H * 0.56} w={F.W - 110} h={F.H * 0.76} tilt={-1.5} push={0.06} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 2.3–3.4 s: the feeling, as emoji (Uber Eats)
const Feeling: React.FC = () => {
  const F = useF();
  return (
    <Shot a={2.3} b={3.45}>
      <LightStage gold={0.3} blue={0.3} />
      <EmojiPill items={["😩", "📚", "🕯️", "⏳"]} at={2.4} x={F.cx} y={F.cy - 60 * F.ky} step={0.14} size={104} />
      <BounceText text="Sound *familiar?*" at={2.75} y={F.cy + 190 * F.ky} size={78} stagger={0.025} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 3.4–8.2 s: the problems, on a hill (Bolt)
const Problems: React.FC = () => {
  const F = useF();
  const t = useS();
  const cw = 900, ch = 560;
  const cy = F.H * 0.33;
  const tx = lerp(-140, F.W + 140, p(t, 3.55, 8.2, (v) => v));
  return (
    <Shot a={3.4} b={8.2}>
      <LightStage gold={0.35} blue={0.3} />
      <Hill at={3.45} out={8.0} />
      <LifeCard img={CLIPS.tundeBooks} label="Too many textbooks" at={3.6} out={5.05} x={F.cx} y={cy} w={cw} h={ch} />
      <LifeCard img={CLIPS.tundeConfused} label="No past questions to practise" at={5.1} out={6.55} x={F.cx} y={cy} w={cw} h={ch} bg="#FDEFD0" />
      <LifeCard img={CLIPS.adaThink} label="Is my answer even right?" at={6.6} out={8.0} x={F.cx} y={cy} w={cw} h={ch} bg="#E3F7EA" />
      <Cutout src={CLIPS.tundeBooks} at={3.55} x={tx} y={hillY(F, tx) + 16} h={430} walk={[3.55, 8.2, -140, F.W + 140]} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 8.2–10.3 s: it shouldn't be a struggle
const Struggle: React.FC = () => {
  const F = useF();
  return (
    <Shot a={8.2} b={10.3}>
      <LightStage gold={0.45} blue={0.3} />
      <BounceText text="Getting ready / shouldn't be / a *struggle.*" at={8.3} y={F.H * 0.27} size={104} stagger={0.022} lh={1.08} />
      <Cutout src={CLIPS.adaThink} at={8.45} x={F.cx} y={F.H * 0.95} h={1080} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 10.3–12.9 s: the dot becomes the logo; every exam
const Brand: React.FC = () => {
  const F = useF();
  return (
    <Shot a={10.3} b={12.9}>
      <LightStage gold={0.5} blue={0.3} />
      <PulseDot at={10.32} x={F.cx} y={F.cy - 260 * F.ky} grow={10.62} out={10.95} />
      <LogoReveal at={10.8} y={F.cy - 260 * F.ky} size={380} width={880} hold={0.55} />
      <KText text="Meet *SolutionTee CBT*" at={11.35} y={F.cy - 40 * F.ky} size={70} />
      <ExamLogos y={F.cy + 260 * F.ky} at={11.75} h={170} step={0.16} />
      <KText text="Every exam. *One app.*" at={12.1} y={F.cy + 500 * F.ky} size={80} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 12.9–15.9 s: the real CBT, the cursor picks A
const CbtPick: React.FC = () => {
  const t = useS();
  const tap = 14.5;
  const sel = p(t, tap, tap + 0.2);
  const ok = spr(t, tap + 0.12, { damping: 10 });
  const rip = t >= tap && t < tap + 0.6 ? (t - tap) / 0.6 : -1;
  return (
    <>
      <div style={{ position: "absolute", left: 50, top: 459, width: 1070, height: 186, borderRadius: 40, border: `7px solid rgba(37,99,179,${sel})`, background: `rgba(37,99,179,${0.1 * sel})` }} />
      {ok > 0 && (
        <div style={{ position: "absolute", left: 975, top: 507, width: 92, height: 92, borderRadius: 99, background: C.blue, display: "grid", placeItems: "center", transform: `scale(${ok})` }}>
          <svg width={56} height={56} viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" stroke="#fff" strokeWidth={3.2} fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </div>
      )}
      {rip >= 0 && <div style={{ position: "absolute", left: 330 - 130, top: 552 - 130, width: 260, height: 260, borderRadius: 999, background: "rgba(37,99,179,.25)", transform: `scale(${0.3 + rip * 1.4})`, opacity: 1 - rip }} />}
    </>
  );
};

const Cbt: React.FC = () => {
  const F = useF();
  const t = useS();
  const push = p(t, 14.1, 15.7, easeInOut);
  return (
    <Shot a={12.9} b={15.9}>
      <LightStage gold={0.4} blue={0.35} />
      <BounceText text="The *real* CBT feel" at={12.95} y={F.H * 0.1} size={96} />
      <KText text="Timed · one question at a time · just like exam day" at={13.25} y={F.H * 0.165} size={34} weight={600} color="#5B6B86" stagger={0.02} />
      <PhoneIn src="major/screens/cbt.png" at={13.0} x={F.cx} y={F.H * 0.6} w={640} rx={6} ry={-8} scale={lerp(1, 1.14, push)}>
        <CbtPick />
      </PhoneIn>
      <Cursor keys={[[13.8, F.W + 80, F.H * 0.9], [14.45, F.cx - 120 * F.ks, F.H * 0.42]]} clicks={[14.5]} from={13.8} to={15.5} size={74} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 15.9–18.4 s: the score, at once
const Score: React.FC = () => {
  const F = useF();
  return (
    <Shot a={15.9} b={18.4}>
      <LightStage gold={0.55} blue={0.3} />
      <BounceText text="See your score / *at once*" at={15.95} y={F.H * 0.12} size={96} lh={1.06} />
      <PhoneIn src="major/screens/results.png" at={16.0} x={F.cx} y={F.H * 0.63} w={620} rx={6} ry={10} />
      <Burst at={16.6} x={F.cx} y={F.H * 0.45} n={90} power={0.9} />
      <Flash at={16.6} max={0.25} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 18.4–21.5 s: the AI tutor explains, step by step
const TutorReveal: React.FC = () => {
  const t = useS();
  // the answer card (y 650–1460 on the real screen) is revealed top to bottom, like streaming text
  const k = p(t, 19.35, 20.6, (v) => v);
  const top = 650 + k * 810;
  return <div style={{ position: "absolute", left: 0, right: 0, top, height: Math.max(0, 1500 - top), background: "#F4F6FA" }} />;
};

const Tutor: React.FC = () => {
  const F = useF();
  return (
    <Shot a={18.4} b={21.5}>
      <LightStage gold={0.35} blue={0.45} />
      <BounceText text="Stuck? *Ask* / the AI tutor" at={18.45} y={F.H * 0.12} size={96} lh={1.06} />
      <PhoneIn src="major/screens/ai.png" at={18.5} x={F.cx} y={F.H * 0.63} w={620} rx={6} ry={-10}>
        <TutorReveal />
      </PhoneIn>
      <Tag text="Step by step" x={F.cx + 300 * F.ks} y={F.H * 0.47} at={19.6} bg={C.gold} color={C.navy} size={38} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 21.5–23.7 s: play with friends
const Games: React.FC = () => {
  const F = useF();
  return (
    <Shot a={21.5} b={23.7}>
      <LightStage gold={0.5} blue={0.35} />
      <BounceText text="Practise with *friends*" at={21.55} y={F.H * 0.1} size={92} />
      <PhoneIn src="screens/04_duel.jpg" at={21.6} x={F.cx + 120 * F.ks} y={F.H * 0.6} w={600} rx={6} ry={-14} from="right" />
      <Cutout src={CLIPS.tundeWin} at={21.95} x={F.cx - 270 * F.ks} y={F.H * 0.94} h={760} />
      <Tag text="Game Zone" x={F.cx + 170 * F.ks} y={F.H * 0.25} at={22.1} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 23.7–26.7 s: let SolutionTee handle the practice (Bolt "Let Bolt handle it")
const Win: React.FC = () => {
  const F = useF();
  return (
    <Shot a={23.7} b={26.7}>
      <LightStage gold={0.55} blue={0.3} />
      <Footage src={CLIPS.win.src} from={CLIPS.win.from} at={23.75} out={26.45} x={F.cx} y={F.cy} w={F.W - 110} h={F.H * 0.86} tilt={1.5} caption="Let SolutionTee / handle the *practice.*" captionSize={76} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 26.7–29.5 s: no stress, no guessing, just practise and go
const Lines: React.FC = () => {
  const F = useF();
  const t = useS();
  const beat = Math.max(0, Math.sin(((t - 26.7) % 0.5) / 0.5 * Math.PI)) * 0.02;
  return (
    <Shot a={26.7} b={29.55}>
      <LightStage gold={0.6} blue={0.3} />
      <div style={{ position: "absolute", inset: 0, transform: `scale(${1 + beat})` }}>
        <Slam text="No stress." at={26.75} y={F.cy - 260 * F.ky} size={150} accentFrom={1} out={28.1} />
        <Slam text="No guessing." at={27.25} y={F.cy - 60 * F.ky} size={150} accentFrom={1} out={28.1} />
        <BounceText text="Just *Practise* / and *Go.*" at={28.15} y={F.cy - 120 * F.ky} size={170} accent={C.blue} stagger={0.03} lh={1.02} />
      </div>
      <Cutout src={CLIPS.adaJump} at={28.35} x={F.cx} y={F.H * 0.98} h={720} />
    </Shot>
  );
};

const Ender: React.FC = () => {
  const t = useS();
  if (t < 29.45) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 29.45, 29.75) }}>
      <EndCard at={29.5} cta="Download free" />
    </AbsoluteFill>
  );
};

export const AdStruggle: React.FC = () => (
  <AbsoluteFill style={{ background: "#F8FAFE", fontFamily: FONT }}>
    <Audio src={staticFile("audio/major_struggle.wav")} />
    <Hook />
    <Feeling />
    <Problems />
    <Struggle />
    <Brand />
    <Cbt />
    <Score />
    <Tutor />
    <Games />
    <Win />
    <Lines />
    <Ender />
  </AbsoluteFill>
);
