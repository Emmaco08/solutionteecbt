import React from "react";
import { AbsoluteFill, Img, Sequence, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Lottie } from "@remotion/lottie";
import "@fontsource/instrument-serif/400-italic.css";
import { C, FONT, clamp, easeInOut, easeOut, lerp, p, rnd, spr } from "../lib";
import loaderLight from "../../public/brand/solutiontee-loader-light.json";

// Shared motion kit for the social ads pack (D-182): format-aware (9:16 and 4:5), all timing in seconds.

export const SERIF = "'Instrument Serif', Georgia, serif";
export { C, FONT };

/** Seconds since the start of the composition. */
export const useS = () => useCurrentFrame() / 30;

/** The frame size: 9:16 (1080 × 1920) is the design size; 4:5 (1080 × 1350) squeezes vertical gaps and shrinks a little. */
export const useF = () => {
  const { width: W, height: H } = useVideoConfig();
  const tall = H / W > 1.5;
  return { W, H, cx: W / 2, cy: H / 2, tall, ky: H / 1920, ks: tall ? 1 : 0.8 };
};

/** Visible between a and b (seconds), with short fades. */
export const win = (t: number, a: number, b: number, fin = 0.12, fout = 0.12) => interpolate(t, [a - fin, a, b - fout, b], [0, 1, 1, 0], clamp);

// ------------------------------------------------------------------------------------------------ kinetic type

type Tok = { w: string; acc: boolean; br: boolean };
/** "If JAMB was *tomorrow*… / would you" → words; *…* = accent (serif italic), "/" = new line. */
const parse = (text: string): Tok[] => {
  const out: Tok[] = [];
  let acc = false;
  for (const raw of text.split(/\s+/).filter(Boolean)) {
    if (raw === "/") {
      if (out.length) out[out.length - 1].br = true;
      continue;
    }
    let w = raw;
    const open = w.startsWith("*");
    if (open) {
      acc = true;
      w = w.slice(1);
    }
    const close = /\*[.,!?…]*$/.test(w);
    if (close) w = w.replace(/\*([.,!?…]*)$/, "$1");
    out.push({ w, acc, br: false });
    if (close) acc = false;
  }
  return out;
};

/**
 * Words that arrive out of a blur (the references' signature move), one after another. Accent words are serif italic
 * in [accent]. mode "mask" slides each word up out of a mask instead (Swiss style); "pop" scales in.
 */
export const KText: React.FC<{
  text: string; at: number; y: number; size?: number; color?: string; accent?: string; stagger?: number; dur?: number;
  out?: number; align?: "center" | "left" | "right"; x?: number; width?: number; weight?: number; mode?: "blur" | "mask" | "pop";
  lh?: number; tracking?: number; serifScale?: number; font?: string; shadow?: string; upper?: boolean;
}> = ({ text, at, y, size = 96, color = C.navy, accent = C.blue, stagger = 0.07, dur = 0.42, out, align = "center", x, width, weight = 800, mode = "blur", lh = 1.02, tracking = -0.035, serifScale = 1.14, font = FONT, shadow, upper }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || (out !== undefined && t > out + 0.4)) return null;
  const toks = parse(text);
  const s = size * F.ks;
  const fo = out === undefined ? 0 : p(t, out, out + 0.28, easeInOut);
  const w = width ?? F.W - 120;
  const left = x ?? (F.W - w) / 2;
  return (
    <div style={{ position: "absolute", left, top: y, width: w, textAlign: align, fontFamily: font, fontWeight: weight, fontSize: s, lineHeight: lh, letterSpacing: `${tracking}em`, color, transform: "translateY(-50%)", opacity: 1 - fo, filter: fo > 0 ? `blur(${fo * 16}px)` : undefined, textTransform: upper ? "uppercase" : undefined }}>
      {toks.map((tk, i) => {
        const a = at + i * stagger;
        const k = p(t, a, a + dur, easeOut);
        const sp = spr(t, a, { damping: 13, stiffness: 160 });
        let tr = "", flt: string | undefined, op = k;
        if (mode === "blur") {
          tr = `translateY(${(1 - k) * 0.42}em) scale(${lerp(1.08, 1, k)})`;
          flt = k < 1 ? `blur(${(1 - k) * 18}px)` : undefined;
        } else if (mode === "mask") {
          tr = `translateY(${(1 - sp) * 105}%)`;
          op = 1;
        } else {
          tr = `scale(${sp})`;
          op = Math.min(1, sp * 2);
        }
        const st: React.CSSProperties = tk.acc
          ? { fontFamily: SERIF, fontStyle: "italic", fontWeight: 400, fontSize: `${serifScale}em`, letterSpacing: "-0.01em", color: accent }
          : {};
        const inner = (
          <span style={{ display: "inline-block", transform: tr, opacity: op, filter: flt, textShadow: shadow, ...st }}>{tk.w}</span>
        );
        return (
          <React.Fragment key={i}>
            {mode === "mask" ? <span style={{ display: "inline-block", overflow: "hidden", verticalAlign: "bottom", padding: "0.04em 0.02em 0.1em" }}>{inner}</span> : inner}
            {tk.br ? <br /> : " "}
          </React.Fragment>
        );
      })}
    </div>
  );
};

