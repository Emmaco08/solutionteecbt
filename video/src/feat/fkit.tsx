import React from "react";
import { AbsoluteFill, interpolate } from "remotion";
import { C, FONT, Grain, SERIF, clamp, easeInOut, easeOut, lerp, p, rnd, spr, typed, useF, useS } from "../pack/kit";

// Feature ads kit (D-183): pieces shared by the six one-feature ads, on top of the pack kit (D-182).

export const GAME = "'Lilita One', 'Plus Jakarta Sans', sans-serif";

/** A scene that blurs and zooms in at [a] and out at [b]. */
export const Shot: React.FC<{ a: number; b: number; children: React.ReactNode; zin?: number; zout?: number; first?: boolean; last?: boolean }> = ({ a, b, children, zin = 1.08, zout = 0.94, first, last }) => {
  const t = useS();
  if (t < a - 0.02 || t > b + 0.02) return null;
  const ki = first ? 1 : p(t, a, a + 0.3);
  const ko = last ? 0 : p(t, b - 0.26, b, easeInOut);
  const s = lerp(zin, 1, ki) * lerp(1, zout, ko);
  const blur = (1 - ki) * 14 + ko * 14;
  return <AbsoluteFill style={{ opacity: Math.min(ki * 1.6, 1) * (1 - ko), transform: `scale(${s})`, filter: blur > 0.3 ? `blur(${blur}px)` : undefined }}>{children}</AbsoluteFill>;
};

