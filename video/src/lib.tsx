import React, { createContext, useContext } from "react";
import { continueRender, delayRender, Easing, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import "@fontsource/plus-jakarta-sans/500.css";
import "@fontsource/plus-jakarta-sans/700.css";
import "@fontsource/plus-jakarta-sans/800.css";
import timeline from "./timeline.json";

export const C = {
  navy: "#0B1F44",
  deep: "#06132B",
  ink: "#040B1A",
  blue: "#2563B3",
  blue2: "#4B86D4",
  gold: "#F2B233",
  gold2: "#FFD27A",
  light: "#EEF4FF",
  muted: "#AFC0DD",
  red: "#E5484D",
  green: "#22C55E",
};
export const FONT = "'Plus Jakarta Sans', system-ui, sans-serif";
export const GAME = "'Lilita One', 'Plus Jakarta Sans', sans-serif";

// Lilita One (OFL, bundled with the app) for the Game Zone moment.
const lilita = delayRender("Lilita One");
const face = new FontFace("Lilita One", `url(${staticFile("fonts/LilitaOne-Regular.ttf")})`);
face.load().then((f) => { (document.fonts as unknown as { add: (x: FontFace) => void }).add(f); continueRender(lilita); }).catch(() => continueRender(lilita));

export type Word = [string, number, number];
export const TL = timeline as unknown as { fps: number; bpm: number; duration: number; vo: { id: string; at: number; text: string; seconds: number; words: Word[] }[] };
export const vo = (id: string) => TL.vo.find((l) => l.id === id)!;
/** Start time (s) of the n-th word of a line. */
export const wordAt = (id: string, n: number) => vo(id).words[n][1];

/** Scenes render inside <Scene>, which tells children the absolute time so everything is written in seconds. */
const Offset = createContext(0);
export const useT = () => {
  const f = useCurrentFrame();
  const off = useContext(Offset);
  const { fps } = useVideoConfig();
  return f / fps + off;
};
/** Frames from the enclosing <Scene> start to absolute second `sec` (for nested <Sequence>). */
export const useFramesTo = (sec: number) => Math.round((sec - useContext(Offset)) * 30);
export const OffsetProvider: React.FC<{ from: number; children: React.ReactNode }> = ({ from, children }) => (
  <Offset.Provider value={from}>{children}</Offset.Provider>
);

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeIn = Easing.bezier(0.7, 0, 0.84, 0);
/** 0→1 between seconds a and b. */
export const p = (t: number, a: number, b: number, e: (x: number) => number = easeOut) => interpolate(t, [a, b], [0, 1], { ...clamp, easing: e });
export const lerp = (a: number, b: number, k: number) => a + (b - a) * k;
/** A spring that starts at second `at`. */
export const spr = (t: number, at: number, cfg: { damping?: number; stiffness?: number; mass?: number } = {}) =>
  t < at ? 0 : spring({ frame: (t - at) * 30, fps: 30, config: { damping: 14, stiffness: 140, mass: 0.9, ...cfg } });
/** Deterministic pseudo random 0..1. */
export const rnd = (i: number) => {
  const x = Math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};
/** Decaying camera shake after hit times. */
export const shake = (t: number, hits: number[], amp = 18, decay = 9) => {
  let x = 0, y = 0, r = 0;
  for (const h of hits) {
    const d = t - h;
    if (d < 0 || d > 0.8) continue;
    const k = Math.exp(-d * decay) * amp;
    x += Math.sin(d * 83) * k;
    y += Math.cos(d * 71) * k * 0.8;
    r += Math.sin(d * 57) * k * 0.04;
  }
  return { x, y, r };
};
