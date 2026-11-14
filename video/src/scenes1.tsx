import React from "react";
import { AbsoluteFill, Img, Sequence, staticFile, interpolate } from "remotion";
import { Lottie } from "@remotion/lottie";
import { C, FONT, clamp, easeIn, easeInOut, easeOut, lerp, p, rnd, shake, spr, useFramesTo, useT, wordAt } from "./lib";
import { Chip, CoinBurst, Confetti, Flash, Glass, Phone, Ring, Sparkle, Stage, Sweep, Words, useCut } from "./components";
import loaderDark from "../public/brand/solutiontee-loader-dark.json";

const W = 1080;

/* ------------------------------------------------------------------ 0–2 s: exam day is coming */
export const Cold: React.FC = () => {
  const t = useT();
  const o = useCut(0, 2.02, 0.01, 0.02);
  const n = Math.round(interpolate(t, [0.55, 1.85], [122, 0], { ...clamp, easing: easeIn }));
  const ring = interpolate(t, [0.55, 1.85], [1, 0], { ...clamp, easing: easeIn });
  const beat = Math.exp(-((t % 0.5) * 9));
  const push = lerp(1, 1.12, p(t, 0, 2, (x) => x));
  const R = 250, L = 2 * Math.PI * R;
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="black" dust={18} />
      <AbsoluteFill style={{ background: `radial-gradient(60% 40% at 50% 42%, rgba(229,72,77,${0.08 + beat * 0.12}), transparent 70%)` }} />
      <AbsoluteFill style={{ transform: `scale(${push})` }}>
        <svg width={W} height={1100} style={{ position: "absolute", top: 260 }} viewBox={`0 0 ${W} 1100`}>
          <circle cx={W / 2} cy={520} r={R} fill="none" stroke="rgba(255,255,255,.08)" strokeWidth={14} />
          <circle cx={W / 2} cy={520} r={R} fill="none" stroke={n < 20 ? C.red : C.gold} strokeWidth={14} strokeLinecap="round" strokeDasharray={L} strokeDashoffset={L * (1 - ring)} transform={`rotate(-90 ${W / 2} 520)`} style={{ filter: `drop-shadow(0 0 18px ${n < 20 ? C.red : C.gold})` }} />
          {Array.from({ length: 60 }).map((_, i) => (
            <line key={i} x1={W / 2} y1={520 - R - 40} x2={W / 2} y2={520 - R - (i % 5 ? 52 : 70)} stroke="rgba(255,255,255,.25)" strokeWidth={i % 5 ? 3 : 6} transform={`rotate(${i * 6} ${W / 2} 520)`} />
          ))}
        </svg>
        <div style={{ position: "absolute", top: 650, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 220, color: "#fff", letterSpacing: -6, fontVariantNumeric: "tabular-nums", transform: `scale(${1 + beat * 0.03})`, textShadow: "0 0 60px rgba(255,255,255,.25)" }}>{n}</div>
        <div style={{ position: "absolute", top: 905, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 700, fontSize: 34, letterSpacing: 10, color: C.muted }}>DAYS LEFT</div>
      </AbsoluteFill>
      <Words y={1290} size={96} words={[{ w: "Exam", at: 0.6 }, { w: "day", at: 0.92 }, { w: "is", at: 1.14, br: true }, { w: "coming.", at: 1.32, hl: true }]} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 2–4.4 s: JAMB. WAEC. NECO. */
const LOGOS = [
  { src: "brand/jamb.png", name: "JAMB", at: 2.0, slot: -345 },
  { src: "brand/waec.png", name: "WAEC", at: 2.75, slot: 0 },
  { src: "brand/neco.png", name: "NECO", at: 3.5, slot: 345 },
];
export const Logos: React.FC = () => {
  const t = useT();
  const o = useCut(1.98, 4.75, 0.01, 0.3);
  const s = shake(t, [2.0, 2.75, 3.5], 22);
  const away = p(t, 4.25, 4.75, easeIn);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="navy" dust={30} />
      <AbsoluteFill style={{ transform: `translate(${s.x}px, ${s.y}px) rotate(${s.r}deg) scale(${1 - away * 0.4})`, filter: `blur(${away * 8}px)` }}>
        {LOGOS.map((l, i) => {
          if (t < l.at - 0.02) return null;
          const hit = spr(t, l.at, { damping: 13, stiffness: 260 });
          const move = spr(t, l.at + 0.42, { damping: 16, stiffness: 150 });
          const big = 430, small = 280;
          const size = lerp(big, small, move);
          const scale = lerp(2.4, 1, hit);
          const x = W / 2 + l.slot * move;
          const y = lerp(820, 860, move);
          return (
            <React.Fragment key={l.name}>
              <Ring x={x} y={y} at={l.at} size={900} color="rgba(255,255,255,.7)" dur={0.55} width={10} />
              <div style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size, transform: `scale(${scale})`, opacity: Math.min(1, hit * 2), borderRadius: size * 0.14, background: "linear-gradient(160deg,#ffffff,#e9eef7)", boxShadow: "0 40px 90px -30px rgba(0,0,0,.8), inset 0 -6px 0 rgba(11,31,68,.08)", display: "grid", placeItems: "center" }}>
                <Img src={staticFile(l.src)} style={{ width: "76%", height: "70%", objectFit: "contain" }} />
              </div>
              <div style={{ position: "absolute", left: x - 200, width: 400, top: y + size / 2 + 26, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: lerp(76, 52, move), color: "#fff", letterSpacing: 2, opacity: p(t, l.at + 0.05, l.at + 0.2) }}>{l.name}</div>
              <Sparkle x={x + size * 0.4} y={y - size * 0.4} at={l.at + 0.1} size={80} />
              {i === 0 ? null : null}
            </React.Fragment>
          );
        })}
      </AbsoluteFill>
      <Flash at={2.0} dur={0.18} max={0.35} />
      <Flash at={2.75} dur={0.18} max={0.3} />
      <Flash at={3.5} dur={0.18} max={0.3} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 4.2–6 s: are you ready? */