/** Dark stage with two drifting glows in the given colours, dust and grain. */
export const DeepStage: React.FC<{ base?: string; a?: string; b?: string; dust?: string }> = ({ base = "#050B1C", a = "rgba(37,99,179,.55)", b = "rgba(120,80,220,.30)", dust = "#9CC0FF" }) => {
  const t = useS();
  const F = useF();
  return (
    <AbsoluteFill style={{ background: base }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W * 1.2}px ${F.H * 0.55}px at ${50 + Math.sin(t * 0.4) * 16}% ${30 + Math.cos(t * 0.3) * 8}%, ${a}, transparent 70%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse ${F.W}px ${F.H * 0.45}px at ${30 + Math.cos(t * 0.35) * 14}% 85%, ${b}, transparent 70%)` }} />
      {Array.from({ length: 36 }).map((_, i) => {
        const x = rnd(i) * F.W, y0 = rnd(i + 40) * F.H;
        const yy = (y0 - t * (10 + rnd(i + 3) * 26) + F.H * 4) % F.H;
        const s = 2 + rnd(i + 7) * 3.5;
        return <div key={i} style={{ position: "absolute", left: x, top: yy, width: s, height: s, borderRadius: 9, background: dust, opacity: 0.12 + rnd(i + 9) * 0.35 }} />;
      })}
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 45%, transparent 50%, rgba(0,0,0,.55))" }} />
      <Grain strength={0.08} />
    </AbsoluteFill>
  );
};

/** Stadium purple with turning light beams (Game Zone). */
export const ArenaStage: React.FC = () => {
  const t = useS();
  const F = useF();
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg,#1A0F4A 0%,#2B1572 45%,#12093A 100%)" }}>
      {[0, 1, 2, 3].map((i) => {
        const ang = Math.sin(t * 0.7 + i * 1.7) * 22 + (i - 1.5) * 18;
        return <div key={i} style={{ position: "absolute", left: F.cx - 160, top: -200, width: 320, height: F.H * 1.4, transformOrigin: "50% 0", transform: `rotate(${ang}deg)`, background: `linear-gradient(180deg, rgba(${i % 2 ? "255,214,90" : "120,180,255"},.22), transparent 75%)`, filter: "blur(18px)" }} />;
      })}
      {Array.from({ length: 40 }).map((_, i) => {
        const tw = 0.4 + 0.6 * Math.abs(Math.sin(t * (1 + rnd(i) * 2) + i));
        return <div key={i} style={{ position: "absolute", left: rnd(i) * F.W, top: rnd(i + 9) * F.H * 0.7, width: 4, height: 4, borderRadius: 9, background: "#fff", opacity: tw * 0.6 }} />;
      })}
      <div style={{ position: "absolute", left: -F.W * 0.2, right: -F.W * 0.2, bottom: -F.H * 0.12, height: F.H * 0.32, borderRadius: "50%", background: "radial-gradient(ellipse at 50% 0%, rgba(255,214,90,.25), rgba(43,21,114,0) 70%)" }} />
      <Grain strength={0.07} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------------------------------------ icons

const PATHS: Record<string, string> = {
  camera: "M4 8h3l2-3h6l2 3h3v11H4z M12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
  wifiOff: "M2 2l20 20 M8.5 16.5a5 5 0 0 1 7 0 M5 12.5a10 10 0 0 1 4.5-2.6 M19 12.5a10 10 0 0 0-3-2 M1.5 8.6a15 15 0 0 1 4.6-2.8 M22.5 8.6A15 15 0 0 0 11 5 M12 20h.01",
  plane: "M2 16l8-3V6a2 2 0 0 1 4 0v7l8 3v2l-8-2v3l3 2v1l-5-1-5 1v-1l3-2v-3l-8 2z",
  bell: "M6 16V11a6 6 0 0 1 12 0v5l2 2H4z M10 20a2 2 0 0 0 4 0",
  check: "M5 12.5l4.5 4.5L19 7.5",
  cloud: "M7 18a5 5 0 0 1-.5-10 6 6 0 0 1 11.3 1.5A4.3 4.3 0 0 1 17 18z M9 13l2.2 2.2L15.5 11",
  download: "M12 4v11 M7 10l5 5 5-5 M5 20h14",
  bolt: "M13 2L4 14h7l-1 8 9-12h-7z",
  moon: "M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z",
  trophy: "M7 4h10v4a5 5 0 0 1-10 0z M7 6H4a3 3 0 0 0 3 4 M17 6h3a3 3 0 0 1-3 4 M12 13v4 M8 21h8 M9 17h6v4H9z",
  fire: "M12 2c1 4 6 6 6 12a6 6 0 0 1-12 0c0-3 2-5 3-6 0 3 2 4 3 4-1-4 0-7 0-10z",
  shield: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z M8.5 12l2.5 2.5 4.5-4.5",
  play: "M8 5v14l11-7z",
  chat: "M4 5h16v11H9l-5 4z",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 7v5l3 2",
  sparkle: "M12 2l2 7 7 3-7 3-2 7-2-7-7-3 7-3z",
  video: "M3 6h12v12H3z M15 10l6-3v10l-6-3z",
  book: "M4 4h7a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H4z M20 4h-4a2 2 0 0 0-2 2v14a2 2 0 0 1 2-2h4z",
  calc: "M6 2h12v20H6z M9 6h6 M9 11h.01 M12 11h.01 M15 11h.01 M9 15h.01 M12 15h.01 M15 15h.01 M9 19h6",
  grid: "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z",
  flag: "M5 21V4 M5 4h12l-2 4 2 4H5",
  timer: "M12 22a8 8 0 1 0 0-16 8 8 0 0 0 0 16z M12 10v4l2 2 M10 2h4",
  arrowUp: "M12 19V5 M5 12l7-7 7 7",
  pin: "M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11z M12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z",
};
export const Ico: React.FC<{ n: keyof typeof PATHS | string; size?: number; color?: string; stroke?: number; fill?: string }> = ({ n, size = 40, color = "#fff", stroke = 2, fill = "none" }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
    <path d={PATHS[n]} stroke={color} strokeWidth={stroke} fill={fill} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

// ------------------------------------------------------------------------------------------------ pieces

/** A rounded label that pops in. */
export const Pill: React.FC<{ x: number; y: number; at: number; out?: number; bg?: string; fg?: string; size?: number; icon?: string; children: React.ReactNode; bob?: boolean; anchor?: "center" | "left" | "right" }> = ({ x, y, at, out, bg = "#fff", fg = C.navy, size = 38, icon, children, bob = true, anchor = "center" }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 11, stiffness: 170 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.22);
  if (k <= 0.001 || o <= 0) return null;
  const s = size * F.ks;
  const tx = anchor === "center" ? "-50%" : anchor === "left" ? "0%" : "-100%";
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(${tx},-50%) scale(${k}) translateY(${bob ? Math.sin(t * 2.2 + x * 0.01) * 6 : 0}px)`, transformOrigin: anchor === "left" ? "0 50%" : anchor === "right" ? "100% 50%" : "50% 50%", opacity: o, display: "flex", alignItems: "center", gap: s * 0.35, padding: `${s * 0.42}px ${s * 0.75}px`, borderRadius: 999, background: bg, color: fg, fontFamily: FONT, fontWeight: 800, fontSize: s, whiteSpace: "nowrap", boxShadow: "0 22px 44px -16px rgba(0,0,0,.55)" }}>
      {icon && <Ico n={icon} size={s * 1.15} color={fg} stroke={2.4} />}
      {children}
    </div>
  );
};

