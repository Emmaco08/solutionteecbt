import React from "react";
import * as THREE from "three";
import { AbsoluteFill, Audio, Img, staticFile } from "remotion";
import { Phone } from "../components";
import { ExamLogos, KText, LogoReveal, useF, useS } from "../pack/kit";
import { C, FONT, Ico, easeInOut, lerp, p, spr } from "../feat/fkit";
import { Cam, LAP, LaptopModel, Stage3D, project, screenPoint } from "./Laptop3D";

// Advert: "SolutionTee CBT is now on Windows" (D-186, v4). White studio look, professional motion: the real exam
// screen assembling from its parts, a match cut into a phone, a 3D laptop opening under a moving light, a camera dive
// into the screen, spotlighted tools, screens flying out of the laptop. 24.5 s, voice lines from public/vo_win.
export const WIN_SECONDS = 24.5;

/** Scene starts, and the moments the voice says each key word (public/vo_win/words.json). */
export const T = { tiny: 2.1, reveal: 4.5, open: 4.6, cbt: 7.9, all: 13.2, same: 17.2, end: 19.4 };
const W = {
  computer: 1.17, phone: 3.99, solution: 5.0, now: 6.68, windows: 7.04, realCbt: 8.0, big: 9.34, timer: 10.24, calc: 10.72, keyboard: 11.3, keys: 11.44, exam: 12.12,
  ai: 13.3, game: 14.32, videos: 15.28, notes: 15.58, everything: 16.04, account: 17.3, premium: 18.14, download: 19.75, url: 20.79,
};

// ------------------------------------------------------------------ layout helpers

const useL = () => {
  const F = useF();
  const land = F.W > F.H;
  const f45 = !F.tall && !land;
  const pick = <V,>(tall: V, four5: V, wide: V): V => (land ? wide : f45 ? four5 : tall);
  const vx = land ? F.W * 0.645 : F.cx;
  const ty = (yt: number, y45: number, yl: number) => (land ? { y: yl, x: 120, width: 700, align: "left" as const } : { y: f45 ? y45 : yt });
  return { ...F, land, f45, pick, vx, ty };
};
type LT = ReturnType<typeof useL>;

const clamp01 = (x: number) => Math.max(0, Math.min(1, x));
/** Decisive easing for camera moves: fast start, long soft landing. */
const expo = (x: number) => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * Math.max(0, x)));
const ease = (t: number, a: number, b: number, f: (x: number) => number = expo) => f(clamp01((t - a) / (b - a)));
const cubicOut = (x: number) => 1 - Math.pow(1 - x, 3);

/** The app window (the real Windows app has a light title bar with its name and the window buttons). */
const BAR = 0.034; // title bar height as a share of the window width
const examRect = (L: LT) => {
  const w = L.pick(1040, 940, 980);
  const h = w * (9 / 16) + w * BAR;
  const cx = L.vx + (L.land ? 70 : 0), cy = L.pick(L.cy + 60, L.cy + 70, L.cy + 40);
  return { x: cx - w / 2, y: cy - h / 2, w, h, sx: w / 1920 };
};
type RT = ReturnType<typeof examRect>;

const fit = (L: LT, look: THREE.Vector3, width: number, frac: number, yaw: number, pitch: number, at: [number, number], fov = 26): Cam => {
  const th = Math.tan(THREE.MathUtils.degToRad(fov / 2)) * (L.W / L.H);
  const d = width / 2 / (frac * th);
  const y = THREE.MathUtils.degToRad(yaw), pt = THREE.MathUtils.degToRad(pitch);
  return { pos: [look.x + d * Math.sin(y) * Math.cos(pt), look.y + d * Math.sin(pt), look.z + d * Math.cos(y) * Math.cos(pt)], look: [look.x, look.y, look.z], fov, shift: [at[0] - L.W / 2, at[1] - L.H / 2] };
};
const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);

// ------------------------------------------------------------------ the white studio

