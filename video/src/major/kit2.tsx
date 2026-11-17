import React from "react";
import { AbsoluteFill, Img, OffthreadVideo, Sequence, staticFile } from "remotion";
import { Phone } from "../components";
import { C, FONT, Grain, SERIF, clamp, easeInOut, easeOut, lerp, p, rnd, spr, useF, useS } from "../pack/kit";
import { interpolate } from "remotion";

// Motion kit for the two major adverts (D-183, plan docs/plans/advert-major.md). Built on the pack kit (D-182);
// every time is in seconds from the start of the composition.

export { C, FONT, SERIF, clamp, easeInOut, easeOut, lerp, p, rnd, spr, useF, useS };

/** Fade/scale/blur in at [a] and out at [b]: one shot of the ad. */
export const Shot: React.FC<{ a: number; b: number; children: React.ReactNode; zin?: number; zout?: number; first?: boolean; last?: boolean }> = ({ a, b, children, zin = 1.06, zout = 0.95, first, last }) => {
  const t = useS();
  if (t < a - 0.02 || t > b + 0.02) return null;
  const ki = first ? 1 : p(t, a, a + 0.3);
  const ko = last ? 0 : p(t, b - 0.26, b, easeInOut);
  const s = lerp(zin, 1, ki) * lerp(1, zout, ko);
  const blur = (1 - ki) * 12 + ko * 12;
  return <AbsoluteFill style={{ opacity: Math.min(ki * 1.6, 1) * (1 - ko), transform: `scale(${s})`, filter: blur > 0.3 ? `blur(${blur}px)` : undefined }}>{children}</AbsoluteFill>;
};

// ------------------------------------------------------------------------------------------------ stages

/** Clean white stage with soft brand glows (Gojek, Glovo, ClickUp). */
export const LightStage: React.FC<{ gold?: number; blue?: number; base?: string }> = ({ gold = 0.5, blue = 0.35, base = "#F8FAFE" }) => {
  const t = useS();
  const F = useF();
  return (
    <AbsoluteFill style={{ background: base }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 1.1}px ${F.H * 0.5}px at ${50 + Math.sin(t * 0.45) * 16}% ${70 + Math.cos(t * 0.35) * 8}%, rgba(242,178,51,${gold}), rgba(242,178,51,0) 70%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W}px ${F.H * 0.42}px at ${25 + Math.cos(t * 0.3) * 14}% ${18 + Math.sin(t * 0.4) * 8}%, rgba(37,99,179,${blue}), rgba(37,99,179,0) 70%)` }} />
      <Grain strength={0.05} />
    </AbsoluteFill>
  );
};

/** Navy stage with a gold glow from below (Spotify-style dark section, in our colours). */
export const NavyStage: React.FC<{ glow?: number }> = ({ glow = 1 }) => {
  const t = useS();
  const F = useF();
  return (
    <AbsoluteFill style={{ background: "#071530" }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 1.2}px ${F.H * 0.5}px at ${50 + Math.sin(t * 0.3) * 12}% 78%, rgba(242,178,51,${0.36 * glow}), transparent 72%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W}px ${F.H * 0.4}px at ${30 + Math.cos(t * 0.27) * 14}% 16%, rgba(37,99,179,${0.45 * glow}), transparent 70%)` }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, transparent 55%, rgba(0,0,0,.45))" }} />
      <Grain strength={0.08} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------------------------------------ type

/**
 * Letters that jump in one by one (the Bolt "Negotiating" move). Words between *stars* are drawn in [accent] and
 * bob a little higher. "/" starts a new line.
 */
