import React from "react";
import { AbsoluteFill, Audio, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { C, FONT, easeInOut, easeOut, lerp, p, spr } from "../lib";

// App tutorial videos (D-187): real Android screens from the app (test_shots/tutorial_test.dart), a finger that taps
// exactly where the student must tap, typing, slider drags, camera moves, captions, voice and music. 9:16 and 16:9.

type Rect = { x: number; y: number; w: number; h: number };
type Action = { frame: number; kind: "tap" | "type" | "drag" | "scroll" | "hold"; start: number; end: number; rect?: Rect; text?: string; dx?: number; dy?: number; next?: number; nav?: boolean };
type Chapter = { start: number; end: number; caption: string; say: string };
export type TutSpec = {
  name: string; title: string; kicker: string; duration: number;
  intro: { start: number; end: number; say: string }; outro: { start: number; end: number; say: string };
  chapters: Chapter[]; frames: string[]; actions: Action[]; cam: { t: number; z: number; x: number; y: number }[]; audio: string;
};

const SW = 1170, SH = 2532; // screenshot size
const ink = C.navy, blue = C.blue;

const useT = () => useCurrentFrame() / 30;
const useBox = () => {
  const { width: W, height: H } = useVideoConfig();
  const land = W > H;
  // the phone: screen size and where it sits
  const screenH = land ? 930 : 1330;
  const screenW = (screenH * SW) / SH;
  const bez = land ? 12 : 16;
  const pw = screenW + bez * 2, ph = screenH + bez * 2;
  const px = land ? 470 : W / 2, py = land ? H / 2 + 6 : 410 + ph / 2;
  return { W, H, land, screenW, screenH, bez, pw, ph, px, py, k: screenW / SW };
};

/** **bold** words in blue. */
const Rich: React.FC<{ text: string }> = ({ text }) => (
  <>
    {text.split(/(\*\*[^*]+\*\*)/).map((s, i) => (s.startsWith("**") ? <span key={i} style={{ color: blue }}>{s.slice(2, -2)}</span> : <span key={i}>{s}</span>))}
  </>
);

// ------------------------------------------------------------------ the phone and its screen

/** Which picture is on screen at time t, and the transition into the next one. */
const screenState = (spec: TutSpec, t: number) => {
  let cur = spec.actions[0]?.frame ?? 0;
  let tr: { from: number; to: number; k: number; nav: boolean; dy?: number } | null = null;
  let typing: { a: Action; k: number } | null = null;
  for (const a of spec.actions) {
    if (a.next === undefined) continue;
    const t0 = a.kind === "scroll" ? a.end : a.end - 0.35;
    if (t >= a.end) cur = a.next;
    else if (t >= t0) {
      cur = a.frame;
      tr = { from: a.frame, to: a.next, k: easeInOut(p(t, t0, a.end)), nav: !!a.nav };
    } else if (t >= a.start) {
      cur = a.frame;
      if (a.kind === "type" && a.text) typing = { a, k: p(t, a.start + 0.55, a.start + 0.55 + a.text.length * 0.055) };
      if (a.kind === "drag") tr = { from: a.frame, to: a.next, k: easeInOut(p(t, a.start + 0.35, a.start + 1.05)), nav: false };
      if (a.kind === "scroll") tr = { from: a.frame, to: a.next, k: easeInOut(p(t, a.start + 0.3, a.start + 1.0)), nav: false, dy: a.dy };
    }
    if (a.kind === "scroll" && t >= a.start + 1.0 && t < a.end) cur = a.next;
  }
  return { cur, tr, typing };
};

const Shot: React.FC<{ src: string; style?: React.CSSProperties }> = ({ src, style }) => (
  <Img src={staticFile(src)} style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH, ...style }} />
);

const StatusBar: React.FC = () => (
  <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: 96, display: "flex", alignItems: "center", padding: "0 60px", fontFamily: FONT, fontWeight: 700, fontSize: 40, color: "#1D2433" }}>
    <span>9:41</span>
    <div style={{ flex: 1 }} />
    <svg width={190} height={44} viewBox="0 0 190 44">
      <path d="M8 34 L8 26 M20 34 L20 20 M32 34 L32 13 M44 34 L44 6" stroke="#1D2433" strokeWidth={7} strokeLinecap="round" />
      <path d="M70 18 a26 26 0 0 1 38 0 M77 25 a16 16 0 0 1 24 0 M84 32 a6 6 0 0 1 10 0" stroke="#1D2433" strokeWidth={5.5} fill="none" strokeLinecap="round" />
      <rect x={124} y={9} width={52} height={26} rx={7} fill="none" stroke="#1D2433" strokeWidth={4} />
      <rect x={129} y={14} width={36} height={16} rx={3} fill="#1D2433" />
      <rect x={178} y={17} width={5} height={10} rx={2} fill="#1D2433" />
    </svg>
  </div>
);