const WhiteStage: React.FC = () => {
  const t = useS();
  const F = useF();
  return (
    <AbsoluteFill style={{ background: "#FFFFFF" }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 0.9}px ${F.H * 0.5}px at ${30 + Math.sin(t * 0.3) * 8}% 12%, rgba(37,99,179,.07), transparent 70%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 0.9}px ${F.H * 0.45}px at ${70 + Math.cos(t * 0.25) * 8}% 92%, rgba(242,178,51,.08), transparent 70%)` }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, transparent 60%, rgba(11,31,68,.05))" }} />
    </AbsoluteFill>
  );
};

/** A scene layer: shown between a and b, with optional fades. */
const Layer: React.FC<{ a: number; b: number; fin?: number; fout?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ a, b, fin = 0, fout = 0, children, style }) => {
  const t = useS();
  if (t < a - 0.01 || t > b + 0.01) return null;
  const o = (fin > 0 ? p(t, a, a + fin) : 1) * (fout > 0 ? 1 - p(t, b - fout, b) : 1);
  return <AbsoluteFill style={{ opacity: o, ...style }}>{children}</AbsoluteFill>;
};

/** Navy title, accent words in blue serif italic, each word sliding up out of a mask. */
const Title: React.FC<{ text: string; at: number; y: { y: number; x?: number; width?: number; align?: "left" | "center" | "right" }; size: number; out?: number }> = ({ text, at, y, size, out }) => (
  <KText text={text} at={at} {...y} size={size} mode="mask" stagger={0.055} dur={0.5} color={C.navy} accent={C.blue} out={out} />
);

// ------------------------------------------------------------------ parts of the real exam screen (2x screenshots)

type Crop = { k: string; x: number; y: number; w: number; h: number };
// positions in the 1920 × 1080 screen (the crop files are 2x)
const CROPS: Crop[] = [
  { k: "head", x: 10, y: 5, w: 200, h: 43 },
  { k: "timer", x: 1336, y: 7, w: 107, h: 40 },
  { k: "submit", x: 1450, y: 7, w: 99, h: 40 },
  { k: "q", x: 330, y: 80, w: 895, h: 70 },
  { k: "optA", x: 340, y: 169, w: 880, h: 59 },
  { k: "optB", x: 340, y: 238, w: 880, h: 59 },
  { k: "optC", x: 340, y: 307, w: 880, h: 59 },
  { k: "optD", x: 340, y: 376, w: 880, h: 59 },
  { k: "calc", x: 1261, y: 514, w: 320, h: 435 },
  { k: "side", x: 1570, y: 20, w: 335, h: 130 },
  { k: "keys", x: 1575, y: 255, w: 330, h: 200 },
];
const crop = (k: string) => CROPS.find((c) => c.k === k)!;
/** Where a part of the screen lands on the frame, inside window R. */
const place = (R: RT, c: { x: number; y: number; w: number; h: number }) => ({ x: R.x + c.x * R.sx, y: R.y + R.w * BAR + c.y * R.sx, w: c.w * R.sx, h: c.h * R.sx });

const Window: React.FC<{ R: RT; src?: string; o?: number; children?: React.ReactNode; scale?: number; shadow?: number }> = ({ R, src, o = 1, children, scale = 1, shadow = 1 }) => (
  <div style={{ position: "absolute", left: R.x, top: R.y, width: R.w, height: R.h, opacity: o, transform: `scale(${scale})`, transformOrigin: "50% 50%", borderRadius: R.w * 0.014, overflow: "hidden", background: "#fff", boxShadow: `0 ${R.w * 0.05}px ${R.w * 0.1}px -${R.w * 0.03}px rgba(11,31,68,${0.32 * shadow}), 0 0 0 1px rgba(11,31,68,.08)` }}>
    <div style={{ height: R.w * BAR, background: "#F3F5F8", borderBottom: "1px solid #E4E8EE", display: "flex", alignItems: "center", padding: `0 ${R.w * 0.012}px`, fontFamily: FONT, fontWeight: 600, fontSize: R.w * 0.013, color: "#3B4A63" }}>
      <Img src={staticFile("brand/favicon.svg")} style={{ width: R.w * 0.018, height: R.w * 0.018, objectFit: "contain", marginRight: R.w * 0.008 }} />
      SolutionTee CBT
      <div style={{ flex: 1 }} />
      {["—", "☐", "✕"].map((g) => (
        <span key={g} style={{ width: R.w * 0.04, textAlign: "center", color: "#59677E", fontWeight: 500 }}>{g}</span>
      ))}
    </div>
    {src && <Img src={staticFile(src)} style={{ position: "absolute", left: 0, top: R.w * BAR, width: R.w, height: (R.w * 9) / 16 }} />}
    {children}
  </div>
);

// ------------------------------------------------------------------ 0–2.1 s: the exam screen assembles from its parts

const SCATTER: Record<string, [number, number, number, number]> = {
  // dx, dy (window widths), rotation (deg), delay (s)
  head: [-0.5, -0.55, -14, 0.1], timer: [0.45, -0.6, 18, 0.18], submit: [0.62, -0.42, 22, 0.24], q: [-0.2, -0.9, -6, 0.0],
  optA: [-0.75, -0.1, -12, 0.14], optB: [0.8, 0.05, 10, 0.2], optC: [-0.8, 0.25, 8, 0.26], optD: [0.75, 0.45, -10, 0.32],
  calc: [0.55, 0.9, 16, 0.22], side: [0.9, -0.75, 20, 0.3], keys: [1.0, 0.25, -18, 0.36],
};

const Hook: React.FC = () => {
  const L = useL();
  const t = useS();
  const R = examRect(L);
  const base = p(t, 1.15, 1.45);
  const push = lerp(1, 1.035, clamp01(t / T.tiny));
  return (
    <Layer a={0} b={T.tiny}>
      <Title text="JAMB is written" at={0.1} y={L.ty(L.cy - 640, L.cy - 500, L.cy - 70)} size={L.pick(104, 100, 96)} />
      <Title text="*on a computer.*" at={0.75} y={L.ty(L.cy - 500, L.cy - 385, L.cy + 50)} size={L.pick(150, 136, 130)} />
      <AbsoluteFill style={{ transform: `scale(${push})` }}>
        <Window R={R} src="screens/win2x/cbt_calculator.jpg" o={base} shadow={base} />
        {base < 1 &&
          CROPS.map((c) => {
            const [dx, dy, rot, d] = SCATTER[c.k];
            const k = spr(t, 0.2 + d, { damping: 16, stiffness: 120 });
            const k1 = spr(t - 1 / 30, 0.2 + d, { damping: 16, stiffness: 120 });
            const vel = Math.abs(k - k1) * R.w * Math.hypot(dx, dy);
            const pos = place(R, c);
            return (
              <div key={c.k} style={{ position: "absolute", left: pos.x, top: pos.y, width: pos.w, height: pos.h, transform: `translate(${(1 - k) * dx * R.w}px, ${(1 - k) * dy * R.w}px) rotate(${(1 - k) * rot}deg) scale(${lerp(1.6, 1, k)})`, opacity: Math.min(1, k * 4) * (1 - base), filter: vel > 1.5 ? `blur(${Math.min(10, vel * 0.08)}px)` : undefined, boxShadow: `0 ${30 * (1 - k) + 4}px ${60 * (1 - k) + 8}px -10px rgba(11,31,68,${0.38 * (1 - k) + 0.06}), 0 0 0 1px rgba(11,31,68,.08)`, borderRadius: 8, overflow: "hidden", background: "#fff" }}>
                <Img src={staticFile(`screens/win2x/c_${c.k}.png`)} style={{ width: "100%", height: "100%" }} />
              </div>
            );
          })}
      </AbsoluteFill>
    </Layer>
  );
};

// ------------------------------------------------------------------ 2.1–4.5 s: match cut into a small phone

/** A thin dimension line with end ticks that draws outward from its middle, like a product spec drawing. */
const Dim: React.FC<{ x1: number; y1: number; x2: number; y2: number; k: number; color?: string }> = ({ x1, y1, x2, y2, k, color = C.blue }) => {
  if (k <= 0) return null;
  const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
  const ax = lerp(mx, x1, k), ay = lerp(my, y1, k), bx = lerp(mx, x2, k), by = lerp(my, y2, k);
  const vert = Math.abs(x2 - x1) < Math.abs(y2 - y1);
  const tk = 14;
  const tick = (x: number, y: number) => (vert ? `M${x - tk},${y} L${x + tk},${y}` : `M${x},${y - tk} L${x},${y + tk}`);
  return (
    <path d={`M${ax},${ay} L${bx},${by} ${k > 0.98 ? tick(x1, y1) + " " + tick(x2, y2) : ""}`} stroke={color} strokeWidth={3} strokeLinecap="round" fill="none" />
  );
};

const Label: React.FC<{ x: number; y: number; k: number; text: string; L: LT; strong?: boolean }> = ({ x, y, k, text, L, strong }) => {
  if (k <= 0.01) return null;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) translateY(${(1 - k) * 14}px)`, opacity: k, padding: `${8 * L.ks}px ${20 * L.ks}px`, borderRadius: 999, background: strong ? C.blue : "#fff", color: strong ? "#fff" : "#4A5A75", border: strong ? "none" : "1px solid #DDE3EC", fontFamily: FONT, fontWeight: 800, fontSize: 30 * L.ks, whiteSpace: "nowrap", boxShadow: strong ? "0 12px 26px -10px rgba(37,99,179,.7)" : "0 8px 20px -12px rgba(11,31,68,.35)" }}>
      {text}
    </div>
  );
};

