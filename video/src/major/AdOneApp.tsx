import React from "react";
import { AbsoluteFill, Audio, Img, staticFile } from "remotion";
import { BookOpenText, Calculator, ChalkboardTeacher, Exam, GameController, Sparkle, Timer, Trophy, UsersThree, WifiSlash } from "@phosphor-icons/react";
import { Cursor, EndCard, Flash, KText, LogoReveal, PromptBar } from "../pack/kit";
import { BounceText, C, Flood, FONT, Footage, LightStage, MorphButton, NavyStage, OrbitRing, PhoneIn, Shot, Sticker, Swoosh, Tag, easeInOut, lerp, p, spr, useF, useS } from "./kit2";
import { CLIPS } from "./clips";

// Ad 2, "One app. Every subject." (D-183, plan docs/plans/advert-major.md): 34 s, Gojek + Glovo + ClickUp + Spotify
// style. Light and premium, a dive into the phone, a dark navy section, a gold finish. Real app screens throughout.
export const ONEAPP_SECONDS = 34;

const ic = (I: React.ElementType, color: string = C.navy, size = 66) => <I size={size} weight="fill" color={color} />;

// ------------------------------------------------------------------ 0–3 s: the question, with stickers floating round it (Glovo)
const Ask: React.FC = () => {
  const F = useF();
  const y = F.cy - 40 * F.ky;
  const st: [number, number, React.ReactNode, number][] = [
    [F.cx - 330 * F.ks, y - 330 * F.ky, ic(BookOpenText, C.blue), 0.15],
    [F.cx + 320 * F.ks, y - 300 * F.ky, ic(Calculator, C.navy), 0.3],
    [F.cx - 360 * F.ks, y + 300 * F.ky, ic(Timer, "#E5484D"), 0.45],
    [F.cx + 330 * F.ks, y + 320 * F.ky, ic(Trophy, "#C98A0E"), 0.6],
    [F.cx, y - 470 * F.ky, ic(Exam, C.blue), 0.75],
  ];
  return (
    <Shot a={0} b={3.05} first>
      <LightStage gold={0.5} blue={0.35} />
      {st.map(([x, yy, node, at], i) => (
        <Sticker key={i} x={x} y={yy} at={at} size={150} seed={i + 1}>{node}</Sticker>
      ))}
      {/* the prompt bar's type is sized for 940 px; scaled up as a whole so the hook reads on a phone */}
      <div style={{ position: "absolute", inset: 0, transform: `scale(${F.tall ? 1.3 : 1.1})`, transformOrigin: `${F.cx}px ${y}px` }}>
        <PromptBar x={F.cx} y={y} w={760 * F.ks} at={0.35} text="How do I get ready for UTME?" cps={24} placeholder="Ask anything…" send={2.55} />
      </div>
      <BounceText text="The question every / *student* asks…" at={0.1} y={F.H * 0.12} size={80} stagger={0.022} out={2.7} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 3–5 s: introducing… (Glovo / Gojek)
const Intro: React.FC = () => {
  const F = useF();
  return (
    <Shot a={3.0} b={5.05}>
      <LightStage gold={0.55} blue={0.3} />
      <KText text="Introducing" at={3.05} y={F.cy - 230 * F.ky} size={70} weight={700} color="#5B6B86" out={4.75} />
      <LogoReveal at={3.45} y={F.cy - 20 * F.ky} size={400} width={900} hold={0.6} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 5–7.2 s: one app, every subject; exam pins pop round the phone
const ExamPin: React.FC<{ file: string; x: number; y: number; at: number }> = ({ file, x, y, at }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 9, stiffness: 200 });
  if (k <= 0.001) return null;
  const s = 150 * F.ks;
  return (
    <div style={{ position: "absolute", left: x, top: y + Math.sin(t * 2 + x) * 8, transform: `translate(-50%,-100%) scale(${k})`, transformOrigin: "50% 100%" }}>
      <div style={{ width: s, height: s, borderRadius: "50% 50% 50% 0", transform: "rotate(-45deg)", background: "#fff", boxShadow: "0 24px 50px -20px rgba(11,31,68,.55)", display: "grid", placeItems: "center" }}>
        <Img src={staticFile(`brand/${file}.png`)} style={{ width: s * 0.66, height: s * 0.66, objectFit: "contain", transform: "rotate(45deg)" }} />
      </div>
    </div>
  );
};

const OneApp: React.FC = () => {
  const F = useF();
  return (
    <Shot a={5.0} b={7.25}>
      <LightStage gold={0.55} blue={0.35} />
      <PhoneIn src="major/screens/home.png" at={5.0} x={F.cx} y={F.H * 0.56} w={560} from="blur" rx={4} ry={0} />
      <KText text="One app" at={5.35} y={F.H * 0.12} size={100} />
      <KText text="*Every subject.*" at={5.6} y={F.H * 0.2} size={100} serifScale={1.12} />
      <ExamPin file="jamb" x={F.cx - 380 * F.ks} y={F.H * 0.42} at={6.0} />
      <ExamPin file="waec" x={F.cx + 390 * F.ks} y={F.H * 0.5} at={6.18} />
      <ExamPin file="neco" x={F.cx - 370 * F.ks} y={F.H * 0.7} at={6.36} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 7.2–15 s: every feature rides the swoosh, one per beat (Gojek)
const FEATURES: [string, string, React.ElementType][] = [
  ["major/screens/cbt.png", "CBT practice", Exam],
  ["major/screens/ai.png", "AI tutor", Sparkle],
  ["major/screens/study.png", "Notes & video lessons", BookOpenText],
  ["screens/01_hub.jpg", "Game Zone", GameController],
  ["screens/class_live.jpg", "Live classes", ChalkboardTeacher],
  ["screens/store_community.jpg", "Community", UsersThree],
];
const STEP = 1.3;
const T0 = 7.2;

const Features: React.FC = () => {
  const F = useF();
  return (
    <Shot a={T0} b={T0 + STEP * FEATURES.length}>
      <LightStage gold={0.4} blue={0.4} />
      <Swoosh at={T0} out={T0 + STEP * FEATURES.length - 0.4} width={300} />
      <KText text="Everything for your exam" at={T0 + 0.05} y={F.H * 0.09} size={70} />
      {FEATURES.map(([src, label, I], i) => {
        const a = T0 + i * STEP;
        const last = i === FEATURES.length - 1;
        return (
          <React.Fragment key={src}>
            <PhoneIn src={src} at={a} out={last ? undefined : a + STEP - 0.2} x={F.cx} y={F.H * 0.55} w={560} from="right" rx={4} ry={-16} rz={-3} />
            <Tag text={label} x={F.cx} y={F.H * 0.9} at={a + 0.15} out={a + STEP - 0.2} bg={C.navy} icon={<I size={44 * F.ks} weight="fill" color={C.gold} />} />
          </React.Fragment>
        );
      })}
    </Shot>
  );
};

// ------------------------------------------------------------------ 15–18 s: practise anywhere, even offline (footage)
const Anywhere: React.FC = () => {
  const F = useF();
  return (
    <Shot a={15.0} b={18.05}>
      <LightStage gold={0.5} blue={0.3} />
      <Footage src={CLIPS.bus.src} from={CLIPS.bus.from} at={15.05} out={17.8} x={F.cx} y={F.cy + 40 * F.ky} w={F.W - 110} h={F.H * 0.84} tilt={-1.5} caption="Practise anywhere. / Even *offline.*" captionSize={76} />
      <Tag text="Works offline" x={F.cx} y={F.H * 0.07} at={15.6} bg="#fff" color={C.navy} icon={<WifiSlash size={44 * F.ks} weight="fill" color={C.blue} />} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 18–21 s: practise your way (real Test tab, the cursor picks Topic drill)
const YourWay: React.FC = () => {
  const F = useF();
  const t = useS();
  const tap = 19.75;
  const hl = p(t, tap, tap + 0.2);
  return (
    <Shot a={18.0} b={21.05}>
      <LightStage gold={0.45} blue={0.4} />
      <BounceText text="Practise *your* way" at={18.05} y={F.H * 0.1} size={96} />
      <KText text="Full JAMB mock · topic drill · custom exam" at={18.35} y={F.H * 0.165} size={36} weight={600} color="#5B6B86" stagger={0.02} />
      <PhoneIn src="major/screens/test.png" at={18.1} x={F.cx} y={F.H * 0.6} w={620} rx={6} ry={8}>
        <div style={{ position: "absolute", left: 40, top: 1110, width: 1090, height: 205, borderRadius: 36, border: `7px solid rgba(37,99,179,${hl})`, background: `rgba(37,99,179,${0.08 * hl})` }} />
      </PhoneIn>
      <Cursor keys={[[18.9, -80, F.H * 0.9], [19.7, F.cx - 80 * F.ks, F.H * 0.565]]} clicks={[tap]} from={18.9} to={20.8} size={74} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 21–23.1 s: the camera dives into the phone (Spotify)
const Dive: React.FC = () => {
  const F = useF();
  const t = useS();
  const z = p(t, 21.6, 22.9, (v) => v * v * v);
  const dark = p(t, 22.55, 23.0);
  return (
    <Shot a={21.0} b={23.1} last>
      <LightStage gold={0.5} blue={0.4} />
      <div style={{ position: "absolute", inset: 0, transform: `scale(${lerp(1, 9, z)})`, transformOrigin: `${F.cx}px ${F.H * 0.36}px` }}>
        <PhoneIn src="major/screens/home.png" at={21.0} x={F.cx} y={F.H * 0.55} w={560} from="blur" rx={lerp(10, 0, z)} ry={lerp(-12, 0, z)} />
      </div>
      <KText text="Let's go *inside*" at={21.1} y={F.H * 0.1} size={84} out={21.8} />
      <AbsoluteFill style={{ background: "#071530", opacity: dark }} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 23–25.6 s: all connected (ClickUp ring, navy stage)
const Connected: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 23.15, { damping: 12 });
  const ring = [Exam, Sparkle, BookOpenText, GameController, ChalkboardTeacher, UsersThree, Trophy, Timer].map((I, i) => (
    <div key={i} style={{ width: 120 * F.ks, height: 120 * F.ks, borderRadius: 36 * F.ks, background: "rgba(255,255,255,.1)", border: "2px solid rgba(255,255,255,.18)", display: "grid", placeItems: "center", boxShadow: "0 0 30px rgba(242,178,51,.25)" }}>
      <I size={60 * F.ks} weight="fill" color={i % 2 ? C.gold : "#fff"} />
    </div>
  ));
  return (
    <Shot a={23.0} b={25.65} first>
      <NavyStage />
      <OrbitRing at={23.1} x={F.cx} y={F.cy - 60 * F.ky} r={400} icons={ring} speed={16} />
      {/* the real app icon file (brand/favicon.svg), unchanged */}
      <div style={{ position: "absolute", left: F.cx, top: F.cy - 60 * F.ky, transform: `translate(-50%,-50%) scale(${k})` }}>
        <Img src={staticFile("brand/favicon.svg")} style={{ width: 260 * F.ks, height: 260 * F.ks, borderRadius: 64 * F.ks, boxShadow: "0 0 90px rgba(242,178,51,.55)" }} />
      </div>
      <BounceText text="All *connected.*" at={23.6} y={F.H * 0.82} size={110} color="#fff" accent={C.gold} />
      <KText text="Practice, lessons, games and people, in one place" at={24.0} y={F.H * 0.89} size={36} weight={600} color="#AFC0DD" stagger={0.02} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 25.6–28.6 s: learn with your friends (footage on navy)
const Friends: React.FC = () => {
  const F = useF();
  return (
    <Shot a={25.6} b={28.65}>
      <NavyStage glow={0.9} />
      <Footage src={CLIPS.duel.src} from={CLIPS.duel.from} at={25.65} out={28.35} x={F.cx} y={F.cy} w={F.W - 110} h={F.H * 0.86} tilt={1.5} caption="Learn with / your *friends.*" captionSize={84} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 28.6–30.9 s: gold flood, the button becomes an arrow (Gojek)
const Go: React.FC = () => {
  const F = useF();
  return (
    <Shot a={28.6} b={30.95} first>
      <NavyStage />
      <Flood at={28.6} x={F.cx} y={F.H * 0.62} />
      <BounceText text="Ready when / *you are.*" at={28.95} y={F.H * 0.36} size={124} color={C.navy} accent={C.blue} lh={1.04} />
      <MorphButton text="Download free" at={29.2} press={29.95} x={F.cx} y={F.H * 0.62} />
      <Flash at={30.75} max={0.6} />
    </Shot>
  );
};

const Ender: React.FC = () => {
  const t = useS();
  if (t < 30.85) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 30.85, 31.15, easeInOut) }}>
      <EndCard at={30.9} cta="Download free" />
    </AbsoluteFill>
  );
};

export const AdOneApp: React.FC = () => (
  <AbsoluteFill style={{ background: "#F8FAFE", fontFamily: FONT }}>
    <Audio src={staticFile("audio/major_oneapp.wav")} />
    <Ask />
    <Intro />
    <OneApp />
    <Features />
    <Anywhere />
    <YourWay />
    <Dive />
    <Connected />
    <Friends />
    <Go />
    <Ender />
  </AbsoluteFill>
);