const Phone: React.FC<{ spec: TutSpec; t: number }> = ({ spec, t }) => {
  const B = useBox();
  const { cur, tr, typing } = screenState(spec, t);
  const tapA = spec.actions.find((a) => (a.rect || a.kind === "scroll") && t >= a.start - 0.05 && t <= a.end);
  return (
    <div style={{ position: "absolute", left: B.px - B.pw / 2, top: B.py - B.ph / 2, width: B.pw, height: B.ph, borderRadius: B.pw * 0.11, background: "linear-gradient(145deg,#2A2F38,#0E1116 45%,#1B2028)", boxShadow: "0 50px 100px -40px rgba(11,31,68,.55), 0 0 0 2px #3A404C inset" }}>
      <div style={{ position: "absolute", left: B.bez, top: B.bez, width: B.screenW, height: B.screenH, borderRadius: B.pw * 0.09, overflow: "hidden", background: "#fff" }}>
        <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH, transform: `scale(${B.k})`, transformOrigin: "0 0" }}>
          {tr && tr.dy ? (
            <>
              {/* a real scroll: both pictures move together, so the content lines up the whole way */}
              <Shot src={spec.frames[tr.from]} style={{ transform: `translateY(${-tr.k * tr.dy}px)` }} />
              <Shot src={spec.frames[tr.to]} style={{ transform: `translateY(${(1 - tr.k) * tr.dy}px)`, opacity: p(tr.k, 0, 0.25) }} />
            </>
          ) : tr && tr.nav ? (
            <>
              <Shot src={spec.frames[tr.from]} style={{ transform: `translateX(${-tr.k * 30}%)`, filter: `brightness(${1 - tr.k * 0.12})` }} />
              <Shot src={spec.frames[tr.to]} style={{ transform: `translateX(${(1 - tr.k) * 100}%)`, boxShadow: "-30px 0 60px rgba(0,0,0,.18)" }} />
            </>
          ) : (
            <>
              <Shot src={spec.frames[cur]} />
              {tr && <Shot src={spec.frames[tr.to]} style={{ opacity: tr.k }} />}
            </>
          )}
          {/* typed text appears letter by letter: the next picture is revealed inside the field */}
          {typing && typing.a.rect && typing.a.next !== undefined && (
            <Shot src={spec.frames[typing.a.next]} style={{ clipPath: `inset(${typing.a.rect.y}px ${SW - (typing.a.rect.x + typing.a.rect.w * Math.min(1, 0.08 + typing.k * 0.95))}px ${SH - typing.a.rect.y - typing.a.rect.h}px ${typing.a.rect.x}px)` }} />
          )}
          {tapA && <Touch a={tapA} t={t} />}
          <StatusBar />
          <div style={{ position: "absolute", left: SW / 2 - 150, bottom: 18, width: 300, height: 12, borderRadius: 99, background: "rgba(20,24,32,.55)" }} />
        </div>
      </div>
      {/* punch-hole camera */}
      <div style={{ position: "absolute", left: B.pw / 2 - 9, top: B.bez + 14, width: 18, height: 18, borderRadius: 99, background: "#05070A", boxShadow: "0 0 0 2px #1B1F27" }} />
    </div>
  );
};

