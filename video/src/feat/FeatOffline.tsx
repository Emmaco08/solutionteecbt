import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Phone } from "../components";
import { EndCard, Flash, KText, useF, useS } from "../pack/kit";
import { C, FONT, Ico, Pill, ScoreRing, Toggle, easeOut, lerp, p, spr } from "./fkit";

// Feature ad 5: Offline, "Data finished? No wahala." (D-183). 19 s, flat colour blocks, a cut on the beat.
export const OFFLINE_SECONDS = 19;
const RED = "#E5484D";
const CREAM = "#F7F3EA";

const Block: React.FC<{ a: number; b: number; color: string; children?: React.ReactNode; from?: "bottom" | "left" | "right" | "top" }> = ({ a, b, color, children, from = "bottom" }) => {
  const t = useS();
  if (t < a || t >= b) return null;
  const k = p(t, a, a + 0.16, easeOut);
  const clip = from === "bottom" ? `inset(${(1 - k) * 100}% 0 0 0)` : from === "top" ? `inset(0 0 ${(1 - k) * 100}% 0)` : from === "left" ? `inset(0 ${(1 - k) * 100}% 0 0)` : `inset(0 0 0 ${(1 - k) * 100}%)`;
  return <AbsoluteFill style={{ background: color, clipPath: clip }}>{children}</AbsoluteFill>;
};

const Big: React.FC<{ text: string; at: number; y: number; size: number; color: string; accent?: string }> = ({ text, at, y, size, color, accent }) => (
  <KText text={text} at={at} y={y} size={size} color={color} accent={accent ?? color} mode="mask" stagger={0.06} lh={0.95} tracking={-0.05} serifScale={1.05} />
);

/** "STEP 1" tag. */
const Step: React.FC<{ n: number; at: number; y: number; dark?: boolean }> = ({ n, at, y, dark }) => {
  const F = useF();
  return <Pill x={F.cx} y={y} at={at} bg={dark ? "#fff" : C.navy} fg={dark ? C.navy : "#fff"} size={34} bob={false}>STEP {n}</Pill>;
};

// ------------------------------------------------------------------ 0–3.2 s: hook

const Bars: React.FC<{ level: number; size: number }> = ({ level, size }) => (
  <div style={{ display: "flex", alignItems: "flex-end", gap: size * 0.08, height: size }}>
    {[0.3, 0.5, 0.75, 1].map((h, i) => (
      <div key={i} style={{ width: size * 0.18, height: size * h, borderRadius: 8, background: i < level ? "#fff" : "rgba(255,255,255,.25)" }} />
    ))}
  </div>
);

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  const level = Math.max(0, 4 - Math.floor(t / 0.13));
  const mb = Math.max(0, 52.4 - t * 90).toFixed(1);
  return (
    <>
      <Block a={0} b={0.85} color={RED}>
        <div style={{ position: "absolute", left: F.cx - 110 * F.ks, top: F.cy - 640 * F.ky }}><Bars level={level} size={220 * F.ks} /></div>
        <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy - 300 * F.ky, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 90 * F.ks, color: "#fff", fontVariantNumeric: "tabular-nums", opacity: 0.85 }}>{mb} MB left</div>
        <Big text="Data / finished?" at={0} y={F.cy + 220 * F.ky} size={210} color="#fff" />
      </Block>
      <Block a={0.85} b={1.7} color={C.gold}>
        <Big text="*No* / *wahala.*" at={0.85} y={F.cy} size={300} color={C.navy} />
      </Block>
      <Block a={1.7} b={3.2} color={C.navy}>
        <div style={{ position: "absolute", left: F.cx - 140 * F.ks, top: F.cy - 600 * F.ky, transform: `scale(${spr(t, 1.75, { damping: 9 })}) rotate(${Math.sin(t * 3) * 5}deg)` }}>
          <Ico n="wifiOff" size={280 * F.ks} color={C.gold} stroke={1.8} />
        </div>
        <Big text="SolutionTee" at={1.8} y={F.cy - 40 * F.ky} size={150} color="#fff" />
        <Big text="works" at={1.95} y={F.cy + 120 * F.ky} size={150} color="#fff" />
        <Big text="*offline.*" at={2.1} y={F.cy + 320 * F.ky} size={230} color="#fff" accent={C.gold} />
      </Block>
    </>
  );
};

// ------------------------------------------------------------------ 3.2–6 s: step 1, download once

