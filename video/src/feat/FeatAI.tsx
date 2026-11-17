import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Phone } from "../components";
import { EndCard, Flash, KText } from "../pack/kit";
import { Bubble, C, DeepStage, FONT, Ico, Pill, SERIF, Shot, TypeLine, easeInOut, easeOut, lerp, p, rnd, spr } from "./fkit";
import { useF, useS } from "../pack/kit";

// Feature ad 1: AI Tutor, "Snap it. Solve it." (D-183). 19 s, deep navy, 120 BPM.
export const AI_SECONDS = 19;
const SKY = "#8FB8FF";

/** The handwritten-looking question on paper. */
const Paper: React.FC<{ x: number; y: number; w: number; rot?: number; scale?: number }> = ({ x, y, w, rot = 0, scale = 1 }) => {
  const F = useF();
  return (
    <div style={{ position: "absolute", left: x - w / 2, top: y - w * 0.36, width: w, transform: `rotate(${rot}deg) scale(${scale})` }}>
      <div style={{ background: "repeating-linear-gradient(180deg,#FFFDF6 0px,#FFFDF6 46px,#DCE6F5 47px,#FFFDF6 49px)", borderRadius: 18, padding: `${40 * F.ks}px ${46 * F.ks}px`, boxShadow: "0 40px 80px -30px rgba(0,0,0,.8)", borderLeft: "6px solid #F3A6A6" }}>
        <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: 30 * F.ks, color: "#8A97AD" }}>Question 12 · Mathematics</div>
        <div style={{ fontFamily: SERIF, fontStyle: "italic", fontSize: 92 * F.ks, color: C.navy, marginTop: 10 }}>Solve 2x² − 8 = 0</div>
        <div style={{ display: "flex", gap: 22, marginTop: 14, fontFamily: FONT, fontWeight: 700, fontSize: 32 * F.ks, color: "#55627A" }}>
          <span>A. 2</span><span>B. ±2</span><span>C. 4</span><span>D. ±4</span>
        </div>
      </div>
    </div>
  );
};

// ------------------------------------------------------------------ 0–3 s: the hook

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  return (
    <Shot a={0} b={1.6} first>
      <div style={{ position: "absolute", left: F.cx - 210 * F.ks, top: F.cy - 740 * F.ky, display: "flex", alignItems: "center", gap: 18, opacity: p(t, 0, 0.2) }}>
        <Ico n="moon" size={70 * F.ks} color="#FFD27A" stroke={2} fill="rgba(255,210,122,.25)" />
        <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 92 * F.ks, color: "#fff", fontVariantNumeric: "tabular-nums" }}>11:4{7 + Math.floor(t * 0.6)} PM</div>
      </div>
      <Paper x={F.cx} y={F.cy - 160 * F.ky} w={860 * F.ks} rot={-4 + Math.sin(t * 3) * 0.6} />
      {[0, 1, 2].map((i) => {
        const k = spr(t, 0.25 + i * 0.18, { damping: 8 });
        return <div key={i} style={{ position: "absolute", left: F.cx + (i - 1) * 300 * F.ks + (i === 1 ? 0 : 40), top: F.cy - (i === 1 ? 470 : 380) * F.ky, transform: `scale(${k}) rotate(${(i - 1) * 18}deg)`, fontFamily: FONT, fontWeight: 800, fontSize: 130 * F.ks, color: "#FF6B6B" }}>?</div>;
      })}
      <KText text="Stuck on a question / *this late?*" at={0.02} y={F.cy + 420 * F.ky} size={104} color="#fff" accent="#FFD27A" stagger={0.05} dur={0.3} serifScale={1.2} />
    </Shot>
  );
};