/** The finger: a highlight ring on the target, a touch dot that presses with a ripple (Android "show taps" style). */
const Touch: React.FC<{ a: Action; t: number }> = ({ a, t }) => {
  if (a.kind === "scroll") {
    // a swipe up: the finger lands, slides up with the page, lifts off
    const s = t - a.start, dy = a.dy ?? 600;
    const k = easeInOut(p(s, 0.3, 1.0));
    const o = p(s, 0.05, 0.3) * (1 - p(s, 1.0, 1.25));
    return <div style={{ position: "absolute", left: SW / 2 - 62, top: 1700 - 62 - k * dy, width: 124, height: 124, borderRadius: 999, background: "rgba(255,255,255,.55)", border: "6px solid rgba(255,255,255,.95)", boxShadow: "0 18px 40px rgba(11,31,68,.45)", opacity: o, transform: `scale(${s > 0.3 && s < 1.0 ? 0.82 : 1})` }} />;
  }
  const r = a.rect!;
  const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
  const s = t - a.start;
  const ring = p(s, 0, 0.3, easeOut) * (1 - p(s, a.end - a.start - 0.3, a.end - a.start));
  const press = a.kind === "type" ? 0.25 : 0.45;
  let x = cx, y = cy;
  if (a.kind === "drag" && a.dx) {
    const k = easeInOut(p(s, 0.35, 1.05));
    x = cx - a.dx / 2 + a.dx * k;
  }
  const dotIn = p(s, 0.05, 0.35, easeOut);
  const dotOut = 1 - p(s, a.kind === "drag" ? 1.15 : press + 0.45, a.kind === "drag" ? 1.35 : press + 0.7);
  const down = a.kind === "drag" ? (s > 0.3 && s < 1.1 ? 1 : 0) : s > press && s < press + 0.18 ? 1 : 0;
  const rip = p(s, press, press + 0.55);
  return (
    <>
      <div style={{ position: "absolute", left: r.x - 14, top: r.y - 14, width: r.w + 28, height: r.h + 28, borderRadius: Math.min(48, r.h / 2 + 14), border: `8px solid rgba(37,99,179,${0.85 * ring})`, boxShadow: `0 0 0 ${18 * ring}px rgba(37,99,179,${0.14 * ring})` }} />
      {a.kind !== "drag" && rip > 0 && rip < 1 && (
        <div style={{ position: "absolute", left: x - 140, top: y - 140, width: 280, height: 280, borderRadius: 999, background: `rgba(37,99,179,${0.28 * (1 - rip)})`, transform: `scale(${0.3 + rip})` }} />
      )}
      <div style={{ position: "absolute", left: x - 62, top: y - 62 + (1 - dotIn) * 160, width: 124, height: 124, borderRadius: 999, background: "rgba(255,255,255,.55)", border: "6px solid rgba(255,255,255,.95)", boxShadow: "0 18px 40px rgba(11,31,68,.45)", opacity: dotIn * dotOut, transform: `scale(${down ? 0.82 : 1})` }} />
    </>
  );
};

/** Camera: zooms the phone onto small targets, following the keyframes from tut_build.py. */
const camAt = (spec: TutSpec, t: number) => {
  const c = spec.cam;
  if (t <= c[0].t) return c[0];
  for (let i = 1; i < c.length; i++) {
    if (t < c[i].t) {
      const a = c[i - 1], b = c[i];
      const k = easeInOut(p(t, a.t, Math.min(b.t, a.t + 0.6)));
      return { t, z: lerp(a.z, b.z, k), x: lerp(a.x, b.x, k), y: lerp(a.y, b.y, k) };
    }
  }
  return c[c.length - 1];
};

// ------------------------------------------------------------------ titles, captions, steps

const Kicker: React.FC<{ text: string; size: number }> = ({ text, size }) => (
  <div style={{ display: "inline-flex", alignItems: "center", gap: 10, padding: `${size * 0.3}px ${size * 0.8}px`, borderRadius: 999, background: "#EAF1FB", color: blue, fontFamily: FONT, fontWeight: 800, fontSize: size, letterSpacing: "0.04em", textTransform: "uppercase" }}>{text}</div>
);

