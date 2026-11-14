import React from "react";
import { AbsoluteFill, Audio, Img, Sequence, interpolate, staticFile } from "remotion";
import { Lottie } from "@remotion/lottie";
import { C, FONT, GAME, clamp, easeInOut, easeOut, lerp, p, rnd, spr, useT } from "../lib";
import { CoinBurst, CoinRain, Confetti, Flash, Ring, Sparkle } from "../components";
import tl from "./timeline.json";
import loaderLight from "../../public/brand/solutiontee-loader-light.json";

/*
 * 30 s short (D-165): "snap-scroll". One tall page; the camera snaps down one screen per beat-cut, like swiping a feed.
 * A gold trace line (the brand's route motif) runs down the right edge and detours to underline, tick, circle and slash
 * things, then plugs into the real logo animation. Neo-brutalist stickers: thick ink outlines and hard shadows.
 */
const W = 1080, H = 1920;
const INK = "#071230";
const CREAM = "#FBF6EA";
const STATIONS = (tl as { stations: { id: string; at: number }[] }).stations;
const SNAP = STATIONS.slice(1).map((s) => s.at);
const word = (id: string, n: number) => (tl as unknown as { vo: { id: string; words: [string, number, number][] }[] }).vo.find((l) => l.id === id)!.words[n][1];

/* ------------------------------------------------------------------ building blocks */
const Paper: React.FC = () => (
  <AbsoluteFill style={{ background: CREAM }}>
    <AbsoluteFill style={{ backgroundImage: "repeating-linear-gradient(180deg, transparent 0 78px, rgba(37,99,179,.16) 78px 81px)" }} />
    <div style={{ position: "absolute", left: 120, top: 0, bottom: 0, width: 4, background: "rgba(229,72,77,.35)" }} />
  </AbsoluteFill>
);
const Dots: React.FC<{ bg: string; dot: string }> = ({ bg, dot }) => (
  <AbsoluteFill style={{ background: bg }}>
    <AbsoluteFill style={{ backgroundImage: `radial-gradient(${dot} 3px, transparent 3.5px)`, backgroundSize: "36px 36px", opacity: 0.5 }} />
  </AbsoluteFill>
);

/** Polyline with rounded corners; returns the SVG path and cumulative lengths at each vertex. */
function route(pts: [number, number][], r = 70) {
  let d = `M${pts[0][0]} ${pts[0][1]}`;
  const lens = [0];
  let acc = 0;
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1], [x1, y1] = pts[i];
    acc += Math.hypot(x1 - x0, y1 - y0);
    lens.push(acc);
    if (i < pts.length - 1) {
      const [x2, y2] = pts[i + 1];
      const l1 = Math.hypot(x1 - x0, y1 - y0), l2 = Math.hypot(x2 - x1, y2 - y1);
      const rr = Math.min(r, l1 / 2, l2 / 2);
      const ax = x1 - ((x1 - x0) / l1) * rr, ay = y1 - ((y1 - y0) / l1) * rr;
      const bx = x1 + ((x2 - x1) / l2) * rr, by = y1 + ((y2 - y1) / l2) * rr;
      d += ` L${ax} ${ay} Q${x1} ${y1} ${bx} ${by}`;
    } else d += ` L${x1} ${y1}`;
  }
  return { d, lens };
}

/** The trace: ink outline + gold (or white) core, drawn to `frac`. */
const Trace: React.FC<{ d: string; frac: number; fill?: string; width?: number; opacity?: number }> = ({ d, frac, fill = C.gold, width = 30, opacity = 1 }) => {
  if (frac <= 0) return null;
  return (
    <svg width={W} height={H} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", opacity }}>
      <path d={d} pathLength={1} fill="none" stroke={INK} strokeWidth={width + 16} strokeLinecap="round" strokeLinejoin="round" strokeDasharray="1 1" strokeDashoffset={1 - frac} />
      <path d={d} pathLength={1} fill="none" stroke={fill} strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" strokeDasharray="1 1" strokeDashoffset={1 - frac} />
    </svg>
  );
};
/** A route drawn so that each vertex is reached at its given time. */
const Route: React.FC<{ pts: [number, number][]; times: number[]; fill?: string; r?: number; opacity?: number }> = ({ pts, times, fill, r, opacity }) => {
  const t = useT();
  const { d, lens } = route(pts, r);
  const frac = interpolate(t, times, lens.map((l) => l / lens[lens.length - 1]), clamp);
  return <Trace d={d} frac={frac} fill={fill} opacity={opacity} />;
};
const Accent: React.FC<{ d: string; from: number; to: number; fill?: string; width?: number }> = ({ d, from, to, fill, width = 26 }) => {
  const t = useT();
  return <Trace d={d} frac={p(t, from, to, easeInOut)} fill={fill} width={width} />;
};