// ------------------------------------------------------------------------------------------------ stages

/** Cream stage with soft gold and blue glows drifting (references 1 and 4). */
export const WarmStage: React.FC<{ intensity?: number; dark?: number }> = ({ intensity = 1, dark = 0 }) => {
  const t = useS();
  const F = useF();
  const gx = 50 + Math.sin(t * 0.5) * 18, gy = 62 + Math.cos(t * 0.4) * 10;
  const bx = 20 + Math.cos(t * 0.33) * 14, by = 18 + Math.sin(t * 0.45) * 8;
  return (
    <AbsoluteFill style={{ background: "#FBF7EF" }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 1.1}px ${F.H * 0.55}px at ${gx}% ${gy}%, rgba(242,178,51,${0.55 * intensity}), rgba(242,178,51,0) 70%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 0.9}px ${F.H * 0.4}px at ${bx}% ${by}%, rgba(75,134,212,${0.28 * intensity}), rgba(75,134,212,0) 70%)` }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 50%, transparent 55%, rgba(120,90,30,.10))" }} />
      {dark > 0 && <AbsoluteFill style={{ background: C.deep, opacity: dark }} />}
      <Grain />
    </AbsoluteFill>
  );
};

/** Near-black stage with a gold glow and slow dust (reference 3). */
export const GoldStage: React.FC<{ glow?: number; y?: number }> = ({ glow = 1, y = 78 }) => {
  const t = useS();
  const F = useF();
  return (
    <AbsoluteFill style={{ background: "#03060D" }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 1.3}px ${F.H * 0.5}px at ${50 + Math.sin(t * 0.3) * 10}% ${y}%, rgba(242,178,51,${0.42 * glow}), rgba(140,90,10,${0.12 * glow}) 45%, transparent 75%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W}px ${F.H * 0.35}px at ${30 + Math.cos(t * 0.25) * 12}% 14%, rgba(37,99,179,.22), transparent 70%)` }} />
      {Array.from({ length: 46 }).map((_, i) => {
        const x = rnd(i) * F.W, y0 = rnd(i + 40) * F.H;
        const yy = (y0 - t * (12 + rnd(i + 3) * 30) + F.H * 4) % F.H;
        const s = 2 + rnd(i + 7) * 4;
        return <div key={i} style={{ position: "absolute", left: x + Math.sin(t + i) * 10, top: yy, width: s, height: s, borderRadius: 9, background: "#FFD27A", opacity: 0.15 + rnd(i + 9) * 0.45, filter: s > 4.5 ? "blur(1.5px)" : undefined }} />;
      })}
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, transparent 50%, rgba(0,0,0,.65))" }} />
      <Grain strength={0.09} />
    </AbsoluteFill>
  );
};

export const Grain: React.FC<{ strength?: number }> = ({ strength = 0.06 }) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ backgroundImage: `url(${staticFile(`grain${f % 4}.png`)})`, backgroundSize: "384px 384px", opacity: strength, mixBlendMode: "overlay", pointerEvents: "none" }} />;
};

// ------------------------------------------------------------------------------------------------ UI pieces