/**
 * "Only on a phone?": the phone lands; a laptop-size screen grows out from behind it (morphing from the phone's
 * screen into a full app window with the real exam), the phone stays in front of its corner, and measurement lines
 * draw along both with labels.
 */
const Tiny: React.FC = () => {
  const L = useL();
  const t = useS();
  const R0 = examRect(L);
  // the big screen, and the phone standing in front of its lower-left corner
  const pw = L.pick(230, 190, 210);
  const ph = pw * 2.085;
  const bw = L.pick(900, 800, 860);
  const big = { w: bw, h: bw * (9 / 16) + bw * BAR, cx: L.land ? L.vx + 60 : L.cx + L.pick(40, 30, 0), cy: L.pick(L.cy + 60, L.cy + 70, L.cy + 10) };
  const B = { x: big.cx - big.w / 2, y: big.cy - big.h / 2, w: big.w, h: big.h, sx: big.w / 1920 };
  const px = B.x + L.pick(150, 125, 120), py = B.y + B.h - ph * L.pick(0.18, 0.2, 0.3);
  // phone screen rectangle (the morph starts from here)
  const ps = { x: px - pw * 0.466, y: py - pw * 1.008, w: pw * 0.932, h: pw * 2.017 };
  const m = ease(t, T.tiny - 0.25, T.tiny + 0.35, easeInOut);
  const land = spr(t, T.tiny + 0.05, { damping: 14, stiffness: 140 });
  const grow = spr(t, 2.72, { damping: 15, stiffness: 95 });
  const fill = p(t, 2.95, 3.3);
  const dims = ease(t, 3.25, 3.75, easeInOut);
  const whip = ease(t, T.reveal - 0.3, T.reveal, (x) => x * x);
  const r = { x: lerp(ps.x, B.x, grow), y: lerp(ps.y, B.y, grow), w: lerp(ps.w, B.w, grow), h: lerp(ps.h, B.h, grow) };
  const rad = lerp(pw * 0.1, B.w * 0.014, grow);
  const toY = py - (R0.y + R0.h / 2), toX = px - (R0.x + R0.w / 2);
  return (
    <>
      {/* match cut: the exam window shrinks into the phone */}
      {t > T.tiny - 0.26 && t < T.tiny + 0.4 && (
        <AbsoluteFill style={{ opacity: 1 - p(t, T.tiny + 0.2, T.tiny + 0.38), transform: `translate(${toX * m}px, ${toY * m}px)` }}>
          <Window R={R0} src="screens/win2x/cbt_calculator.jpg" scale={lerp(1, (pw * 0.9) / R0.w, m)} />
        </AbsoluteFill>
      )}
      <Layer a={T.tiny} b={T.reveal} style={{ transform: `translateX(${-whip * L.W * 1.1}px)`, filter: whip > 0.02 ? `blur(${whip * 24}px)` : undefined }}>
        <Title text="So why practise" at={T.tiny + 0.05} y={L.ty(L.cy - 640, L.cy - 500, L.cy - 70)} size={L.pick(104, 100, 96)} />
        <Title text="only on a *phone?*" at={T.tiny + 0.85} y={L.ty(L.cy - 500, L.cy - 385, L.cy + 50)} size={L.pick(112, 104, 100)} />
        {/* the laptop-size screen growing out from behind the phone */}
        {grow > 0.002 && (
          <>
            <div style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, borderRadius: rad, background: `linear-gradient(160deg, rgba(37,99,179,${0.10 * (1 - fill)}), rgba(37,99,179,${0.03 * (1 - fill)}))`, border: `${lerp(2, 1, fill)}px solid rgba(37,99,179,${0.55 * (1 - fill) + 0.08})`, boxShadow: `0 ${40 * grow}px ${80 * grow}px -${30 * grow}px rgba(11,31,68,${0.3 * grow})` }} />
            {fill > 0 && <Window R={B} src="screens/win2x/cbt_calculator.jpg" o={fill} shadow={fill} />}
          </>
        )}
        {/* the phone, in front */}
        <div style={{ opacity: Math.min(1, land * 1.5), transform: `translateY(${(1 - land) * 40}px)` }}>
          <Phone src="screens/cbt.jpg" width={pw} x={px} y={py} ry={lerp(0, -8, grow)} rz={0} />
          <div style={{ position: "absolute", left: ps.x, top: ps.y, width: ps.w, height: ps.h, borderRadius: pw * 0.1, background: `rgba(11,31,68,${0.18 * fill})` }} />
        </div>
        {/* measurements */}
        <svg width={L.W} height={L.H} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
          <Dim x1={B.x} y1={B.y - 34} x2={B.x + B.w} y2={B.y - 34} k={dims} />
          <Dim x1={px - pw * 0.64} y1={py - ph / 2} x2={px - pw * 0.64} y2={py + ph / 2} k={dims} color="#8A97AC" />
        </svg>
        <Label x={B.x + B.w / 2} y={B.y - 34} k={p(t, 3.55, 3.8)} text="Laptop screen" L={L} strong />
        <Label x={px} y={py + ph / 2 + 44 * L.ks} k={p(t, 3.65, 3.9)} text="Your phone" L={L} />
      </Layer>
    </>
  );
};