/** A label joined to a point by a line that draws itself (pointing at parts of a screen). */
export const Callout: React.FC<{ at: number; out?: number; from: [number, number]; to: [number, number]; label: string; icon?: string; dark?: boolean; size?: number }> = ({ at, out, from, to, label, icon, dark, size = 32 }) => {
  const t = useS();
  const F = useF();
  const k = p(t, at, at + 0.35, easeOut);
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.22);
  if (k <= 0 || o <= 0) return null;
  const [x0, y0] = from, [x1, y1] = to;
  const len = Math.hypot(x1 - x0, y1 - y0);
  const left = x1 < x0;
  const col = dark ? "#fff" : C.navy;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: o }}>
      <svg width={F.W} height={F.H} style={{ position: "absolute", inset: 0 }}>
        <line x1={x0} y1={y0} x2={x1} y2={y1} stroke={col} strokeWidth={3} strokeDasharray={`${len}`} strokeDashoffset={len * (1 - k)} strokeLinecap="round" />
        <circle cx={x0} cy={y0} r={10 * spr(t, at, { damping: 9 })} fill={C.gold} stroke={col} strokeWidth={3} />
      </svg>
      <Pill x={x1} y={y1} at={at + 0.25} bg={dark ? "#fff" : C.navy} fg={dark ? C.navy : "#fff"} size={size} icon={icon} anchor={left ? "right" : "left"} bob={false}>{label}</Pill>
    </div>
  );
};

/** A chat bubble (me: right, blue; ai: left, white or navy) that pops up. */
export const Bubble: React.FC<{ at: number; me?: boolean; x: number; y: number; w: number; children: React.ReactNode; dark?: boolean; out?: number }> = ({ at, me, x, y, w, children, dark, out }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 13, stiffness: 170 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.2);
  if (k <= 0.001 || o <= 0) return null;
  const bg = me ? C.blue : dark ? "#13224A" : "#fff";
  const fg = me || dark ? "#fff" : C.navy;
  return (
    <div style={{ position: "absolute", left: me ? x + w * 0.18 : x, top: y, width: w * 0.82, transform: `scale(${lerp(0.7, 1, k)})`, transformOrigin: me ? "100% 100%" : "0% 100%", opacity: o * Math.min(1, k * 2) }}>
      <div style={{ background: bg, color: fg, borderRadius: 34, borderBottomRightRadius: me ? 8 : 34, borderBottomLeftRadius: me ? 34 : 8, padding: `${26 * F.ks}px ${32 * F.ks}px`, fontFamily: FONT, fontWeight: 600, fontSize: 36 * F.ks, lineHeight: 1.35, boxShadow: "0 24px 50px -24px rgba(0,0,0,.6)", border: dark && !me ? "1.5px solid rgba(255,255,255,.12)" : undefined }}>
        {children}
      </div>
    </div>
  );
};

