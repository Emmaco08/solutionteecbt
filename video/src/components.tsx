import React from "react";
import { AbsoluteFill, Img, Sequence, staticFile, useVideoConfig } from "remotion";
import { C, FONT, OffsetProvider, clamp, easeOut, lerp, p, rnd, spr, useT } from "./lib";
import { interpolate } from "remotion";

/** Mounts children between seconds `from` and `to` (+ `pad` either side) and gives them absolute time. */
export const Scene: React.FC<{ from: number; to: number; pad?: number; children: React.ReactNode }> = ({ from, to, pad = 0.3, children }) => {
  const { fps } = useVideoConfig();
  const a = Math.max(0, from - pad);
  return (
    <Sequence from={Math.round(a * fps)} durationInFrames={Math.round((to + pad - a) * fps)} layout="none">
      <OffsetProvider from={Math.round(a * fps) / fps}>{children}</OffsetProvider>
    </Sequence>
  );
};

/** Opacity for a scene that cuts in at `from` and out at `to` with short fades. */
export const useCut = (from: number, to: number, fin = 0.08, fout = 0.08) => {
  const t = useT();
  return interpolate(t, [from - fin, from, to - fout, to], [0, 1, 1, 0], clamp);
};

/** Deep navy stage with slow aurora light and gold dust. */
export const Stage: React.FC<{ hue?: "navy" | "gold" | "blue" | "black"; dust?: number; grid?: boolean }> = ({ hue = "navy", dust = 40, grid = false }) => {
  const t = useT();
  const { width, height } = useVideoConfig();
  const base = hue === "black" ? "#02060F" : C.deep;
  const a = hue === "gold" ? "rgba(242,178,51,.38)" : "rgba(37,99,179,.55)";
  const b = hue === "gold" ? "rgba(37,99,179,.35)" : hue === "blue" ? "rgba(75,134,212,.35)" : "rgba(242,178,51,.22)";
  const bx = 50 + Math.sin(t * 0.35) * 25, by = 25 + Math.cos(t * 0.28) * 12;
  const cx = 50 + Math.cos(t * 0.31) * 30, cy = 80 + Math.sin(t * 0.4) * 10;
  return (
    <AbsoluteFill style={{ background: base, overflow: "hidden" }}>
      {hue !== "black" && (
        <AbsoluteFill
          style={{
            background: `radial-gradient(60% 40% at ${bx}% ${by}%, ${a}, transparent 70%), radial-gradient(55% 35% at ${cx}% ${cy}%, ${b}, transparent 70%), linear-gradient(180deg, ${C.navy} 0%, ${base} 60%, #030914 100%)`,
          }}
        />
      )}
      {grid && (
        <div
          style={{
            position: "absolute", left: "-50%", width: "200%", bottom: -200, height: height * 0.7,
            backgroundImage: "linear-gradient(rgba(120,160,230,.16) 2px, transparent 2px), linear-gradient(90deg, rgba(120,160,230,.16) 2px, transparent 2px)",
            backgroundSize: "120px 120px", backgroundPosition: `0 ${(t * 120) % 120}px`,
            transform: "perspective(900px) rotateX(70deg)", transformOrigin: "50% 100%",
            maskImage: "linear-gradient(to top, black 10%, transparent 85%)", WebkitMaskImage: "linear-gradient(to top, black 10%, transparent 85%)",
          }}
        />
      )}
      {Array.from({ length: dust }).map((_, i) => {
        const z = 0.3 + rnd(i) * 0.9;
        const x = (rnd(i + 11) * width + Math.sin(t * 0.3 + i) * 30 * z) % width;
        const y = (((rnd(i + 23) * height - t * 40 * z) % height) + height) % height;
        const s = 2 + z * 5;
        const tw = 0.4 + 0.6 * Math.abs(Math.sin(t * (1 + rnd(i + 5) * 2) + i));
        return (
          <div key={i} style={{ position: "absolute", left: x, top: y, width: s, height: s, borderRadius: 99, background: i % 3 ? C.gold2 : "#CFE0FF", opacity: 0.35 * tw * z, boxShadow: `0 0 ${s * 3}px ${i % 3 ? C.gold : C.blue2}` }} />
        );
      })}
    </AbsoluteFill>
  );
};

