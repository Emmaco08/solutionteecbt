import React from "react";
import { AbsoluteFill, Audio, Img, staticFile } from "remotion";
import { Phone } from "../components";
import { Burst, EndCard, Flash, KText, Star4, WarmStage, useF, useS } from "../pack/kit";
import { C, DeepStage, FONT, Ico, Pill, Shot, easeInOut, easeOut, lerp, p, spr } from "../feat/fkit";

// Advert: "SolutionTee CBT is now on Windows" (D-186). 20 s, 120 BPM, 9:16, 4:5 and 16:9.
export const WIN_SECONDS = 20;

/** The frame plus which of the three formats it is. */
const useL = () => {
  const F = useF();
  const land = F.W > F.H;
  const f45 = !F.tall && !land;
  /** pick a value for 9:16, 4:5, 16:9 */
  const pick = <T,>(tall: T, four5: T, wide: T): T => (land ? wide : f45 ? four5 : tall);
  // in 16:9 the words sit in a left column and the pictures on the right; in 9:16 and 4:5 both are centred
  const vx = land ? F.W * 0.665 : F.cx;
  /** where a title line goes: centred at y (9:16 / 4:5), or left-aligned in the left column at yl (16:9) */
  const ty = (yt: number, y45: number, yl: number) => (land ? { y: yl, x: 120, width: 760, align: "left" as const } : { y: f45 ? y45 : yt });
  return { ...F, land, f45, pick, vx, ty };
};

const SCR = { w: 1920, h: 1080 };

/**
 * A laptop in 3D: the lid rises from the keyboard deck ([open] 0 → 1), the screen powers on ([on] 0 → 1).
 * [y] is the centre of the screen. Children are drawn over the screen in the screenshot's own pixels (1920 × 1080).
 */