export const BounceText: React.FC<{
  text: string; at: number; y: number; size?: number; color?: string; accent?: string; stagger?: number; out?: number;
  weight?: number; x?: number; width?: number; align?: "center" | "left"; shadow?: string; lh?: number;
}> = ({ text, at, y, size = 110, color = C.navy, accent = C.blue, stagger = 0.028, out, weight = 800, x, width, align = "center", shadow, lh = 1.04 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || (out !== undefined && t > out + 0.35)) return null;
  const fo = out === undefined ? 0 : p(t, out, out + 0.28, easeInOut);
  const lines = text.split(" / ");
  const w = width ?? F.W - 120;
  const left = x ?? (F.W - w) / 2;
  let n = 0;
  return (
    <div style={{ position: "absolute", left, top: y, width: w, transform: "translateY(-50%)", textAlign: align, fontFamily: FONT, fontWeight: weight, fontSize: size * F.ks, lineHeight: lh, letterSpacing: "-0.035em", color, opacity: 1 - fo, filter: fo > 0 ? `blur(${fo * 14}px)` : undefined }}>
      {lines.map((line, li) => {
        let acc = false;
        return (
          <div key={li} style={{ whiteSpace: "nowrap" }}>
            {[...line].map((ch, i) => {
              if (ch === "*") {
                acc = !acc;
                return null;
              }
              const a = at + n++ * stagger;
              const k = spr(t, a, { damping: 9, stiffness: 210, mass: 0.7 });
              const lift = acc ? Math.sin(Math.max(0, t - a) * 5) * 0.03 : 0;
              return (
                <span key={i} style={{ display: "inline-block", whiteSpace: "pre", color: acc ? accent : undefined, transform: `translateY(${(1 - k) * 0.7 + lift}em) scale(${lerp(0.4, 1, Math.min(k, 1.2))})`, opacity: Math.min(1, k * 2.2), textShadow: shadow }}>
                  {ch}
                </span>
              );
            })}
          </div>
        );
      })}
    </div>
  );
};

/** A word that slams in on a beat, with a small squash (No stress. / No guessing.). */
export const Slam: React.FC<{ text: string; at: number; y: number; size?: number; color?: string; accentFrom?: number; accent?: string; out?: number }> = ({ text, at, y, size = 150, color = C.navy, accentFrom, accent = C.blue, out }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.02 || (out !== undefined && t > out + 0.3)) return null;
  const k = spr(t, at, { damping: 10, stiffness: 260 });
  const fo = out === undefined ? 0 : p(t, out, out + 0.22);
  const words = text.split(" ");
  return (
    <div style={{ position: "absolute", left: 0, width: F.W, top: y, textAlign: "center", transform: `translateY(-50%) scale(${lerp(1.6, 1, Math.min(k, 1))}, ${lerp(0.6, 1, Math.min(k, 1))})`, opacity: Math.min(1, k * 3) * (1 - fo), fontFamily: FONT, fontWeight: 800, fontSize: size * F.ks, letterSpacing: "-0.04em", color }}>
      {words.map((w, i) => (
        <span key={i} style={{ color: accentFrom !== undefined && i >= accentFrom ? accent : undefined }}>
          {w}
          {i < words.length - 1 ? " " : ""}
        </span>
      ))}
    </div>
  );
};

/** A rounded pill tag (Pizza Hut / Gojek labels). */
export const Tag: React.FC<{ text: string; x: number; y: number; at: number; out?: number; bg?: string; color?: string; size?: number; icon?: React.ReactNode }> = ({ text, x, y, at, out, bg = C.navy, color = "#fff", size = 40, icon }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 12, stiffness: 190 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.2);
  if (k <= 0.001 || o <= 0) return null;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${k})`, opacity: o }}>
      <div style={{ display: "flex", alignItems: "center", gap: 14 * F.ks, whiteSpace: "nowrap", padding: `${18 * F.ks}px ${34 * F.ks}px`, borderRadius: 999, background: bg, color, fontFamily: FONT, fontWeight: 800, fontSize: size * F.ks, boxShadow: "0 24px 50px -22px rgba(11,31,68,.55)" }}>
        {icon}
        {text}
      </div>
    </div>
  );
};

// ------------------------------------------------------------------------------------------------ media

/**
 * A rounded footage card (the Bolt cards): a Flow clip (.mp4) or still (.jpg), popping in with a tilt, a slow push-in,
 * and an optional bold caption in its lower-left corner.
 */
export const Footage: React.FC<{
  src: string; at: number; out: number; x: number; y: number; w: number; h: number; from?: number; radius?: number;
  tilt?: number; caption?: string; captionSize?: number; push?: number; border?: boolean; rate?: number; dim?: number;
}> = ({ src, at, out, x, y, w, h, from = 0, radius = 56, tilt = -3, caption, captionSize = 64, push = 0.08, border = true, rate = 1, dim = 0 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || t > out + 0.4) return null;
  const k = spr(t, at, { damping: 13, stiffness: 120 });
  const ko = p(t, out, out + 0.32, easeInOut);
  const z = 1 + push * p(t, at, out, (v) => v);
  const isVideo = src.endsWith(".mp4");
  return (
    <div style={{ position: "absolute", left: x - w / 2, top: y - h / 2, width: w, height: h, transform: `translateY(${(1 - k) * 260}px) rotate(${tilt * (1 - k) * 2 + tilt * 0.4}deg) scale(${lerp(0.7, 1, Math.min(k, 1)) * lerp(1, 0.85, ko)})`, opacity: Math.min(1, k * 2) * (1 - ko), borderRadius: radius * F.ks, overflow: "hidden", boxShadow: "0 60px 120px -50px rgba(11,31,68,.75)", border: border ? `${10 * F.ks}px solid #fff` : undefined, background: "#0B1F44" }}>
      <div style={{ position: "absolute", inset: 0, transform: `scale(${z})` }}>
        {isVideo ? (
          <Sequence from={Math.round((at - 0.05) * 30)} layout="none">
            <OffthreadVideo src={staticFile(src)} startFrom={Math.round(from * 30)} muted playbackRate={rate} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
          </Sequence>
        ) : (
          <Img src={staticFile(src)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        )}
      </div>
      {dim > 0 && <AbsoluteFill style={{ background: `rgba(0,0,0,${dim})` }} />}
      {caption && (
        <>
          <AbsoluteFill style={{ background: "linear-gradient(to top, rgba(6,19,43,.78), rgba(6,19,43,0) 45%)" }} />
          <BounceText text={caption} at={at + 0.35} y={h - 150 * F.ks} x={48 * F.ks} width={w - 96 * F.ks} align="left" size={captionSize} color="#fff" accent={C.gold} shadow="0 4px 20px rgba(0,0,0,.4)" />
        </>
      )}
    </div>
  );
};