/** Film grain + vignette over everything. */
export const Finish: React.FC = () => {
  const t = useT();
  const i = Math.floor(t * 24) % 4;
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <AbsoluteFill style={{ backgroundImage: `url(${staticFile(`grain${i}.png`)})`, backgroundSize: "384px 384px", opacity: 0.07, mixBlendMode: "overlay" }} />
      <AbsoluteFill style={{ background: "radial-gradient(120% 85% at 50% 45%, transparent 55%, rgba(0,0,0,.55) 100%)" }} />
    </AbsoluteFill>
  );
};

/** Full-frame flash peaking at `at`. */
export const Flash: React.FC<{ at: number; dur?: number; color?: string; max?: number }> = ({ at, dur = 0.35, color = "#fff", max = 1 }) => {
  const t = useT();
  const o = interpolate(t, [at - 0.04, at, at + dur], [0, max, 0], clamp);
  if (o <= 0) return null;
  return <AbsoluteFill style={{ background: color, opacity: o, pointerEvents: "none" }} />;
};

/** A diagonal light sweep across the frame (used on cuts). */
export const Sweep: React.FC<{ at: number; dur?: number; color?: string }> = ({ at, dur = 0.5, color = "rgba(255,226,160,.55)" }) => {
  const t = useT();
  const k = p(t, at, at + dur, (x) => x);
  if (k <= 0 || k >= 1) return null;
  return (
    <AbsoluteFill style={{ overflow: "hidden", pointerEvents: "none", mixBlendMode: "screen" }}>
      <div style={{ position: "absolute", top: "-30%", height: "160%", width: "45%", left: `${lerp(-60, 120, k)}%`, transform: "rotate(18deg)", background: `linear-gradient(90deg, transparent, ${color}, transparent)` }} />
    </AbsoluteFill>
  );
};

export const SCREEN = { w: 1170, h: 2532 };

/**
 * A modern phone in 3D: titanium frame with depth, black bezel, camera island, moving glass glare and a floor shadow.
 * Children are drawn over the screen in the screenshot's own pixel space (1170 × 2532).
 */
export const Phone: React.FC<{
  src?: string; width?: number; x: number; y: number; rx?: number; ry?: number; rz?: number; scale?: number; z?: number;
  opacity?: number; shadow?: boolean; children?: React.ReactNode; screenBg?: string;
}> = ({ src, width = 640, x, y, rx = 0, ry = 0, rz = 0, scale = 1, z = 0, opacity = 1, shadow = true, children, screenBg = "#000" }) => {
  const pad = width * 0.034;
  const sw = width - pad * 2;
  const sh = (sw * SCREEN.h) / SCREEN.w;
  const H = sh + pad * 2;
  const R = width * 0.15;
  const k = sw / SCREEN.w;
  const glare = Math.max(-1, Math.min(1, ry / 35));
  return (
    <div style={{ position: "absolute", left: x, top: y, width: 0, height: 0, perspective: 2400, opacity }}>
      <div style={{ position: "absolute", left: -width / 2, top: -H / 2, width, height: H, transformStyle: "preserve-3d", transform: `translateZ(${z}px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg) scale(${scale})` }}>
        {shadow && (
          <div style={{ position: "absolute", left: "8%", right: "8%", bottom: -H * 0.06, height: H * 0.08, borderRadius: "50%", background: "radial-gradient(closest-side, rgba(0,0,0,.6), transparent)", transform: `translateZ(-60px) translateX(${-ry * 2}px)`, filter: "blur(6px)" }} />
        )}
        {/* depth layers give the frame thickness when it turns */}
        {[18, 12, 6].map((d) => (
          <div key={d} style={{ position: "absolute", inset: 0, borderRadius: R, background: "#151c29", transform: `translateZ(${-d}px)` }} />
        ))}
        <div
          style={{
            position: "absolute", inset: 0, borderRadius: R, padding: pad,
            background: "linear-gradient(145deg,#8a96aa 0%,#2a3446 18%,#0b111d 50%,#2a3446 80%,#9aa6ba 100%)",
            boxShadow: "inset 0 0 0 2px rgba(255,255,255,.12), inset 0 3px 2px rgba(255,255,255,.35), 0 60px 120px -40px rgba(0,0,0,.8)",
          }}
        >
          <div style={{ position: "relative", width: sw, height: sh, borderRadius: R - pad, overflow: "hidden", background: screenBg }}>
            <div style={{ position: "absolute", left: 0, top: 0, width: SCREEN.w, height: SCREEN.h, transform: `scale(${k})`, transformOrigin: "0 0" }}>
              {src && <Img src={staticFile(src)} style={{ position: "absolute", inset: 0, width: SCREEN.w, height: SCREEN.h }} />}
              {children}
            </div>
            <div style={{ position: "absolute", left: "50%", top: sw * 0.03, width: sw * 0.3, height: sw * 0.085, marginLeft: -sw * 0.15, borderRadius: 99, background: "#000" }} />
            <div style={{ position: "absolute", inset: "-20% -60%", background: "linear-gradient(115deg, transparent 38%, rgba(255,255,255,.16) 46%, rgba(255,255,255,.04) 52%, transparent 60%)", transform: `translateX(${glare * 30}%)`, pointerEvents: "none" }} />
          </div>
        </div>
      </div>
    </div>
  );
};