export const Ready: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [4.3, 4.4, 5.74, 5.75], [0, 1, 1, 0], clamp);
  const build = p(t, 4.4, 5.75, (x) => x * x);
  const s = shake(t, [4.4, 5.1], 26);
  const jit = (t > 4.4 && t < 4.65) || (t > 5.1 && t < 5.3) ? 1 : 0;
  const zoom = lerp(1, 1.25, build);
  const text = (dx: number, col: string, op: number) => (
    <div style={{ position: "absolute", top: 640, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 170, lineHeight: 0.95, letterSpacing: -6, color: col, opacity: op, transform: `translateX(${dx}px)`, mixBlendMode: col === "#fff" ? "normal" : "screen" }}>
      <span style={{ opacity: p(t, 4.4, 4.5) }}>ARE </span>
      <span style={{ opacity: p(t, 4.52, 4.6) }}>YOU</span>
      <br />
      <span style={{ display: "inline-block", opacity: p(t, 4.66, 4.74), transform: `scale(${lerp(1.4, 1, spr(t, 4.66, { stiffness: 220 }))})`, color: col === "#fff" ? C.gold : col }}>READY?</span>
    </div>
  );
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="black" dust={50} grid />
      <AbsoluteFill style={{ background: `radial-gradient(50% 35% at 50% 50%, rgba(242,178,51,${build * 0.35}), transparent 70%)` }} />
      <AbsoluteFill style={{ transform: `translate(${s.x + (rnd(Math.floor(t * 30)) - 0.5) * 30 * jit}px, ${s.y}px) scale(${zoom})` }}>
        {jit ? text(-14, "#ff3355", 0.8) : null}
        {jit ? text(14, "#33d6ff", 0.8) : null}
        {text(0, "#fff", 1)}
        {jit ? <div style={{ position: "absolute", left: 0, right: 0, top: 640 + rnd(Math.floor(t * 30) + 5) * 300, height: 40, background: "rgba(255,255,255,.12)" }} /> : null}
      </AbsoluteFill>
      {/* speed lines on the build */}
      {Array.from({ length: 26 }).map((_, i) => {
        const a = (i / 26) * Math.PI * 2;
        const len = 200 + build * 600;
        const r0 = 900 - build * 500;
        return <div key={i} style={{ position: "absolute", left: W / 2 + Math.cos(a) * r0, top: 960 + Math.sin(a) * r0, width: len, height: 3, background: "linear-gradient(90deg, rgba(255,255,255,.5), transparent)", transform: `rotate(${(a * 180) / Math.PI + 180}deg)`, transformOrigin: "0 50%", opacity: build * 0.7 }} />;
      })}
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 6–8.2 s: Meet SolutionTee CBT */
export const Meet: React.FC = () => {
  const t = useT();
  const o = useCut(6.0, 8.3, 0.01, 0.25);
  const s = shake(t, [6.0], 30, 6);
  const rays = (t - 6) * 18;
  const up = p(t, 7.25, 8.3, easeInOut);
  const lottieFrom = useFramesTo(6.0);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="blue" dust={60} />
      <AbsoluteFill style={{ background: `conic-gradient(from ${rays}deg at 50% 36%, transparent 0deg, rgba(242,178,51,.14) 10deg, transparent 22deg, transparent 40deg, rgba(75,134,212,.16) 52deg, transparent 64deg, transparent 90deg, rgba(242,178,51,.12) 100deg, transparent 112deg, transparent 140deg, rgba(75,134,212,.14) 150deg, transparent 162deg, transparent 180deg, rgba(242,178,51,.14) 190deg, transparent 202deg, transparent 230deg, rgba(75,134,212,.16) 242deg, transparent 254deg, transparent 280deg, rgba(242,178,51,.12) 290deg, transparent 302deg, transparent 330deg, rgba(75,134,212,.14) 340deg, transparent 352deg)`, opacity: p(t, 6, 6.4) * (1 - up) }} />
      <AbsoluteFill style={{ transform: `translate(${s.x}px, ${s.y - up * 520}px) scale(${1 - up * 0.35})`, opacity: 1 - up * 0.9 }}>
        <div style={{ position: "absolute", left: W / 2 - 230, top: 420, width: 460, height: 460, transform: `scale(${lerp(0.6, 1, spr(t, 6.0, { damping: 11 }))})` }}>
          <Sequence from={lottieFrom} layout="none">
            <Lottie animationData={loaderDark as never} loop={false} style={{ width: 460, height: 460 }} />
          </Sequence>
        </div>
        <Ring x={W / 2} y={650} at={6.0} size={1300} color={C.gold} dur={0.8} width={14} />
        <Words y={950} size={70} weight={700} color={C.muted} words={[{ w: "Meet", at: 6.25 }]} />
        <Words y={1030} size={124} tracking={-4} words={[{ w: "SolutionTee", at: 6.45 }, { w: "CBT", at: 6.89, hl: true }]} />
        <Sparkle x={W / 2 + 230} y={470} at={6.4} size={110} />
        <Sparkle x={W / 2 - 260} y={820} at={6.7} size={70} />
      </AbsoluteFill>
      <Flash at={6.0} dur={0.5} max={1} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 7.3–12 s: real CBT */
export const Cbt: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [7.3, 7.6], [0, 1], clamp);
  const enter = spr(t, 7.35, { damping: 18, stiffness: 70 });
  const zoom = p(t, 10.55, 11.3, easeInOut);
  const exit = p(t, 11.8, 12.1, easeIn);
  const ry = lerp(-38, -14, enter) + Math.sin(t * 0.8) * 3 + zoom * 10 - exit * 60;
  const rx = lerp(30, 8, enter) - zoom * 4;
  const y = lerp(1900, 1230, enter) + zoom * 330;
  const scale = lerp(0.9, 1, enter) * lerp(1, 1.45, zoom);
  const x = 540 - exit * 1500;
  const tapAt = 9.5;
  const sel = p(t, tapAt, tapAt + 0.15);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="navy" dust={40} grid />
      <Phone src="screens/cbt.jpg" x={x} y={y} width={600} rx={rx} ry={ry} scale={scale} rz={exit * -8}>
        {/* answer B gets picked */}
        <div style={{ position: "absolute", left: 48, top: 765, width: 1074, height: 160, borderRadius: 44, border: `${7 * sel}px solid ${C.blue}`, background: `rgba(37,99,179,${0.08 * sel})`, boxShadow: sel ? `0 0 ${40 * sel}px rgba(37,99,179,.5)` : undefined }} />
        <div style={{ position: "absolute", left: 82, top: 801, width: 92, height: 92, borderRadius: 30, background: C.navy, color: "#fff", display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: 44, opacity: sel, transform: `scale(${lerp(0.6, 1, spr(t, tapAt, { stiffness: 260 }))})` }}>A</div>
        <Ring x={600} y={845} at={tapAt} size={420} color={C.blue} dur={0.5} width={14} />
        {/* the clock pulses each second */}
        <div style={{ position: "absolute", left: 560, top: 150, width: 300, height: 92, borderRadius: 46, boxShadow: `0 0 0 ${6 + Math.sin(t * Math.PI * 2) * 4}px rgba(229,72,77,${0.25 * p(t, 10.4, 10.7)})` }} />
      </Phone>
      <Words y={250} size={88} words={[{ w: "Real", at: 8.64 }, { w: "past", at: 8.92 }, { w: "questions", at: 9.2, br: true }]} out={10.25} />
      <Words y={250} size={88} words={[{ w: "Real", at: 10.4 }, { w: "exam", at: 10.68 }, { w: "timer", at: 11.04, hl: true }]} out={11.8} />
      <Glass x={650} y={600} w={340} at={11.0} rz={6} from="right" out={11.8}>
        <div style={{ fontSize: 26, fontWeight: 700, color: C.muted, letterSpacing: 2 }}>TIME LEFT</div>
        <div style={{ fontSize: 74, fontWeight: 800, fontVariantNumeric: "tabular-nums", color: "#fff" }}>1:12:{String(38 - Math.max(0, Math.floor((t - 11) * 1))).padStart(2, "0")}</div>
      </Glass>
      <Glass x={80} y={560} w={330} at={9.25} rz={-5} from="left" out={10.25}>
        <div style={{ fontSize: 26, fontWeight: 700, color: C.muted, letterSpacing: 2 }}>PAST QUESTIONS</div>
        <div style={{ fontSize: 56, fontWeight: 800, color: C.gold }}>2010–2025</div>
      </Glass>
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 12–16 s: JAMB score */
export const Result: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [11.85, 12.0], [0, 1], clamp);
  const enter = spr(t, 11.9, { damping: 17, stiffness: 120 });
  const hit = 13.85;
  const s = shake(t, [hit], 16);
  const into = p(t, 15.75, 16.15, easeIn);
  const score = Math.round(312 * interpolate(t, [12.62, hit], [0, 1], { ...clamp, easing: easeOut }));
  const ringK = interpolate(t, [12.62, hit], [0, 312 / 400], { ...clamp, easing: easeOut });
  const R = 276, L = 2 * Math.PI * R;
  const bars = [78, 64, 70, 75];
  const ys = [1818, 1959, 2100, 2241];
  const scale = lerp(1, 1.06, p(t, 12.2, 15.7, (x) => x)) * (1 + into * 3);
  return (
    <AbsoluteFill style={{ opacity: o * (1 - p(t, 16.0, 16.15)) }}>
      <Stage hue="blue" dust={40} />
      <AbsoluteFill style={{ transform: `translate(${s.x}px, ${s.y}px)` }}>
        <Phone src="screens/result.jpg" x={lerp(1700, 540, enter)} y={1210 + into * 600} width={600} ry={lerp(40, -6, enter) + Math.sin(t) * 3} rx={6} scale={scale}>
          <div style={{ position: "absolute", left: 470, top: 560, width: 230, height: 160, background: "#0B1F44" }} />
          <svg width={1170} height={1200} style={{ position: "absolute", left: 0, top: 0 }}>
            <defs>
              <linearGradient id="rg" x1="0" x2="1"><stop offset="0" stopColor="#FFD27A" /><stop offset="1" stopColor="#F2B233" /></linearGradient>
            </defs>
            <circle cx={584.5} cy={665.5} r={R} fill="none" stroke="url(#rg)" strokeWidth={53} strokeLinecap="round" strokeDasharray={L} strokeDashoffset={L * (1 - ringK)} transform="rotate(-90 584.5 665.5)" style={{ filter: "drop-shadow(0 0 16px rgba(242,178,51,.6))" }} />
          </svg>
          <div style={{ position: "absolute", left: 385, width: 400, top: 560, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 150, color: "#fff", letterSpacing: -4, fontVariantNumeric: "tabular-nums", transform: `scale(${1 + 0.12 * Math.exp(-Math.max(0, t - hit) * 6) * (t > hit ? 1 : 0)})` }}>{score}</div>
          {bars.map((b, i) => {
            const k = p(t, 13.0 + i * 0.15, 13.7 + i * 0.15);
            return <div key={i} style={{ position: "absolute", left: 96, top: ys[i], height: 24, borderRadius: 12, width: (1074 - 96) * (b / 100) * k, background: i % 2 ? C.blue2 : C.blue }} />;
          })}
        </Phone>
        <Confetti at={hit} x={540} y={760} n={110} power={1.1} />
        <Glass x={640} y={500} w={360} at={hit} rz={7} from="right">
          <div style={{ fontSize: 26, fontWeight: 700, color: C.muted, letterSpacing: 2 }}>JAMB SCORE</div>
          <div style={{ fontSize: 96, fontWeight: 800, color: C.gold, lineHeight: 1 }}>312<span style={{ fontSize: 40, color: "#fff" }}> /400</span></div>
          <div style={{ fontSize: 28, fontWeight: 700, color: C.green, marginTop: 8 }}>▲ 38 points</div>
        </Glass>
      </AbsoluteFill>
      <Words y={250} size={88} words={[{ w: "Your", at: 12.48 }, { w: "JAMB", at: 12.62, hl: true }, { w: "score,", at: 12.92, br: true }, { w: "instantly.", at: 13.6 }]} out={15.6} />
      <Flash at={hit} dur={0.25} max={0.25} color={C.gold2} />
    </AbsoluteFill>
  );
};