/** Neo-brutalist sticker that pops in at `at`. */
const Sticker: React.FC<{ x: number; y: number; w?: number; h?: number; rot?: number; at: number; bg?: string; children: React.ReactNode; pad?: number; radius?: number; shadow?: number }> = ({ x, y, w, h, rot = 0, at, bg = "#fff", children, pad = 0, radius = 30, shadow = 14 }) => {
  const t = useT();
  const k = spr(t, at, { damping: 11, stiffness: 230, mass: 0.8 });
  if (t < at) return null;
  return (
    <div style={{ position: "absolute", left: x, top: y, width: w, height: h, padding: pad, background: bg, border: `6px solid ${INK}`, borderRadius: radius, boxShadow: `${shadow}px ${shadow}px 0 ${INK}`, transform: `rotate(${rot + (1 - k) * 14}deg) scale(${lerp(0.3, 1, k)})`, opacity: Math.min(1, k * 2), overflow: "hidden", fontFamily: FONT, color: INK }}>
      {children}
    </div>
  );
};

/** Big editorial title; each line slides up out of a mask. `mark` puts a highlighter swipe behind a line. */
const Title: React.FC<{ lines: { s: string; at: number; color?: string; outline?: boolean; mark?: string }[]; x?: number; y: number; size?: number; color?: string; hard?: boolean }> = ({ lines, x = 70, y, size = 128, color = INK, hard = false }) => {
  const t = useT();
  return (
    <div style={{ position: "absolute", zIndex: 5, left: x, top: y, fontFamily: FONT, fontWeight: 800, fontSize: size, lineHeight: 0.98, letterSpacing: -size * 0.045, color }}>
      {lines.map((l, i) => {
        const k = spr(t, l.at, { damping: 15, stiffness: 190 });
        const m = p(t, l.at + 0.08, l.at + 0.35, easeOut);
        return (
          <div key={i} style={{ overflow: "hidden", padding: "0.04em 0.08em 0.1em 0", position: "relative" }}>
            {l.mark ? <div style={{ position: "absolute", left: -10, right: "auto", top: "22%", height: "62%", width: `${m * 104}%`, background: l.mark, borderRadius: 10, transform: "rotate(-1.5deg)" }} /> : null}
            <div style={{ position: "relative", transform: `translateY(${(1 - k) * 110}%)`, color: l.outline ? "transparent" : l.color ?? color, WebkitTextStroke: l.outline ? `5px ${l.color ?? color}` : hard ? `4px ${INK}` : undefined, paintOrder: "stroke fill", textShadow: hard ? `7px 7px 0 ${INK}` : undefined }}>{l.s}</div>
          </div>
        );
      })}
    </div>
  );
};
const Tag: React.FC<{ n: number; at: number; dark?: boolean }> = ({ n, at, dark }) => {
  const t = useT();
  const k = spr(t, at, { stiffness: 220 });
  return (
    <div style={{ position: "absolute", left: 70, top: 130, transform: `scale(${k})`, transformOrigin: "0 50%", fontFamily: FONT, fontWeight: 800, fontSize: 34, letterSpacing: 3, color: dark ? "#fff" : INK, border: `4px solid ${dark ? "#fff" : INK}`, borderRadius: 99, padding: "8px 22px" }}>
      {String(n).padStart(2, "0")} / 07
    </div>
  );
};
/** A crop of an app screen inside a sticker. */
const Crop: React.FC<{ src: string; sx: number; sy: number; sw: number; sh: number; w: number }> = ({ src, sx, sy, sw, sh, w }) => {
  const k = w / sw;
  return (
    <div style={{ position: "relative", width: w, height: sh * k, overflow: "hidden" }}>
      <Img src={staticFile(src)} style={{ position: "absolute", left: -sx * k, top: -sy * k, width: 1170 * k }} />
    </div>
  );
};