const Laptop: React.FC<{ x: number; y: number; w: number; src?: string; open?: number; on?: number; rx?: number; ry?: number; scale?: number; children?: React.ReactNode; shadow?: boolean }> = ({ x, y, w, src, open = 1, on = 1, rx = 8, ry = 0, scale = 1, children, shadow = true }) => {
  const b = w * 0.024;
  const sw = w - b * 2;
  const sh = (sw * SCR.h) / SCR.w;
  const chin = w * 0.018;
  const lh = sh + b * 2 + chin;
  const deck = w * 0.6;
  const k = sw / SCR.w;
  const lid = lerp(-74, 4, easeOut(open));
  return (
    <div style={{ position: "absolute", left: x, top: y, width: 0, height: 0, perspective: 3200 }}>
      <div style={{ position: "absolute", left: -w / 2, top: -(b + sh / 2), width: w, height: lh, transformStyle: "preserve-3d", transform: `rotateX(${rx}deg) rotateY(${ry}deg) scale(${scale})`, transformOrigin: `50% ${lh}px` }}>
        {shadow && <div style={{ position: "absolute", left: "-6%", right: "-6%", top: lh + w * 0.03, height: w * 0.09, borderRadius: "50%", background: "radial-gradient(closest-side, rgba(0,0,0,.45), transparent)", filter: "blur(8px)", transform: "translateZ(-40px)" }} />}
        {/* keyboard deck, lying towards the viewer */}
        <div style={{ position: "absolute", left: -w * 0.07, top: lh, width: w * 1.14, height: deck, transformOrigin: "50% 0", transform: "rotateX(84deg)", borderRadius: `${w * 0.012}px ${w * 0.012}px ${w * 0.03}px ${w * 0.03}px`, background: "linear-gradient(180deg,#c9d1dd,#aeb8c7 60%,#8d97a8)", boxShadow: "inset 0 2px 0 rgba(255,255,255,.7)" }}>
          <div style={{ position: "absolute", left: "9%", right: "9%", top: "8%", height: "52%", borderRadius: w * 0.008, background: "repeating-linear-gradient(90deg,#2a3242 0 5.2%,#3a4458 5.2% 6%)", opacity: 0.9 }} />
          <div style={{ position: "absolute", left: "36%", right: "36%", top: "66%", height: "26%", borderRadius: w * 0.01, background: "#b8c1cf", boxShadow: "inset 0 0 0 2px rgba(0,0,0,.08)" }} />
        </div>
        {/* front lip of the deck */}
        <div style={{ position: "absolute", left: -w * 0.07, top: lh - 1, width: w * 1.14, height: w * 0.022, borderRadius: `0 0 ${w * 0.03}px ${w * 0.03}px`, background: "linear-gradient(180deg,#d7dde6,#8b95a6)", transform: `translateZ(${deck * 0.995}px) translateY(${deck * 0.1}px)`, opacity: 0 }} />
        {/* lid */}
        <div style={{ position: "absolute", left: 0, top: 0, width: w, height: lh, transformOrigin: "50% 100%", transform: `rotateX(${lid}deg)`, transformStyle: "preserve-3d" }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: w * 0.022, background: "linear-gradient(160deg,#2b3446,#0b111d 40%,#0b111d 70%,#283246)", boxShadow: "inset 0 0 0 2px rgba(255,255,255,.12), 0 50px 100px -40px rgba(0,0,0,.7)" }} />
          <div style={{ position: "absolute", left: "50%", top: b * 0.38, width: b * 0.28, height: b * 0.28, marginLeft: -b * 0.14, borderRadius: 99, background: "#334" }} />
          <div style={{ position: "absolute", left: b, top: b, width: sw, height: sh, borderRadius: w * 0.006, overflow: "hidden", background: "#04070F" }}>
            <div style={{ position: "absolute", left: 0, top: 0, width: SCR.w, height: SCR.h, transform: `scale(${k})`, transformOrigin: "0 0", opacity: on, filter: on < 1 ? `brightness(${lerp(2.2, 1, on)})` : undefined }}>
              {src && <Img src={staticFile(src)} style={{ position: "absolute", inset: 0, width: SCR.w, height: SCR.h }} />}
              {children}
            </div>
            <div style={{ position: "absolute", inset: "-30% -60%", background: "linear-gradient(115deg, transparent 40%, rgba(255,255,255,.10) 47%, rgba(255,255,255,.03) 53%, transparent 60%)", transform: `translateX(${ry * 1.2}%)`, pointerEvents: "none" }} />
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, bottom: chin * 0.2, textAlign: "center", fontFamily: FONT, fontWeight: 700, fontSize: chin * 0.55, color: "rgba(255,255,255,.35)", letterSpacing: "0.1em" }}>SOLUTIONTEE CBT</div>
        </div>
      </div>
    </div>
  );
};

/** Screen height of a laptop of width w (for laying things out under it). */
const screenH = (w: number) => ((w - w * 0.048) * SCR.h) / SCR.w;

/** A keyboard key that presses down at [press] (seconds) and glows gold while held. */
const Key: React.FC<{ x: number; y: number; at: number; press: number; label: string; w?: number; size: number; caption?: string; dark?: boolean }> = ({ x, y, at, press, label, w = 1, size, caption }) => {
  const t = useS();
  const k = spr(t, at, { damping: 12, stiffness: 170 });
  if (k < 0.002) return null;
  const d = t >= press ? Math.max(0, 1 - (t - press) / 0.22) : 0;
  const lit = t >= press ? 1 - p(t, press + 0.9, press + 1.3) * 0.6 : 0;
  const h = size;
  const kw = size * w;
  const depth = size * 0.11;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${k})`, display: "flex", flexDirection: "column", alignItems: "center", gap: size * 0.16 }}>
      <div style={{ position: "relative", width: kw, height: h + depth }}>
        <div style={{ position: "absolute", left: 0, top: depth, width: kw, height: h, borderRadius: size * 0.2, background: lit > 0 ? "#B98418" : "#9AA4B5" }} />
        <div style={{ position: "absolute", left: 0, top: depth * d, width: kw, height: h, borderRadius: size * 0.2, background: lit > 0 ? `linear-gradient(180deg,#FFD978,${C.gold})` : "linear-gradient(180deg,#fff,#E9EDF3)", boxShadow: lit > 0 ? `0 0 ${40 * lit}px rgba(242,178,51,${0.8 * lit})` : "inset 0 -2px 0 rgba(0,0,0,.06)", display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: size * (label.length > 3 ? 0.3 : 0.42), color: C.navy, letterSpacing: "-0.02em" }}>{label}</div>
      </div>
      {caption && <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: size * 0.27, color: C.navy, whiteSpace: "nowrap", opacity: p(t, at + 0.1, at + 0.4) }}>{caption}</div>}
    </div>
  );
};