const Download: React.FC = () => {
  const F = useF();
  const t = useS();
  const w = 900 * F.ks;
  const k = spr(t, 3.3, { damping: 13 });
  const prog = p(t, 4.3, 5.3, easeOut);
  const done = t > 5.35;
  const R = 70 * F.ks, L = 2 * Math.PI * R;
  return (
    <Block a={3.2} b={6.0} color={CREAM}>
      <Step n={1} at={3.25} y={F.cy - 800 * F.ky} />
      <Big text="Start a test once / *with internet.*" at={3.3} y={F.cy - 600 * F.ky} size={100} color={C.navy} accent={C.blue} />
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 300 * F.ky, width: w, transform: `translateY(${(1 - k) * 300}px)`, opacity: Math.min(1, k * 2) }}>
        <div style={{ background: "#fff", borderRadius: 44, padding: 46 * F.ks, boxShadow: "0 40px 80px -40px rgba(0,0,0,.4)", fontFamily: FONT }}>
          <div style={{ fontWeight: 700, fontSize: 30 * F.ks, color: "#7B88A1" }}>JAMB UTME · full mock</div>
          <div style={{ fontWeight: 800, fontSize: 60 * F.ks, color: C.navy, marginTop: 6 }}>4 subjects · 180 questions</div>
          <div style={{ display: "flex", gap: 14, marginTop: 20, flexWrap: "wrap" }}>
            {["English", "Mathematics", "Physics", "Chemistry"].map((s) => <div key={s} style={{ padding: "10px 20px", borderRadius: 99, background: "#EEF2F8", fontWeight: 700, fontSize: 28 * F.ks, color: C.navy }}>{s}</div>)}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 30, marginTop: 40 * F.ks }}>
            <div style={{ position: "relative", width: R * 2 + 16, height: R * 2 + 16 }}>
              <svg width={R * 2 + 16} height={R * 2 + 16} viewBox={`${-R - 8} ${-R - 8} ${R * 2 + 16} ${R * 2 + 16}`}>
                <circle r={R} fill="none" stroke="#E8EDF5" strokeWidth={14} />
                <circle r={R} fill="none" stroke={done ? "#22C55E" : C.blue} strokeWidth={14} strokeLinecap="round" strokeDasharray={`${L * prog} ${L}`} transform="rotate(-90)" />
              </svg>
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}><Ico n={done ? "check" : "download"} size={60 * F.ks} color={done ? "#22C55E" : C.blue} stroke={2.6} /></div>
            </div>
            <div>
              <div style={{ fontWeight: 800, fontSize: 46 * F.ks, color: done ? "#16A34A" : C.navy }}>{done ? "Saved on your phone" : t > 4.3 ? `Downloading ${Math.round(prog * 100)}%` : "Download"}</div>
              <div style={{ fontWeight: 600, fontSize: 30 * F.ks, color: "#7B88A1" }}>{done ? "Ready to practise offline" : "Once. That's all."}</div>
            </div>
          </div>
        </div>
      </div>
    </Block>
  );
};

// ------------------------------------------------------------------ 6–9 s: step 2, offline and still practising

const Practise: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 6.6, { damping: 15, stiffness: 110 });
  const pw = 460 * F.ks * (F.tall ? 1 : 0.72);
  return (
    <Block a={6.0} b={9.0} color={C.blue} from="right">
      <Step n={2} at={6.05} y={F.cy - 800 * F.ky} dark />
      <Big text="Go offline. / *Keep practising.*" at={6.1} y={F.cy - 600 * F.ky} size={100} color="#fff" accent={C.gold} />
      <Toggle x={F.cx} y={F.cy - 360 * F.ky} at={6.2} on={6.55} label="Airplane mode" icon="plane" />
      <Phone src="screens/cbt.jpg" width={pw} x={F.cx} y={F.cy + 330 * F.ky + (1 - k) * 900} rx={8} ry={-12} rz={-3} />
      <Pill x={F.cx + 290 * F.ks} y={F.cy + 60 * F.ky} at={7.1} bg={C.navy} fg={C.gold} icon="wifiOff" size={36}>Offline</Pill>
      <Pill x={F.cx - 290 * F.ks} y={F.cy + 420 * F.ky} at={7.5} bg="#22C55E" fg="#fff" icon="check" size={36}>Still works</Pill>
      <KText text="On the bus. In the village. When NEPA takes light." at={7.9} y={F.cy + 830 * F.ky} size={40} color="#fff" weight={700} stagger={0.03} />
    </Block>
  );
};

// ------------------------------------------------------------------ 9–11.5 s: step 3, results offline

const Results: React.FC = () => {
  const F = useF();
  return (
    <Block a={9.0} b={11.5} color={C.gold} from="left">
      <Step n={3} at={9.05} y={F.cy - 800 * F.ky} />
      <Big text="Instant results. / *Even offline.*" at={9.1} y={F.cy - 600 * F.ky} size={100} color={C.navy} />
      <ScoreRing at={9.5} dur={1.0} x={F.cx} y={F.cy + 80 * F.ky} r={250 * F.ks} value={287} max={400} dark />
      <Pill x={F.cx} y={F.cy + 520 * F.ky} at={10.4} bg={C.navy} fg="#fff" icon="wifiOff" size={36}>Marked on your phone</Pill>
    </Block>
  );
};