/** Words that rise into place when the voice says them. `hl` words go gold. */
export const Words: React.FC<{
  words: { w: string; at: number; hl?: boolean; br?: boolean }[]; size?: number; color?: string; weight?: number; align?: "center" | "left";
  x?: number; y: number; width?: number; out?: number; lineHeight?: number; font?: string; tracking?: number;
}> = ({ words, size = 92, color = "#fff", weight = 800, align = "center", x = 0, y, width = 1080, out, lineHeight = 1.04, font = FONT, tracking = -2 }) => {
  const t = useT();
  const fade = out === undefined ? 1 : interpolate(t, [out, out + 0.18], [1, 0], clamp);
  const lift = out === undefined ? 0 : interpolate(t, [out, out + 0.18], [0, -40], clamp);
  return (
    <div style={{ position: "absolute", left: x, top: y, width, textAlign: align, fontFamily: font, fontWeight: weight, fontSize: size, lineHeight, letterSpacing: tracking, color, opacity: fade, transform: `translateY(${lift}px)`, padding: "0 60px" }}>
      {words.map((w, i) => {
        const k = spr(t, w.at, { damping: 15, stiffness: 170 });
        const o = p(t, w.at, w.at + 0.12);
        return (
          <React.Fragment key={i}>
            <span style={{ display: "inline-block", overflow: "hidden", verticalAlign: "top", padding: "0.06em 0.02em 0.12em" }}>
              <span style={{ display: "inline-block", transform: `translateY(${(1 - k) * 85}%) rotate(${(1 - k) * 6}deg)`, opacity: o, filter: `blur(${(1 - o) * 10}px)`, color: w.hl ? C.gold : undefined, textShadow: w.hl ? "0 0 40px rgba(242,178,51,.45)" : "0 8px 30px rgba(0,0,0,.35)" }}>
                {w.w}
              </span>
            </span>
            {w.br ? <br /> : " "}
          </React.Fragment>
        );
      })}
    </div>
  );
};