/** A phone notification that drops in from the top. */
export const Notif: React.FC<{ at: number; out?: number; y: number; title: string; body: string; icon?: string; tint?: string }> = ({ at, out, y, title, body, icon = "bell", tint = C.gold }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 14, stiffness: 140 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  if (k <= 0.001 || o <= 0) return null;
  const w = 900 * F.ks;
  return (
    <div style={{ position: "absolute", left: F.cx - w / 2, top: y, width: w, transform: `translateY(${(1 - k) * -260}px)`, opacity: o }}>
      <div style={{ display: "flex", gap: 24, alignItems: "center", padding: `${26 * F.ks}px ${30 * F.ks}px`, borderRadius: 40, background: "rgba(255,255,255,.94)", boxShadow: "0 30px 60px -20px rgba(0,0,0,.6)" }}>
        <div style={{ width: 84 * F.ks, height: 84 * F.ks, borderRadius: 22, background: C.navy, display: "grid", placeItems: "center", flexShrink: 0 }}>
          <Ico n={icon} size={46 * F.ks} color={tint} stroke={2.2} />
        </div>
        <div style={{ flex: 1, fontFamily: FONT }}>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 26 * F.ks, fontWeight: 700, color: "#7B88A1" }}><span>SOLUTIONTEE CBT</span><span>now</span></div>
          <div style={{ fontSize: 36 * F.ks, fontWeight: 800, color: C.navy, marginTop: 4 }}>{title}</div>
          <div style={{ fontSize: 31 * F.ks, fontWeight: 600, color: "#55627A" }}>{body}</div>
        </div>
      </div>
    </div>
  );
};