const Alone: React.FC = () => {
  const F = useF();
  const t = useS();
  const w = 840 * F.ks;
  const strike = (at: number) => p(t, at, at + 0.25, easeOut);
  return (
    <Shot a={1.6} b={3.0}>
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 560 * F.ky, width: w }}>
        <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: 30 * F.ks, color: "#7F8BA8", marginBottom: 14 }}>SS3 Study Group · 214 members</div>
        <Bubble at={1.65} x={0} y={0} w={w * 1.1}><span>Pls who understands no. 12??</span></Bubble>
      </div>
      <div style={{ position: "absolute", left: F.cx + w / 2 - 260 * F.ks, top: F.cy - 340 * F.ky, fontFamily: FONT, fontWeight: 700, fontSize: 30 * F.ks, color: "#7F8BA8", opacity: p(t, 2.0, 2.2) }}>Seen by 37 ✓✓</div>
      {[["No teacher.", 2.15, -40], ["No answer.", 2.45, 150]].map(([s, at, dy]) => (
        <div key={s as string} style={{ position: "absolute", left: 0, width: F.W, top: F.cy + (dy as number) * F.ky, textAlign: "center" }}>
          <span style={{ position: "relative", display: "inline-block", fontFamily: FONT, fontWeight: 800, fontSize: 130 * F.ks, color: "#fff", letterSpacing: "-0.04em", opacity: p(t, at as number, (at as number) + 0.15), transform: `translateY(${(1 - p(t, at as number, (at as number) + 0.3)) * 40}px)` }}>
            {s}
            <span style={{ position: "absolute", left: -10, right: -10, top: "52%", height: 12, borderRadius: 9, background: "#FF6B6B", transform: `scaleX(${strike((at as number) + 0.3)})`, transformOrigin: "0 50%" }} />
          </span>
        </div>
      ))}
    </Shot>
  );
};

// ------------------------------------------------------------------ 3–4.7 s: snap it

const Snap: React.FC = () => {
  const F = useF();
  const t = useS();
  const vw = 900 * F.ks, vh = 1180 * F.ky;
  const lock = p(t, 3.4, 4.2, easeInOut);
  const corner = (rx: number, ry: number) => (
    <div style={{ position: "absolute", left: rx ? undefined : 0, right: rx ? 0 : undefined, top: ry ? undefined : 0, bottom: ry ? 0 : undefined, width: 90, height: 90, borderColor: "#fff", borderStyle: "solid", borderWidth: `${ry ? 0 : 8}px ${rx ? 8 : 0}px ${ry ? 8 : 0}px ${rx ? 0 : 8}px`, borderRadius: 20 }} />
  );
  return (
    <Shot a={3.0} b={4.75}>
      <KText text="Just *snap it.*" at={3.02} y={F.cy - 770 * F.ky} size={120} color="#fff" accent={SKY} serifScale={1.15} />
      <div style={{ position: "absolute", left: F.cx - vw / 2, top: F.cy - vh / 2 + 80 * F.ky, width: vw, height: vh, borderRadius: 50, overflow: "hidden", background: "#1d2433", boxShadow: "0 50px 100px -40px rgba(0,0,0,.9)" }}>
        <div style={{ position: "absolute", inset: 0, background: "radial-gradient(ellipse at 50% 40%, #4b4436, #1e1b16 80%)" }} />
        <Paper x={vw / 2} y={vh * 0.45} w={vw * 0.86} rot={lerp(-9, 0, lock)} scale={lerp(0.9, 1, lock)} />
        <div style={{ position: "absolute", left: vw * 0.06, right: vw * 0.06, top: vh * 0.16, bottom: vh * 0.32, transform: `scale(${lerp(1.12, 1, lock)})`, opacity: 0.95 }}>
          {corner(0, 0)}{corner(1, 0)}{corner(0, 1)}{corner(1, 1)}
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, top: vh * 0.07, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 30 * F.ks, color: lock > 0.95 ? "#7CF0A9" : "#fff" }}>{lock > 0.95 ? "Question found ✓" : "Point at the question"}</div>
        <div style={{ position: "absolute", left: vw / 2 - 66, bottom: vh * 0.06, width: 132, height: 132, borderRadius: 99, border: "8px solid #fff", display: "grid", placeItems: "center" }}>
          <div style={{ width: 100, height: 100, borderRadius: 99, background: "#fff", transform: `scale(${t > 4.45 && t < 4.6 ? 0.82 : 1})` }} />
        </div>
      </div>
      <Flash at={4.55} max={0.95} dur={0.3} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 4.7–9.2 s: step by step

const Header: React.FC<{ y: number }> = ({ y }) => {
  const F = useF();
  return (
    <div style={{ position: "absolute", left: F.cx - 450 * F.ks, top: y, width: 900 * F.ks, display: "flex", alignItems: "center", gap: 18 }}>
      <div style={{ width: 70 * F.ks, height: 70 * F.ks, borderRadius: 22, background: C.gold, display: "grid", placeItems: "center" }}><Ico n="sparkle" size={42 * F.ks} color={C.navy} fill={C.navy} /></div>
      <div style={{ fontFamily: FONT }}>
        <div style={{ fontWeight: 800, fontSize: 40 * F.ks, color: "#fff" }}>SolutionTee AI</div>
        <div style={{ fontWeight: 600, fontSize: 27 * F.ks, color: "#7CF0A9" }}>● Online · explains step by step</div>
      </div>
    </div>
  );
};