const Caption: React.FC<{ spec: TutSpec; t: number }> = ({ spec, t }) => {
  const B = useBox();
  const i = spec.chapters.findIndex((c) => t >= c.start && t < c.end);
  if (i < 0) return null;
  const c = spec.chapters[i];
  const k = spr(t, c.start, { damping: 16, stiffness: 160 });
  const n = spec.chapters.length;
  if (B.land) {
    return (
      <div style={{ position: "absolute", left: 860, top: 120, width: 960, fontFamily: FONT }}>
        <Kicker text={spec.kicker} size={24} />
        <div style={{ marginTop: 18, fontWeight: 800, fontSize: 62, color: ink, letterSpacing: "-0.02em" }}>{spec.title}</div>
        <div style={{ marginTop: 40, display: "flex", gap: 26, alignItems: "flex-start", opacity: Math.min(1, k * 1.5), transform: `translateY(${(1 - k) * 30}px)` }}>
          <div style={{ flex: "0 0 auto", width: 84, height: 84, borderRadius: 24, background: blue, color: "#fff", display: "grid", placeItems: "center", fontWeight: 800, fontSize: 44, boxShadow: "0 16px 30px -12px rgba(37,99,179,.7)" }}>{i + 1}</div>
          <div style={{ fontWeight: 800, fontSize: 52, lineHeight: 1.15, color: ink }}><Rich text={c.caption} /></div>
        </div>
        <div style={{ marginTop: 44, display: "flex", flexDirection: "column", gap: 10 }}>
          {spec.chapters.map((ch, j) => (
            <div key={j} style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 26, fontWeight: j === i ? 800 : 600, color: j < i ? "#9AA6B8" : j === i ? ink : "#6B7A93" }}>
              <div style={{ width: 36, height: 36, borderRadius: 99, display: "grid", placeItems: "center", fontSize: 18, fontWeight: 800, background: j < i ? "#22C55E" : j === i ? blue : "#E7ECF3", color: j <= i ? "#fff" : "#6B7A93" }}>{j < i ? "✓" : j + 1}</div>
              <span><Rich text={ch.caption.replace(/\*\*/g, "")} /></span>
            </div>
          ))}
        </div>
      </div>
    );
  }
  return (
    <div style={{ position: "absolute", left: 60, right: 60, top: 70, fontFamily: FONT }}>
      <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
        <Kicker text={spec.kicker} size={26} />
        <div style={{ fontWeight: 700, fontSize: 30, color: "#6B7A93" }}>Step {i + 1} of {n}</div>
      </div>
      <div style={{ marginTop: 26, display: "flex", gap: 22, alignItems: "center", opacity: Math.min(1, k * 1.5), transform: `translateY(${(1 - k) * 26}px)` }}>
        <div style={{ flex: "0 0 auto", width: 96, height: 96, borderRadius: 28, background: blue, color: "#fff", display: "grid", placeItems: "center", fontWeight: 800, fontSize: 50, boxShadow: "0 16px 30px -12px rgba(37,99,179,.7)" }}>{i + 1}</div>
        <div style={{ fontWeight: 800, fontSize: 58, lineHeight: 1.1, color: ink, letterSpacing: "-0.015em" }}><Rich text={c.caption} /></div>
      </div>
    </div>
  );
};

const Progress: React.FC<{ spec: TutSpec; t: number }> = ({ spec, t }) => {
  const B = useBox();
  const a = spec.chapters[0].start, b = spec.chapters[spec.chapters.length - 1].end;
  if (t < a - 0.3 || t > b + 0.3) return null;
  const n = spec.chapters.length;
  const w = B.land ? 960 : B.W - 120;
  const x = B.land ? 860 : 60, y = B.land ? B.H - 80 : B.H - 64;
  return (
    <div style={{ position: "absolute", left: x, top: y, width: w, display: "flex", gap: 8 }}>
      {spec.chapters.map((c, i) => (
        <div key={i} style={{ flex: 1, height: 8, borderRadius: 99, background: "#E3E8F0", overflow: "hidden" }}>
          <div style={{ width: `${p(t, c.start, c.end) * 100}%`, height: "100%", background: blue }} />
        </div>
      ))}
      <span style={{ display: "none" }}>{n}</span>
    </div>
  );
};

// ------------------------------------------------------------------ intro and outro cards

