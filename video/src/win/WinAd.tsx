import React from "react";
import * as THREE from "three";
import { AbsoluteFill, Audio, Sequence, staticFile } from "remotion";
import { Phone } from "../components";
import { EndCard, Flash, KText, Star4, WarmStage, useF, useS } from "../pack/kit";
import { C, DeepStage, FONT, Ico, Pill, Shot, easeInOut, easeOut, lerp, p, spr } from "../feat/fkit";
import { Cam, LaptopModel, MonitorModel, Screen, Stage3D, project, screenPoint } from "./Laptop3D";

// Advert: "SolutionTee CBT is now on Windows" (D-186, v2): a photoreal 3D laptop and a voice-over.
// 24.5 s, 120 BPM, 9:16, 4:5 and 16:9. Scene times follow the voice lines (public/vo_win/vo.json).
export const WIN_SECONDS = 24.5;

/** When each scene starts and when its voice line is said. */
export const T = { tiny: 2.1, reveal: 4.5, open: 4.6, cbt: 7.9, all: 13.2, same: 17.2, end: 19.4 };
export const VO: [string, number][] = [["w1", 0.15], ["w2", 2.15], ["w3", 5.0], ["w4", 8.0], ["w5", 13.3], ["w6", 17.3], ["w7", 19.75]];

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

/** A camera that fits [width] cm across [frac] of the frame, seen from yaw/pitch (degrees), with [look] drawn at [at] (px). */
const fit = (L: ReturnType<typeof useL>, look: THREE.Vector3, width: number, frac: number, yaw: number, pitch: number, at: [number, number], fov = 26): Cam => {
  const aspect = L.W / L.H;
  const th = Math.tan(THREE.MathUtils.degToRad(fov / 2)) * aspect;
  const d = width / 2 / (frac * th);
  const y = THREE.MathUtils.degToRad(yaw), pt = THREE.MathUtils.degToRad(pitch);
  const pos: [number, number, number] = [look.x + d * Math.sin(y) * Math.cos(pt), look.y + d * Math.sin(pt), look.z + d * Math.cos(y) * Math.cos(pt)];
  return { pos, look: [look.x, look.y, look.z], fov, shift: [at[0] - L.W / 2, at[1] - L.H / 2] };
};
const V = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);
const mixV = (a: THREE.Vector3, b: THREE.Vector3, k: number) => a.clone().lerp(b, k);

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

// ------------------------------------------------------------------ the hook: a CBT centre, three monitors drop in

const Hook: React.FC = () => {
  const L = useL();
  const t = useS();
  const drops = [0.45, 0.55, 0.65].map((a) => (1 - spr(t, a, { damping: 12, stiffness: 120 })) * 60);
  const cam = fit(L, V(0, 24, 0), 126, L.pick(0.98, 0.92, 0.6), lerp(-6, 6, p(t, 0, T.tiny)), 10, [L.land ? L.vx + 40 : L.cx, L.pick(L.cy + 140, L.cy + 150, L.cy + 40)]);
  return (
    <Shot a={0} b={T.tiny} first>
      <KText text="JAMB is written" at={0.1} {...L.ty(L.cy - 560, L.cy - 440, L.cy - 70)} size={L.pick(104, 104, 96)} stagger={0.05} dur={0.3} />
      <KText text="*on a computer.*" at={0.45} {...L.ty(L.cy - 410, L.cy - 310, L.cy + 50)} size={L.pick(150, 140, 130)} serifScale={1.1} />
      <Stage3D cam={cam} floor={0.25}>
        <MonitorModel x={-44} z={-8} rotY={0.32} src="screens/win/cbt_from_test.jpg" drop={drops[0]} />
        <MonitorModel x={44} z={-8} rotY={-0.32} src="screens/win/cbt_from_test.jpg" drop={drops[2]} />
        <MonitorModel x={0} z={4} src="screens/win/cbt_from_test.jpg" drop={drops[1]} />
      </Stage3D>
    </Shot>
  );
};

// ------------------------------------------------------------------ only on a phone?