// ------------------------------------------------------------------ 4.5–7.9 s: the laptop opens under a moving light

const Reveal: React.FC = () => {
  const L = useL();
  const t = useS();
  const k = ease(t, T.reveal, T.cbt, cubicOut);
  const openK = ease(t, T.open + 0.05, T.open + 1.05, cubicOut);
  const on = p(t, T.open + 0.85, T.open + 1.2);
  const atp: [number, number] = [L.vx + (L.land ? 90 : 0), L.pick(L.cy + 230, L.cy + 200, L.cy + 40)];
  const look = V(0, 6, 0).lerp(screenPoint(0.5, 0.6), ease(t, T.open + 0.2, T.open + 1.4, easeInOut));
  const cam = fit(L, look, 36, L.pick(lerp(0.95, 0.8, k), lerp(0.85, 0.7, k), lerp(0.55, 0.44, k)), lerp(-48, -14, k), lerp(9, 17, k), atp);
  const corner = project(cam, L.W, L.H, screenPoint(1, 0));
  const badge = spr(t, W.windows + 0.05, { damping: 9, stiffness: 190 });
  return (
    <Layer a={T.reveal} b={T.cbt + 0.02}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${L.W * 0.7}px ${L.H * 0.3}px at ${(atp[0] / L.W) * 100}% ${(atp[1] / L.H) * 100 - 6}%, rgba(37,99,179,${0.15 * on}), transparent 70%)` }} />
      <Title text="SolutionTee CBT" at={W.solution} y={L.ty(L.cy - 720, L.cy - 540, L.cy - 140)} size={L.pick(96, 88, 88)} />
      <Title text="is now on *Windows.*" at={W.now - 0.15} y={L.ty(L.cy - 580, L.cy - 420, L.cy - 30)} size={L.pick(112, 100, 104)} />
      <Stage3D cam={cam} floor={0.2} lightX={lerp(-70, 50, ease(t, T.reveal, T.open + 1.4, easeInOut))} exposure={1.05}>
        <LaptopModel open={openK} on={on} screens={[{ src: "screens/win/home.jpg" }]} shadow={0.35} />
      </Stage3D>
      {badge > 0.01 && (
        <div style={{ position: "absolute", left: Math.min(corner[0], L.W - 90), top: corner[1] - 6, transform: `translate(-50%,-50%) rotate(${lerp(-30, 8, badge)}deg) scale(${badge})`, padding: `${12 * L.ks}px ${28 * L.ks}px`, borderRadius: 999, background: C.gold, color: C.navy, fontFamily: FONT, fontWeight: 800, fontSize: 40 * L.ks, letterSpacing: "0.04em", boxShadow: "0 16px 36px -10px rgba(242,178,51,.7)" }}>NEW</div>
      )}
    </Layer>
  );
};

// ------------------------------------------------------------------ 7.9–13.2 s: dive into the screen; the real tools

const Key: React.FC<{ x: number; y: number; at: number; press: number; label: string; size: number; caption?: string }> = ({ x, y, at: a, press, label, size, caption }) => {
  const t = useS();
  const k = spr(t, a, { damping: 13, stiffness: 170 });
  if (k < 0.002) return null;
  const d = t >= press ? Math.max(0, 1 - (t - press) / 0.22) : 0;
  const lit = t >= press;
  const depth = size * 0.11;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${k})`, display: "flex", flexDirection: "column", alignItems: "center", gap: size * 0.14 }}>
      <div style={{ position: "relative", width: size, height: size + depth }}>
        <div style={{ position: "absolute", left: 0, top: depth, width: size, height: size, borderRadius: size * 0.2, background: lit ? "#1E4F96" : "#C9D0DB" }} />
        <div style={{ position: "absolute", left: 0, top: depth * d, width: size, height: size, borderRadius: size * 0.2, background: lit ? `linear-gradient(180deg,#3B7BD0,${C.blue})` : "linear-gradient(180deg,#FFFFFF,#EEF1F5)", boxShadow: lit ? "0 10px 26px -8px rgba(37,99,179,.7)" : "0 6px 14px -8px rgba(11,31,68,.4), inset 0 0 0 1px rgba(11,31,68,.06)", display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: size * 0.42, color: lit ? "#fff" : C.navy }}>{label}</div>
      </div>
      {caption && <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: size * 0.24, color: "#5B6B86", whiteSpace: "nowrap", opacity: p(t, a + 0.1, a + 0.4) }}>{caption}</div>}
    </div>
  );
};