// ------------------------------------------------------------------ 11.5–14 s: step 4, it syncs

const Sync: React.FC = () => {
  const F = useF();
  const t = useS();
  const up = spr(t, 11.9, { damping: 11 });
  const spin = p(t, 12.0, 12.7);
  return (
    <Block a={11.5} b={14.0} color={C.navy} from="bottom">
      <Step n={4} at={11.55} y={F.cy - 800 * F.ky} dark />
      <Big text="Back online? / *It syncs itself.*" at={11.6} y={F.cy - 600 * F.ky} size={100} color="#fff" accent={C.gold} />
      <div style={{ position: "absolute", left: F.cx - 180 * F.ks, top: F.cy - 330 * F.ky, transform: `scale(${up})` }}>
        <div style={{ width: 360 * F.ks, height: 360 * F.ks, borderRadius: 99, background: "rgba(255,255,255,.08)", display: "grid", placeItems: "center", transform: `rotate(${(1 - spin) * -360}deg)` }}>
          <Ico n="cloud" size={230 * F.ks} color={spin > 0.99 ? "#7CF0A9" : "#fff"} stroke={1.6} />
        </div>
      </div>
      <Pill x={F.cx} y={F.cy + 220 * F.ky} at={12.8} bg="#fff" icon="check" size={38}>Finished tests sent</Pill>
      <Pill x={F.cx} y={F.cy + 380 * F.ky} at={13.05} bg={C.gold} icon="cloud" size={38}>Saved to your account</Pill>
      <Flash at={12.7} color="#7CF0A9" max={0.2} />
    </Block>
  );
};

// ------------------------------------------------------------------ 14–16 s: videos and notes too

const Saved: React.FC = () => {
  const F = useF();
  const t = useS();
  const w = 880 * F.ks;
  const items: [string, string, string, string][] = [
    ["video", "Video solution", "Quadratic equations · 6 min", RED],
    ["book", "Lesson notes", "Motion and forces · PDF", C.blue],
    ["flag", "Your bookmarks", "42 saved questions", C.gold],
  ];
  return (
    <Block a={14.0} b={16.1} color={CREAM} from="top">
      <Big text="Videos and notes, / *too.*" at={14.05} y={F.cy - 640 * F.ky} size={110} color={C.navy} accent={C.blue} />
      {items.map(([icon, a, b, col], i) => {
        const k = spr(t, 14.3 + i * 0.15, { damping: 12 });
        return (
          <div key={a} style={{ position: "absolute", left: F.cx - w / 2, top: F.cy + (-300 + i * 230) * F.ky, width: w, transform: `translateX(${(1 - k) * (i % 2 ? 700 : -700)}px)`, opacity: Math.min(1, k * 2) }}>
            <div style={{ display: "flex", alignItems: "center", gap: 26, background: "#fff", borderRadius: 34, padding: `${26 * F.ks}px ${30 * F.ks}px`, boxShadow: "0 30px 60px -32px rgba(0,0,0,.4)", fontFamily: FONT }}>
              <div style={{ width: 96 * F.ks, height: 96 * F.ks, borderRadius: 26, background: col, display: "grid", placeItems: "center" }}><Ico n={icon} size={54 * F.ks} color="#fff" stroke={2.2} /></div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 800, fontSize: 42 * F.ks, color: C.navy }}>{a}</div>
                <div style={{ fontWeight: 600, fontSize: 30 * F.ks, color: "#7B88A1" }}>{b}</div>
              </div>
              <div style={{ padding: "10px 18px", borderRadius: 99, background: "#DCFCE7", color: "#15803D", fontWeight: 800, fontSize: 26 * F.ks }}>✓ Offline</div>
            </div>
          </div>
        );
      })}
    </Block>
  );
};

export const FeatOffline: React.FC = () => (
  <AbsoluteFill style={{ background: CREAM }}>
    <Audio src={staticFile("audio/feat_offline.wav")} />
    <Hook />
    <Download />
    <Practise />
    <Results />
    <Sync />
    <Saved />
    <End />
    {[0.85, 1.7, 3.2, 6.0, 9.0, 11.5, 14.0].map((a) => <Flash key={a} at={a} max={0.22} dur={0.18} />)}
  </AbsoluteFill>
);

const End: React.FC = () => {
  const t = useS();
  if (t < 16.0) return null;
  return (
    <AbsoluteFill style={{ clipPath: `inset(${(1 - p(t, 16.0, 16.2, easeOut)) * 100}% 0 0 0)` }}>
      <EndCard at={16.0} cta="Download free" />
    </AbsoluteFill>
  );
};

void lerp;