/* ------------------------------------------------------------------ 16–20 s: AI tutor */
const Bubble: React.FC<{ at: number; side: "l" | "r"; children: React.ReactNode; y: number; w?: number; bg?: string }> = ({ at, side, children, y, w = 820, bg }) => {
  const t = useT();
  const k = spr(t, at, { damping: 14, stiffness: 190 });
  if (t < at) return null;
  return (
    <div style={{ position: "absolute", top: y, [side === "l" ? "left" : "right"]: 48, width: w, transform: `translateY(${(1 - k) * 60}px) scale(${0.85 + 0.15 * k})`, transformOrigin: side === "l" ? "0 0" : "100% 0", opacity: Math.min(1, k * 1.6), background: bg ?? (side === "l" ? "#fff" : C.navy), color: side === "l" ? C.navy : "#fff", borderRadius: 48, borderTopLeftRadius: side === "l" ? 12 : 48, borderTopRightRadius: side === "r" ? 12 : 48, padding: "34px 40px", fontFamily: FONT, fontSize: 42, lineHeight: 1.35, boxShadow: "0 16px 40px -18px rgba(11,31,68,.35)" }}>
      {children}
    </div>
  );
};
export const Ai: React.FC = () => {
  const t = useT();
  const o = interpolate(t, [15.85, 16.05], [0, 1], clamp);
  const zin = spr(t, 15.85, { damping: 18, stiffness: 90 });
  const snap = wordAt("l09", 4);
  const flip = p(t, 19.85, 20.15, easeIn);
  const look = p(t, 18.3, 19.2, easeInOut);
  const step = (i: number) => p(t, [18.55, 19.25, 19.75][i], [18.55, 19.25, 19.75][i] + 0.2);
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Stage hue="blue" dust={50} />
      <Phone src="screens/ai.jpg" x={540} y={1230 + look * 260} width={600} scale={lerp(0.3, 1, zin) * lerp(1, 1.42, look)} rx={lerp(20, 4, zin)} ry={flip * 90 + Math.sin(t * 0.9) * 4} opacity={1 - (flip > 0.98 ? 1 : 0)}>
        <div style={{ position: "absolute", left: 0, top: 470, width: 1170, height: 1680, background: "#F4F6FA" }} />
        <Bubble at={snap + 0.05} side="r" y={520} w={700} bg="#E9EEF7">
          <div style={{ background: "#FFFDF6", borderRadius: 24, padding: "30px 34px", transform: "rotate(-2deg)", boxShadow: "0 10px 20px rgba(0,0,0,.12)", backgroundImage: "repeating-linear-gradient(transparent 0 58px, rgba(37,99,179,.18) 58px 60px)" }}>
            <div style={{ fontFamily: "Georgia, serif", fontSize: 40, color: "#1d2433" }}>Q14. Find the roots of</div>
            <div style={{ fontFamily: "Georgia, serif", fontSize: 54, color: "#1d2433", marginTop: 8 }}>x² − 5x + 6 = 0</div>
          </div>
          <div style={{ fontSize: 30, color: "#64748b", marginTop: 14, textAlign: "right" }}>Photo · just now</div>
        </Bubble>
        {t > snap + 0.5 && t < 18.5 ? (
          <div style={{ position: "absolute", left: 48, top: 1060, background: "#fff", borderRadius: 40, padding: "30px 40px", display: "flex", gap: 14 }}>
            {[0, 1, 2].map((i) => <div key={i} style={{ width: 22, height: 22, borderRadius: 99, background: C.blue, opacity: 0.3 + 0.7 * Math.abs(Math.sin(t * 6 + i)) }} />)}
          </div>
        ) : null}
        <Bubble at={18.5} side="l" y={1060} w={1000}>
          <div style={{ display: "flex", alignItems: "center", gap: 14, fontWeight: 800, color: C.blue, fontSize: 34, marginBottom: 14 }}>✦ SolutionTee AI</div>
          {[
            ["1", "Find two numbers that multiply to 6 and add to −5: −2 and −3."],
            ["2", "So x² − 5x + 6 = (x − 2)(x − 3) = 0"],
            ["3", "x = 2  or  x = 3"],
          ].map(([n, s], i) => (
            <div key={n} style={{ display: "flex", gap: 22, marginTop: 18, opacity: step(i), transform: `translateX(${(1 - step(i)) * 40}px)` }}>
              <div style={{ flex: "0 0 60px", height: 60, borderRadius: 30, background: i === 2 ? "#16A34A" : C.navy, color: "#fff", display: "grid", placeItems: "center", fontWeight: 800, fontSize: 32 }}>{i === 2 ? "✓" : n}</div>
              <div style={{ fontWeight: i === 2 ? 800 : 500, color: i === 2 ? "#15803D" : C.navy, fontSize: i === 2 ? 50 : 40 }}>{s}</div>
            </div>
          ))}
        </Bubble>
      </Phone>
      <Words y={250} size={92} words={[{ w: "Stuck?", at: 15.85 }, { w: "Snap", at: snap, hl: true }, { w: "it.", at: snap + 0.12 }]} out={17.72} />
      <Words y={250} size={92} words={[{ w: "Step", at: 19.23 }, { w: "by", at: 19.53 }, { w: "step.", at: 19.73, hl: true }]} out={19.95} />
      <Words y={250} size={92} words={[{ w: "Your", at: 17.83 }, { w: "AI", at: 17.93, hl: true }, { w: "tutor", at: 18.29, br: true }, { w: "explains.", at: 18.47 }]} out={19.1} />
      <Flash at={snap} dur={0.3} max={0.9} />
    </AbsoluteFill>
  );
};

export { Sweep, CoinBurst };