/** A part of the screen lifts out towards the viewer (white veil over the rest), with a label. */
const Spotlight: React.FC<{ R: RT; k: string; a: number; b: number; scale: number; to: [number, number]; label: string; icon: string; L: LT }> = ({ R, k, a, b, scale, to, label, icon, L }) => {
  const t = useS();
  const s = spr(t, a, { damping: 15, stiffness: 150 }) * (1 - spr(t, b, { damping: 16, stiffness: 160 }));
  if (s < 0.003) return null;
  const c = place(R, crop(k));
  const x = lerp(c.x + c.w / 2, to[0], s), y = lerp(c.y + c.h / 2, to[1], s);
  const sc = lerp(1, scale, s);
  return (
    <>
      <div style={{ position: "absolute", left: R.x, top: R.y, width: R.w, height: R.h, borderRadius: R.w * 0.014, background: `rgba(255,255,255,${0.75 * s})` }} />
      <div style={{ position: "absolute", left: x - c.w / 2, top: y - c.h / 2, width: c.w, height: c.h, transform: `scale(${sc})`, borderRadius: 8, overflow: "hidden", background: "#fff", boxShadow: `0 ${30 * s}px ${60 * s}px -${12 * s}px rgba(11,31,68,${0.35 * s}), 0 0 0 ${3 * s}px rgba(37,99,179,${0.9 * s})` }}>
        <Img src={staticFile(`screens/win2x/c_${k}.png`)} style={{ width: "100%", height: "100%" }} />
      </div>
      <div style={{ position: "absolute", left: x, top: y + (c.h * sc) / 2 + 48 * L.ks, transform: `translate(-50%,-50%) scale(${s})`, display: "flex", alignItems: "center", gap: 12, padding: `${12 * L.ks}px ${26 * L.ks}px`, borderRadius: 999, background: C.navy, color: "#fff", fontFamily: FONT, fontWeight: 800, fontSize: 36 * L.ks, whiteSpace: "nowrap" }}>
        <Ico n={icon} size={38 * L.ks} color="#fff" stroke={2.4} />
        {label}
      </div>
    </>
  );
};