/** A white card with score bars that fill. rows: [label, value, max]. */
export const Bars: React.FC<{ at: number; x: number; y: number; w: number; rows: [string, number, number][]; title?: string; dark?: boolean }> = ({ at, x, y, w, rows, title, dark }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 14 });
  const fg = dark ? "#fff" : C.navy;
  return (
    <div style={{ position: "absolute", left: x, top: y, width: w, transform: `translateY(${(1 - k) * 200}px)`, opacity: Math.min(1, k * 2) }}>
      <div style={{ background: dark ? "rgba(255,255,255,.08)" : "#fff", border: dark ? "1.5px solid rgba(255,255,255,.12)" : undefined, borderRadius: 40, padding: 44 * F.ks, boxShadow: "0 40px 80px -36px rgba(0,0,0,.5)", fontFamily: FONT }}>
        {title && <div style={{ fontWeight: 800, fontSize: 40 * F.ks, color: fg, marginBottom: 18 * F.ks }}>{title}</div>}
        {rows.map(([l, v, m], i) => {
          const f = p(t, at + 0.25 + i * 0.12, at + 0.9 + i * 0.12, easeOut);
          return (
            <div key={l} style={{ marginTop: 22 * F.ks }}>
              <div style={{ display: "flex", justifyContent: "space-between", fontWeight: 700, fontSize: 33 * F.ks, color: fg }}><span>{l}</span><span style={{ fontVariantNumeric: "tabular-nums" }}>{Math.round(v * f)}/{m}</span></div>
              <div style={{ height: 16 * F.ks, marginTop: 10 * F.ks, borderRadius: 99, background: dark ? "rgba(255,255,255,.12)" : "#E8EDF5", overflow: "hidden" }}>
                <div style={{ height: "100%", width: `${(v / m) * 100 * f}%`, borderRadius: 99, background: v / m >= 0.7 ? "#22C55E" : v / m >= 0.5 ? C.gold : "#E5484D" }} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

/** A big score ring that counts up to [value] out of [max]. */
export const ScoreRing: React.FC<{ at: number; dur?: number; x: number; y: number; r: number; value: number; max: number; dark?: boolean; label?: string }> = ({ at, dur = 1, x, y, r, value, max, dark, label }) => {
  const t = useS();
  const k = p(t, at, at + dur, easeOut);
  const v = Math.round(value * k);
  const L = 2 * Math.PI * r;
  const sw = r * 0.18;
  const pop = spr(t, at - 0.3, { damping: 13 });
  return (
    <div style={{ position: "absolute", left: x - r - sw, top: y - r - sw, width: (r + sw) * 2, height: (r + sw) * 2, transform: `scale(${pop})` }}>
      <svg width={(r + sw) * 2} height={(r + sw) * 2} viewBox={`${-r - sw} ${-r - sw} ${(r + sw) * 2} ${(r + sw) * 2}`} style={{ position: "absolute", inset: 0 }}>
        <circle r={r} fill={dark ? "#0E2148" : "#fff"} stroke={dark ? "rgba(255,255,255,.12)" : "#E8EDF5"} strokeWidth={sw} />
        <circle r={r} fill="none" stroke={C.gold} strokeWidth={sw} strokeLinecap="round" strokeDasharray={`${L * (v / max)} ${L}`} transform="rotate(-90)" />
      </svg>
      <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", fontFamily: FONT, color: dark ? "#fff" : C.navy }}>
        <div style={{ fontWeight: 800, fontSize: r * 0.62, lineHeight: 1, letterSpacing: "-0.04em", fontVariantNumeric: "tabular-nums" }}>{v}</div>
        <div style={{ fontWeight: 600, fontSize: r * 0.15, opacity: 0.75 }}>{label ?? `out of ${max}`}</div>
      </div>
    </div>
  );
};

/** A switch that flips on at [on]. */
export const Toggle: React.FC<{ x: number; y: number; at: number; on: number; label: string; icon?: string; w?: number }> = ({ x, y, at, on, label, icon, w = 860 }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 14 });
  const s = p(t, on, on + 0.22, easeInOut);
  const W = w * F.ks;
  return (
    <div style={{ position: "absolute", left: x - W / 2, top: y, width: W, transform: `translateY(-50%) scale(${lerp(0.85, 1, k)})`, opacity: Math.min(1, k * 2) }}>
      <div style={{ display: "flex", alignItems: "center", gap: 24, padding: `${28 * F.ks}px ${34 * F.ks}px`, borderRadius: 36, background: "#fff", boxShadow: "0 30px 60px -28px rgba(0,0,0,.5)" }}>
        {icon && (
          <div style={{ width: 76 * F.ks, height: 76 * F.ks, borderRadius: 22, background: s > 0.5 ? "#F2994A" : "#E8EDF5", display: "grid", placeItems: "center" }}>
            <Ico n={icon} size={44 * F.ks} color={s > 0.5 ? "#fff" : C.navy} stroke={2.2} />
          </div>
        )}
        <div style={{ flex: 1, fontFamily: FONT, fontWeight: 800, fontSize: 42 * F.ks, color: C.navy }}>{label}</div>
        <div style={{ width: 128 * F.ks, height: 74 * F.ks, borderRadius: 99, background: interpolate(s, [0, 1], [0, 1]) > 0.5 ? "#22C55E" : "#CBD3E1", position: "relative" }}>
          <div style={{ position: "absolute", top: 6 * F.ks, left: lerp(6, 60, s) * F.ks, width: 62 * F.ks, height: 62 * F.ks, borderRadius: 99, background: "#fff", boxShadow: "0 4px 10px rgba(0,0,0,.25)" }} />
        </div>
      </div>
    </div>
  );
};

/** A typed line with a caret while typing. */
export const TypeLine: React.FC<{ at: number; text: string; cps?: number; style?: React.CSSProperties }> = ({ at, text, cps = 26, style }) => {
  const t = useS();
  const s = typed(t, at, text, cps);
  const typing = t >= at && s.length < text.length;
  return (
    <span style={style}>
      {s}
      {typing && <span style={{ display: "inline-block", width: 4, height: "1em", marginLeft: 3, verticalAlign: "-0.1em", background: "currentColor", opacity: Math.floor(t * 3) % 2 ? 0.2 : 1 }} />}
    </span>
  );
};

/** Big digital timer counting down from [from] seconds at [rate]× speed, starting at [at]. */
export const BigTimer: React.FC<{ at: number; from: number; rate?: number; x: number; y: number; size: number; color?: string; warnBelow?: number }> = ({ at, from, rate = 1, x, y, size, color = "#fff", warnBelow = 10 }) => {
  const t = useS();
  const left = Math.max(0, Math.round(from - Math.max(0, t - at) * rate));
  const h = Math.floor(left / 3600), m = Math.floor((left % 3600) / 60), s = left % 60;
  const warn = left <= warnBelow;
  const pulse = warn ? 1 + Math.max(0, Math.sin(t * Math.PI * 4)) * 0.05 : 1;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${pulse})`, fontFamily: FONT, fontWeight: 800, fontSize: size, letterSpacing: "-0.03em", color: warn ? "#FF6B6B" : color, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap", textShadow: warn ? "0 0 40px rgba(255,80,80,.6)" : undefined }}>
      {h}:{String(m).padStart(2, "0")}:{String(s).padStart(2, "0")}
    </div>
  );
};

export { C, FONT, SERIF, clamp, easeInOut, easeOut, lerp, p, rnd, spr };