const Steps: React.FC = () => {
  const F = useF();
  const t = useS();
  const w = 900 * F.ks;
  const x = F.cx - w / 2;
  const steps: [string, string, number][] = [
    ["Add 8 to both sides", "2x² = 8", 6.0],
    ["Divide both sides by 2", "x² = 4", 6.75],
    ["Take the square root", "x = 2  or  x = −2", 7.5],
  ];
  return (
    <Shot a={4.7} b={9.2}>
      <KText text="Step by step. / *Like a patient teacher.*" at={4.75} y={F.cy - 770 * F.ky} size={86} color="#fff" accent={SKY} />
      <Header y={F.cy - 590 * F.ky} />
      <div style={{ position: "absolute", left: x + w * 0.42, top: F.cy - 450 * F.ky, width: w * 0.58, transform: `scale(${spr(t, 4.85, { damping: 13 })})`, transformOrigin: "100% 0" }}>
        <div style={{ background: C.blue, borderRadius: 30, borderBottomRightRadius: 8, padding: 14, boxShadow: "0 24px 50px -24px rgba(0,0,0,.7)" }}>
          <div style={{ height: 150 * F.ks, borderRadius: 20, overflow: "hidden", position: "relative", background: "#FFFDF6" }}>
            <div style={{ position: "absolute", left: 18, top: 16, fontFamily: SERIF, fontStyle: "italic", fontSize: 46 * F.ks, color: C.navy }}>Solve 2x² − 8 = 0</div>
          </div>
          <div style={{ fontFamily: FONT, fontWeight: 600, fontSize: 32 * F.ks, color: "#fff", padding: "14px 10px 4px" }}>Help me with this one</div>
        </div>
      </div>
      <div style={{ position: "absolute", left: x, top: F.cy - 170 * F.ky, width: w * 0.92, opacity: p(t, 5.3, 5.5), transform: `translateY(${(1 - p(t, 5.3, 5.6)) * 40}px)` }}>
        <div style={{ background: "#13224A", border: "1.5px solid rgba(255,255,255,.12)", borderRadius: 34, borderBottomLeftRadius: 8, padding: `${30 * F.ks}px ${34 * F.ks}px`, fontFamily: FONT, color: "#fff" }}>
          <TypeLine at={5.35} text="Let's solve it together. Three steps:" cps={45} style={{ fontWeight: 700, fontSize: 36 * F.ks }} />
          {steps.map(([how, math, at], i) => {
            const k = spr(t, at, { damping: 13 });
            const done = i === 2 && t > at + 0.55;
            return (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 20, marginTop: 24 * F.ks, opacity: Math.min(1, k * 2), transform: `translateX(${(1 - k) * -60}px)` }}>
                <div style={{ width: 56 * F.ks, height: 56 * F.ks, borderRadius: 99, background: done ? "#22C55E" : C.gold, color: C.navy, display: "grid", placeItems: "center", fontWeight: 800, fontSize: 30 * F.ks, flexShrink: 0 }}>{done ? "✓" : i + 1}</div>
                <div>
                  <div style={{ fontWeight: 600, fontSize: 28 * F.ks, color: "#AFC0DD" }}>{how}</div>
                  <div style={{ fontFamily: SERIF, fontStyle: "italic", fontSize: 60 * F.ks, color: done ? "#7CF0A9" : "#fff", lineHeight: 1.1 }}>{math}</div>
                </div>
              </div>
            );
          })}
          <div style={{ marginTop: 26 * F.ks, padding: "12px 20px", borderRadius: 18, background: "rgba(124,240,169,.12)", color: "#7CF0A9", fontWeight: 800, fontSize: 32 * F.ks, opacity: p(t, 8.2, 8.4) }}>Answer: B. ±2</div>
        </div>
      </div>
    </Shot>
  );
};

// ------------------------------------------------------------------ 9.2–11.8 s: ask again

const AskAgain: React.FC = () => {
  const F = useF();
  const t = useS();
  const w = 900 * F.ks;
  const x = F.cx - w / 2;
  return (
    <Shot a={9.2} b={11.8}>
      <KText text="Still confused? / *Ask again.*" at={9.25} y={F.cy - 720 * F.ky} size={104} color="#fff" accent={SKY} />
      <Header y={F.cy - 470 * F.ky} />
      <Bubble at={9.55} me x={x} y={F.cy - 300 * F.ky} w={w}><TypeLine at={9.6} text="Why are there two answers?" cps={30} /></Bubble>
      <Bubble at={10.55} dark x={x} y={F.cy - 110 * F.ky} w={w * 1.12}>
        <TypeLine at={10.6} text="Because (−2)² is also 4. Squaring removes the minus sign, so both 2 and −2 work. Check: 2(−2)² − 8 = 0 ✓" cps={70} />
      </Bubble>
    </Shot>
  );
};