const BigCbt: React.FC = () => {
  const L = useL();
  const t = useS();
  const R = examRect(L);
  const scr = { cx: R.x + R.w / 2, cy: R.y + R.w * BAR + (R.w * 9) / 32 };
  // the camera flies to the screen until it matches the window; then the sharp flat screen takes over
  const dive = ease(t, T.cbt, T.cbt + 0.85, easeInOut);
  const out = ease(t, W.exam - 0.05, W.exam + 0.9, easeInOut);
  const flat = t >= T.cbt + 0.8 && t < W.exam + 0.05;
  const startAt: [number, number] = [L.vx + (L.land ? 90 : 0), L.pick(L.cy + 230, L.cy + 200, L.cy + 40)];
  const camIn = fit(L, screenPoint(0.5, 0.5), LAP.SW, lerp(L.pick(0.5, 0.45, 0.28), R.w / L.W, dive), lerp(-14, 0, dive), lerp(17, 0, dive), [lerp(startAt[0], scr.cx, dive), lerp(startAt[1], scr.cy, dive)]);
  const camOut = fit(L, screenPoint(0.5, 0.55), LAP.SW, lerp(R.w / L.W, L.pick(0.62, 0.55, 0.42), out), lerp(0, 12, out), lerp(0, 14, out), [scr.cx, lerp(scr.cy, L.pick(L.cy + 120, L.cy + 110, L.cy + 40), out)]);
  const selB = t >= W.keys + 0.02;
  const ks = L.pick(120, 96, 88);
  const ky = L.land ? L.cy + 230 : R.y + R.h + L.pick(150, 120, 0);
  const keyX = (i: number) => (L.land ? 120 + ks / 2 + i * (ks * 1.35) : L.cx + (i - 1) * ks * 1.5);
  const optB = place(R, crop("optB"));
  return (
    <Layer a={T.cbt} b={T.all + 0.02}>
      <Title text="A real CBT." at={W.realCbt} out={W.exam - 0.3} y={L.ty(L.cy - 720, L.cy - 560, L.cy - 300)} size={L.pick(104, 96, 96)} />
      <Title text="*On a big screen.*" at={W.big - 0.45} out={W.exam - 0.3} y={L.ty(L.cy - 590, L.cy - 450, L.cy - 185)} size={L.pick(124, 112, 112)} />
      <Title text="Just like *exam day.*" at={W.exam} y={L.ty(L.cy - 650, L.cy - 500, L.cy - 120)} size={L.pick(112, 100, 104)} />
      {!flat && (
        <Stage3D cam={t < W.exam ? camIn : camOut} floor={0.2} exposure={1.05}>
          <LaptopModel screens={[{ src: "screens/win/cbt_calculator.jpg" }]} shadow={0.35} />
        </Stage3D>
      )}
      {flat && (
        <>
          <Window R={R} src="screens/win2x/cbt_calculator.jpg" o={p(t, T.cbt + 0.8, T.cbt + 0.95)}>
            {selB && (
              <div style={{ position: "absolute", left: optB.x - R.x, top: optB.y - R.y, width: optB.w, height: optB.h, borderRadius: 16 * R.sx, border: `3px solid ${C.blue}`, background: "rgba(37,99,179,.10)", transform: `scale(${1 + Math.max(0, 1 - (t - W.keys) / 0.25) * 0.03})` }} />
            )}
          </Window>
          <Spotlight R={R} L={L} k="timer" a={W.timer - 0.08} b={W.calc - 0.12} scale={3.1} to={[scr.cx, R.y + R.h * 0.32]} label="Timer like the real exam" icon="timer" />
          <Spotlight R={R} L={L} k="calc" a={W.calc - 0.08} b={W.keyboard - 0.12} scale={L.pick(1.15, 1.05, 1.15)} to={[scr.cx, scr.cy - 20]} label="Calculator" icon="calc" />
        </>
      )}
      {t < W.exam + 0.2 && (
        <AbsoluteFill style={{ opacity: 1 - p(t, W.exam, W.exam + 0.2) }}>
          <Key x={keyX(0)} y={ky} at={W.keyboard - 0.1} press={W.keys + 0.02} label="B" size={ks} caption="Choose" />
          <Key x={keyX(1)} y={ky} at={W.keyboard - 0.02} press={W.keys + 0.32} label="→" size={ks} caption="Next" />
          <Key x={keyX(2)} y={ky} at={W.keyboard + 0.06} press={W.keys + 0.55} label="F" size={ks} caption="Flag" />
        </AbsoluteFill>
      )}
    </Layer>
  );
};

// ------------------------------------------------------------------ 13.2–17.2 s: screens fly out of the laptop

const SHOWS: { src: string; label: string; icon: string; at: number }[] = [
  { src: "screens/win2x/ai.jpg", label: "AI tutor", icon: "sparkle", at: W.ai },
  { src: "screens/win2x/games_from_sidebar.jpg", label: "Game Zone", icon: "trophy", at: W.game },
  { src: "screens/win2x/study.jpg", label: "Videos", icon: "video", at: W.videos },
  { src: "screens/win2x/news.jpg", label: "Notes & news", icon: "book", at: W.notes },
];