/** Small pill label ("LIVE", "AI TUTOR", ...). */
export const Chip: React.FC<{ children: React.ReactNode; x: number; y: number; at: number; bg?: string; color?: string; size?: number; center?: boolean }> = ({ children, x, y, at, bg = "rgba(255,255,255,.1)", color = C.gold, size = 30, center = true }) => {
  const t = useT();
  const k = spr(t, at, { damping: 12, stiffness: 200 });
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(${center ? "-50%" : "0"}, 0) scale(${k})`, opacity: Math.min(1, k * 1.5), background: bg, color, fontFamily: FONT, fontWeight: 800, fontSize: size, letterSpacing: 3, padding: `${size * 0.4}px ${size * 0.9}px`, borderRadius: 999, border: "1.5px solid rgba(255,255,255,.14)", whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: size * 0.4 }}>
      {children}
    </div>
  );
};

/** Expanding ring (tap or shockwave). */
export const Ring: React.FC<{ x: number; y: number; at: number; size?: number; color?: string; dur?: number; width?: number }> = ({ x, y, at, size = 220, color = C.gold, dur = 0.6, width = 8 }) => {
  const t = useT();
  const k = p(t, at, at + dur);
  if (t < at || k >= 1) return null;
  return <div style={{ position: "absolute", left: x - (size * k) / 2, top: y - (size * k) / 2, width: size * k, height: size * k, borderRadius: "50%", border: `${width * (1 - k) + 1}px solid ${color}`, opacity: 1 - k }} />;
};

/** A glassy floating card. */
export const Glass: React.FC<{ x: number; y: number; w: number; at: number; children: React.ReactNode; rz?: number; from?: "left" | "right" | "up" | "down"; out?: number; light?: boolean }> = ({ x, y, w, at, children, rz = 0, from = "up", out, light = false }) => {
  const t = useT();
  const k = spr(t, at, { damping: 13, stiffness: 150 });
  const o = Math.min(1, k * 1.4) * (out === undefined ? 1 : interpolate(t, [out, out + 0.2], [1, 0], clamp));
  const d = (1 - k) * 160;
  const tx = from === "left" ? -d : from === "right" ? d : 0, ty = from === "up" ? d * 0.6 : from === "down" ? -d * 0.6 : 0;
  const bob = Math.sin((t - at) * 2.2) * 8;
  return (
    <div style={{ position: "absolute", left: x, top: y, width: w, transform: `translate(${tx}px, ${ty + bob}px) rotate(${rz}deg) scale(${0.85 + 0.15 * k})`, opacity: o, background: light ? "rgba(255,255,255,.96)" : "linear-gradient(160deg, rgba(30,58,110,.92), rgba(11,31,68,.92))", border: light ? "none" : "1.5px solid rgba(255,255,255,.14)", borderRadius: 34, padding: 30, boxShadow: "0 40px 80px -30px rgba(0,0,0,.7), inset 0 1px 0 rgba(255,255,255,.12)", fontFamily: FONT, color: light ? C.navy : "#fff" }}>
      {children}
    </div>
  );
};

/** A gold naira coin seen spinning in 3D. */
export const Coin: React.FC<{ x: number; y: number; size: number; spin: number; rot?: number; blur?: number }> = ({ x, y, size, spin, rot = 0, blur = 0 }) => {
  const sx = Math.cos(spin);
  const face = sx >= 0;
  return (
    <div style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size, transform: `rotate(${rot}deg) scaleX(${Math.max(0.08, Math.abs(sx))})`, filter: blur ? `blur(${blur}px)` : undefined }}>
      <div style={{ width: "100%", height: "100%", borderRadius: "50%", background: face ? "radial-gradient(circle at 35% 30%, #FFF1C4 0%, #FFD27A 25%, #F2B233 55%, #B97A0E 100%)" : "radial-gradient(circle at 60% 40%, #FFE29A, #D99A1E 60%, #8E5C08)", boxShadow: `inset 0 0 0 ${size * 0.06}px rgba(140,90,10,.55), inset 0 0 0 ${size * 0.1}px rgba(255,236,170,.6), 0 ${size * 0.08}px ${size * 0.2}px rgba(0,0,0,.35)`, display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: size * 0.5, color: "rgba(122,74,4,.85)" }}>
        {face ? "₦" : ""}
      </div>
    </div>
  );
};

/** Coins burst up from a point and fall with gravity. */
export const CoinBurst: React.FC<{ at: number; x: number; y: number; n?: number; spread?: number }> = ({ at, x, y, n = 40, spread = 1 }) => {
  const t = useT();
  const d = t - at;
  if (d < 0 || d > 3.2) return null;
  return (
    <>
      {Array.from({ length: n }).map((_, i) => {
        const delay = rnd(i + 3) * 0.5;
        const dd = d - delay;
        if (dd < 0) return null;
        const vx = (rnd(i) - 0.5) * 1500 * spread, vy = -900 - rnd(i + 7) * 1300;
        const px = x + vx * dd, py = y + vy * dd + 0.5 * 2600 * dd * dd;
        const size = 60 + rnd(i + 9) * 70;
        return <Coin key={i} x={px} y={py} size={size} spin={dd * (8 + rnd(i + 1) * 10) + i} rot={(rnd(i + 2) - 0.5) * 40} blur={Math.min(4, Math.abs(vy + 2600 * dd) / 900)} />;
      })}
    </>
  );
};

/** Coins raining from the top. */
export const CoinRain: React.FC<{ from: number; to: number; n?: number }> = ({ from, to, n = 34 }) => {
  const t = useT();
  const { width, height } = useVideoConfig();
  if (t < from || t > to + 2) return null;
  return (
    <>
      {Array.from({ length: n }).map((_, i) => {
        const start = from + rnd(i + 40) * (to - from);
        const d = t - start;
        if (d < 0) return null;
        const size = 50 + rnd(i + 41) * 90;
        const py = -150 + d * (900 + size * 6);
        if (py > height + 200) return null;
        const px = rnd(i + 42) * width + Math.sin(d * 3 + i) * 30;
        return <Coin key={i} x={px} y={py} size={size} spin={d * (6 + rnd(i) * 6) + i} rot={(rnd(i + 43) - 0.5) * 60} blur={size < 70 ? 2 : 0} />;
      })}
    </>
  );
};

/** Confetti burst. */
export const Confetti: React.FC<{ at: number; x: number; y: number; n?: number; power?: number }> = ({ at, x, y, n = 80, power = 1 }) => {
  const t = useT();
  const d = t - at;
  if (d < 0 || d > 3) return null;
  const cols = [C.gold, "#fff", C.blue2, "#FF6B6B", "#3DDC97", C.gold2];
  return (
    <>
      {Array.from({ length: n }).map((_, i) => {
        const ang = rnd(i) * Math.PI * 2;
        const v = (700 + rnd(i + 5) * 1100) * power;
        const drag = (1 - Math.exp(-d * 2.2)) / 2.2;
        const px = x + Math.cos(ang) * v * drag + Math.sin(d * 4 + i) * 20 * d;
        const py = y + Math.sin(ang) * v * drag + 380 * d * d;
        const w = 14 + rnd(i + 8) * 14, h = w * (0.4 + rnd(i + 9) * 0.5);
        return <div key={i} style={{ position: "absolute", left: px, top: py, width: w, height: h, background: cols[i % cols.length], borderRadius: i % 4 === 0 ? 99 : 3, transform: `rotate(${d * 600 * (rnd(i + 3) - 0.5) + i * 30}deg) scaleY(${Math.cos(d * 9 + i)})`, opacity: interpolate(d, [2, 3], [1, 0], clamp) }} />;
      })}
    </>
  );
};

/** Sparkle star. */
export const Sparkle: React.FC<{ x: number; y: number; at: number; size?: number; color?: string }> = ({ x, y, at, size = 60, color = "#fff" }) => {
  const t = useT();
  const k = interpolate(t, [at, at + 0.25, at + 0.7], [0, 1, 0], clamp);
  if (k <= 0) return null;
  return (
    <svg style={{ position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size, transform: `scale(${k}) rotate(${(t - at) * 120}deg)`, filter: `drop-shadow(0 0 12px ${C.gold})` }} viewBox="-10 -10 20 20">
      <path d="M0 -10 L2 -2 L10 0 L2 2 L0 10 L-2 2 L-10 0 L-2 -2 Z" fill={color} />
    </svg>
  );
};

export const easeK = easeOut;