// ------------------------------------------------------------------ 11.8–14 s: every subject

const SUBJECTS = ["Mathematics", "Physics", "Chemistry", "Biology", "Use of English", "Economics", "Government", "Literature", "Geography", "Commerce", "CRS", "Accounting"];

const Every: React.FC = () => {
  const F = useF();
  const t = useS();
  const core = spr(t, 11.85, { damping: 10 });
  return (
    <Shot a={11.8} b={14.0}>
      <div style={{ position: "absolute", left: F.cx - 110 * F.ks, top: F.cy - 110 * F.ks, width: 220 * F.ks, height: 220 * F.ks, borderRadius: 70, background: `linear-gradient(135deg,${C.gold},#FFD27A)`, display: "grid", placeItems: "center", transform: `scale(${core}) rotate(${(1 - core) * 90}deg)`, boxShadow: "0 0 120px rgba(242,178,51,.55)" }}>
        <Ico n="sparkle" size={130 * F.ks} color={C.navy} fill={C.navy} />
      </div>
      {SUBJECTS.map((s, i) => {
        const ring = i % 2 ? 1 : 0.74;
        const ang = (i / SUBJECTS.length) * Math.PI * 2 + (t - 11.8) * 0.4;
        const k = spr(t, 11.9 + i * 0.05, { damping: 12 });
        const rx = 420 * F.ks * ring * k, ry = 640 * F.ky * ring * k;
        return (
          <div key={s} style={{ position: "absolute", left: F.cx + Math.cos(ang) * rx, top: F.cy + Math.sin(ang) * ry, transform: "translate(-50%,-50%)", padding: `${14 * F.ks}px ${26 * F.ks}px`, borderRadius: 99, background: i % 3 === 0 ? C.blue : "rgba(255,255,255,.1)", border: "1.5px solid rgba(255,255,255,.2)", fontFamily: FONT, fontWeight: 700, fontSize: 32 * F.ks, color: "#fff", whiteSpace: "nowrap", opacity: Math.min(1, k * 2) }}>
            {s}
          </div>
        );
      })}
      <KText text="Every subject." at={12.2} y={F.cy - 820 * F.ky} size={104} color="#fff" />
      <KText text="*Any time.*" at={12.45} y={F.cy + 820 * F.ky} size={130} color="#fff" accent={SKY} serifScale={1} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 14–16 s: the real screen

const Real: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 14.0, { damping: 15, stiffness: 100 });
  const pw = 580 * F.ks * (F.tall ? 1 : 0.8);
  return (
    <Shot a={14.0} b={16.1}>
      <KText text="Your *AI tutor,* / in your pocket." at={14.05} y={F.cy - 740 * F.ky} size={96} color="#fff" accent="#FFD27A" />
      <Phone src="screens/ai.jpg" width={pw} x={F.cx} y={F.cy + 180 * F.ky + (1 - k) * 900} rx={8} ry={lerp(-26, -12, k)} rz={lerp(-6, -2, k)} />
      <Pill x={F.cx - 290 * F.ks} y={F.cy - 160 * F.ky} at={14.5} icon="camera">Snap or type</Pill>
      <Pill x={F.cx + 260 * F.ks} y={F.cy + 260 * F.ky} at={14.75} bg={C.gold} icon="sparkle">Free questions daily</Pill>
      <Pill x={F.cx - 250 * F.ks} y={F.cy + 640 * F.ky} at={15.0} bg="#22C55E" fg="#fff" icon="check">Explained simply</Pill>
    </Shot>
  );
};

export const FeatAI: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/feat_ai.wav")} />
    <DeepStage />
    <Hook />
    <Alone />
    <Snap />
    <Steps />
    <AskAgain />
    <Every />
    <Real />
    <End />
  </AbsoluteFill>
);

const End: React.FC = () => {
  const t = useS();
  if (t < 15.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 15.95, 16.25) }}>
      <EndCard at={16.0} cta="Try the AI tutor free" />
    </AbsoluteFill>
  );
};

void rnd;
void easeOut;