/* ------------------------------------------------------------------ stations (each is one 1080 × 1920 screen) */
const S0: React.FC = () => {
  const t = useT();
  const pop = lerp(1.08, 1, p(t, 0, 0.35));
  return (
    <AbsoluteFill>
      <Paper />
      <div style={{ transform: `scale(${pop})`, transformOrigin: "20% 30%" }}>
        <Title y={300} size={150} lines={[{ s: "What if", at: -1 }, { s: "JAMB…", at: -1, color: C.blue }]} />
      </div>
      <Sticker x={700} y={330} w={300} h={220} rot={8} at={-0.6} bg="#fff">
        <div style={{ display: "grid", placeItems: "center", height: "100%" }}><Img src={staticFile("brand/jamb.png")} style={{ width: "72%", height: "72%", objectFit: "contain" }} /></div>
      </Sticker>
      <Title y={900} size={150} lines={[{ s: "felt like", at: word("s02", 0) }, { s: "practice?", at: word("s02", 2), mark: C.gold }]} />
      <Route pts={[[80, 1330], [1010, 1330], [1010, 1920]]} times={[1.62, 2.1, 2.4]} />
    </AbsoluteFill>
  );
};
const S1: React.FC = () => (
  <AbsoluteFill>
    <Dots bg={C.gold} dot="rgba(7,18,48,.18)" />
    <Title y={270} size={84} lines={[{ s: "With", at: word("s03", 0) }]} />
    <Title y={370} size={150} lines={[{ s: "SolutionTee", at: word("s03", 1) }, { s: "CBT", at: word("s03", 2), color: "#fff", outline: false }]} />
    <Route pts={[[1010, 0], [1010, 1080], [110, 1080], [110, 1820], [1010, 1820], [1010, 1920]]} times={[2.4, 2.85, 3.35, 4.1, 4.7, 5.0]} fill="#fff" />
    <Sticker x={250} y={1250} w={600} h={330} rot={-5} at={word("s03", 3)} bg={C.navy}>
      <div style={{ height: "100%", display: "flex", alignItems: "center", justifyContent: "center", gap: 30, color: "#fff", fontSize: 96, fontWeight: 800, letterSpacing: -3 }}>it does.</div>
    </Sticker>
    <Accent d="M720 1200 L810 1290 L990 1060" from={word("s03", 4) + 0.05} to={word("s03", 4) + 0.3} fill={C.gold} width={30} />
  </AbsoluteFill>
);
const LOGO = (src: string, x: number, y: number, at: number, rot: number, name: string) => (
  <Sticker x={x - 175} y={y - 140} w={350} h={280} rot={rot} at={at} bg="#fff">
    <div style={{ height: "100%", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8 }}>
      <Img src={staticFile(src)} style={{ width: "62%", height: 150, objectFit: "contain" }} />
      <div style={{ fontWeight: 800, fontSize: 40, letterSpacing: 2 }}>{name}</div>
    </div>
  </Sticker>
);
const S2: React.FC = () => {
  const t = useT();
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: C.navy, backgroundImage: "linear-gradient(rgba(255,255,255,.06) 2px, transparent 2px), linear-gradient(90deg, rgba(255,255,255,.06) 2px, transparent 2px)", backgroundSize: "90px 90px" }} />
      <Route pts={[[1010, 0], [1010, 600], [120, 600], [120, 1080], [960, 1080], [960, 1560], [120, 1560], [120, 1800], [1010, 1800], [1010, 1920]]} times={[5.0, 5.1, 5.3, 5.42, 5.6, 5.8, 6.2, 6.5, 6.95, 7.2]} />
      {LOGO("brand/jamb.png", 340, 600, word("s04", 0), -6, "JAMB")}
      {LOGO("brand/waec.png", 740, 1080, word("s04", 1), 5, "WAEC")}
      {LOGO("brand/neco.png", 340, 1560, word("s04", 2), -4, "NECO")}
      <Ring x={340} y={600} at={word("s04", 0)} size={600} color={C.gold} />
      <Ring x={740} y={1080} at={word("s04", 1)} size={600} color={C.gold} />
      <Ring x={340} y={1560} at={word("s04", 2)} size={600} color={C.gold} />
      <div style={{ position: "absolute", top: 170, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 56, letterSpacing: 6, color: C.gold, opacity: p(t, 5.1, 5.3) }}>EVERY EXAM. ONE APP.</div>
    </AbsoluteFill>
  );
};
const S3: React.FC = () => {
  const t = useT();
  const hl = p(t, 7.95, 8.25, easeOut);
  return (
    <AbsoluteFill>
      <Paper />
      <Tag n={1} at={7.20} />
      <Title y={230} size={128} lines={[{ s: "Real past", at: 7.28 }, { s: "questions.", at: word("s05", 2), color: C.blue }]} />
      <Route pts={[[1010, 0], [1010, 1920]]} times={[7.2, 9.2]} />
      <Sticker x={100} y={720} w={800} rot={2} at={7.55} bg="#fff">
        <div style={{ position: "relative" }}>
          <Crop src="screens/cbt.jpg" sx={30} sy={520} sw={1110} sh={1160} w={788} />
          <div style={{ position: "absolute", left: 18, top: 180, height: 102, width: 750 * hl, background: "rgba(242,178,51,.45)", borderRadius: 18, mixBlendMode: "multiply" }} />
        </div>
      </Sticker>
      <Sticker x={600} y={1500} w={330} h={130} rot={-8} at={8.2} bg="#16A34A">
        <div style={{ height: "100%", display: "grid", placeItems: "center", color: "#fff", fontWeight: 800, fontSize: 58 }}>✓ Correct</div>
      </Sticker>
    </AbsoluteFill>
  );
};
const S4: React.FC = () => {
  const t = useT();
  const secs = Math.max(0, 38 - Math.floor(Math.max(0, t - 9.4) / 0.4));
  const d = "M1010 0 V1050 Q1010 1150 910 1150 A390 390 0 1 1 130 1150 A390 390 0 1 1 910 1150 Q1010 1150 1010 1250 V1920";
  const T = 1050 + 157 + 2450 + 157 + 670;
  const frac = interpolate(t, [9.2, 9.45, 10.9, 11.2], [0, 1207 / T, 3657 / T, 1], clamp);
  return (
    <AbsoluteFill>
      <Dots bg={C.blue} dot="rgba(255,255,255,.14)" />
      <Tag n={2} at={9.20} dark />
      <Title y={230} size={128} color="#fff" lines={[{ s: "The real", at: 9.28 }, { s: "exam timer.", at: word("s06", 2), color: C.gold }]} />
      <Trace d={d} frac={frac} />
      <div style={{ position: "absolute", left: 130, width: 780, top: 1060, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 150, letterSpacing: -4, color: "#fff", fontVariantNumeric: "tabular-nums", transform: `scale(${spr(t, 9.5, { stiffness: 200 })})` }}>
        1:12:<span style={{ color: C.gold }}>{String(secs).padStart(2, "0")}</span>
      </div>
      <Sticker x={300} y={1600} w={440} h={110} rot={4} at={10.3} bg={C.red}>
        <div style={{ height: "100%", display: "grid", placeItems: "center", color: "#fff", fontWeight: 800, fontSize: 44 }}>Auto-submit at 0:00</div>
      </Sticker>
    </AbsoluteFill>
  );
};
const S5: React.FC = () => {
  const t = useT();
  const k = interpolate(t, [11.5, 12.3], [0, 1], { ...clamp, easing: easeOut });
  const score = Math.round(312 * k);
  const bars: [string, number][] = [["English", 78], ["Maths", 64], ["Physics", 70], ["Chemistry", 75]];
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: "#fff" }} />
      <div style={{ position: "absolute", top: 820, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 520, color: "rgba(11,31,68,.04)", letterSpacing: -20 }}>400</div>
      <Tag n={3} at={11.20} />
      <Title y={230} size={128} lines={[{ s: "Your score,", at: 11.28 }, { s: "instantly.", at: word("s07", 2), mark: C.gold }]} />
      <Route pts={[[1010, 0], [1010, 1920]]} times={[11.2, 13.2]} />
      <svg width={W} height={H} style={{ position: "absolute", left: 0, top: 0 }}>
        <path d="M210 1200 A330 330 0 0 1 870 1200" fill="none" stroke="rgba(7,18,48,.1)" strokeWidth={46} strokeLinecap="round" />
      </svg>
      <Trace d="M210 1200 A330 330 0 0 1 870 1200" frac={k * 0.78} width={30} />
      <div style={{ position: "absolute", top: 960, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 230, letterSpacing: -10, color: INK, fontVariantNumeric: "tabular-nums", lineHeight: 1 }}>{score}</div>
      <div style={{ position: "absolute", top: 1200, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 52, color: "#5b6b86" }}>out of 400</div>
      <Sticker x={150} y={1340} w={700} rot={-2} at={12.2} pad={34} bg={CREAM}>
        {bars.map(([n, v], i) => (
          <div key={n} style={{ display: "flex", alignItems: "center", gap: 20, marginTop: i ? 14 : 0 }}>
            <div style={{ width: 230, fontSize: 34, fontWeight: 800 }}>{n}</div>
            <div style={{ flex: 1, height: 26, borderRadius: 13, background: "rgba(7,18,48,.1)", border: `3px solid ${INK}`, overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${v * p(t, 12.35 + i * 0.1, 12.8 + i * 0.1)}%`, background: i % 2 ? C.blue : C.gold }} />
            </div>
            <div style={{ width: 70, fontSize: 32, fontWeight: 800, textAlign: "right" }}>{v}</div>
          </div>
        ))}
      </Sticker>
      <Confetti at={12.3} x={540} y={1100} n={70} power={0.9} />
    </AbsoluteFill>
  );
};
const S6: React.FC = () => {
  const t = useT();
  const steps: [string, number][] = [["Two numbers: ×6, +(−5) → −2, −3", 14.5], ["(x − 2)(x − 3) = 0", 14.75], ["x = 2 or x = 3", 15.0]];
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: C.navy }} />
      <Tag n={4} at={13.20} dark />
      <Title y={230} size={124} color="#fff" lines={[{ s: "An AI tutor,", at: 13.28 }, { s: "step by step.", at: word("s08", 3), color: C.gold }]} />
      <Route pts={[[1010, 0], [1010, 1920]]} times={[13.2, 15.6]} />
      <Sticker x={330} y={640} w={560} rot={4} at={13.55} pad={26} bg="#FFFDF6">
        <div style={{ fontFamily: "Georgia, serif", fontSize: 38, color: "#1d2433", backgroundImage: "repeating-linear-gradient(transparent 0 52px, rgba(37,99,179,.2) 52px 54px)" }}>Find the roots of<br /><span style={{ fontSize: 54 }}>x² − 5x + 6 = 0</span></div>
        <div style={{ position: "absolute", right: 16, top: 12, fontSize: 26, fontWeight: 800, color: C.blue }}>📷</div>
      </Sticker>
      <Sticker x={90} y={1000} w={840} rot={-2} at={13.9} pad={34} bg="#fff">
        <div style={{ fontSize: 34, fontWeight: 800, color: C.blue, marginBottom: 10 }}>✦ SolutionTee AI</div>
        {steps.map(([s, at], i) => (
          <div key={i} style={{ display: "flex", gap: 20, alignItems: "center", marginTop: 18, opacity: p(t, at, at + 0.12), transform: `translateX(${(1 - p(t, at, at + 0.2)) * 50}px)` }}>
            <div style={{ flex: "0 0 64px", height: 64, borderRadius: 32, border: `4px solid ${INK}`, background: i === 2 ? "#16A34A" : C.gold, display: "grid", placeItems: "center", fontWeight: 800, fontSize: 32, color: i === 2 ? "#fff" : INK }}>{i === 2 ? "✓" : i + 1}</div>
            <div style={{ fontSize: i === 2 ? 52 : 40, fontWeight: 800, color: i === 2 ? "#15803D" : INK }}>{s}</div>
          </div>
        ))}
      </Sticker>
    </AbsoluteFill>
  );
};
const S7: React.FC = () => {
  const t = useT();
  const saved = t >= 16.5;
  const prog = p(t, 16.05, 16.5, easeInOut);
  return (
    <AbsoluteFill>
      <Dots bg={C.gold} dot="rgba(7,18,48,.18)" />
      <Tag n={5} at={15.60} />
      <Title y={230} size={140} lines={[{ s: "Practise", at: 15.68 }, { s: "offline.", at: word("s09", 1), color: "#fff" }]} />
      <Route pts={[[1010, 0], [1010, 1920]]} times={[15.6, 17.6]} fill="#fff" />
      <svg width={560} height={480} viewBox="0 0 26 22" style={{ position: "absolute", left: 260, top: 780, transform: `scale(${spr(t, 15.75, { stiffness: 200 })})` }}>
        <g fill="none" stroke={INK} strokeWidth={2.6} strokeLinecap="round">
          <path d="M2 8 Q13 -1 24 8" /><path d="M5.5 11.5 Q13 5 20.5 11.5" /><path d="M9 15 Q13 12 17 15" />
        </g>
        <circle cx={13} cy={18.5} r={1.9} fill={INK} />
      </svg>
      <Accent d="M250 790 L840 1300" from={15.9} to={16.05} fill={C.red} width={34} />
      <Sticker x={180} y={1400} w={720} rot={-3} at={16.05} pad={30} bg="#fff">
        <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 38, fontWeight: 800 }}>JAMB Maths · 1,240 Qs</div>
            <div style={{ height: 30, marginTop: 14, borderRadius: 15, border: `4px solid ${INK}`, overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${prog * 100}%`, background: saved ? "#16A34A" : C.blue }} />
            </div>
          </div>
          <div style={{ fontSize: 42, fontWeight: 800, color: saved ? "#16A34A" : INK, width: 150, textAlign: "right" }}>{saved ? "Saved ✓" : `${Math.round(prog * 100)}%`}</div>
        </div>
      </Sticker>
    </AbsoluteFill>
  );
};
const S8: React.FC = () => {
  const t = useT();
  const vs = spr(t, 17.8, { damping: 9, stiffness: 240 });
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: "linear-gradient(160deg, #1B2A8F, #3A1C8C 60%, #8C1C4A)" }} />
      <AbsoluteFill style={{ background: `repeating-conic-gradient(from ${t * 40}deg at 50% 52%, rgba(255,255,255,.07) 0 9deg, transparent 9deg 18deg)` }} />
      <Tag n={6} at={17.60} dark />
      <Title y={230} size={124} color="#fff" lines={[{ s: "Battle your", at: 17.68 }, { s: "friends.", at: word("s10", 2), color: C.gold }]} />
      <Sticker x={60} y={700} w={430} rot={-7} at={17.85} radius={40}>
        <Crop src="screens/03_vs.jpg" sx={0} sy={120} sw={1170} sh={900} w={418} />
      </Sticker>
      <Sticker x={590} y={1060} w={430} rot={6} at={18.0} radius={40}>
        <Crop src="screens/03_vs.jpg" sx={0} sy={1250} sw={1170} sh={900} w={418} />
      </Sticker>
      <Route pts={[[1010, 0], [1010, 520], [600, 960], [780, 980], [420, 1460], [1010, 1460], [1010, 1920]]} times={[17.6, 17.75, 17.85, 17.9, 18.0, 18.2, 19.6]} r={12} />
      <div style={{ position: "absolute", top: 880, width: W, textAlign: "center", fontFamily: GAME, fontSize: 260, color: C.gold, WebkitTextStroke: `10px ${INK}`, textShadow: `0 16px 0 ${INK}`, transform: `scale(${lerp(3, 1, vs)}) rotate(-8deg)`, opacity: Math.min(1, vs * 2) }}>VS</div>
      <div style={{ position: "absolute", top: 1700, width: W, textAlign: "center", fontFamily: GAME, fontSize: 64, color: "#fff", letterSpacing: 2, opacity: p(t, 18.4, 18.6) }}>GAME ZONE · LIVE 1V1</div>
    </AbsoluteFill>
  );
};
const S9: React.FC = () => {
  const t = useT();
  const cash = word("s11", 2);
  const amount = Math.round((50000 * interpolate(t, [19.95, cash + 0.25], [0, 1], { ...clamp, easing: easeOut })) / 50) * 50;
  const card = spr(t, 19.75, { damping: 12, stiffness: 160 });
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: C.navy }} />
      <AbsoluteFill style={{ background: `repeating-conic-gradient(from ${t * 25}deg at 50% 62%, rgba(242,178,51,.12) 0 8deg, transparent 8deg 16deg)` }} />
      <Tag n={7} at={19.60} dark />
      <Route pts={[[1010, 0], [1010, 1920]]} times={[19.6, 22.0]} />
      <div style={{ position: "absolute", left: 90, top: 820, width: 880, transform: `rotate(${lerp(12, -3, card)}deg) scale(${lerp(0.4, 1, card)})`, opacity: Math.min(1, card * 2), border: `6px solid ${INK}`, borderRadius: 60, boxShadow: `16px 16px 0 ${INK}`, overflow: "hidden" }}>
        <Img src={staticFile("screens/card_cash.png")} style={{ width: 880, display: "block" }} />
        <div style={{ position: "absolute", left: 30, top: 178, width: 440, height: 84, background: "#0E2552", display: "flex", alignItems: "center", paddingLeft: 8, fontFamily: FONT, fontWeight: 800, fontSize: 72, color: "#F6C35A", letterSpacing: -1.5, opacity: t < cash + 0.3 ? 1 : 0 }}>Win ₦{amount.toLocaleString("en-NG")}</div>
      </div>
      <AbsoluteFill style={{ zIndex: 1 }}>
        <CoinBurst at={cash} x={540} y={1150} n={36} spread={1.2} />
        <CoinRain from={cash + 0.2} to={21.6} n={30} />
      </AbsoluteFill>
      <Title y={230} size={132} color="#fff" hard lines={[{ s: "And win", at: 19.68 }, { s: "cash prizes.", at: cash, color: C.gold }]} />
      <div style={{ position: "absolute", top: 1620, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 600, fontSize: 30, color: "rgba(255,255,255,.75)", opacity: p(t, 20.6, 20.9) }}>Free to join. Eligibility and terms apply.</div>
    </AbsoluteFill>
  );
};
const S10: React.FC = () => {
  const t = useT();
  const plug = 22.32;
  const toWord = p(t, 23.75, 24.2, easeInOut);
  const chips: [string, number][] = [["Learn", 24.4], ["Think", 24.7], ["Solve", 25.0]];
  const cta = spr(t, 25.9, { damping: 13, stiffness: 170 });
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: "#fff" }} />
      <Route pts={[[1010, 0], [1010, 576], [735, 576]]} times={[22.0, 22.2, plug]} opacity={1 - p(t, 22.45, 22.75)} />
      <Ring x={674} y={576} at={plug} size={260} color={C.gold} width={10} />
      <div style={{ position: "absolute", left: 280, top: 420, width: 520, height: 520, opacity: 1 - toWord }}>
        <Sequence from={Math.round(plug * 30)} layout="none">
          <Lottie animationData={loaderLight as never} loop={false} style={{ width: 520, height: 520 }} />
        </Sequence>
      </div>
      <div style={{ position: "absolute", left: W / 2 - 470, top: 470, width: 940, height: 336, overflow: "hidden", opacity: toWord, transform: `scale(${lerp(1.08, 1, toWord)})` }}>
        <Img src={staticFile("brand/solutiontee-wordmark.jpg")} style={{ position: "absolute", width: 940, left: 0, top: -235 }} />
      </div>
      <div style={{ position: "absolute", top: 860, width: W, display: "flex", justifyContent: "center", gap: 26 }}>
        {chips.map(([s, at], i) => {
          const k = spr(t, at, { damping: 10, stiffness: 240 });
          return <div key={s} style={{ transform: `scale(${k}) rotate(${[-4, 3, -2][i]}deg)`, opacity: Math.min(1, k * 2), fontFamily: FONT, fontWeight: 800, fontSize: 52, color: INK, background: [C.gold, CREAM, C.gold][i], border: `5px solid ${INK}`, borderRadius: 99, padding: "14px 34px", boxShadow: `8px 8px 0 ${INK}` }}>{s}.</div>;
        })}
      </div>
      <div style={{ position: "absolute", top: 1030, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 104, lineHeight: 1, letterSpacing: -4, color: INK }}>
        {["Download", "free,", "today."].map((w, i) => {
          const at = [25.4, 25.74, 26.08][i];
          const k = spr(t, at, { damping: 14, stiffness: 200 });
          return <React.Fragment key={w}><span style={{ display: "inline-block", transform: `translateY(${(1 - k) * 60}px)`, opacity: Math.min(1, k * 2), color: i === 1 ? C.blue : INK, margin: "0 12px" }}>{w}</span>{i === 1 ? <br /> : null}</React.Fragment>;
        })}
      </div>
      <div style={{ position: "absolute", left: W / 2 - 330, top: 1290, width: 660, height: 150, borderRadius: 34, background: INK, color: "#fff", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", fontFamily: FONT, transform: `scale(${cta})`, boxShadow: `10px 10px 0 ${C.gold}` }}>
        <div style={{ fontSize: 28, fontWeight: 700, letterSpacing: 4, color: C.muted }}>GET IT ON</div>
        <div style={{ fontSize: 60, fontWeight: 800 }}>Google Play</div>
      </div>
      <div style={{ position: "absolute", top: 1480, width: W, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 48, color: C.blue, opacity: p(t, 26.3, 26.6) }}>cbt.solutiontee.com</div>
      <div style={{ position: "absolute", top: 1570, width: W, display: "flex", justifyContent: "center", gap: 22, opacity: p(t, 26.6, 26.9) }}>
        {["brand/jamb.png", "brand/waec.png", "brand/neco.png"].map((s) => (
          <div key={s} style={{ width: 120, height: 92, borderRadius: 18, background: "#fff", border: `4px solid ${INK}`, display: "grid", placeItems: "center" }}><Img src={staticFile(s)} style={{ width: "76%", height: "72%", objectFit: "contain" }} /></div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 110, right: 110, top: 1710, textAlign: "center", fontFamily: FONT, fontWeight: 500, fontSize: 24, lineHeight: 1.45, color: "#6b7a93", opacity: p(t, 26.9, 27.3) }}>
        SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
      </div>
      <Sparkle x={860} y={470} at={22.5} size={90} color={C.gold} />
    </AbsoluteFill>
  );
};
const LIST = [S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10];

/* ------------------------------------------------------------------ camera: snap one screen per cut */
const camAt = (t: number) => SNAP.reduce((acc, s) => acc + spr(t, s - 0.12, { damping: 24, stiffness: 190, mass: 0.8 }), 0);
export const Short: React.FC = () => {
  const t = useT();
  const cam = camAt(t);
  const vel = (camAt(t + 1 / 60) - camAt(t - 1 / 60)) * 30; // screens per second
  const tilt = Math.max(-3, Math.min(3, vel * 0.9));
  const dip = 1 - Math.min(0.06, Math.abs(vel) * 0.012);
  const world = (dy: number, op: number) => (
    <AbsoluteFill style={{ transform: `translateY(${-cam * H + dy}px)`, opacity: op }}>
      {LIST.map((S, i) => (Math.abs(i - cam) < 1.05 ? <div key={i} style={{ position: "absolute", left: 0, top: i * H, width: W, height: H, overflow: "hidden" }}><S /></div> : null))}
    </AbsoluteFill>
  );
  const blur = Math.min(1, Math.abs(vel) / 3);
  return (
    <AbsoluteFill style={{ background: CREAM, overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `rotate(${tilt}deg) scale(${dip})` }}>
        {blur > 0.15 ? world(vel * 14, 0.35 * blur) : null}
        {world(0, 1)}
        {blur > 0.15 ? world(-vel * 14, 0.35 * blur) : null}
      </AbsoluteFill>
      <Flash at={2.4} dur={0.2} max={0.5} color="#fff" />
      <AbsoluteFill style={{ backgroundImage: `url(${staticFile(`grain${Math.floor(t * 24) % 4}.png`)})`, backgroundSize: "384px 384px", opacity: 0.06, mixBlendMode: "multiply", pointerEvents: "none" }} />
      <Audio src={staticFile("audio/short.wav")} />
    </AbsoluteFill>
  );
};