/** A mouse pointer that glides between key points and clicks. keys: [second, x, y]. */
export const Cursor: React.FC<{ keys: [number, number, number][]; clicks?: number[]; size?: number; from?: number; to?: number }> = ({ keys, clicks = [], size = 64, from, to }) => {
  const t = useS();
  if ((from !== undefined && t < from) || (to !== undefined && t > to)) return null;
  let x = keys[0][1], y = keys[0][2];
  for (let i = 1; i < keys.length; i++) {
    const [a, x0, y0] = keys[i - 1];
    const [b, x1, y1] = keys[i];
    if (t >= a) {
      const k = p(t, a, b, easeInOut);
      x = lerp(x0, x1, k);
      y = lerp(y0, y1, k);
    }
  }
  let press = 1, ring = 0, rk = 0;
  for (const c of clicks) {
    const d = t - c;
    if (d >= 0 && d < 0.18) press = 1 - Math.sin((d / 0.18) * Math.PI) * 0.18;
    if (d >= 0 && d < 0.55) {
      ring = d / 0.55;
      rk = 1;
    }
  }
  const op = from !== undefined ? p(t, from, from + 0.2) : 1;
  return (
    <>
      {rk > 0 && <div style={{ position: "absolute", left: x - 60, top: y - 60, width: 120, height: 120, borderRadius: 99, border: "4px solid rgba(37,99,179,.7)", transform: `scale(${0.3 + ring})`, opacity: 1 - ring }} />}
      <svg width={size} height={size} viewBox="0 0 24 24" style={{ position: "absolute", left: x - size * 0.2, top: y - size * 0.1, transform: `scale(${press})`, transformOrigin: "20% 10%", opacity: op, filter: "drop-shadow(0 6px 10px rgba(0,0,0,.35))" }}>
        <path d="M5 2.5 L5 19 L9.3 15 L12.2 21.4 L15 20.2 L12.2 13.9 L18 13.9 Z" fill="#fff" stroke="#111" strokeWidth={1.4} strokeLinejoin="round" />
      </svg>
    </>
  );
};

/** Text typed in at [cps] characters a second from [at]. */
export const typed = (t: number, at: number, text: string, cps = 22) => text.slice(0, Math.max(0, Math.floor((t - at) * cps)));
export const Caret: React.FC<{ color?: string }> = ({ color = C.blue }) => {
  const t = useS();
  return <span style={{ display: "inline-block", width: 4, height: "1em", marginLeft: 4, verticalAlign: "-0.12em", background: color, opacity: Math.floor(t * 2.4) % 2 ? 0 : 1 }} />;
};

/** The white prompt bar of the references, with a gold send button. */
export const PromptBar: React.FC<{ x: number; y: number; w: number; at: number; text: string; cps?: number; placeholder?: string; send?: number; dark?: boolean }> = ({ x, y, w, at, text, cps = 22, placeholder = "Ask any question…", send, dark }) => {
  const t = useS();
  const k = spr(t, at - 0.35, { damping: 16 });
  const s = typed(t, at, text, cps);
  const pressed = send !== undefined && t >= send && t < send + 0.2;
  return (
    <div style={{ position: "absolute", left: x, top: y, width: w, transform: `translate(-50%,-50%) scale(${lerp(0.85, 1, k)})`, opacity: Math.min(1, k * 1.5) }}>
      <div style={{ display: "flex", alignItems: "center", gap: 18, padding: "26px 26px 26px 36px", borderRadius: 40, background: dark ? "rgba(255,255,255,.08)" : "#fff", border: dark ? "2px solid rgba(255,255,255,.14)" : "2px solid rgba(11,31,68,.06)", boxShadow: dark ? "0 30px 80px -30px rgba(0,0,0,.8)" : "0 40px 80px -30px rgba(120,80,10,.35)" }}>
        <div style={{ flex: 1, fontFamily: FONT, fontWeight: 600, fontSize: 38, color: s ? (dark ? "#fff" : C.navy) : dark ? "rgba(255,255,255,.4)" : "#9AA6BC", minHeight: 48, lineHeight: 1.25 }}>
          {s || placeholder}
          {t >= at - 0.2 && (send === undefined || t < send) && <Caret />}
        </div>
        <div style={{ width: 76, height: 76, borderRadius: 40, background: C.gold, display: "grid", placeItems: "center", transform: `scale(${pressed ? 0.86 : 1})`, boxShadow: "0 10px 24px -8px rgba(242,178,51,.8)" }}>
          <svg width={38} height={38} viewBox="0 0 24 24"><path d="M12 19V5M5 12l7-7 7 7" stroke={C.navy} strokeWidth={2.8} fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </div>
      </div>
    </div>
  );
};