/** A cut-out 3D character (transparent PNG) that pops in, bobs and can walk across. */
export const Cutout: React.FC<{
  src: string; at: number; out?: number; x: number; y: number; h: number; walk?: [number, number, number, number]; flip?: boolean; bob?: number; tilt?: number;
}> = ({ src, at, out, x, y, h, walk, flip, bob = 1, tilt = 0 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || (out !== undefined && t > out + 0.35)) return null;
  const k = spr(t, at, { damping: 11, stiffness: 170 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  let xx = x;
  let step = 0;
  if (walk) {
    const [a, b, x0, x1] = walk;
    xx = lerp(x0, x1, p(t, a, b, (v) => v));
    step = t >= a && t <= b ? Math.abs(Math.sin((t - a) * Math.PI * 3.2)) : 0;
  }
  const breathe = Math.sin((t - at) * 2.6) * 0.012 * bob;
  return (
    <div style={{ position: "absolute", left: xx, top: y, height: h * F.ks, transform: `translate(-50%, -100%) translateY(${-step * 18 * F.ks}px) rotate(${tilt + (walk ? Math.sin((t - at) * Math.PI * 3.2) * 1.6 : 0)}deg) scale(${(flip ? -1 : 1) * Math.min(k, 1.1)}, ${Math.min(k, 1.1) * (1 + breathe)})`, transformOrigin: "50% 100%", opacity: Math.min(1, k * 2) * o }}>
      <Img src={staticFile(src)} style={{ height: "100%", width: "auto", filter: "drop-shadow(0 30px 30px rgba(11,31,68,.28))" }} />
    </div>
  );
};

/** A real app screen inside the 3D phone, rising in and settling (Gojek / Glovo). */
export const PhoneIn: React.FC<{
  src: string; at: number; out?: number; x: number; y: number; w: number; from?: "below" | "blur" | "right" | "left"; rx?: number; ry?: number; rz?: number; children?: React.ReactNode; scale?: number;
}> = ({ src, at, out, x, y, w, from = "below", rx = 8, ry = -14, rz = 0, children, scale = 1 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || (out !== undefined && t > out + 0.4)) return null;
  const k = spr(t, at, { damping: 15, stiffness: 95 });
  const ko = out === undefined ? 0 : p(t, out, out + 0.32, easeInOut);
  const dx = from === "right" ? (1 - k) * F.W : from === "left" ? -(1 - k) * F.W : 0;
  const dy = from === "below" ? (1 - k) * F.H * 0.6 : 0;
  const blur = from === "blur" ? (1 - Math.min(k, 1)) * 30 : 0;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: (from === "blur" ? Math.min(1, k * 1.5) : 1) * (1 - ko), filter: blur + ko * 14 > 0.4 ? `blur(${blur + ko * 14}px)` : undefined }}>
      <Phone src={src} width={w * F.ks} x={x + dx} y={y + dy} rx={lerp(rx * 2.2, rx, k)} ry={lerp(ry * 2, ry, k) + Math.sin(t * 0.8) * 2} rz={lerp(rz - 6, rz, k)} scale={scale * lerp(1, 0.9, ko)}>
        {children}
      </Phone>
    </div>
  );
};