const Everything: React.FC = () => {
  const L = useL();
  const t = useS();
  const atp: [number, number] = [L.vx, L.pick(L.cy + 420, L.cy + 330, L.cy + 230)];
  const cam = fit(L, screenPoint(0.5, 0.6), 36, L.pick(0.66, 0.5, 0.36), lerp(-10, 10, p(t, T.all, T.same)), 14, atp);
  const tl = project(cam, L.W, L.H, screenPoint(0, 0)), br = project(cam, L.W, L.H, screenPoint(1, 1));
  const sw = br[0] - tl[0];
  const sc: [number, number] = [(tl[0] + br[0]) / 2, (tl[1] + br[1]) / 2];
  const cw = L.pick(430, 345, 290);
  const slots: [number, number][] = L.land
    ? [[L.vx - 480, L.cy - 290], [L.vx - 160, L.cy - 320], [L.vx + 160, L.cy - 320], [L.vx + 480, L.cy - 290]]
    : L.f45
      ? [[L.cx - 190, L.cy - 410], [L.cx + 190, L.cy - 410], [L.cx - 190, L.cy - 130], [L.cx + 190, L.cy - 130]]
      : [[L.cx - 232, L.cy - 570], [L.cx + 232, L.cy - 570], [L.cx - 232, L.cy - 205], [L.cx + 232, L.cy - 205]];
  const big = spr(t, W.everything, { damping: 14, stiffness: 120 });
  const flash = p(t, T.same - 0.25, T.same - 0.05) * (1 - p(t, T.same - 0.05, T.same + 0.15));
  return (
    <Layer a={T.all} b={T.same + 0.15}>
      <Title text="Everything, *bigger.*" at={W.everything} y={L.ty(L.cy - 840, L.cy - 610, L.cy - 60)} size={L.pick(96, 86, 96)} />
      <Stage3D cam={cam} floor={0.2} exposure={1.05}>
        <LaptopModel screens={[{ src: "screens/win/home.jpg" }]} shadow={0.35} />
      </Stage3D>
      {SHOWS.map((s, i) => {
        const k = spr(t, s.at - 0.1, { damping: 15, stiffness: 110 });
        if (k < 0.002) return null;
        const k1 = spr(t - 1 / 30, s.at - 0.1, { damping: 15, stiffness: 110 });
        const [tx, ty] = slots[i];
        const x = lerp(sc[0], tx, k), y = lerp(sc[1], ty, k);
        const w = lerp(sw, cw, k) * lerp(1, 1.08, big);
        const vel = Math.abs(k - k1) * Math.hypot(tx - sc[0], ty - sc[1]);
        const tilt = (i % 2 === 0 ? 1 : -1) * 10 * (1 - big * 0.6);
        return (
          <React.Fragment key={s.src}>
            <div style={{ position: "absolute", left: x - w / 2, top: y - (w * 9) / 32, width: w, height: (w * 9) / 16, transform: `perspective(1400px) rotateY(${tilt * k}deg) rotateX(${(1 - k) * 25}deg)`, borderRadius: 14, overflow: "hidden", background: "#fff", boxShadow: "0 30px 60px -22px rgba(11,31,68,.42), 0 0 0 1px rgba(11,31,68,.08)", filter: vel > 3 ? `blur(${Math.min(8, vel * 0.04)}px)` : undefined, opacity: Math.min(1, k * 3) }}>
              <Img src={staticFile(s.src)} style={{ width: "100%", height: "100%" }} />
            </div>
            <div style={{ position: "absolute", left: x, top: y + (w * 9) / 32 + 34 * L.ks, transform: `translate(-50%,-50%) scale(${p(t, s.at + 0.15, s.at + 0.4)})`, display: "flex", alignItems: "center", gap: 10, padding: `${10 * L.ks}px ${22 * L.ks}px`, borderRadius: 999, background: C.navy, color: "#fff", fontFamily: FONT, fontWeight: 800, fontSize: 30 * L.ks, whiteSpace: "nowrap" }}>
              <Ico n={s.icon} size={30 * L.ks} color="#fff" stroke={2.4} />
              {s.label}
            </div>
          </React.Fragment>
        );
      })}
      {flash > 0 && <AbsoluteFill style={{ background: "#fff", opacity: flash }} />}
    </Layer>
  );
};

// ------------------------------------------------------------------ 17.2–19.4 s: same account, same Premium

const PremiumChip: React.FC<{ x: number; y: number; a: number; L: LT }> = ({ x, y, a, L }) => {
  const t = useS();
  const k = spr(t, a, { damping: 9, stiffness: 200 });
  if (k < 0.01) return null;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${k})`, display: "flex", alignItems: "center", gap: 10, padding: `${10 * L.ks}px ${22 * L.ks}px`, borderRadius: 999, background: `linear-gradient(180deg,#FFD46B,${C.gold})`, color: C.navy, fontFamily: FONT, fontWeight: 800, fontSize: 30 * L.ks, boxShadow: "0 14px 30px -10px rgba(242,178,51,.8)", whiteSpace: "nowrap" }}>
      <Ico n="check" size={30 * L.ks} color={C.navy} stroke={3} /> Premium
    </div>
  );
};

const Together: React.FC = () => {
  const L = useL();
  const t = useS();
  const pw = L.pick(250, 210, 240);
  const atp: [number, number] = [L.vx - L.pick(120, 110, 130), L.pick(L.cy + 150, L.cy + 140, L.cy + 60)];
  const cam = fit(L, screenPoint(0.5, 0.6), 36, L.pick(0.62, 0.52, 0.38), lerp(26, 16, p(t, T.same, T.end)), 12, atp);
  const right = project(cam, L.W, L.H, screenPoint(1, 0.55));
  const top = project(cam, L.W, L.H, screenPoint(0.35, 0));
  const px = right[0] + pw * 0.15, py = right[1] + L.pick(150, 130, 120);
  const phoneTop = py - pw * 1.08;
  const line = ease(t, W.account + 0.3, W.premium - 0.05, easeInOut);
  const ax = top[0], ay = top[1] - 70, bx = px, by = phoneTop - 70;
  const mx = (ax + bx) / 2, my = Math.min(ay, by) - L.pick(150, 120, 100);
  const q = (u: number) => [(1 - u) * (1 - u) * ax + 2 * (1 - u) * u * mx + u * u * bx, (1 - u) * (1 - u) * ay + 2 * (1 - u) * u * my + u * u * by];
  const [dx, dy] = q(line);
  const pin = spr(t, T.same, { damping: 14 });
  return (
    <Layer a={T.same} b={T.end + 0.3} fout={0.3}>
      <Title text="Same account." at={W.account} y={L.ty(L.cy - 700, L.cy - 540, L.cy - 140)} size={L.pick(104, 96, 96)} />
      <Title text="*Same Premium.*" at={W.premium - 0.1} y={L.ty(L.cy - 570, L.cy - 420, L.cy - 20)} size={L.pick(124, 112, 116)} />
      <Stage3D cam={cam} floor={0.2} exposure={1.05}>
        <LaptopModel screens={[{ src: "screens/win/home.jpg" }]} shadow={0.35} />
      </Stage3D>
      <div style={{ opacity: pin, transform: `translateY(${(1 - pin) * 80}px)` }}>
        <Phone src="screens/study.jpg" width={pw} x={px} y={py} ry={-12} />
      </div>
      <svg width={L.W} height={L.H} style={{ position: "absolute", inset: 0 }}>
        <path d={`M${ax},${ay} Q${mx},${my} ${bx},${by}`} stroke="rgba(37,99,179,.18)" strokeWidth={6} fill="none" strokeLinecap="round" strokeDasharray="10 12" />
        <path d={`M${ax},${ay} Q${mx},${my} ${bx},${by}`} stroke={C.blue} strokeWidth={6} fill="none" strokeLinecap="round" pathLength={1} strokeDasharray={`${line} 1`} />
        {line > 0 && line < 1 && <circle cx={dx} cy={dy} r={12} fill={C.gold} stroke="#fff" strokeWidth={4} />}
      </svg>
      <PremiumChip x={ax} y={ay} a={W.premium + 0.1} L={L} />
      <PremiumChip x={bx} y={by} a={W.premium + 0.18} L={L} />
      <div style={{ position: "absolute", left: L.land ? 120 : L.cx, top: L.pick(L.cy + 640, L.cy + 520, L.cy + 110), transform: L.land ? "translateY(-50%)" : "translate(-50%,-50%)", opacity: p(t, W.premium + 0.4, W.premium + 0.7), display: "flex", alignItems: "center", gap: 12, padding: `${12 * L.ks}px ${26 * L.ks}px`, borderRadius: 999, background: "#F1F4F9", color: C.navy, fontFamily: FONT, fontWeight: 700, fontSize: 30 * L.ks, whiteSpace: "nowrap" }}>
        <Ico n="download" size={30 * L.ks} color={C.navy} stroke={2.4} /> Windows 10 & 11 · 64-bit · Free to start
      </div>
    </Layer>
  );
};

