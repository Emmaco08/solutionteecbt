import React from "react";
import { AbsoluteFill, Img, Sequence, staticFile, interpolate } from "remotion";
import { Lottie } from "@remotion/lottie";
import { C, FONT, GAME, clamp, easeIn, easeInOut, easeOut, lerp, p, rnd, shake, spr, useFramesTo, useT, wordAt } from "./lib";
import { Chip, CoinBurst, CoinRain, Flash, Glass, Phone, Ring, Sparkle, Stage, Sweep, Words, useCut } from "./components";
import loaderLight from "../public/brand/solutiontee-loader-light.json";

const W = 1080;

/* ------------------------------------------------------------------ 20–24 s: offline */
const Wifi: React.FC<{ cut: number; color: string }> = ({ cut, color }) => (
  <svg width={260} height={220} viewBox="0 0 26 22">
    <g fill="none" stroke={color} strokeWidth={2.4} strokeLinecap="round">
      <path d="M2 8 Q13 -1 24 8" />
      <path d="M5.5 11.5 Q13 5 20.5 11.5" />
      <path d="M9 15 Q13 12 17 15" />
    </g>
    <circle cx={13} cy={18.5} r={1.8} fill={color} />
    <line x1={3} y1={2} x2={3 + 20 * cut} y2={2 + 18 * cut} stroke={C.red} strokeWidth={2.6} strokeLinecap="round" />
  </svg>
);
export const Offline: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [19.95, 20.05], [0, 1], clamp);
  const flipIn = p(t, 19.95, 20.3, easeOut);
  const gray = interpolate(t, [20.4, 20.6, 21.15, 21.25], [0, 1, 1, 0], clamp);
  const ok = 21.22;
  const s = shake(t, [ok], 14);
  const exit = p(t, 23.7, 24.05, easeIn);
  const prog = p(t, 22.3, 23.4, easeInOut);
  const done = t >= 23.4;
  const R = 70, L = 2 * Math.PI * R;
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <AbsoluteFill style={{ filter: `grayscale(${gray}) brightness(${1 - gray * 0.35})` }}>
        <Stage hue="navy" dust={40} />
        <AbsoluteFill style={{ transform: `translate(${s.x}px, ${s.y}px)` }}>
          <Phone src="screens/gate_offline.jpg" x={540} y={1250 + exit * 900} width={600} ry={lerp(-90, -8, flipIn) + Math.sin(t) * 3} rx={6} scale={1 - exit * 0.3} />
          <div style={{ position: "absolute", left: W / 2 - 130, top: 470, transform: `scale(${spr(t, 20.35, { stiffness: 220 })})`, opacity: 1 - p(t, 21.2, 21.35) }}>
            <Wifi cut={p(t, 20.5, 20.85)} color="#fff" />
          </div>
          <Words y={250} size={104} words={[{ w: "No", at: 20.4 }, { w: "data?", at: 20.58 }]} out={21.15} />
          <div style={{ position: "absolute", top: 230, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 130, letterSpacing: -4, color: C.gold, transform: `scale(${lerp(1.8, 1, spr(t, ok, { damping: 9, stiffness: 200 }))}) rotate(${lerp(-8, -2, spr(t, ok))}deg)`, opacity: t >= ok ? 1 - p(t, 22.25, 22.4) : 0, textShadow: "0 0 50px rgba(242,178,51,.5)" }}>
            No wahala.
          </div>
          <Words y={250} size={84} words={[{ w: "Download", at: 22.28 }, { w: "&", at: 22.42, br: true }, { w: "practise", at: 22.84 }, { w: "offline.", at: 23.18, hl: true }]} out={23.75} />
          <Glass x={590} y={560} w={420} at={22.3} rz={5} from="right" out={23.75}>
            <div style={{ display: "flex", alignItems: "center", gap: 22 }}>
              <svg width={150} height={150} viewBox="0 0 160 160">
                <circle cx={80} cy={80} r={R} fill="none" stroke="rgba(255,255,255,.12)" strokeWidth={12} />
                <circle cx={80} cy={80} r={R} fill="none" stroke={done ? C.green : C.gold} strokeWidth={12} strokeLinecap="round" strokeDasharray={L} strokeDashoffset={L * (1 - prog)} transform="rotate(-90 80 80)" />
                <text x={80} y={92} textAnchor="middle" fontFamily={FONT} fontWeight={800} fontSize={done ? 60 : 38} fill="#fff">{done ? "✓" : `${Math.round(prog * 100)}%`}</text>
              </svg>
              <div>
                <div style={{ fontSize: 30, fontWeight: 800 }}>JAMB Maths</div>
                <div style={{ fontSize: 24, color: C.muted, fontWeight: 600 }}>1,240 questions</div>
                <div style={{ fontSize: 24, color: done ? C.green : C.gold, fontWeight: 800, marginTop: 6 }}>{done ? "Saved offline" : "Downloading…"}</div>
              </div>
            </div>
          </Glass>
        </AbsoluteFill>
      </AbsoluteFill>
      <Flash at={ok} dur={0.25} max={0.4} color={C.gold2} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 24–28 s: Game Zone */