// ------------------------------------------------------------------------------------------------ props

/** The Uber Eats emoji pill: grows one emoji at a time. */
export const EmojiPill: React.FC<{ items: string[]; at: number; x: number; y: number; step?: number; size?: number; out?: number }> = ({ items, at, x, y, step = 0.18, size = 96, out }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || (out !== undefined && t > out + 0.3)) return null;
  const s = size * F.ks;
  const shown = items.filter((_, i) => t >= at + i * step).length;
  const k = spr(t, at, { damping: 13 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  const wTarget = s * 1.25 * Math.max(1, shown) + s * 0.6;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${k})`, opacity: o }}>
      <div style={{ height: s * 1.7, width: wTarget, borderRadius: 999, background: "#fff", boxShadow: "0 40px 80px -30px rgba(11,31,68,.45)", display: "flex", alignItems: "center", justifyContent: "center", gap: s * 0.25, transition: "none", overflow: "hidden" }}>
        {items.map((e, i) => {
          const ki = spr(t, at + i * step, { damping: 9, stiffness: 220 });
          if (ki <= 0.001) return null;
          return (
            <span key={i} style={{ fontSize: s, lineHeight: 1, display: "inline-block", transform: `scale(${ki}) rotate(${(1 - Math.min(ki, 1)) * 30}deg)`, fontFamily: "'Segoe UI Emoji','Apple Color Emoji','Noto Color Emoji',sans-serif" }}>
              {e}
            </span>
          );
        })}
      </div>
    </div>
  );
};

/** A card with a picture and a bold label (Bolt's "Heading to work" cards). */
export const LifeCard: React.FC<{ img: string; label: string; at: number; out: number; x: number; y: number; w: number; h: number; bg?: string; imgH?: number; imgY?: number }> = ({ img, label, at, out, x, y, w, h, bg = "#DCE8FA", imgH = 0.95, imgY = 0.04 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || t > out + 0.35) return null;
  const k = spr(t, at, { damping: 12, stiffness: 170 });
  const ko = p(t, out, out + 0.3, easeInOut);
  const W = w * F.ks, H = h * F.ks;
  return (
    <div style={{ position: "absolute", left: x - W / 2, top: y - H / 2, width: W, height: H, transform: `translateY(${(1 - k) * 160 - ko * 90}px) scale(${lerp(0.6, 1, Math.min(k, 1))}) rotate(${(1 - k) * -8}deg)`, opacity: Math.min(1, k * 2) * (1 - ko), borderRadius: 48 * F.ks, background: bg, overflow: "hidden", border: `${8 * F.ks}px solid #fff`, boxShadow: "0 40px 80px -36px rgba(11,31,68,.6)" }}>
      <Img src={staticFile(img)} style={{ position: "absolute", height: H * imgH, right: W * 0.04, top: H * imgY, width: "auto" }} />
      <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(11,31,68,.85), rgba(11,31,68,.2) 62%, rgba(11,31,68,0))" }} />
      <div style={{ position: "absolute", left: 40 * F.ks, bottom: 36 * F.ks, width: W * 0.62, fontFamily: FONT, fontWeight: 800, fontSize: 54 * F.ks, lineHeight: 1.02, letterSpacing: "-0.03em", color: "#fff" }}>{label}</div>
    </div>
  );
};

/** The navy hill the Bolt van rides over, rising from below. */
export const Hill: React.FC<{ at: number; out: number; color?: string; top?: number }> = ({ at, out, color = C.navy, top = 0.74 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || t > out + 0.4) return null;
  const k = spr(t, at, { damping: 16, stiffness: 80 });
  const ko = p(t, out, out + 0.35, easeInOut);
  const y0 = F.H * top;
  return (
    <svg style={{ position: "absolute", left: 0, top: 0, width: F.W, height: F.H, transform: `translateY(${(1 - k) * F.H * 0.4 + ko * F.H * 0.4}px)` }} viewBox={`0 0 ${F.W} ${F.H}`}>
      <path d={`M -40 ${y0 + 120} C ${F.W * 0.25} ${y0 - 70}, ${F.W * 0.75} ${y0 - 70}, ${F.W + 40} ${y0 + 120} L ${F.W + 40} ${F.H + 40} L -40 ${F.H + 40} Z`} fill={color} />
      <path d={`M -40 ${y0 + 150} C ${F.W * 0.25} ${y0 - 40}, ${F.W * 0.75} ${y0 - 40}, ${F.W + 40} ${y0 + 150}`} fill="none" stroke={C.gold} strokeWidth={10} strokeDasharray="34 26" opacity={0.85} />
    </svg>
  );
};