const Card: React.FC<{ spec: TutSpec; t: number; kind: "intro" | "outro" }> = ({ spec, t, kind }) => {
  const B = useBox();
  const seg = spec[kind];
  const o = kind === "intro" ? 1 - p(t, seg.end - 0.35, seg.end) : p(t, seg.start, seg.start + 0.35);
  if (o <= 0.001) return null;
  const k = spr(t, seg.start + 0.1, { damping: 15, stiffness: 120 });
  const logo = spr(t, seg.start + 0.05, { damping: 11, stiffness: 160 });
  const big = B.land ? 92 : 104;
  return (
    <AbsoluteFill style={{ opacity: o, background: "#fff", display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", fontFamily: FONT, textAlign: "center" }}>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 30% 15%, rgba(37,99,179,.10), transparent 60%), radial-gradient(ellipse at 75% 90%, rgba(242,178,51,.12), transparent 60%)" }} />
      <Img src={staticFile("brand/favicon.svg")} style={{ width: 150, height: 150, transform: `scale(${logo}) rotate(${(1 - logo) * -20}deg)`, filter: "drop-shadow(0 18px 30px rgba(11,31,68,.25))" }} />
      <div style={{ marginTop: 40, opacity: Math.min(1, k * 1.4), transform: `translateY(${(1 - k) * 30}px)` }}>
        {kind === "intro" ? (
          <>
            <Kicker text={`How to · ${spec.kicker}`} size={B.land ? 26 : 30} />
            <div style={{ marginTop: 28, fontWeight: 800, fontSize: big, lineHeight: 1.05, color: ink, letterSpacing: "-0.025em", padding: "0 60px" }}>{spec.title}</div>
            <div style={{ marginTop: 26, fontWeight: 600, fontSize: B.land ? 34 : 38, color: "#5B6B86" }}>SolutionTee CBT · Android app</div>
          </>
        ) : (
          <>
            <div style={{ fontWeight: 800, fontSize: big * 0.8, color: ink, letterSpacing: "-0.02em" }}>You're all set!</div>
            <div style={{ marginTop: 24, fontWeight: 600, fontSize: B.land ? 34 : 38, color: "#5B6B86", padding: "0 80px", lineHeight: 1.3 }}>{seg.say.split(". ").slice(-1)[0].replace(/\.$/, "")}</div>
            <div style={{ marginTop: 44, display: "inline-flex", padding: "18px 38px", borderRadius: 999, background: ink, color: "#fff", fontWeight: 800, fontSize: B.land ? 34 : 40 }}>cbt.solutiontee.com</div>
          </>
        )}
      </div>
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ the video

export const Tutorial: React.FC<{ spec: TutSpec }> = ({ spec }) => {
  const t = useT();
  const B = useBox();
  const cam = camAt(spec, t);
  // the phone slides up into place after the intro card
  const enter = spr(t, spec.intro.end - 0.35, { damping: 16, stiffness: 110 });
  const leave = p(t, spec.outro.start - 0.2, spec.outro.start + 0.3, easeInOut);
  // the camera works inside a stage (below the caption in 9:16, left of the steps in 16:9) and brings the target
  // towards the middle of it as it zooms, so the phone never covers the caption or leaves the frame unseen
  const stage = B.land ? { x: 0, y: 0, w: 830, h: B.H } : { x: 0, y: 360, w: B.W, h: B.H - 360 - 96 };
  const zMax = B.land ? 1.3 : 1.4;
  const z = Math.min(cam.z, zMax);
  const m = (z - 1) / (zMax - 1);
  const ox = B.px + (cam.x - SW / 2) * B.k, oy = B.py + (cam.y - SH / 2) * B.k;
  const sx = (stage.x + stage.w / 2 - ox) * m * (B.land ? 1 : 0.6), sy = (stage.y + stage.h / 2 - oy) * m * 0.6;
  return (
    <AbsoluteFill style={{ background: "#F7F9FC" }}>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 20% 10%, rgba(37,99,179,.07), transparent 55%), radial-gradient(ellipse at 85% 95%, rgba(242,178,51,.07), transparent 55%)" }} />
      <Audio src={staticFile(spec.audio)} />
      <Caption spec={spec} t={t} />
      <AbsoluteFill style={{ transform: `translateY(${(1 - enter) * 300 + leave * 120}px) scale(${lerp(0.94, 1, enter)})`, opacity: Math.min(1, enter * 1.4) * (1 - leave) }}>
        <div style={{ position: "absolute", left: stage.x, top: stage.y, width: stage.w, height: stage.h, overflow: "hidden", WebkitMaskImage: B.land ? "linear-gradient(to right, #000 calc(100% - 40px), transparent)" : "linear-gradient(to bottom, transparent 0, #000 36px, #000 calc(100% - 24px), transparent)" }}>
          <div style={{ position: "absolute", left: -stage.x, top: -stage.y, width: B.W, height: B.H, transformOrigin: `${ox}px ${oy}px`, transform: `translate(${sx}px, ${sy}px) scale(${z})` }}>
            <Phone spec={spec} t={t} />
          </div>
        </div>
      </AbsoluteFill>
      <Progress spec={spec} t={t} />
      <Card spec={spec} t={t} kind="intro" />
      <Card spec={spec} t={t} kind="outro" />
    </AbsoluteFill>
  );
};