const Tiny: React.FC = () => {
  const L = useL();
  const t = useS();
  const a = T.tiny + 0.15;
  const k = spr(t, a, { damping: 9, stiffness: 160 });
  const wob = Math.sin((t - a) * 9) * Math.exp(-(t - a) * 2.2) * 9;
  const pw = L.pick(250, 210, 250);
  return (
    <Shot a={T.tiny} b={T.reveal}>
      <KText text="So why practise" at={T.tiny + 0.05} {...L.ty(L.cy - 560, L.cy - 430, L.cy - 70)} size={L.pick(104, 100, 96)} />
      <KText text="only on a *phone?*" at={T.tiny + 0.4} {...L.ty(L.cy - 430, L.cy - 315, L.cy + 45)} size={L.pick(104, 100, 96)} />
      <Phone src="screens/cbt.jpg" width={pw * k} x={L.vx} y={L.pick(L.cy + 230, L.cy + 190, L.cy + 30)} rz={wob} />
      <Pill x={L.vx + pw * 0.9} y={L.pick(L.cy + 40, L.cy + 40, L.cy - 160)} at={T.tiny + 0.9} bg="#fff" fg={C.navy} size={L.pick(36, 32, 34)} icon="sparkle">so small…</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ the reveal: the lid rises, the screen comes on

/** 0 → 1 with a small settle past the end, like a real hinge. */
const lidOpen = (t: number, a: number) => {
  const k = p(t, a, a + 0.85);
  const e = 1 - Math.pow(1 - k, 3);
  return e + Math.sin(k * Math.PI) * 0.06 * (k > 0.6 ? 1 : 0);
};

const Reveal: React.FC = () => {
  const L = useL();
  const t = useS();
  const open = lidOpen(t, T.open);
  const on = p(t, T.open + 0.7, T.open + 1.05);
  const k = p(t, T.reveal, T.cbt, easeInOut);
  const at: [number, number] = [L.vx, L.pick(L.cy + 200, L.cy + 170, L.cy + 10)];
  const cam = fit(L, mixV(V(0, 6, 0), screenPoint(0.5, 0.62), p(t, T.open, T.open + 1.0, easeInOut)), 36, L.pick(lerp(0.66, 0.8, k), lerp(0.58, 0.7, k), lerp(0.4, 0.48, k)), lerp(-38, -10, k), lerp(30, 14, k), at);
  const nw = project(cam, L.W, L.H, screenPoint(1, 0));
  const badge = spr(t, T.open + 1.3, { damping: 8, stiffness: 200 });
  return (
    <Shot a={T.reveal} b={T.cbt} zin={1.12}>
      <DeepStage />
      <KText text="SolutionTee CBT" at={T.open + 0.45} {...L.ty(L.cy - 740, L.cy - 540, L.cy - 130)} size={L.pick(92, 84, 84)} color="#fff" accent={C.gold} />
      <KText text="is now on" at={T.open + 0.75} {...L.ty(L.cy - 610, L.cy - 430, L.cy - 30)} size={L.pick(118, 108, 104)} color="#fff" accent={C.gold} />
      <KText text="*Windows.*" at={T.open + 1.0} {...L.ty(L.cy - 480, L.cy - 320, L.cy + 95)} size={L.pick(150, 130, 140)} color="#fff" accent={C.gold} />
      <Stage3D cam={cam} floor={0.5}>
        <LaptopModel open={open} on={on} screens={[{ src: "screens/win/home.jpg" }]} shadow={0.7} />
      </Stage3D>
      {badge > 0.01 && (
        <div style={{ position: "absolute", left: nw[0] - 20, top: nw[1] - 10, transform: `translate(-50%,-50%) rotate(${lerp(-40, 10, badge)}deg) scale(${badge})`, padding: `${14 * L.ks}px ${30 * L.ks}px`, borderRadius: 999, background: C.gold, color: C.navy, fontFamily: FONT, fontWeight: 800, fontSize: 44 * L.ks, boxShadow: "0 20px 50px -10px rgba(242,178,51,.8)" }}>NEW</div>
      )}
      <Star4 x={at[0] - L.pick(400, 360, 420)} y={at[1] - L.pick(220, 200, 200)} size={70} at={T.open + 1.0} />
      <Star4 x={at[0] + L.pick(420, 380, 450)} y={at[1] + 60} size={50} at={T.open + 1.15} />
      <Flash at={T.open + 0.75} max={0.45} color="#DDE9FF" />
    </Shot>
  );
};

// ------------------------------------------------------------------ a real CBT on a big screen: the camera moves into the question

const BigCbt: React.FC = () => {
  const L = useL();
  const t = useS();
  const a = T.cbt;
  const push = p(t, a + 0.3, a + 1.4, easeInOut) * (1 - p(t, a + 3.4, a + 4.4, easeInOut));
  const at: [number, number] = [L.vx, L.pick(L.cy - 40, L.cy - 20, L.cy - 30)];
  const look = mixV(screenPoint(0.5, 0.55), screenPoint(0.36, 0.16), push);
  const cam = fit(L, look, lerp(36, L.land ? 22 : 15, push), L.pick(0.8, 0.7, 0.48), lerp(-6, 0, push), lerp(14, 4, push), [at[0] + (L.land ? 90 * push : 0), at[1]]);
  const ks = L.pick(124, 92, 88);
  const keys: [string, number, string][] = [["A", 1, "Choose"], ["→", 1, "Next"], ["F", 1, "Flag"], ["Shift+C", 2.1, "Calculator"]];
  const step = L.pick(215, 176, 128);
  const xs = L.land ? [120 + ks / 2, 120 + ks / 2 + step, 120 + ks / 2 + step * 2, 120 + step * 3 + ks * 1.05] : [-1.75, -0.75, 0.25, 1.6].map((m) => L.cx + m * step);
  const ky = L.pick(L.cy + 560, L.cy + 400, L.cy + 170);
  const tm = project(cam, L.W, L.H, screenPoint(0.86, 0.0));
  return (
    <Shot a={T.cbt} b={T.all}>
      <KText text="A real CBT." at={a + 0.05} {...L.ty(L.cy - 720, L.cy - 560, L.cy - 230)} size={L.pick(104, 96, 96)} />
      <KText text="*On a big screen.*" at={a + 0.4} {...L.ty(L.cy - 590, L.cy - 455, L.cy - 115)} size={L.pick(124, 110, 112)} />
      <Stage3D cam={cam} floor={0.28}>
        <LaptopModel screens={[{ src: "screens/win/cbt_calculator.jpg" }]} />
      </Stage3D>
      {keys.map(([lab, w, cap], i) => (
        <Key key={lab} x={xs[i]} y={ky} at={a + 1.6 + i * 0.12} press={a + 2.2 + i * 0.45} label={lab} w={w} size={ks} caption={cap} />
      ))}
      <Pill x={Math.min(tm[0], L.W - 40)} y={tm[1] - 50} at={a + 1.5} out={a + 2.6} bg={C.navy} fg="#fff" icon="timer" size={L.pick(34, 30, 30)} anchor="right">Timer like the real exam</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ everything, bigger: the laptop turns, the screens change

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
  const t0 = T.all + 0.35, per = 0.62;
  const idx = Math.max(0, Math.min(SHOWS.length - 1, Math.floor((t - t0) / per)));
  const local = t - t0 - idx * per;
  const at: [number, number] = [L.vx, L.pick(L.cy + 120, L.cy + 110, L.cy - 40)];
  const cam = fit(L, screenPoint(0.5, 0.6), 36, L.pick(0.78, 0.68, 0.46), lerp(-24, 22, p(t, T.all, T.same)), 14, at);
  const screens: Screen[] = SHOWS.map(([src], i) => ({ src, opacity: i < idx ? 1 : i === idx ? (i === 0 || t < t0 ? 1 : p(local, 0, 0.14)) : 0 }));
  const below = project(cam, L.W, L.H, V(0, 0, 11));
  return (
    <Shot a={T.all} b={T.same}>
      <DeepStage a="rgba(242,178,51,.30)" b="rgba(37,99,179,.5)" />
      <KText text="Everything you love." at={T.all + 0.05} {...L.ty(L.cy - 640, L.cy - 500, L.cy - 70)} size={L.pick(96, 88, 84)} color="#fff" accent={C.gold} />
      <KText text="*Bigger.*" at={T.all + 2.7} {...L.ty(L.cy - 500, L.cy - 385, L.cy + 55)} size={L.pick(150, 130, 150)} color="#fff" accent={C.gold} />
      <Stage3D cam={cam} floor={0.5}>
        <LaptopModel screens={screens} shadow={0.7} />
      </Stage3D>
      {SHOWS.map(([, label, icon], i) => {
        const s0 = t0 + i * per;
        if (t < s0 || (i < SHOWS.length - 1 && t > s0 + per + 0.05)) return null;
        return <Pill key={label} x={at[0]} y={below[1] + L.pick(110, 90, 70)} at={s0} bg={C.gold} fg={C.navy} size={L.pick(52, 44, 44)} icon={icon} bob={false}>{label}</Pill>;
      })}
    </Shot>
  );
};

// ------------------------------------------------------------------ same account, same Premium

const Together: React.FC = () => {
  const L = useL();
  const t = useS();
  const a = T.same;
  const pw = L.pick(250, 210, 250);
  const at: [number, number] = [L.vx - L.pick(110, 100, 120), L.pick(L.cy + 60, L.cy + 50, L.cy + 40)];
  const cam = fit(L, screenPoint(0.5, 0.6), 36, L.pick(0.62, 0.54, 0.38), lerp(26, 18, p(t, a, T.end)), 12, at);
  const right = project(cam, L.W, L.H, screenPoint(1, 0.55));
  const top = project(cam, L.W, L.H, screenPoint(0.3, 0));
  const px = right[0] + pw * 0.2, py = right[1] + L.pick(140, 120, 120);
  const line = p(t, a + 0.6, a + 1.2, easeOut);
  const ok = spr(t, a + 1.2, { damping: 9, stiffness: 200 });
  const ax = top[0], ay = top[1] - 30;
  const bx = px, by = py - pw * 1.08 - 30;
  const mx = (ax + bx) / 2, my = Math.min(ay, by) - L.pick(170, 130, 110);
  const qx = 0.25 * ax + 0.5 * mx + 0.25 * bx, qy = 0.25 * ay + 0.5 * my + 0.25 * by;
  return (
    <Shot a={T.same} b={T.end + 0.1} last>
      <WarmStage />
      <KText text="Same account." at={a + 0.05} {...L.ty(L.cy - 690, L.cy - 540, L.cy - 130)} size={L.pick(104, 96, 96)} />
      <KText text="*Same Premium.*" at={a + 0.75} {...L.ty(L.cy - 560, L.cy - 425, L.cy - 10)} size={L.pick(124, 112, 116)} />
      <Stage3D cam={cam} floor={0.3}>
        <LaptopModel screens={[{ src: "screens/win/home.jpg" }]} />
      </Stage3D>
      <Phone src="screens/study.jpg" width={pw} x={px} y={py} ry={-12} />
      <svg width={L.W} height={L.H} style={{ position: "absolute", inset: 0 }}>
        <path d={`M${ax},${ay} Q${mx},${my} ${bx},${by}`} stroke={C.gold} strokeWidth={8} fill="none" strokeLinecap="round" strokeDasharray="2000" strokeDashoffset={2000 * (1 - line)} />
      </svg>
      {ok > 0.01 && (
        <div style={{ position: "absolute", left: qx, top: qy, transform: `translate(-50%,-50%) scale(${ok})`, width: 96 * L.ks, height: 96 * L.ks, borderRadius: 99, background: "#22C55E", display: "grid", placeItems: "center", boxShadow: "0 16px 40px -10px rgba(34,197,94,.8)" }}>
          <Ico n="check" size={60 * L.ks} color="#fff" stroke={3} />
        </div>
      )}
      <Pill x={L.land ? 120 : L.cx} y={L.pick(L.cy + 600, L.cy + 470, L.cy + 120)} at={a + 1.4} bg={C.navy} fg="#fff" size={L.pick(36, 32, 30)} icon="download" bob={false} anchor={L.land ? "left" : "center"}>Windows 10 & 11 · 64-bit · Free to start</Pill>
    </Shot>
  );
};

const End: React.FC = () => {
  const t = useS();
  if (t < T.end - 0.15) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, T.end - 0.15, T.end + 0.15) }}>
      <EndCard at={T.end} cta="Download for Windows" />
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

void Sequence;