/** Height of the hill's top edge at x (matches <Hill top>), so characters stand on it. */
export const hillY = (F: { W: number; H: number }, x: number, top = 0.74) => {
  // cubic bezier from (−40, y0+120) via (W/4, y0−70), (3W/4, y0−70) to (W+40, y0+120); solve x→u by search
  const y0 = F.H * top;
  const P = [[-40, y0 + 120], [F.W * 0.25, y0 - 70], [F.W * 0.75, y0 - 70], [F.W + 40, y0 + 120]];
  const at = (u: number, i: 0 | 1) => (1 - u) ** 3 * P[0][i] + 3 * (1 - u) ** 2 * u * P[1][i] + 3 * (1 - u) * u * u * P[2][i] + u ** 3 * P[3][i];
  let lo = 0, hi = 1;
  for (let k = 0; k < 24; k++) {
    const m = (lo + hi) / 2;
    if (at(m, 0) < x) lo = m;
    else hi = m;
  }
  return at((lo + hi) / 2, 1);
};

/** A thick navy swoosh band that draws itself across the frame (Gojek). */
export const Swoosh: React.FC<{ at: number; out: number; color?: string; width?: number; d?: (W: number, H: number) => string }> = ({ at, out, color = C.navy, width = 260, d }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || t > out + 0.5) return null;
  const k = p(t, at, at + 0.7, easeOut);
  const ko = p(t, out, out + 0.45, easeInOut);
  const path = d ? d(F.W, F.H) : `M ${-0.2 * F.W} ${0.86 * F.H} C ${0.3 * F.W} ${0.55 * F.H}, ${0.55 * F.W} ${0.62 * F.H}, ${1.25 * F.W} ${0.18 * F.H}`;
  return (
    <svg style={{ position: "absolute", inset: 0, width: F.W, height: F.H }} viewBox={`0 0 ${F.W} ${F.H}`}>
      <path d={path} fill="none" stroke={color} strokeWidth={width * F.ks} strokeLinecap="round" pathLength={1} strokeDasharray="1 1" strokeDashoffset={1 - k + ko} />
    </svg>
  );
};

/** A gold ring with icons orbiting a centre (ClickUp). */
export const OrbitRing: React.FC<{ at: number; out?: number; x: number; y: number; r: number; icons: React.ReactNode[]; speed?: number }> = ({ at, out, x, y, r, icons, speed = 18 }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || (out !== undefined && t > out + 0.4)) return null;
  const k = spr(t, at, { damping: 15, stiffness: 90 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.3);
  const R = r * F.ks;
  const spin = (t - at) * speed;
  return (
    <div style={{ position: "absolute", left: x, top: y, opacity: o }}>
      <div style={{ position: "absolute", left: -R, top: -R, width: R * 2, height: R * 2, borderRadius: 9999, transform: `scale(${k}) rotate(${spin}deg)`, background: `conic-gradient(from 0deg, rgba(242,178,51,0), rgba(242,178,51,.9), rgba(75,134,212,.9), rgba(242,178,51,0) 70%)`, WebkitMask: `radial-gradient(circle, transparent ${R - 7}px, #000 ${R - 6}px, #000 ${R}px, transparent ${R + 1}px)`, mask: `radial-gradient(circle, transparent ${R - 7}px, #000 ${R - 6}px, #000 ${R}px, transparent ${R + 1}px)`, filter: "drop-shadow(0 0 18px rgba(242,178,51,.8))" }} />
      {icons.map((ic, i) => {
        const ang = ((i / icons.length) * 360 + spin * 0.6) * (Math.PI / 180);
        const ki = spr(t, at + 0.2 + i * 0.08, { damping: 11 });
        return (
          <div key={i} style={{ position: "absolute", left: Math.cos(ang) * R * k, top: Math.sin(ang) * R * k, transform: `translate(-50%,-50%) scale(${ki})` }}>
            {ic}
          </div>
        );
      })}
    </div>
  );
};