/** A gold four-point star (reference 3), spinning slowly and pulsing in. */
export const Star4: React.FC<{ x: number; y: number; size: number; at: number; spin?: number; color?: string; out?: number }> = ({ x, y, size, at, spin = 20, color = "#F7C65A", out }) => {
  const t = useS();
  const k = spr(t, at, { damping: 10, stiffness: 120 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.3);
  if (k <= 0.001 || o <= 0) return null;
  return (
    <svg style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size, transform: `scale(${k}) rotate(${(t - at) * spin}deg)`, opacity: o, filter: `drop-shadow(0 0 ${size * 0.18}px rgba(242,178,51,.7))` }} viewBox="-10 -10 20 20">
      <defs>
        <linearGradient id={`g${x}${y}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#FFF1C4" />
          <stop offset=".45" stopColor={color} />
          <stop offset="1" stopColor="#9A6410" />
        </linearGradient>
      </defs>
      <path d="M0 -10 C1 -3 3 -1 10 0 C3 1 1 3 0 10 C-1 3 -3 1 -10 0 C-3 -1 -1 -3 0 -10 Z" fill={`url(#g${x}${y})`} />
    </svg>
  );
};

/** JAMB, WAEC and NECO logos (the real files), popping in one by one. */
export const ExamLogos: React.FC<{ y: number; at: number; gap?: number; h?: number; card?: boolean; step?: number; out?: number }> = ({ y, at, gap = 50, h = 150, card = true, step = 0.25, out }) => {
  const t = useS();
  const F = useF();
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  const files = ["jamb", "waec", "neco"];
  const hh = h * F.ks;
  return (
    <div style={{ position: "absolute", left: 0, width: F.W, top: y, transform: "translateY(-50%)", display: "flex", justifyContent: "center", gap: gap * F.ks, opacity: o }}>
      {files.map((f, i) => {
        const k = spr(t, at + i * step, { damping: 11, stiffness: 170 });
        return (
          <div key={f} style={{ transform: `scale(${k}) rotate(${(1 - k) * (i - 1) * 14}deg)`, opacity: Math.min(1, k * 2), background: card ? "#fff" : undefined, borderRadius: 28 * F.ks, padding: card ? 22 * F.ks : 0, boxShadow: card ? "0 24px 50px -24px rgba(0,0,0,.45)" : undefined, height: hh + (card ? 44 * F.ks : 0), display: "grid", placeItems: "center" }}>
            <Img src={staticFile(`brand/${f}.png`)} style={{ height: hh, width: "auto", objectFit: "contain" }} />
          </div>
        );
      })}
    </div>
  );
};

/**
 * The SolutionTee logo: the official logo animation (Lottie) plays, then hands over to the full wordmark lockup (the
 * real file, which includes the mark). Light stages only (the wordmark is navy and blue on white).
 */
export const LogoReveal: React.FC<{ at: number; y: number; size?: number; width?: number; hold?: number }> = ({ at, y, size = 380, width = 820, hold = 1.05 }) => {
  const t = useS();
  const F = useF();
  const s = size * F.ks;
  const ww = width * F.ks;
  const swap = p(t, at + hold, at + hold + 0.35, easeInOut);
  const wm = p(t, at + hold + 0.1, at + hold + 0.55);
  return (
    <>
      {swap < 1 && (
        <Sequence from={Math.round(at * 30)} layout="none">
          <div style={{ position: "absolute", left: F.cx - s / 2, top: y - s / 2, width: s, height: s, opacity: 1 - swap, transform: `scale(${1 - swap * 0.4})`, filter: swap > 0 ? `blur(${swap * 10}px)` : undefined }}>
            <Lottie animationData={loaderLight as never} loop={false} style={{ width: s, height: s }} />
          </div>
        </Sequence>
      )}
      {/* the wordmark file is a 2000 × 1778 square with the lockup in a band across the middle */}
      <div style={{ position: "absolute", left: F.cx - ww / 2, top: y - (ww * 0.235) / 2, width: ww, height: ww * 0.235, overflow: "hidden", opacity: wm, transform: `scale(${lerp(0.9, 1, wm)})`, filter: wm < 1 ? `blur(${(1 - wm) * 14}px)` : undefined, mixBlendMode: "multiply" }}>
        <Img src={staticFile("brand/solutiontee-wordmark.jpg")} style={{ position: "absolute", width: ww, left: 0, top: -ww * 0.325 }} />
      </div>
    </>
  );
};

/** The end card shared by the three ads: logo, call to action, address, platforms, exam logos and the disclaimer. */
export const EndCard: React.FC<{ at: number; cta?: string }> = ({ at, cta = "Practise free today" }) => {
  const t = useS();
  const F = useF();
  const y0 = F.cy - 480 * F.ky;
  const btn = spr(t, at + 1.3, { damping: 12 });
  const pulse = 1 + Math.sin(Math.max(0, t - at - 2) * 6) * 0.025;
  return (
    <AbsoluteFill>
      <WarmStage intensity={0.85} />
      <LogoReveal at={at} y={y0} size={340} width={860} />
      <KText text="Learn. Think. *Solve.*" at={at + 1.2} y={y0 + 210 * F.ky} size={72} />
      <div style={{ position: "absolute", left: F.cx, top: F.cy + 60 * F.ky, transform: `translate(-50%,-50%) scale(${btn * pulse})`, opacity: Math.min(1, btn * 2) }}>
        <div style={{ padding: `${34 * F.ks}px ${70 * F.ks}px`, borderRadius: 999, background: C.gold, color: C.navy, fontFamily: FONT, fontWeight: 800, fontSize: 58 * F.ks, whiteSpace: "nowrap", boxShadow: "0 30px 60px -20px rgba(242,178,51,.9), inset 0 -6px 0 rgba(0,0,0,.08)" }}>{cta}</div>
      </div>
      <KText text="cbt.solutiontee.com" at={at + 1.6} y={F.cy + 230 * F.ky} size={56} weight={700} />
      <KText text="Android · Windows · JAMB · WAEC · NECO" at={at + 1.8} y={F.cy + 315 * F.ky} size={32} weight={600} color="#5B6B86" stagger={0.03} />
      <ExamLogos y={F.cy + 500 * F.ky} at={at + 1.9} h={90} gap={34} step={0.12} />
      <div style={{ position: "absolute", left: 90, right: 90, top: F.H - 120 * F.ky, textAlign: "center", fontFamily: FONT, fontWeight: 500, fontSize: 22 * F.ks, lineHeight: 1.35, color: "#6B7A93", opacity: p(t, at + 2.1, at + 2.5) }}>
        SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
      </div>
    </AbsoluteFill>
  );
};

/** Hard white flash for cuts. */
export const Flash: React.FC<{ at: number; dur?: number; color?: string; max?: number }> = ({ at, dur = 0.3, color = "#fff", max = 0.9 }) => {
  const t = useS();
  const k = interpolate(t, [at, at + 0.04, at + dur], [0, max, 0], clamp);
  return k > 0 ? <AbsoluteFill style={{ background: color, opacity: k, pointerEvents: "none" }} /> : null;
};

/** Confetti burst in brand colours. */
export const Burst: React.FC<{ at: number; x: number; y: number; n?: number; power?: number; dur?: number }> = ({ at, x, y, n = 90, power = 1, dur = 3 }) => {
  const t = useS();
  const d = t - at;
  if (d < 0 || d > dur) return null;
  const cols = [C.gold, C.navy, C.blue, "#FFD27A", "#3DDC97", "#fff"];
  return (
    <>
      {Array.from({ length: n }).map((_, i) => {
        const ang = rnd(i) * Math.PI * 2;
        const v = (600 + rnd(i + 5) * 1200) * power;
        const drag = (1 - Math.exp(-d * 2.4)) / 2.4;
        const px = x + Math.cos(ang) * v * drag + Math.sin(d * 4 + i) * 18 * d;
        const py = y + Math.sin(ang) * v * drag + 420 * d * d;
        const w = 12 + rnd(i + 8) * 14, h = w * (0.45 + rnd(i + 9) * 0.5);
        return <div key={i} style={{ position: "absolute", left: px, top: py, width: w, height: h, background: cols[i % cols.length], borderRadius: i % 4 === 0 ? 99 : 3, transform: `rotate(${d * 640 * (rnd(i + 3) - 0.5) + i * 33}deg) scaleY(${Math.cos(d * 9 + i)})`, opacity: interpolate(d, [dur - 1, dur], [1, 0], clamp) }} />;
      })}
    </>
  );
};

export { easeOut, easeInOut, lerp, p, rnd, spr, clamp };