// ------------------------------------------------------------------ 19.4–24.5 s: white end card

const End: React.FC = () => {
  const L = useL();
  const t = useS();
  const a = T.end;
  if (t < a - 0.2) return null;
  const y0 = L.pick(L.cy - 470, L.cy - 380, L.cy - 300);
  const btn = spr(t, W.download - 0.1, { damping: 12 });
  const url = "cbt.solutiontee.com";
  const typedN = Math.max(0, Math.min(url.length, Math.floor((t - (W.url - 0.25)) * 14)));
  const bx = L.cx, by = L.pick(L.cy + 20, L.cy + 10, L.cy + 40);
  return (
    <AbsoluteFill style={{ opacity: p(t, a - 0.2, a + 0.15) }}>
      <WhiteStage />
      <LogoReveal at={a} y={y0} size={L.pick(340, 300, 260)} width={L.pick(860, 760, 700)} />
      <Title text="Learn. Think. *Solve.*" at={a + 1.1} y={{ y: y0 + L.pick(200, 170, 150) }} size={L.pick(72, 64, 60)} />
      <div style={{ position: "absolute", left: bx, top: by, transform: `translate(-50%,-50%) scale(${btn})`, opacity: Math.min(1, btn * 2), display: "flex", alignItems: "center", gap: 18, padding: `${30 * L.ks}px ${60 * L.ks}px`, borderRadius: 999, background: C.navy, color: "#fff", fontFamily: FONT, fontWeight: 800, fontSize: 52 * L.ks, whiteSpace: "nowrap", boxShadow: "0 30px 60px -22px rgba(11,31,68,.6)" }}>
        <Ico n="download" size={52 * L.ks} color={C.gold} stroke={2.6} /> Download for Windows
      </div>
      <div style={{ position: "absolute", left: bx, top: by + L.pick(170, 150, 130), transform: "translate(-50%,-50%)", opacity: p(t, W.url - 0.4, W.url - 0.2), display: "flex", alignItems: "center", gap: 14, padding: `${16 * L.ks}px ${34 * L.ks}px`, borderRadius: 999, background: "#F1F4F9", border: "1px solid #E1E6EE", fontFamily: FONT, fontWeight: 700, fontSize: 44 * L.ks, color: C.navy, minWidth: 520 * L.ks }}>
        <Ico n="pin" size={36 * L.ks} color={C.blue} stroke={2.4} />
        <span>{url.slice(0, typedN)}</span>
        <span style={{ width: 3, height: 44 * L.ks, background: C.blue, opacity: Math.floor(t * 2.5) % 2 ? 1 : 0.15 }} />
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: by + L.pick(280, 245, 215), textAlign: "center", fontFamily: FONT, fontWeight: 600, fontSize: 30 * L.ks, color: "#5B6B86", opacity: p(t, W.url + 0.6, W.url + 0.9) }}>Windows · Android · JAMB · WAEC · NECO</div>
      <ExamLogos y={by + L.pick(430, 370, 330)} at={W.url + 0.8} h={L.pick(90, 80, 70)} gap={34} step={0.12} />
      <div style={{ position: "absolute", left: 90, right: 90, top: L.H - L.pick(110, 90, 70), textAlign: "center", fontFamily: FONT, fontWeight: 500, fontSize: 22 * L.ks, lineHeight: 1.35, color: "#7A879C", opacity: p(t, W.url + 1.0, W.url + 1.3) }}>
        SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
      </div>
    </AbsoluteFill>
  );
};

export const WinAd: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/win_ad.wav")} />
    <WhiteStage />
    <Hook />
    <Tiny />
    <Reveal />
    <BigCbt />
    <Everything />
    <Together />
    <End />
  </AbsoluteFill>
);