/** A round white sticker holding an icon, floating gently (Glovo). */
export const Sticker: React.FC<{ x: number; y: number; at: number; out?: number; size?: number; children: React.ReactNode; bg?: string; seed?: number }> = ({ x, y, at, out, size = 150, children, bg = "#fff", seed = 1 }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 10, stiffness: 170 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  if (k <= 0.001 || o <= 0) return null;
  const s = size * F.ks;
  const fx = Math.sin(t * 1.3 + seed * 2) * 14, fy = Math.cos(t * 1.1 + seed) * 18;
  return (
    <div style={{ position: "absolute", left: x + fx, top: y + fy, width: s, height: s, transform: `translate(-50%,-50%) scale(${k}) rotate(${Math.sin(t + seed) * 8}deg)`, opacity: o, borderRadius: s * 0.32, background: bg, boxShadow: "0 30px 60px -26px rgba(11,31,68,.55)", display: "grid", placeItems: "center" }}>
      {children}
    </div>
  );
};

/** A gold flood that fills the frame from a point (Gojek's green flood). */
export const Flood: React.FC<{ at: number; x: number; y: number; color?: string; out?: number }> = ({ at, x, y, color = C.gold, out }) => {
  const t = useS();
  const F = useF();
  if (t < at) return null;
  const k = p(t, at, at + 0.55, easeInOut);
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.3);
  const R = Math.hypot(F.W, F.H) * 1.1 * k;
  return <div style={{ position: "absolute", left: x - R, top: y - R, width: R * 2, height: R * 2, borderRadius: 9999, background: color, opacity: o }} />;
};

/** A pill button that is pressed, then turns into a round arrow (Gojek "Order now"). */
export const MorphButton: React.FC<{ text: string; at: number; press: number; x: number; y: number; out?: number }> = ({ text, at, press, x, y, out }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 12 });
  const m = p(t, press + 0.15, press + 0.55, easeInOut);
  const pr = t >= press && t < press + 0.18 ? 0.9 : 1;
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  if (k <= 0.001 || o <= 0) return null;
  const H = 150 * F.ks;
  const W = lerp(640 * F.ks, H, m);
  const slide = p(t, press + 0.55, press + 0.95, easeInOut);
  return (
    <div style={{ position: "absolute", left: x + slide * F.W * 0.7, top: y, transform: `translate(-50%,-50%) scale(${k * pr})`, opacity: o }}>
      <div style={{ width: W, height: H, borderRadius: 999, background: "#fff", display: "flex", alignItems: "center", justifyContent: "center", gap: 22 * F.ks, overflow: "hidden", boxShadow: "0 40px 80px -30px rgba(11,31,68,.6)" }}>
        <span style={{ fontFamily: FONT, fontWeight: 800, fontSize: 56 * F.ks, color: C.navy, whiteSpace: "nowrap", opacity: 1 - m, maxWidth: (1 - m) * 500 * F.ks, overflow: "hidden" }}>{text}</span>
        <div style={{ width: 92 * F.ks, height: 92 * F.ks, borderRadius: 999, background: C.navy, display: "grid", placeItems: "center", flex: "none", transform: `scale(${lerp(1, 1.3, m)})` }}>
          <svg width={50 * F.ks} height={50 * F.ks} viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" stroke="#fff" strokeWidth={2.8} fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </div>
      </div>
    </div>
  );
};

/** A gold dot that pulses, then grows (Spotify's dot → logo). */
export const PulseDot: React.FC<{ at: number; x: number; y: number; grow: number; out: number; color?: string }> = ({ at, x, y, grow, out, color = C.gold }) => {
  const t = useS();
  const F = useF();
  if (t < at || t > out + 0.2) return null;
  const k = spr(t, at, { damping: 9 });
  const g = p(t, grow, out, easeInOut);
  const r = (34 + Math.max(0, Math.sin((t - at) * 9)) * 6 + g * 300) * F.ks * k;
  return <div style={{ position: "absolute", left: x - r, top: y - r, width: r * 2, height: r * 2, borderRadius: 999, background: color, opacity: 1 - p(t, out - 0.15, out + 0.15), boxShadow: `0 0 ${60 * F.ks}px rgba(242,178,51,.8)` }} />;
};

export const fadeIn = (t: number, a: number, d = 0.25) => interpolate(t, [a, a + d], [0, 1], clamp);