// ------------------------------------------------------------------ 0–2.1 s: the hook, a CBT centre

const Monitor: React.FC<{ x: number; y: number; w: number; at: number }> = ({ x, y, w, at }) => {
  const t = useS();
  const k = spr(t, at, { damping: 11, stiffness: 150 });
  if (k < 0.002) return null;
  const sh = (w * 0.94 * 9) / 16;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) translateY(${(1 - k) * -500}px) rotate(${(1 - k) * 12}deg)`, opacity: Math.min(1, k * 2) }}>
      <div style={{ width: w, padding: w * 0.03, borderRadius: w * 0.04, background: "#0B111D", boxShadow: "0 30px 60px -25px rgba(30,30,60,.6)" }}>
        <Img src={staticFile("screens/win/cbt_from_test.jpg")} style={{ display: "block", width: w * 0.94, height: sh, borderRadius: w * 0.012, objectFit: "cover" }} />
      </div>
      <div style={{ width: w * 0.12, height: w * 0.12, margin: "0 auto", background: "linear-gradient(90deg,#7d889b,#c9d1dd,#7d889b)" }} />
      <div style={{ width: w * 0.42, height: w * 0.035, margin: "0 auto", borderRadius: 99, background: "#8d97a8" }} />
    </div>
  );
};

const Hook: React.FC = () => {
  const L = useL();
  const mw = L.pick(520, 400, 480);
  const my = L.pick(L.cy + 90, L.cy + 110, L.cy + 20);
  const gap = L.pick(300, 330, 300);
  const hx = L.vx + (L.land ? 60 : 0);
  return (
    <Shot a={0} b={2.1} first>
      <KText text="JAMB is written" at={0.0} {...L.ty(L.cy - 560, L.cy - 420, L.cy - 70)} size={L.pick(104, 104, 96)} stagger={0.05} dur={0.3} />
      <KText text="*on a computer.*" at={0.3} {...L.ty(L.cy - 410, L.cy - 290, L.cy + 50)} size={L.pick(150, 140, 130)} serifScale={1.1} />
      <Monitor x={hx - gap} y={my + 20} w={mw * 0.86} at={0.55} />
      <Monitor x={hx + gap} y={my + 20} w={mw * 0.86} at={0.7} />
      <Monitor x={hx} y={my} w={mw} at={0.62} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 2.1–3.7 s: on a tiny phone

const Tiny: React.FC = () => {
  const L = useL();
  const t = useS();
  const k = spr(t, 2.25, { damping: 9, stiffness: 160 });
  const wob = Math.sin((t - 2.25) * 9) * Math.exp(-(t - 2.25) * 2.2) * 9;
  const pw = L.pick(250, 210, 250);
  return (
    <Shot a={2.1} b={3.7}>
      <KText text="So why practise" at={2.15} {...L.ty(L.cy - 560, L.cy - 430, L.cy - 70)} size={L.pick(104, 100, 96)} />
      <KText text="only on a *phone?*" at={2.35} {...L.ty(L.cy - 430, L.cy - 315, L.cy + 45)} size={L.pick(104, 100, 96)} />
      <Phone src="screens/cbt.jpg" width={pw * k} x={L.vx} y={L.pick(L.cy + 230, L.cy + 190, L.cy + 30)} rz={wob} />
      <Pill x={L.vx + pw * 0.9} y={L.pick(L.cy + 40, L.cy + 40, L.cy - 160)} at={2.85} bg="#fff" fg={C.navy} size={L.pick(36, 32, 34)} icon="sparkle">so small…</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ 3.7–6.8 s: the reveal

const Reveal: React.FC = () => {
  const L = useL();
  const t = useS();
  const lw = L.pick(880, 780, 900);
  const open = p(t, 3.8, 4.55);
  const on = p(t, 4.5, 4.85);
  const sy = L.pick(L.cy + 150, L.cy + 150, L.cy - 20);
  const zoom = lerp(0.92, 1, p(t, 3.8, 6.8, easeInOut));
  const badge = spr(t, 5.35, { damping: 8, stiffness: 200 });
  return (
    <Shot a={3.7} b={6.8} zin={1.15}>
      <DeepStage />
      <KText text="SolutionTee CBT" at={4.55} {...L.ty(L.cy - 740, L.cy - 540, L.cy - 130)} size={L.pick(92, 84, 84)} color="#fff" accent={C.gold} />
      <KText text="is now on" at={4.75} {...L.ty(L.cy - 610, L.cy - 430, L.cy - 30)} size={L.pick(118, 108, 104)} color="#fff" accent={C.gold} />
      <KText text="*Windows.*" at={4.95} {...L.ty(L.cy - 480, L.cy - 320, L.cy + 95)} size={L.pick(150, 130, 140)} color="#fff" accent={C.gold} />
      <Laptop x={L.vx} y={sy} w={lw} src="screens/win/home.jpg" open={open} on={on} rx={lerp(14, 6, open)} scale={zoom} />
      {badge > 0.01 && (
        <div style={{ position: "absolute", left: L.vx + lw * 0.42, top: sy - screenH(lw) * 0.55, transform: `translate(-50%,-50%) rotate(${lerp(-40, 10, badge)}deg) scale(${badge})`, padding: `${14 * L.ks}px ${30 * L.ks}px`, borderRadius: 999, background: C.gold, color: C.navy, fontFamily: FONT, fontWeight: 800, fontSize: 44 * L.ks, boxShadow: "0 20px 50px -10px rgba(242,178,51,.8)" }}>NEW</div>
      )}
      <Star4 x={L.vx - lw * 0.46} y={sy - screenH(lw) * 0.5} size={70} at={4.9} />
      <Star4 x={L.vx + lw * 0.5} y={sy + screenH(lw) * 0.38} size={50} at={5.05} />
      <Burst at={4.85} x={L.vx} y={sy} n={70} power={0.9} />
      <Flash at={4.55} max={0.5} color="#DDE9FF" />
    </Shot>
  );
};

// ------------------------------------------------------------------ 6.8–10.8 s: a real CBT on a big screen, with keys

const BigCbt: React.FC = () => {
  const L = useL();
  const t = useS();
  const lw = L.pick(900, 780, 940);
  const sy = L.pick(L.cy + 20, L.cy - 20, L.cy - 30);
  // the camera moves into the question, then back out to the whole exam screen
  const push = p(t, 7.0, 7.9, easeInOut) * (1 - p(t, 9.3, 10.1, easeInOut));
  const ks = L.pick(124, 92, 88);
  const keys: [string, number, string][] = [["A", 1, "Choose"], ["→", 1, "Next"], ["F", 1, "Flag"], ["Shift+C", 2.1, "Calculator"]];
  const step = L.pick(215, 176, 128);
  const xs = L.land ? [120 + ks / 2, 120 + ks / 2 + step, 120 + ks / 2 + step * 2, 120 + step * 3 + ks * 1.05] : [-1.75, -0.75, 0.25, 1.6].map((m) => L.cx + m * step);
  const ky = L.pick(L.cy + 530, L.cy + 380, L.cy + 170);
  return (
    <Shot a={6.8} b={10.8}>
      <KText text="A real CBT." at={6.85} {...L.ty(L.cy - 720, L.cy - 560, L.cy - 230)} size={L.pick(104, 96, 96)} />
      <KText text="*On a big screen.*" at={7.05} {...L.ty(L.cy - 590, L.cy - 455, L.cy - 115)} size={L.pick(124, 110, 112)} />
      <Laptop x={L.vx} y={sy} w={lw} rx={4} shadow={false}>
        <Img src={staticFile("screens/win/cbt_calculator.jpg")} style={{ position: "absolute", inset: 0, width: SCR.w, height: SCR.h, transformOrigin: "330px 170px", transform: `scale(${lerp(1, 1.7, push)})` }} />
      </Laptop>
      {keys.map(([lab, w, cap], i) => (
        <Key key={lab} x={xs[i]} y={ky} at={7.6 + i * 0.12} press={8.25 + i * 0.5} label={lab} w={w} size={ks} caption={cap} />
      ))}
      <Pill x={L.vx + lw * 0.46} y={sy - screenH(lw) * 0.6} at={8.0} bg={C.navy} fg="#fff" icon="timer" size={L.pick(34, 30, 30)} anchor="right">Timer like the real exam</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ 10.8–13.6 s: everything, bigger

const SHOWS: [string, string, string][] = [
  ["screens/win/ai.jpg", "AI tutor", "sparkle"],
  ["screens/win/games_from_sidebar.jpg", "Game Zone", "trophy"],
  ["screens/win/study.jpg", "Videos & notes", "video"],
  ["screens/win/news.jpg", "Exam news", "bell"],
  ["screens/win/badges.jpg", "Badges & streaks", "fire"],
];

const Everything: React.FC = () => {
  const L = useL();
  const t = useS();
  const lw = L.pick(900, 780, 940);
  const sy = L.pick(L.cy + 60, L.cy + 50, L.cy - 50);
  const t0 = 11.25, per = 0.46;
  const idx = Math.max(0, Math.min(SHOWS.length - 1, Math.floor((t - t0) / per)));
  const local = t - t0 - idx * per;
  const ry = Math.sin((t - 10.8) * 0.9) * 6;
  return (
    <Shot a={10.8} b={13.6}>
      <DeepStage a="rgba(242,178,51,.30)" b="rgba(37,99,179,.5)" />
      <KText text="Everything you love." at={10.85} {...L.ty(L.cy - 640, L.cy - 500, L.cy - 70)} size={L.pick(96, 88, 84)} color="#fff" accent={C.gold} />
      <KText text="*Bigger.*" at={11.05} {...L.ty(L.cy - 500, L.cy - 385, L.cy + 55)} size={L.pick(150, 130, 150)} color="#fff" accent={C.gold} />
      <Laptop x={L.vx} y={sy} w={lw} ry={ry} rx={6} shadow={false}>
        {SHOWS.map(([src], i) => {
          if (t < t0 && i > 0) return null;
          const vis = i === idx ? 1 : i === idx - 1 ? 1 - p(local, 0, 0.12) : 0;
          if (vis <= 0) return null;
          const inK = i === idx && t >= t0 ? p(local, 0, 0.14, easeOut) : 1;
          return <Img key={src} src={staticFile(src)} style={{ position: "absolute", inset: 0, width: SCR.w, height: SCR.h, opacity: i === idx ? 1 : vis, transform: `translateY(${(1 - inK) * 60}px) scale(${lerp(1.04, 1, inK)})` }} />;
        })}
      </Laptop>
      {SHOWS.map(([, label, icon], i) => {
        const a = t0 + i * per;
        if (t < a || (i < SHOWS.length - 1 && t > a + per + 0.05)) return null;
        return <Pill key={label} x={L.vx} y={sy + screenH(lw) / 2 + L.pick(150, 120, 130)} at={a} bg={C.gold} fg={C.navy} size={L.pick(52, 44, 44)} icon={icon} bob={false}>{label}</Pill>;
      })}
    </Shot>
  );
};

// ------------------------------------------------------------------ 13.6–16.1 s: same account, same Premium

const Together: React.FC = () => {
  const L = useL();
  const t = useS();
  const lw = L.pick(720, 640, 760);
  const pw = L.pick(250, 210, 250);
  const ly = L.pick(L.cy + 40, L.cy + 30, L.cy + 60);
  const lx = L.vx - L.pick(90, 80, 110);
  const px = lx + lw / 2 + pw * L.pick(0.25, 0.3, 0.3);
  const py = ly + L.pick(60, 50, 50);
  const line = p(t, 14.2, 14.8, easeOut);
  const ok = spr(t, 14.8, { damping: 9, stiffness: 200 });
  const ax = lx + lw * 0.2, ay = ly - screenH(lw) / 2 - 30;
  const bx = px, by = py - pw * 1.08 - 30;
  const mx = (ax + bx) / 2, my = Math.min(ay, by) - L.pick(170, 130, 110);
  // the middle of the quadratic curve, where the tick sits
  const cx = 0.25 * ax + 0.5 * mx + 0.25 * bx, cy = 0.25 * ay + 0.5 * my + 0.25 * by;
  return (
    <Shot a={13.6} b={16.1} last>
      <WarmStage />
      <KText text="Same account." at={13.65} {...L.ty(L.cy - 690, L.cy - 540, L.cy - 130)} size={L.pick(104, 96, 96)} />
      <KText text="*Same Premium.*" at={13.85} {...L.ty(L.cy - 560, L.cy - 425, L.cy - 10)} size={L.pick(124, 112, 116)} />
      <Laptop x={lx} y={ly} w={lw} src="screens/win/home.jpg" rx={6} ry={8} />
      <Phone src="screens/study.jpg" width={pw} x={px} y={py} ry={-10} />
      <svg width={L.W} height={L.H} style={{ position: "absolute", inset: 0 }}>
        <path d={`M${ax},${ay} Q${mx},${my} ${bx},${by}`} stroke={C.gold} strokeWidth={8} fill="none" strokeLinecap="round" strokeDasharray="2000" strokeDashoffset={2000 * (1 - line)} />
      </svg>
      {ok > 0.01 && (
        <div style={{ position: "absolute", left: cx, top: cy, transform: `translate(-50%,-50%) scale(${ok})`, width: 96 * L.ks, height: 96 * L.ks, borderRadius: 99, background: "#22C55E", display: "grid", placeItems: "center", boxShadow: "0 16px 40px -10px rgba(34,197,94,.8)" }}>
          <Ico n="check" size={60 * L.ks} color="#fff" stroke={3} />
        </div>
      )}
      <Pill x={L.land ? 120 : L.cx} y={L.pick(L.cy + 560, L.cy + 440, L.cy + 120)} at={15.0} bg={C.navy} fg="#fff" size={L.pick(36, 32, 30)} icon="download" bob={false} anchor={L.land ? "left" : "center"}>Windows 10 & 11 · 64-bit · Free to start</Pill>
    </Shot>
  );
};

const End: React.FC = () => {
  const t = useS();
  if (t < 15.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 15.95, 16.25) }}>
      <EndCard at={16.1} cta="Download for Windows" />
    </AbsoluteFill>
  );
};

export const WinAd: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/win_ad.wav")} />
    <WarmStage />
    <Hook />
    <Tiny />
    <Reveal />
    <BigCbt />
    <Everything />
    <Together />
    <End />
  </AbsoluteFill>
);