const GAMES = ["screens/01_hub.jpg", "screens/04_duel.jpg", "screens/09_rush.jpg", "screens/12_victory.jpg", "screens/15_ranks.jpg", "screens/04_duel.jpg"];
export const Games: React.FC = () => {
  const t = useT();
  const o = useCut(24.0, 28.05, 0.01, 0.1);
  const cuts = [25.0, 25.5, 26.0, 26.5, 27.0, 27.5];
  const idx = cuts.filter((c) => t >= c).length - 1;
  const lastCut = idx >= 0 ? cuts[idx] : 24.0;
  const punch = Math.exp(-(t - lastCut) * 8);
  const s = shake(t, [24.0, ...cuts], 12, 12);
  const vs = spr(t, 24.0, { damping: 9, stiffness: 240 });
  const side = idx % 2 === 0 ? 1 : -1;
  const src = idx < 0 ? "screens/03_vs.jpg" : GAMES[idx];
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <AbsoluteFill style={{ background: "linear-gradient(135deg, #1B2A8F 0%, #3A1C8C 50%, #8C1C4A 100%)" }} />
      <AbsoluteFill style={{ background: `repeating-conic-gradient(from ${t * 30}deg at 50% 55%, rgba(255,255,255,.07) 0 8deg, transparent 8deg 16deg)` }} />
      <AbsoluteFill style={{ transform: `translate(${s.x}px, ${s.y}px)` }}>
        <Phone src={src} x={540 + side * 10} y={1230} width={620} rz={side * (3 + punch * 4)} ry={side * -8} rx={6} scale={1 + punch * 0.08} />
        {idx < 0 && (
          <div style={{ position: "absolute", top: 820, width: W, textAlign: "center", fontFamily: GAME, fontSize: 300, color: C.gold, transform: `scale(${lerp(3, 1, vs)}) rotate(-8deg)`, opacity: Math.min(1, vs * 2) * (1 - p(t, 24.8, 25.0)), WebkitTextStroke: "10px #3a1c00", textShadow: "0 14px 0 #7a3c00, 0 30px 60px rgba(0,0,0,.6)" }}>VS</div>
        )}
      </AbsoluteFill>
      <Words y={230} size={100} font={GAME} weight={400} tracking={2} words={[{ w: "BATTLE", at: 24.3 }, { w: "YOUR", at: 24.52 }, { w: "FRIENDS", at: 24.66, br: true }, { w: "LIVE", at: 24.86, hl: true }]} out={25.55} />
      <div style={{ position: "absolute", top: 220, width: W, textAlign: "center", fontFamily: GAME, fontSize: 150, color: C.gold, letterSpacing: 2, WebkitTextStroke: "6px #3a1c00", textShadow: "0 10px 0 #7a3c00, 0 24px 50px rgba(0,0,0,.5)", transform: `scale(${lerp(1.6, 1, spr(t, 25.64, { damping: 10, stiffness: 220 }))}) rotate(-3deg)`, opacity: t >= 25.64 ? 1 : 0 }}>
        GAME ZONE
      </div>
      <Chip x={540} y={430} at={25.9} bg={C.red} color="#fff" size={30}>● LIVE · 1V1</Chip>
      {cuts.map((c) => <Flash key={c} at={c} dur={0.12} max={0.25} />)}
      <Flash at={24.0} dur={0.3} max={0.6} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 28–34 s: cash */
export const Cash: React.FC = () => {
  const t = useT();
  const o = useCut(27.9, 34.05, 0.1, 0.12);
  const win = wordAt("l12", 4);
  const cash = wordAt("l12", 5);
  const s = shake(t, [cash], 18);
  const enter = spr(t, 27.95, { damping: 16, stiffness: 90 });
  const card = spr(t, 28.55, { damping: 13, stiffness: 120 });
  const amount = Math.round(50000 * interpolate(t, [29.5, cash + 0.15], [0, 1], { ...clamp, easing: easeOut }) / 50) * 50;
  const shine = ((t - 30.3) % 1.6) / 1.6;
  const exit = p(t, 33.75, 34.05, easeIn);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="gold" dust={70} />
      <AbsoluteFill style={{ transform: `translate(${s.x}px, ${s.y - exit * 200}px)`, opacity: 1 - exit }}>
        <Phone src="screens/challenge_cash.jpg" x={540} y={lerp(2000, 1390, enter)} width={560} rx={10} ry={Math.sin(t * 0.8) * 5} />
        <div style={{ position: "absolute", left: W / 2 - 440, top: lerp(1200, 560, card), width: 880, transform: `perspective(1600px) rotateX(${lerp(40, 8, card)}deg) rotateZ(${lerp(-8, -2, card)}deg) scale(${lerp(0.6, 1, card) * (1 + 0.06 * Math.exp(-Math.max(0, t - cash) * 5) * (t > cash ? 1 : 0))})`, opacity: Math.min(1, card * 2), filter: "drop-shadow(0 50px 60px rgba(0,0,0,.55))" }}>
          <Img src={staticFile("screens/card_cash.png")} style={{ width: 880 }} />
          {/* the prize line counts up over the card's own text */}
          <div style={{ position: "absolute", left: 30, top: 178, width: 440, height: 84, background: "#0E2552", display: "flex", alignItems: "center", paddingLeft: 8, fontFamily: FONT, fontWeight: 800, fontSize: 72, color: "#F6C35A", letterSpacing: -1.5, opacity: t < cash + 0.2 ? 1 : 0 }}>Win ₦{amount.toLocaleString("en-NG")}</div>
        </div>
        <CoinBurst at={cash} x={540} y={820} n={40} spread={1.2} />
      </AbsoluteFill>
      <CoinRain from={cash + 0.2} to={33.2} n={40} />
      <Words y={230} size={84} words={[{ w: "Join", at: 28.4 }, { w: "live", at: 28.68 }, { w: "challenges", at: 28.92 }]} out={29.85} />
      <AbsoluteFill style={{ zIndex: 10 }}>
        <div style={{ position: "absolute", top: 210, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 132, lineHeight: 1, letterSpacing: -5, opacity: t >= win ? 1 - exit : 0, textShadow: "0 10px 40px rgba(0,0,0,.5)" }}>
          <span style={{ display: "inline-block", color: "#fff", marginRight: 28, transform: `translateY(${(1 - spr(t, win)) * 60}px)` }}>Win</span>
          <span style={{ display: "inline-block", transform: `scale(${lerp(1.7, 1, spr(t, cash, { damping: 9, stiffness: 220 }))})`, opacity: t >= cash ? 1 : 0, color: shine > 0.45 && shine < 0.6 ? "#FFE7A8" : C.gold, textShadow: "0 0 40px rgba(242,178,51,.8), 0 10px 30px rgba(0,0,0,.5)" }}>cash</span>
          <br />
          <span style={{ display: "inline-block", color: "#fff", opacity: t >= 30.42 ? 1 : 0, transform: `translateY(${(1 - spr(t, 30.42)) * 60}px)` }}>prizes</span>
        </div>
      </AbsoluteFill>
      <div style={{ position: "absolute", bottom: 300, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 600, fontSize: 28, color: "rgba(255,255,255,.75)", opacity: p(t, 30.6, 31.0) * (1 - exit) }}>Free to join. Eligibility and terms apply.</div>
      <Flash at={cash} dur={0.3} max={0.35} color={C.gold2} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 34–38 s: leaderboard + streak */
const Flame: React.FC<{ size: number; t: number }> = ({ size, t }) => (
  <svg width={size} height={size * 1.2} viewBox="0 0 100 120" style={{ filter: "drop-shadow(0 0 20px rgba(255,120,30,.7))" }}>
    <defs>
      <linearGradient id="fl" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stopColor="#FF4D1A" /><stop offset=".6" stopColor="#FF9A1F" /><stop offset="1" stopColor="#FFD27A" /></linearGradient>
    </defs>
    <path d={`M50 ${4 + Math.sin(t * 9) * 3} C${62 + Math.sin(t * 7) * 3} 30 90 48 88 76 C86 102 68 116 50 116 C32 116 14 102 12 78 C10 58 26 46 34 30 C36 44 42 50 48 52 C46 34 44 18 50 ${4 + Math.sin(t * 9) * 3} Z`} fill="url(#fl)" />
    <path d={`M50 ${60 + Math.sin(t * 11) * 2} C60 72 68 82 66 94 C64 106 56 112 50 112 C42 112 34 106 34 94 C34 84 42 76 50 ${60 + Math.sin(t * 11) * 2} Z`} fill="#FFE7A3" />
  </svg>
);
export const Leader: React.FC = () => {
  const t = useT();
  const o = useCut(33.9, 38.05, 0.1, 0.12);
  const enter = spr(t, 33.95, { damping: 16, stiffness: 100 });
  const rank = Math.max(4, Math.round(interpolate(t, [34.6, 35.5], [128, 4], { ...clamp, easing: easeOut })));
  const streakAt = wordAt("l13", 5);
  const exit = p(t, 37.8, 38.05, easeIn);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="navy" dust={50} grid />
      <Phone src="screens/leader.jpg" x={lerp(-400, 560, enter) - exit * 1400} y={1260} width={580} ry={lerp(-50, 14, enter) + Math.sin(t) * 3} rx={6} rz={lerp(-10, 2, enter)} />
      <Glass x={600} y={640} w={400} at={34.55} rz={4} from="right" out={37.8}>
        <div style={{ fontSize: 26, fontWeight: 700, color: C.muted, letterSpacing: 2 }}>YOUR RANK</div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 14 }}>
          <div style={{ fontSize: 100, fontWeight: 800, color: "#fff", fontVariantNumeric: "tabular-nums", lineHeight: 1 }}>#{rank}</div>
          <div style={{ fontSize: 50, fontWeight: 800, color: C.green, transform: `translateY(${-Math.abs(Math.sin(t * 6)) * 10}px)` }}>▲</div>
        </div>
        <div style={{ fontSize: 26, fontWeight: 700, color: C.gold, marginTop: 6 }}>Nigeria · JAMB mock</div>
      </Glass>
      <Glass x={70} y={1240} w={430} at={streakAt} rz={-5} from="left" out={37.8}>
        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          <Flame size={110} t={t} />
          <div>
            <div style={{ fontSize: 72, fontWeight: 800, lineHeight: 1 }}>30</div>
            <div style={{ fontSize: 28, fontWeight: 700, color: C.gold }}>day streak</div>
          </div>
        </div>
        <div style={{ display: "flex", gap: 10, marginTop: 18 }}>
          {"MTWTFSS".split("").map((d, i) => {
            const on = t > streakAt + 0.1 + i * 0.08;
            return <div key={i} style={{ flex: 1, height: 44, borderRadius: 14, background: on ? "linear-gradient(180deg,#FFB13B,#FF6A1F)" : "rgba(255,255,255,.1)", display: "grid", placeItems: "center", fontSize: 20, fontWeight: 800, color: on ? "#3a1500" : C.muted, transform: `scale(${on ? 1 : 0.9})` }}>{d}</div>;
          })}
        </div>
      </Glass>
      <Words y={250} size={88} words={[{ w: "Climb", at: 34.3 }, { w: "the", at: 34.56, br: true }, { w: "leaderboard.", at: 34.68, hl: true }]} out={35.45} />
      <Words y={250} size={88} words={[{ w: "Keep", at: 35.54 }, { w: "your", at: 35.62 }, { w: "streak", at: streakAt, hl: true, br: true }, { w: "alive.", at: 36.0 }]} out={37.8} />
      <Sparkle x={930} y={650} at={35.5} size={80} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 38–44 s: classes, tutors, community */
const TutorChat: React.FC = () => {
  const t = useT();
  const msg = (at: number, side: "l" | "r", text: string, y: number) => {
    const k = spr(t, at, { damping: 14, stiffness: 190 });
    if (t < at) return null;
    return (
      <div style={{ position: "absolute", top: y, [side === "l" ? "left" : "right"]: 50, maxWidth: 900, transform: `translateY(${(1 - k) * 50}px) scale(${0.85 + 0.15 * k})`, transformOrigin: side === "l" ? "0 0" : "100% 0", opacity: Math.min(1, k * 1.6), background: side === "l" ? "#fff" : C.navy, color: side === "l" ? C.navy : "#fff", borderRadius: 46, borderTopLeftRadius: side === "l" ? 12 : 46, borderTopRightRadius: side === "r" ? 12 : 46, padding: "36px 44px", fontFamily: FONT, fontSize: 60, lineHeight: 1.3, fontWeight: 600, boxShadow: "0 16px 40px -18px rgba(11,31,68,.35)" }}>
        {text}
      </div>
    );
  };
  return (
    <AbsoluteFill style={{ background: "#F4F6FA" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: 1170, height: 420, background: C.navy }} />
      <div style={{ position: "absolute", left: 60, top: 190, display: "flex", alignItems: "center", gap: 30, fontFamily: FONT, color: "#fff" }}>
        <div style={{ width: 150, height: 150, borderRadius: 99, background: "linear-gradient(135deg,#F2B233,#E58A1F)", display: "grid", placeItems: "center", fontSize: 60, fontWeight: 800, color: C.navy, position: "relative" }}>
          MA
          <div style={{ position: "absolute", right: 6, bottom: 6, width: 36, height: 36, borderRadius: 99, background: C.green, border: "6px solid #0B1F44" }} />
        </div>
        <div>
          <div style={{ fontSize: 56, fontWeight: 800 }}>Mr Adebayo</div>
          <div style={{ fontSize: 38, color: "#9FE3B8", fontWeight: 700 }}>Physics tutor · online</div>
        </div>
      </div>
      {msg(39.7, "l", "Hi Tolu! Ready for projectile motion?", 500)}
      {msg(40.3, "r", "Yes sir, let's go!", 900)}
      {msg(40.9, "l", "First, split the speed into x and y parts.", 1120)}
      {msg(41.6, "r", "Got it, thank you sir!", 1560)}
      <div style={{ position: "absolute", left: 40, right: 40, bottom: 70, height: 130, borderRadius: 65, background: "#fff", boxShadow: "0 8px 30px rgba(0,0,0,.08)", fontFamily: FONT, fontSize: 40, color: "#94a3b8", display: "flex", alignItems: "center", paddingLeft: 50 }}>Message your tutor…</div>
    </AbsoluteFill>
  );
};
export const Classes: React.FC = () => {
  const t = useT();
  const o = useCut(37.9, 44.05, 0.1, 0.15);
  const a = spr(t, 38.3, { damping: 15, stiffness: 110 });
  const b = spr(t, 39.56, { damping: 15, stiffness: 110 });
  const c = spr(t, 40.64, { damping: 15, stiffness: 110 });
  const orbit = Math.sin((t - 38) * 0.6) * 6;
  const exit = p(t, 43.75, 44.05, easeIn);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="blue" dust={50} />
      <AbsoluteFill style={{ transform: `scale(${1 - exit * 0.3})`, opacity: 1 - exit }}>
        <Phone src="screens/class_live.jpg" x={lerp(-300, 255, a)} y={1230} width={430} ry={22 + orbit} rz={-6} rx={6} scale={0.95} z={-100} />
        <Phone src="screens/store_community.jpg" x={lerp(1400, 825, c)} y={1230} width={430} ry={-22 + orbit} rz={6} rx={6} scale={0.95} z={-100} />
        <Phone x={540} y={lerp(2900, 1200, b)} width={480} ry={orbit} rx={4} screenBg="#F4F6FA">
          <TutorChat />
        </Phone>
        <Chip x={255} y={560} at={38.45} bg={C.red} color="#fff" size={26}>● LIVE CLASS</Chip>
        <Chip x={540} y={500} at={39.7} bg={C.green} color="#06210f" size={26}>TUTOR ONLINE</Chip>
        <Chip x={825} y={560} at={40.8} bg="rgba(255,255,255,.12)" color="#fff" size={26}>COMMUNITY</Chip>
      </AbsoluteFill>
      <Words y={250} size={84} words={[{ w: "Live", at: 38.3 }, { w: "classes.", at: 38.58, hl: true }, { w: "Real", at: 39.56, br: true }, { w: "tutors.", at: 39.66, hl: true }]} out={40.55} />
      <Words y={250} size={78} words={[{ w: "A", at: 40.54 }, { w: "community", at: 40.64, hl: true }, { w: "that", at: 40.92, br: true }, { w: "learns", at: 41.26 }, { w: "with", at: 41.48 }, { w: "you.", at: 41.72 }]} out={43.75} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 44–48 s: everything in one app */
const WALL = ["screens/cbt.jpg", "screens/result.jpg", "screens/ai.jpg", "screens/01_hub.jpg", "screens/leader.jpg", "screens/challenge_cash.jpg", "screens/class_list.jpg", "screens/store_community.jpg", "screens/study.jpg", "screens/03_vs.jpg", "screens/invite_cash.jpg", "screens/12_victory.jpg", "screens/gate_offline.jpg", "screens/class_live.jpg", "screens/15_ranks.jpg", "screens/09_rush.jpg"];
export const Wall: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [43.95, 44.1, 47.7, 47.75], [0, 1, 1, 0], clamp);
  const k = p(t, 44.0, 47.75, (x) => x);
  const rush = p(t, 46.0, 47.75, (x) => x * x * x);
  const cols = 4;
  const cw = 380, ch = (cw * 2532) / 1170, gap = 60;
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="navy" dust={30} />
      <AbsoluteFill style={{ perspective: 2200 }}>
        <div style={{ position: "absolute", left: W / 2, top: 1050, transformStyle: "preserve-3d", transform: `rotateX(${lerp(52, 40, k)}deg) rotateZ(${lerp(-32, -24, k)}deg) translateY(${lerp(500, -900, k) - rush * 1200}px) scale(${lerp(0.9, 1.1, k) + rush * 1.4})` }}>
          {WALL.map((src, i) => {
            const cx = (i % cols) - (cols - 1) / 2, cy = Math.floor(i / cols) - 1.5;
            const lift = spr(t, 44.0 + rnd(i) * 0.6, { damping: 14, stiffness: 120 });
            const zz = (1 - lift) * -600 + Math.sin(t * 1.5 + i) * 18;
            return (
              <div key={i} style={{ position: "absolute", left: cx * (cw + gap) - cw / 2, top: cy * (ch + gap) - ch / 2, width: cw, height: ch, borderRadius: 46, overflow: "hidden", transform: `translateZ(${zz}px)`, opacity: Math.min(1, lift * 1.5), boxShadow: "0 40px 70px -20px rgba(0,0,0,.7), 0 0 0 6px #1a2335" }}>
                <Img src={staticFile(src)} style={{ width: cw, height: ch }} />
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(6,19,43,.95) 0%, rgba(6,19,43,.75) 25%, transparent 42%)" }} />
      <Words y={240} size={92} words={[{ w: "Everything", at: 44.2 }, { w: "you", at: 44.54 }, { w: "need", at: 44.68, br: true }, { w: "to", at: 44.8 }, { w: "pass,", at: 44.92, hl: true }]} out={45.55} />
      <Words y={250} size={120} words={[{ w: "in", at: 45.24 + 0.3 }, { w: "one", at: 45.6 }, { w: "app.", at: 45.8, hl: true }]} />
      <AbsoluteFill style={{ background: "#fff", opacity: rush * 0.5 }} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 48–60 s: brand + call to action */
export const Outro: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [47.98, 48.0], [0, 1], clamp);
  const toWord = p(t, 49.55, 50.1, easeInOut);
  const up = p(t, 51.9, 52.6, easeInOut);
  const word = (w: string, at: number, x: number) => {
    const k = spr(t, at, { damping: 10, stiffness: 240 });
    return <span style={{ display: "inline-block", margin: "0 18px", transform: `scale(${lerp(1.8, 1, k)})`, opacity: t >= at ? 1 : 0, color: C.navy }}>{w}<span style={{ color: C.gold }}>.</span></span>;
  };
  const cta = (at: number) => spr(t, at, { damping: 15, stiffness: 140 });
  const shineX = ((t - 54) % 2) / 2;
  const lottieFrom = useFramesTo(48.0);
  return (
    <AbsoluteFill style={{ opacity: o, background: "#fff" }}>
      <AbsoluteFill style={{ background: `radial-gradient(60% 35% at 50% 30%, rgba(37,99,179,.10), transparent 70%), radial-gradient(50% 30% at 50% 85%, rgba(242,178,51,.14), transparent 70%)` }} />
      {Array.from({ length: 24 }).map((_, i) => {
        const x = rnd(i + 70) * W, y = ((rnd(i + 71) * 1920 - (t - 48) * 60 * (0.5 + rnd(i))) % 1920 + 1920) % 1920;
        return <div key={i} style={{ position: "absolute", left: x, top: y, width: 8, height: 8, borderRadius: 9, background: i % 2 ? C.gold : C.blue2, opacity: 0.35 }} />;
      })}
      <AbsoluteFill style={{ transform: `translateY(${-up * 330}px) scale(${1 - up * 0.2})` }}>
        <div style={{ position: "absolute", left: W / 2 - 260, top: 470, width: 520, height: 520, opacity: 1 - toWord, transform: `scale(${lerp(0.7, 1, spr(t, 48.0, { damping: 12 })) * (1 - toWord * 0.35)})` }}>
          <Sequence from={lottieFrom} layout="none">
            <Lottie animationData={loaderLight as never} loop={false} style={{ width: 520, height: 520 }} />
          </Sequence>
        </div>
        <div style={{ position: "absolute", left: W / 2 - 470, top: 560, width: 940, height: 336, overflow: "hidden", opacity: toWord, transform: `scale(${lerp(1.08, 1, toWord)})` }}>
          <Img src={staticFile("brand/solutiontee-wordmark.jpg")} style={{ position: "absolute", width: 940, left: 0, top: -500 * 0.47, mixBlendMode: "multiply" }} />
        </div>
        <div style={{ position: "absolute", top: 940, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 92, letterSpacing: -2 }}>
          {word("Learn", 50.2, 0)}{word("Think", 50.8, 0)}{word("Solve", 51.2, 0)}
        </div>
      </AbsoluteFill>
      {/* call to action */}
      <div style={{ position: "absolute", top: 860, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 96, lineHeight: 1.02, letterSpacing: -3, color: C.navy, opacity: p(t, 52.5, 52.7) }}>
        <Words y={0} size={96} color={C.navy} words={[{ w: "Download", at: 52.6 }, { w: "it", at: 52.92 }, { w: "free,", at: 53.1, br: true }, { w: "today.", at: 53.26 }]} />
      </div>
      <div style={{ position: "absolute", left: W / 2 - 330, top: 1135, width: 660, height: 150, borderRadius: 40, background: C.navy, color: "#fff", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", fontFamily: FONT, transform: `scale(${cta(53.5)})`, opacity: Math.min(1, cta(53.5) * 2), overflow: "hidden", boxShadow: "0 30px 60px -25px rgba(11,31,68,.6)" }}>
        <div style={{ fontSize: 28, fontWeight: 700, letterSpacing: 4, color: C.muted }}>GET IT ON</div>
        <div style={{ fontSize: 60, fontWeight: 800 }}>Google Play</div>
        <div style={{ position: "absolute", top: 0, bottom: 0, width: 120, left: `${shineX * 140 - 20}%`, background: "linear-gradient(90deg, transparent, rgba(255,255,255,.25), transparent)", transform: "skewX(-20deg)" }} />
      </div>
      <div style={{ position: "absolute", top: 1320, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 50, color: C.blue, opacity: p(t, 53.9, 54.2), transform: `translateY(${(1 - p(t, 53.9, 54.3)) * 30}px)` }}>cbt.solutiontee.com</div>
      <div style={{ position: "absolute", top: 1440, width: W, display: "flex", justifyContent: "center", alignItems: "center", gap: 26, opacity: p(t, 54.3, 54.7) }}>
        <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: 28, color: "#5b6b86" }}>Practise for</div>
        {["brand/jamb.png", "brand/waec.png", "brand/neco.png"].map((s, i) => (
          <div key={s} style={{ width: 130, height: 100, borderRadius: 22, background: "#fff", boxShadow: "0 10px 30px -12px rgba(11,31,68,.35)", display: "grid", placeItems: "center", transform: `scale(${spr(t, 54.35 + i * 0.12, { stiffness: 220 })})` }}>
            <Img src={staticFile(s)} style={{ width: "78%", height: "72%", objectFit: "contain" }} />
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 110, right: 110, top: 1610, textAlign: "center", fontFamily: FONT, fontWeight: 500, fontSize: 25, lineHeight: 1.45, color: "#6b7a93", opacity: p(t, 54.8, 55.3) }}>
        SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
      </div>
      <Flash at={48.0} dur={0.45} max={1} />
      <Sparkle x={W / 2 + 250} y={500} at={48.4} size={90} color={C.gold} />
    </AbsoluteFill>
  );
};

export { CoinBurst, Ring, Sweep };
